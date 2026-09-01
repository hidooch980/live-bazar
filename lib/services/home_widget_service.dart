import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/fa_number.dart';
import '../core/utils/price_display.dart';
import '../data/cache/local_state_store.dart';
import '../domain/entities/price_quote.dart';

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

  static Future<bool> isEnabled(KeyValueStore store) async =>
      (await store.getString(enabledKey)) == '1';

  static Future<void> setEnabled(KeyValueStore store, bool value) =>
      store.setString(enabledKey, value ? '1' : '0');

  /// Formats one quote the way the widget shows it: Toman, Persian digits.
  @visibleForTesting
  static String format(PriceQuote quote) {
    final toman = quote.currency == 'IRR'
        ? quote.price
        : quote.price / PriceDisplay.rialPerToman;
    return '${PriceDisplay.tomanText(toman)} ${PriceDisplay.tomanUnit}';
  }

  /// The «به‌روزرسانی HH:MM» line, from the source's own timestamp.
  @visibleForTesting
  static String updatedLabel(DateTime timestamp, {DateTime? nowUtc}) {
    final local = timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'به‌روزرسانی $hh:$mm'.faString;
  }

  /// The key/value payload for a set of quotes. Assets with no usable
  /// quote are left out entirely rather than written as a stale or made
  /// up number.
  @visibleForTesting
  static Map<String, String> payload(Map<String, PriceQuote> quotes) {
    final out = <String, String>{};
    DateTime? newest;
    for (final entry in assets.entries) {
      final q = quotes[entry.key];
      if (q == null || q.price <= 0 || !q.status.isDisplayable) continue;
      out[entry.value] = format(q);
      if (newest == null || q.timestamp.isAfter(newest)) newest = q.timestamp;
    }
    if (out.isEmpty) return out;
    out['w_updated'] = updatedLabel(newest!);
    return out;
  }

  /// Writes the payload and asks Android to redraw. Safe to call often;
  /// a no-op when the user has not enabled the widget.
  static Future<void> publish(
    KeyValueStore store,
    Map<String, PriceQuote> quotes,
  ) async {
    if (!await isEnabled(store)) return;
    final data = payload(quotes);
    if (data.isEmpty) return;
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(androidName: androidName);
    } catch (e) {
      // A missing widget host must never take the app down.
      debugPrint('[widget] $e');
    }
  }
}
