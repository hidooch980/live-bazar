import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/asset_catalog.dart';
import '../core/utils/fa_number.dart';
import '../core/utils/jalali_date.dart';
import '../core/utils/price_display.dart';
import '../data/cache/local_state_store.dart';
import '../domain/entities/price_quote.dart';
import 'widget/widget_data_store.dart';

export 'widget/widget_data_store.dart';

/// How the widget stays fresh while the app is closed.
enum WidgetRefreshMode {
  /// Default: the 15-minute worker, plus a throttled refresh when the
  /// user unlocks the phone.
  lowPower,

  /// Opt-in: a foreground service with a persistent notification
  /// refreshes every few seconds, within each provider's rate limit.
  live;

  static WidgetRefreshMode parse(String? raw) =>
      raw == live.name ? live : lowPower;
}

/// What the widget shows and how it refreshes. Lives in Hive (the source
/// of truth, part of the app's local state) and is MIRRORED into the
/// widget's own key space so background isolates never open Hive.
@immutable
class WidgetConfig {
  const WidgetConfig({
    required this.enabled,
    required this.ids,
    this.mode = WidgetRefreshMode.lowPower,
  });

  final bool enabled;
  final List<String> ids;
  final WidgetRefreshMode mode;

  static const disabled = WidgetConfig(
    enabled: false,
    ids: HomeWidgetService.defaultAssets,
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetConfig &&
      other.enabled == enabled &&
      other.mode == mode &&
      listEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(enabled, mode, Object.hashAll(ids));
}

/// One rendered row, exactly as the Android widget draws it.
@immutable
class WidgetRow {
  const WidgetRow({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.change,
    required this.direction,
    required this.glyph,
    required this.tone,
    required this.spark,
    required this.stale,
  });

  final String id;
  final String label;
  final String subtitle;

  /// Persian-digit number, without its unit.
  final String value;
  final String unit;

  /// «▲ ۰٫۴۲٪», or empty when the source published no change.
  final String change;

  /// 1 up, -1 down, 0 none.
  final int direction;
  final String glyph;
  final String tone;

  /// Normalized 0..1 points («0.10,0.52,…»), or empty: only drawn from
  /// real observations, never interpolated.
  final String spark;

  /// The value is not current (market closed, refresh failed, old print).
  final bool stale;

  Map<String, Object> toJson() => {
    'id': id,
    'l': label,
    's': subtitle,
    'v': value,
    'u': unit,
    'c': change,
    'd': direction,
    'g': glyph,
    't': tone,
    'k': spark,
    'st': stale ? 1 : 0,
  };

  static WidgetRow fromJson(Map<String, dynamic> j) => WidgetRow(
    id: j['id'] as String,
    label: j['l'] as String,
    subtitle: j['s'] as String,
    value: j['v'] as String,
    unit: j['u'] as String,
    change: j['c'] as String,
    direction: (j['d'] as num).toInt(),
    glyph: j['g'] as String,
    tone: j['t'] as String,
    spark: j['k'] as String,
    stale: j['st'] == 1,
  );
}

/// HOME SCREEN WIDGET.
///
/// Publishes the user's chosen prices (up to [maxAssets], in their order)
/// to the Android home screen in three sizes: small shows the first, medium
/// the first three, large all six.
///
/// The widget renders only what was last written and always carries its
/// own «به‌روزرسانی» line, so a widget the OS has not refreshed in hours
/// says so instead of passing stale numbers off as current.
abstract final class HomeWidgetService {
  static const androidName = 'MolidoWidgetProvider';

  /// Persisted opt-in.
  static const enabledKey = 'home_widget_enabled';

  /// Ordered CSV of asset ids. Absent = [defaultAssets], so a user who
  /// never chose sees exactly the 0.4.0 widget and gets future defaults.
  static const selectionKey = 'home_widget_assets';
  static const modeKey = 'home_widget_refresh_mode';

  static const maxAssets = 6;
  static const defaultAssets = <String>['ir_usd', 'gold_18k', 'coin_emami'];

  // ---- keys in the widget's own space -----------------------------------
  static const cfgEnabledKey = 'cfg_enabled';
  static const cfgIdsKey = 'cfg_ids';
  static const cfgModeKey = 'cfg_mode';
  static const cfgProxyKey = 'cfg_proxy';
  static const rowsKey = 'w_rows';
  static const updatedKey = 'w_updated';
  static const liveKey = 'w_live';
  static const versionKey = 'w_v';
  static const seriesKey = 'w_series';

  /// The 0.4.0–0.6.x keys. Written as null so an old layout can never show
  /// a number this version no longer maintains.
  static const legacyKeys = ['w_usd', 'w_gold', 'w_coin'];

  /// Swapped for [MemoryWidgetDataStore] in tests.
  static WidgetDataStore data = const PluginWidgetDataStore();

  static Map<String, String?>? _lastWritten;
  static WidgetConfig? _cachedConfig;
  static Map<String, List<List<num>>>? _series;

  @visibleForTesting
  static void resetForTest() {
    _lastWritten = null;
    _cachedConfig = null;
    _series = null;
    data = const PluginWidgetDataStore();
  }

  // ---- preferences (Hive) ------------------------------------------------

  static Future<bool> isEnabled(KeyValueStore store) async =>
      (await store.getString(enabledKey)) == '1';

  static Future<void> setEnabled(KeyValueStore store, bool value) async {
    await store.setString(enabledKey, value ? '1' : '0');
    await _changed(store);
  }

  /// Drops unknown, disabled, duplicate and unconvertible ids and caps at
  /// [maxAssets]. Nothing left means [defaultAssets]: a selection that an
  /// update made empty falls back instead of drawing an empty widget.
  static List<String> sanitize(Iterable<String> ids) {
    final out = <String>[];
    for (final raw in ids) {
      final id = raw.trim();
      final def = AssetCatalog.byId(id);
      if (def == null || !def.enabled || id == 'fx_irr') continue;
      if (out.contains(id)) continue;
      out.add(id);
      if (out.length == maxAssets) break;
    }
    return out.isEmpty ? List.of(defaultAssets) : out;
  }

  static Future<List<String>> loadSelection(KeyValueStore store) async {
    final raw = await store.getString(selectionKey);
    if (raw == null || raw.trim().isEmpty) return List.of(defaultAssets);
    return sanitize(raw.split(','));
  }

  static Future<void> saveSelection(
    KeyValueStore store,
    List<String> ids,
  ) async {
    await store.setString(selectionKey, sanitize(ids).join(','));
    await _changed(store);
  }

  /// Back to the shipped defaults: the key is removed, not overwritten, so
  /// a future default reaches users who asked for "default".
  static Future<void> resetSelection(KeyValueStore store) async {
    await store.remove(selectionKey);
    await _changed(store);
  }

  static Future<WidgetRefreshMode> loadMode(KeyValueStore store) async =>
      WidgetRefreshMode.parse(await store.getString(modeKey));

  static Future<void> saveMode(
    KeyValueStore store,
    WidgetRefreshMode mode,
  ) async {
    await store.setString(modeKey, mode.name);
    await _changed(store);
  }

  static Future<WidgetConfig> loadConfig(KeyValueStore store) async =>
      WidgetConfig(
        enabled: await isEnabled(store),
        ids: await loadSelection(store),
        mode: await loadMode(store),
      );

  static Future<void> _changed(KeyValueStore store) async {
    _cachedConfig = null;
    _lastWritten = null;
    await mirrorConfig(store);
  }

  /// Copies the config (and the user's proxy, which background fetches
  /// need too) into the widget's key space.
  static Future<void> mirrorConfig(KeyValueStore store) async {
    final c = await loadConfig(store);
    try {
      await data.save(cfgEnabledKey, c.enabled ? '1' : '0');
      await data.save(cfgIdsKey, c.ids.join(','));
      await data.save(cfgModeKey, c.mode.name);
      await data.save(cfgProxyKey, await store.getString('proxy_config'));
    } catch (e) {
      debugPrint('[widget] mirror: $e');
    }
  }

  /// The config as background isolates see it.
  static Future<WidgetConfig> readMirroredConfig() async {
    try {
      final ids = await data.read(cfgIdsKey);
      return WidgetConfig(
        enabled: await data.read(cfgEnabledKey) == '1',
        ids: ids == null || ids.isEmpty
            ? List.of(defaultAssets)
            : sanitize(ids.split(',')),
        mode: WidgetRefreshMode.parse(await data.read(cfgModeKey)),
      );
    } catch (_) {
      return WidgetConfig.disabled;
    }
  }

  /// Ids that must also be fetched so the selection can be shown in Toman.
  /// The free-market dollar and Tether both come from the one TGJU fetch
  /// the Iranian rows already cost.
  static Set<String> rateDependencies(Iterable<String> ids) {
    final needsRate = ids.any((id) {
      final def = AssetCatalog.byId(id);
      if (def == null) return false;
      return def.category == AssetCategory.currency ||
          (def.currency == 'USD' && def.category != AssetCategory.marketIndex);
    });
    return needsRate ? const {'ir_usd', 'usdt_irt'} : const {};
  }

  // ---- formatting ----------------------------------------------------------

  /// The number and its unit, separately, so the widget can set the number
  /// big and the unit small.
  ///
  /// The denomination comes from [PriceDisplay.unitOf], never from
  /// [PriceQuote.currency] alone.
  static (String, String) formatParts(PriceQuote quote, {TomanRate? rate}) {
    final toman = PriceDisplay.toman(quote, rate);
    if (toman != null) {
      return (PriceDisplay.tomanText(toman), PriceDisplay.tomanUnit);
    }
    final unit = PriceDisplay.unitOf(quote) == QuoteUnit.usd
        ? 'دلار'
        : (quote.unit.isNotEmpty ? quote.unit : quote.currency);
    return (quote.price.faPrice(fraction: quote.price < 1000 ? 2 : 0), unit);
  }

  @visibleForTesting
  static String format(PriceQuote quote, {TomanRate? rate}) {
    final (v, u) = formatParts(quote, rate: rate);
    return '$v $u';
  }

  /// «▲ ۰٫۴۲٪» from the source's own change metric; empty when it has none.
  static String changeLabel(double pct) {
    if (pct == 0 || !pct.isFinite) return '';
    final arrow = pct > 0 ? '▲' : '▼';
    final text = pct.abs().toStringAsFixed(2).replaceAll('.', '٫');
    return '$arrow $text٪'.faString;
  }

  /// The «به‌روزرسانی HH:MM» line, from the source's own timestamp. A time
  /// from an earlier day says which day.
  static String updatedLabel(DateTime timestamp, {DateTime? nowUtc}) {
    final local = timestamp.toLocal();
    final now = (nowUtc ?? DateTime.now().toUtc()).toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysAgo = today.difference(day).inDays;
    final String when;
    if (daysAgo <= 0) {
      when = '$hh:$mm';
    } else if (daysAgo == 1) {
      when = 'دیروز $hh:$mm';
    } else {
      final j = JalaliDate.fromGregorian(day);
      when = '${j.day} ${j.monthFa} $hh:$mm';
    }
    return 'به‌روزرسانی $when'.faString;
  }

  /// The time line for the quotes actually on the widget: the OLDEST shown
  /// time, so it never vouches for a row fresher than it is. A previous
  /// session's close is stamped at midnight — a date, not a publish time —
  /// so it never sets the clock; it is named instead.
  static String timeLine(Iterable<PriceQuote> shown, {DateTime? nowUtc}) {
    final timed = shown
        .where((q) => q.status != QuoteStatus.previousClose)
        .toList();
    final hasClose = timed.length != shown.length;
    if (timed.isEmpty) return 'قیمت پایانی بازار';
    final oldest = timed
        .map((q) => q.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final label = updatedLabel(oldest, nowUtc: nowUtc);
    return hasClose ? '$label · برخی پایانی' : label;
  }

  /// Icon glyph and colour tone per asset, as in the approved mockup.
  static (String, String) iconFor(String id, AssetCategory category) {
    if (id.endsWith('_usd') && id.startsWith('ir_') || id == 'fx_usd') {
      return (r'$', 'green');
    }
    if (id.startsWith('usdt')) return ('₮', 'teal');
    if (id.endsWith('_eur')) return ('€', 'blue');
    if (id.endsWith('_gbp')) return ('£', 'blue');
    if (id == 'btc_usd') return ('₿', 'orange');
    if (id == 'eth_usd') return ('Ξ', 'purple');
    if (id == 'xau_usd') return ('oz', 'gold');
    if (id == 'silver') return ('oz', 'silver');
    switch (category) {
      case AssetCategory.coin:
        return ('★', 'gold');
      case AssetCategory.gold:
        return ('▬', 'gold');
      case AssetCategory.marketIndex:
        return ('▲', 'purple');
      case AssetCategory.commodity:
        return ('◆', 'silver');
      default:
        final def = AssetCatalog.byId(id);
        final code = (def?.symbol ?? id).split('/').first;
        return (code.length > 3 ? code.substring(0, 3) : code, 'purple');
    }
  }

  /// «دلار آمریکا (بازار آزاد)» → («دلار آمریکا», «بازار آزاد»).
  static (String, String) labelFor(
    String nameFa,
    AssetCategory category, {
    String id = '',
  }) {
    final open = nameFa.indexOf(' (');
    if (open > 0) {
      final rest = nameFa
          .substring(open + 1)
          .replaceAll('(', '')
          .replaceAll(')', '')
          .trim();
      return (nameFa.substring(0, open), rest);
    }
    final sub = switch (category) {
      _ when nameFa.contains('انس') => 'جهانی',
      _ when id == 'mesghal' => 'هر مثقال',
      AssetCategory.gold when id.startsWith('gold_abshodeh') => 'نقدی',
      AssetCategory.gold => 'هر گرم',
      AssetCategory.coin => 'سکه',
      AssetCategory.crypto => 'کریپتو',
      AssetCategory.currency => 'نرخ جهانی',
      AssetCategory.marketIndex => 'بورس تهران',
      AssetCategory.commodity || AssetCategory.global => 'جهانی',
      _ => 'بازار آزاد',
    };
    return (nameFa, sub);
  }

  static bool _usable(PriceQuote? q) =>
      q != null && q.price > 0 && q.status.isDisplayable;

  static bool _isStale(PriceQuote q, DateTime nowUtc) =>
      q.status == QuoteStatus.stale ||
      q.status == QuoteStatus.delayed ||
      q.status == QuoteStatus.previousClose ||
      q.status == QuoteStatus.cached ||
      nowUtc.difference(q.timestamp.toUtc()) > const Duration(minutes: 30);

  // ---- sparkline series (real observations only) ---------------------------

  /// One point per 30-minute bucket of the SOURCE timestamp, last 24 h.
  static const seriesBucketMinutes = 30;
  static const seriesMaxPoints = 48;

  /// Adds the usable quotes to [series] (id → [[bucket, price], …]).
  /// Returns true when anything changed.
  @visibleForTesting
  static bool updateSeries(
    Map<String, List<List<num>>> series,
    Map<String, PriceQuote> quotes,
    Iterable<String> ids, {
    required DateTime nowUtc,
  }) {
    var changed = false;
    final oldest =
        nowUtc.subtract(const Duration(hours: 24)).millisecondsSinceEpoch ~/
        60000 ~/
        seriesBucketMinutes;
    for (final id in ids) {
      final q = quotes[id];
      if (!_usable(q) || q!.status == QuoteStatus.previousClose) continue;
      final bucket =
          q.timestamp.toUtc().millisecondsSinceEpoch ~/
          60000 ~/
          seriesBucketMinutes;
      final list = series.putIfAbsent(id, () => []);
      if (list.isNotEmpty && list.last[0] > bucket) continue; // out of order
      if (list.isNotEmpty && list.last[0] == bucket) {
        if (list.last[1] != q.price) {
          list.last = [bucket, q.price];
          changed = true;
        }
      } else {
        list.add([bucket, q.price]);
        changed = true;
      }
      final before = list.length;
      list.removeWhere((p) => p[0] < oldest);
      if (list.length > seriesMaxPoints) {
        list.removeRange(0, list.length - seriesMaxPoints);
      }
      if (list.length != before) changed = true;
    }
    series.removeWhere((id, _) => !ids.contains(id));
    return changed;
  }

  /// Buckets real in-app history (the detail-chart series) the same way,
  /// for the settings preview.
  static List<List<num>> seriesFromPoints(Iterable<(DateTime, double)> points) {
    final out = <List<num>>[];
    for (final (t, p) in points) {
      if (p <= 0) continue;
      final b =
          t.toUtc().millisecondsSinceEpoch ~/ 60000 ~/ seriesBucketMinutes;
      if (out.isNotEmpty && out.last[0] == b) {
        out.last = [b, p];
      } else if (out.isEmpty || out.last[0] < b) {
        out.add([b, p]);
      }
    }
    return out.length > seriesMaxPoints
        ? out.sublist(out.length - seriesMaxPoints)
        : out;
  }

  /// Normalized points for drawing; empty with fewer than two real points.
  @visibleForTesting
  static String sparkOf(List<List<num>>? points) {
    if (points == null || points.length < 2) return '';
    final prices = [for (final p in points) p[1].toDouble()];
    final lo = prices.reduce((a, b) => a < b ? a : b);
    final hi = prices.reduce((a, b) => a > b ? a : b);
    final span = hi - lo;
    return [
      for (final p in prices)
        (span == 0 ? 0.5 : (p - lo) / span).toStringAsFixed(2),
    ].join(',');
  }

  // ---- payload -------------------------------------------------------------

  /// The rows for [ids], in order. Unusable quotes are left out entirely
  /// rather than written as a stale or made-up number.
  static List<WidgetRow> rows(
    Map<String, PriceQuote> quotes,
    List<String> ids, {
    Map<String, List<List<num>>> series = const {},
    DateTime? nowUtc,
  }) {
    final now = nowUtc ?? DateTime.now().toUtc();
    final rate = PriceDisplay.rateFrom(
      freeMarket: quotes['ir_usd'],
      tether: quotes['usdt_irt'],
      official: quotes['fx_irr'],
    );
    return [
      for (final id in ids)
        if (_usable(quotes[id])) _row(quotes[id]!, rate, series[id], now),
    ];
  }

  static WidgetRow _row(
    PriceQuote q,
    TomanRate? rate,
    List<List<num>>? series,
    DateTime now,
  ) {
    final def = AssetCatalog.byId(q.id);
    final category = def?.category ?? q.category;
    final (label, subtitle) = labelFor(
      def?.nameFa ?? q.nameFa,
      category,
      id: q.id,
    );
    final (glyph, tone) = iconFor(q.id, category);
    final (value, unit) = formatParts(q, rate: rate);
    return WidgetRow(
      id: q.id,
      label: label,
      subtitle: subtitle,
      value: value,
      unit: unit,
      change: changeLabel(q.changePercent),
      direction: q.changePercent > 0
          ? 1
          : q.changePercent < 0
          ? -1
          : 0,
      glyph: glyph,
      tone: tone,
      spark: sparkOf(series),
      stale: _isStale(q, now),
    );
  }

  /// Everything one publish writes. Empty when nothing is usable, so the
  /// widget keeps its last honest data and its own old time line.
  @visibleForTesting
  static Map<String, String?> payload(
    Map<String, PriceQuote> quotes,
    List<String> ids, {
    Map<String, List<List<num>>> series = const {},
    bool live = false,
    DateTime? nowUtc,
  }) {
    final r = rows(quotes, ids, series: series, nowUtc: nowUtc);
    if (r.isEmpty) return const {};
    return {
      versionKey: '2',
      rowsKey: jsonEncode([for (final row in r) row.toJson()]),
      updatedKey: timeLine([
        for (final row in r) quotes[row.id]!,
      ], nowUtc: nowUtc),
      liveKey: live ? '1' : '0',
      for (final k in legacyKeys) k: null,
    };
  }

  static Future<Map<String, List<List<num>>>> _loadSeries() async {
    if (_series != null) return _series!;
    final out = <String, List<List<num>>>{};
    try {
      final raw = await data.read(seriesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          out[e.key] = [
            for (final p in e.value as List) [p[0] as num, p[1] as num],
          ];
        }
      }
    } catch (_) {
      // A corrupt series only costs the sparkline.
    }
    return _series = out;
  }

  /// Foreground entry point: called on every engine snapshot. Safe to call
  /// often; a no-op when the widget is off or nothing changed.
  static Future<void> publish(
    KeyValueStore store,
    Map<String, PriceQuote> quotes,
  ) async {
    final config = _cachedConfig ??= await loadConfig(store);
    await publishWith(config, quotes);
  }

  /// Shared by the foreground and every background path.
  static Future<void> publishWith(
    WidgetConfig config,
    Map<String, PriceQuote> quotes, {
    DateTime? nowUtc,
  }) async {
    if (!config.enabled) return;
    final now = nowUtc ?? DateTime.now().toUtc();
    try {
      final series = await _loadSeries();
      final seriesChanged = updateSeries(
        series,
        quotes,
        config.ids,
        nowUtc: now,
      );
      final out = payload(
        quotes,
        config.ids,
        series: series,
        live: config.mode == WidgetRefreshMode.live,
        nowUtc: now,
      );
      if (out.isEmpty) return;
      if (mapEquals(out, _lastWritten)) return;
      for (final e in out.entries) {
        await data.save(e.key, e.value);
      }
      if (seriesChanged) await data.save(seriesKey, jsonEncode(series));
      await data.redraw();
      _lastWritten = out;
    } catch (e) {
      // A missing widget host must never take the app down.
      debugPrint('[widget] $e');
    }
  }
}
