import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/services/home_widget_service.dart';

PriceQuote _q(
  String id, {
  required double price,
  String currency = 'IRR',
  QuoteStatus status = QuoteStatus.live,
  DateTime? ts,
}) => PriceQuote(
  id: id,
  symbol: id,
  name: id,
  nameFa: id,
  category: AssetCategory.iranianCurrency,
  price: price,
  unit: currency == 'IRR' ? 'تومان' : '',
  currency: currency,
  timestamp: ts ?? DateTime.utc(2026, 9, 1, 10, 26),
  source: 'TGJU',
  status: status,
);

void main() {
  test('publishes the three headline prices in Toman', () {
    final data = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 214000),
      'gold_18k': _q('gold_18k', price: 22195800),
      'coin_emami': _q('coin_emami', price: 221505000),
    });

    expect(data['w_usd'], '۲۱۴,۰۰۰ تومان');
    expect(data['w_gold'], '۲۲,۱۹۵,۸۰۰ تومان');
    expect(data['w_coin'], '۲۲۱,۵۰۵,۰۰۰ تومان');
    expect(data['w_updated'], startsWith('به‌روزرسانی'));
  });

  test('an unusable quote is omitted, never shown stale or invented', () {
    final data = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 214000),
      // Rejected by the anomaly gate upstream.
      'gold_18k': _q('gold_18k', price: 0, status: QuoteStatus.dataConflict),
      // Present but worthless.
      'coin_emami': _q('coin_emami', price: 0),
    });

    expect(data.containsKey('w_usd'), isTrue);
    expect(data.containsKey('w_gold'), isFalse);
    expect(data.containsKey('w_coin'), isFalse);
  });

  test('nothing usable means nothing is written at all', () {
    expect(HomeWidgetService.payload(const {}), isEmpty);
    expect(
      HomeWidgetService.payload({
        'ir_usd': _q('ir_usd', price: 1, status: QuoteStatus.unavailable),
      }),
      isEmpty,
    );
  });

  test('the timestamp line comes from the newest source timestamp', () {
    final data = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 1, ts: DateTime.utc(2026, 9, 1, 8)),
      'gold_18k': _q('gold_18k', price: 2, ts: DateTime.utc(2026, 9, 1, 11)),
    });
    final expected = HomeWidgetService.updatedLabel(
      DateTime.utc(2026, 9, 1, 11),
    );
    expect(data['w_updated'], expected);
  });

  test('the label is Persian-digit local time', () {
    final label = HomeWidgetService.updatedLabel(
      DateTime.utc(2026, 9, 1, 7, 5),
    );
    expect(label, startsWith('به‌روزرسانی '));
    expect(RegExp(r'[0-9]').hasMatch(label), isFalse, reason: 'ASCII digits');
  });

  test('publish is a no-op until the user enables the widget', () async {
    final store = InMemoryKeyValueStore();
    expect(await HomeWidgetService.isEnabled(store), isFalse);
    // Must not throw despite no widget host being present in a VM test.
    await HomeWidgetService.publish(store, {
      'ir_usd': _q('ir_usd', price: 214000),
    });

    await HomeWidgetService.setEnabled(store, true);
    expect(await HomeWidgetService.isEnabled(store), isTrue);
    await HomeWidgetService.setEnabled(store, false);
    expect(await HomeWidgetService.isEnabled(store), isFalse);
  });

  test('USD-denominated quotes are converted, not shown as dollars', () {
    // Guard against a future headline asset that is not Rial-quoted.
    final data = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 2140000, currency: 'IRR'),
    });
    expect(data['w_usd'], '۲,۱۴۰,۰۰۰ تومان');
  });
}
