import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/fa_number.dart';
import '../core/utils/jalali_date.dart';
import '../core/utils/price_display.dart';
import '../data/cache/local_state_store.dart';
import '../domain/entities/price_quote.dart';

/// Where the widget payload goes. The plugin in the app; a recorder in
/// tests, so "nothing was written" is something a test can actually check.
abstract interface class HomeWidgetSink {
  /// A null value removes the key, so the widget falls back to «—».
  Future<void> save(String key, String? value);
  Future<void> redraw();
}

class _PluginSink implements HomeWidgetSink {
  const _PluginSink();

  @override
  Future<void> save(String key, String? value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> redraw() =>
      HomeWidget.updateWidget(androidName: HomeWidgetService.androidName);
}

/// HOME SCREEN WIDGET.
///
/// Publishes a few headline prices to the Android home screen so the
/// common case — "what is the dollar at?" — costs no app launch.
///
/// The widget renders only what was last written and always carries its
/// own «به‌روزرسانی» line, so a widget the OS has not refreshed in hours
/// says so instead of passing stale numbers off as current.
abstract final class HomeWidgetService {
  static const androidName = 'MolidoWidgetProvider';

  /// Persisted opt-in, mirroring the background alert switch.
  static const enabledKey = 'home_widget_enabled';

  /// The three the widget has room for.
  static const assets = <String, String>{
    'ir_usd': 'w_usd',
    'gold_18k': 'w_gold',
    'coin_emami': 'w_coin',
  };

  static const updatedKey = 'w_updated';

  @visibleForTesting
  static HomeWidgetSink sink = const _PluginSink();

  /// What was last handed to the widget. The foreground engine publishes
  /// every check (2 s); rewriting identical values each time only burns
  /// platform-channel calls and widget redraws.
  static Map<String, String?>? _lastWritten;

  @visibleForTesting
  static void resetForTest() {
    _lastWritten = null;
    sink = const _PluginSink();
  }

  static Future<bool> isEnabled(KeyValueStore store) async =>
      (await store.getString(enabledKey)) == '1';

  static Future<void> setEnabled(KeyValueStore store, bool value) =>
      store.setString(enabledKey, value ? '1' : '0');

  /// Formats one quote the way the widget shows it: Toman, Persian digits.
  ///
  /// The denomination comes from [PriceDisplay.unitOf], never from
  /// [PriceQuote.currency] alone: a USD-quoted asset is converted with the
  /// same real [rate] the app displays with, and anything that cannot be
  /// expressed in Toman is shown in its own unit rather than as a made-up
  /// Toman figure.
  @visibleForTesting
  static String format(PriceQuote quote, {TomanRate? rate}) {
    final toman = PriceDisplay.toman(quote, rate);
    if (toman != null) {
      return '${PriceDisplay.tomanText(toman)} ${PriceDisplay.tomanUnit}';
    }
    // [PriceQuote.currency] names the asset ('EUR' for fx_eur), not what
    // the number is in, so a USD-quoted price is labelled as dollars.
    final unit = PriceDisplay.unitOf(quote) == QuoteUnit.usd
        ? 'دلار'
        : (quote.unit.isNotEmpty ? quote.unit : quote.currency);
    return '${quote.price.faPrice(fraction: quote.price < 1000 ? 2 : 0)} $unit';
  }

  /// The «به‌روزرسانی HH:MM» line, from the source's own timestamp. A time
  /// from an earlier day says which day, so last night's close is not read
  /// as this afternoon's price.
  @visibleForTesting
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

  /// The time line for the quotes actually on the widget.
  ///
  /// It carries the OLDEST shown time: every number on the widget is at
  /// least that fresh, whereas the newest time would vouch for rows it says
  /// nothing about. A previous-session close is stamped at midnight — a
  /// date, not a publish time — so it never sets the clock; it is named
  /// instead.
  @visibleForTesting
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

  /// The key/value payload for a set of quotes. Assets with no usable
  /// quote are left out entirely rather than written as a stale or made
  /// up number.
  @visibleForTesting
  static Map<String, String> payload(
    Map<String, PriceQuote> quotes, {
    DateTime? nowUtc,
  }) {
    final rate = PriceDisplay.rateFrom(
      freeMarket: quotes['ir_usd'],
      tether: quotes['usdt_irt'],
      official: quotes['fx_irr'],
    );
    final out = <String, String>{};
    final shown = <PriceQuote>[];
    for (final entry in assets.entries) {
      final q = quotes[entry.key];
      if (q == null || q.price <= 0 || !q.status.isDisplayable) continue;
      out[entry.value] = format(q, rate: rate);
      shown.add(q);
    }
    if (out.isEmpty) return out;
    out[updatedKey] = timeLine(shown, nowUtc: nowUtc);
    return out;
  }

  /// Everything one publish writes. An asset missing from [payload] is
  /// written as null — removed — so the widget shows «—» for it instead of
  /// keeping the previous cycle's number under this cycle's time line.
  @visibleForTesting
  static Map<String, String?> writes(
    Map<String, PriceQuote> quotes, {
    DateTime? nowUtc,
  }) {
    final data = payload(quotes, nowUtc: nowUtc);
    if (data.isEmpty) return const {};
    return {
      for (final key in assets.values) key: data[key],
      updatedKey: data[updatedKey],
    };
  }

  /// Writes the payload and asks Android to redraw. Safe to call often;
  /// a no-op when the user has not enabled the widget or nothing changed.
  static Future<void> publish(
    KeyValueStore store,
    Map<String, PriceQuote> quotes,
  ) async {
    if (!await isEnabled(store)) return;
    final data = writes(quotes);
    if (data.isEmpty) return;
    if (mapEquals(data, _lastWritten)) return;
    try {
      for (final e in data.entries) {
        await sink.save(e.key, e.value);
      }
      await sink.redraw();
      _lastWritten = data;
    } catch (e) {
      // A missing widget host must never take the app down.
      debugPrint('[widget] $e');
    }
  }
}
