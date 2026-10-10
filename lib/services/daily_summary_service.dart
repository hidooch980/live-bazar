import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../core/utils/fa_number.dart';
import '../core/utils/jalali_date.dart';
import '../data/cache/local_state_store.dart';
import '../domain/entities/price_quote.dart';
import '../providers/adapters/iranian_market_provider.dart';
import '../providers/iprice_provider.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';

/// DAILY MARKET SUMMARY (opt-in, default off).
///
/// Around 20:05 Tehran — after the bazaar has closed for the day — one
/// local notification with the day's REAL change for the dollar, 18K gold
/// and the Emami coin, as the source publishes it. A row the source did
/// not print today (a holiday, a market that never opened) is left out;
/// with nothing left, no notification is sent at all.
abstract final class DailySummaryService {
  static const enabledKey = 'daily_summary_enabled';
  static const lastSentKey = 'daily_summary_last';
  static const taskName = 'molido-daily-summary';
  static const uniqueName = 'molido-daily-summary-next';

  static const assets = <String>['ir_usd', 'gold_18k', 'coin_emami'];

  /// Iran has kept a fixed UTC+03:30 since it dropped DST in 2022 — the
  /// same assumption the TGJU adapter makes for feed timestamps.
  static const tehranOffset = Duration(hours: 3, minutes: 30);
  static const runHour = 20;
  static const runMinute = 5;

  static DateTime toTehran(DateTime utc) => utc.toUtc().add(tehranOffset);

  /// The next 20:05 Tehran strictly after [nowUtc], as UTC.
  @visibleForTesting
  static DateTime nextRunUtc(DateTime nowUtc) {
    final t = toTehran(nowUtc);
    var target = DateTime.utc(t.year, t.month, t.day, runHour, runMinute);
    if (!target.isAfter(t)) target = target.add(const Duration(days: 1));
    return target.subtract(tehranOffset);
  }

  static bool _sameTehranDay(DateTime a, DateTime b) {
    final x = toTehran(a), y = toTehran(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// Title and body, or null when there is nothing real to say today.
  @visibleForTesting
  static ({String title, String body})? compose(
    Map<String, PriceQuote> quotes,
    DateTime nowUtc,
  ) {
    final lines = <String>[];
    for (final id in assets) {
      final q = quotes[id];
      if (q == null || q.price <= 0 || !q.status.isDisplayable) continue;
      // Yesterday's close carries yesterday's change: not today's news.
      if (q.status == QuoteStatus.previousClose) continue;
      if (!_sameTehranDay(q.timestamp, nowUtc)) continue;
      final (label, _) = HomeWidgetService.labelFor(q.nameFa, q.category);
      final (value, unit) = HomeWidgetService.formatParts(q);
      final change = HomeWidgetService.changeLabel(q.changePercent);
      lines.add(
        '$label: $value $unit ${change.isEmpty ? '(بدون تغییر)' : change}',
      );
    }
    if (lines.isEmpty) return null;
    final j = JalaliDate.fromGregorian(toTehran(nowUtc));
    return (
      title:
          'خلاصه بازار امروز — ${j.weekdayFa} ${j.day.faDigits} ${j.monthFa}',
      body: lines.join('\n'),
    );
  }

  /// Only between 20:00 and midnight Tehran: a run WorkManager delayed into
  /// the next morning would report a day that is already over.
  @visibleForTesting
  static bool inWindow(DateTime nowUtc) {
    final t = toTehran(nowUtc);
    return t.hour >= runHour;
  }

  static Future<bool> isEnabled(KeyValueStore store) async =>
      (await store.getString(enabledKey)) == '1';

  static Future<void> setEnabled(KeyValueStore store, bool value) async {
    await store.setString(enabledKey, value ? '1' : '0');
    await restore(store, replace: true);
  }

  /// Re-applied every launch so an OS cleanup cannot silently drop it.
  static Future<void> restore(
    KeyValueStore store, {
    bool replace = false,
  }) async {
    try {
      if (await isEnabled(store)) {
        await schedule(
          policy: replace
              ? ExistingWorkPolicy.replace
              : ExistingWorkPolicy.keep,
        );
      } else {
        await Workmanager().cancelByUniqueName(uniqueName);
      }
    } catch (e) {
      debugPrint('[daily] $e');
    }
  }

  static Future<void> schedule({
    ExistingWorkPolicy policy = ExistingWorkPolicy.keep,
    DateTime? nowUtc,
  }) async {
    final now = nowUtc ?? DateTime.now().toUtc();
    await Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      initialDelay: nextRunUtc(now).difference(now),
      existingWorkPolicy: policy,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// One run: fetch, compose, notify at most once per Tehran day.
  /// Returns true when a notification was shown.
  static Future<bool> run({
    required KeyValueStore store,
    List<IPriceProvider>? providers,
    NotificationService? notifications,
    DateTime? nowUtc,
  }) async {
    final now = nowUtc ?? DateTime.now().toUtc();
    if (!await isEnabled(store)) return false;
    if (!inWindow(now)) return false;
    final today = toTehran(now).toIso8601String().substring(0, 10);
    if (await store.getString(lastSentKey) == today) return false;

    final quotes = <String, PriceQuote>{};
    for (final p in providers ?? [IranianMarketProvider()]) {
      final needed = p.supportedAssets.intersection(assets.toSet());
      if (needed.isEmpty) continue;
      final r = await p.getLatestPrices(needed);
      if (!r.isSuccess) continue;
      for (final q in r.quotes) {
        quotes[q.id] = q;
      }
    }
    final message = compose(quotes, now);
    if (message == null) return false;
    final n = notifications ?? NotificationService();
    await n.init();
    await n.showSummary(title: message.title, body: message.body);
    await store.setString(lastSentKey, today);
    return true;
  }
}
