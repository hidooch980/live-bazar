import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/core/utils/price_display.dart';
import 'package:live_bazar/services/home_widget_service.dart';

/// Records what publish hands to the widget, instead of the plugin.
class _RecordingSink implements HomeWidgetSink {
  final saves = <String, String?>{};
  int saveCalls = 0;
  int redraws = 0;
  bool fail = false;

  @override
  Future<void> save(String key, String? value) async {
    if (fail) throw StateError('no widget host');
    saveCalls++;
    saves[key] = value;
  }

  @override
  Future<void> redraw() async => redraws++;
}

PriceQuote _q(
  String id, {
  required double price,
  String currency = 'IRR',
  QuoteStatus status = QuoteStatus.live,
  DateTime? ts,
  AssetCategory category = AssetCategory.iranianCurrency,
  String? unit,
}) => PriceQuote(
  id: id,
  symbol: id,
  name: id,
  nameFa: id,
  category: category,
  price: price,
  unit: unit ?? (currency == 'IRR' ? 'تومان' : ''),
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

  test('the time line is the OLDEST shown quote, never the newest', () {
    final data = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 1, ts: DateTime.utc(2026, 9, 1, 8)),
      'gold_18k': _q('gold_18k', price: 2, ts: DateTime.utc(2026, 9, 1, 11)),
    }, nowUtc: DateTime.utc(2026, 9, 1, 12));
    final expected = HomeWidgetService.updatedLabel(
      DateTime.utc(2026, 9, 1, 8),
      nowUtc: DateTime.utc(2026, 9, 1, 12),
    );
    expect(data['w_updated'], expected);
  });

  test('an omitted quote does not set the time line', () {
    final now = DateTime.utc(2026, 9, 1, 12);
    final data = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 1, ts: DateTime.utc(2026, 9, 1, 11)),
      'gold_18k': _q(
        'gold_18k',
        price: 0,
        ts: DateTime.utc(2026, 8, 1),
        status: QuoteStatus.unavailable,
      ),
    }, nowUtc: now);
    expect(
      data['w_updated'],
      HomeWidgetService.updatedLabel(DateTime.utc(2026, 9, 1, 11), nowUtc: now),
    );
  });

  test('a previous-session close never sets the clock, it is named', () {
    final now = DateTime.utc(2026, 9, 1, 12);
    // Stamped at midnight: a date, not a publish time.
    final close = _q(
      'coin_emami',
      price: 3,
      ts: DateTime.utc(2026, 8, 31, 20, 30),
      status: QuoteStatus.previousClose,
    );
    final mixed = HomeWidgetService.payload({
      'ir_usd': _q('ir_usd', price: 1, ts: DateTime.utc(2026, 9, 1, 11)),
      'coin_emami': close,
    }, nowUtc: now);
    expect(mixed['w_updated'], endsWith('برخی پایانی'));
    expect(
      mixed['w_updated'],
      startsWith(
        HomeWidgetService.updatedLabel(
          DateTime.utc(2026, 9, 1, 11),
          nowUtc: now,
        ),
      ),
    );

    final onlyClose = HomeWidgetService.payload({
      'coin_emami': close,
    }, nowUtc: now);
    expect(onlyClose['w_updated'], 'قیمت پایانی بازار');
  });

  test('a time from an earlier day says so', () {
    final now = DateTime.utc(2026, 9, 2, 12);
    final yesterday = HomeWidgetService.updatedLabel(
      DateTime.utc(2026, 9, 1, 12),
      nowUtc: now,
    );
    expect(yesterday, contains('دیروز'));
    final older = HomeWidgetService.updatedLabel(
      DateTime.utc(2026, 8, 25, 12),
      nowUtc: now,
    );
    expect(older, contains('شهریور'));
    expect(RegExp(r'[0-9]').hasMatch(older), isFalse, reason: 'ASCII digits');
    final today = HomeWidgetService.updatedLabel(
      DateTime.utc(2026, 9, 2, 11),
      nowUtc: now,
    );
    expect(today, isNot(contains('دیروز')));
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

  group('units come from PriceDisplay.unitOf, not from currency', () {
    final rate = TomanRate(
      100000,
      TomanRateSource.freeMarket,
      DateTime.utc(2026, 9, 1),
    );

    test('a USD-quoted global currency converts at the real rate', () {
      // fx_eur carries 'EUR' but its price is USD per euro. Reading
      // currency as "not IRR, so Rial" divided it by ten.
      final eur = _q(
        'fx_eur',
        price: 1.1,
        currency: 'EUR',
        category: AssetCategory.currency,
      );
      expect(HomeWidgetService.format(eur, rate: rate), '۱۱۰,۰۰۰ تومان');
    });

    test('a USD-quoted asset with no rate stays in dollars', () {
      final btc = _q(
        'btc_usd',
        price: 60000,
        currency: 'USD',
        category: AssetCategory.crypto,
      );
      expect(HomeWidgetService.format(btc), '۶۰,۰۰۰ دلار');
      expect(HomeWidgetService.format(btc, rate: rate), '۶,۰۰۰,۰۰۰,۰۰۰ تومان');
    });

    test('index points are never shown as Toman', () {
      final idx = _q(
        'bourse_index',
        price: 2500000,
        currency: 'IDX',
        category: AssetCategory.marketIndex,
        unit: 'واحد',
      );
      expect(HomeWidgetService.format(idx, rate: rate), '۲,۵۰۰,۰۰۰ واحد');
    });

    test('the three headline assets are unchanged', () {
      expect(
        HomeWidgetService.format(_q('gold_18k', price: 22195800), rate: rate),
        '۲۲,۱۹۵,۸۰۰ تومان',
      );
    });
  });

  group('publish', () {
    late _RecordingSink sink;
    late InMemoryKeyValueStore store;

    setUp(() async {
      HomeWidgetService.resetForTest();
      sink = _RecordingSink();
      HomeWidgetService.sink = sink;
      store = InMemoryKeyValueStore();
      await HomeWidgetService.setEnabled(store, true);
    });

    tearDown(HomeWidgetService.resetForTest);

    final all = {
      'ir_usd': _q('ir_usd', price: 214000),
      'gold_18k': _q('gold_18k', price: 22195800),
      'coin_emami': _q('coin_emami', price: 221505000),
    };

    test('a quote missing this cycle is cleared, not left stale', () async {
      await HomeWidgetService.publish(store, all);
      expect(sink.saves['w_gold'], '۲۲,۱۹۵,۸۰۰ تومان');

      await HomeWidgetService.publish(store, {
        'ir_usd': _q('ir_usd', price: 215000),
        'coin_emami': _q('coin_emami', price: 221505000),
      });
      // Removed, so the widget shows «—» rather than last cycle's gold
      // under this cycle's time line.
      expect(sink.saves.containsKey('w_gold'), isTrue);
      expect(sink.saves['w_gold'], isNull);
      expect(sink.saves['w_usd'], '۲۱۵,۰۰۰ تومان');
    });

    test('an unchanged payload is not rewritten', () async {
      await HomeWidgetService.publish(store, all);
      final calls = sink.saveCalls;
      expect(sink.redraws, 1);

      await HomeWidgetService.publish(store, all);
      expect(sink.saveCalls, calls);
      expect(sink.redraws, 1);

      await HomeWidgetService.publish(store, {
        ...all,
        'ir_usd': _q('ir_usd', price: 215000),
      });
      expect(sink.redraws, 2);
    });

    test('a failed write is retried next time, not remembered', () async {
      sink.fail = true;
      await HomeWidgetService.publish(store, all);
      expect(sink.redraws, 0);

      sink.fail = false;
      await HomeWidgetService.publish(store, all);
      expect(sink.redraws, 1);
    });

    test('nothing usable writes nothing at all', () async {
      await HomeWidgetService.publish(store, const {});
      expect(sink.saveCalls, 0);
      expect(sink.redraws, 0);
    });
  });
}
