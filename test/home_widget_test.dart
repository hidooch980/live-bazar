import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/core/utils/price_display.dart';
import 'package:live_bazar/services/home_widget_service.dart';

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

const _ids = HomeWidgetService.defaultAssets;

Map<String, String?> _payload(
  Map<String, PriceQuote> quotes, {
  DateTime? nowUtc,
  List<String> ids = _ids,
}) => HomeWidgetService.payload(quotes, ids, nowUtc: nowUtc);

List<Map<String, dynamic>> _rows(Map<String, String?> payload) =>
    (jsonDecode(payload[HomeWidgetService.rowsKey]!) as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic>? _row(Map<String, String?> payload, String id) {
  for (final r in _rows(payload)) {
    if (r['id'] == id) return r;
  }
  return null;
}

void main() {
  test('publishes the three default prices in Toman, in order', () {
    final data = _payload({
      'ir_usd': _q('ir_usd', price: 214000),
      'gold_18k': _q('gold_18k', price: 22195800),
      'coin_emami': _q('coin_emami', price: 221505000),
    });

    final rows = _rows(data);
    expect([for (final r in rows) r['id']], _ids);
    expect(rows[0]['v'], '۲۱۴,۰۰۰');
    expect(rows[0]['u'], 'تومان');
    expect(rows[1]['v'], '۲۲,۱۹۵,۸۰۰');
    expect(rows[2]['v'], '۲۲۱,۵۰۵,۰۰۰');
    expect(data['w_updated'], startsWith('به‌روزرسانی'));
    expect(data['w_v'], '2');
    // The 0.6 keys are cleared so an old layout cannot show a dead number.
    for (final k in HomeWidgetService.legacyKeys) {
      expect(data.containsKey(k), isTrue);
      expect(data[k], isNull);
    }
  });

  test('an unusable quote is omitted, never shown stale or invented', () {
    final data = _payload({
      'ir_usd': _q('ir_usd', price: 214000),
      // Rejected by the anomaly gate upstream.
      'gold_18k': _q('gold_18k', price: 0, status: QuoteStatus.dataConflict),
      // Present but worthless.
      'coin_emami': _q('coin_emami', price: 0),
    });

    expect(_row(data, 'ir_usd'), isNotNull);
    expect(_row(data, 'gold_18k'), isNull);
    expect(_row(data, 'coin_emami'), isNull);
  });

  test('nothing usable means nothing is written at all', () {
    expect(_payload(const {}), isEmpty);
    expect(
      _payload({
        'ir_usd': _q('ir_usd', price: 1, status: QuoteStatus.unavailable),
      }),
      isEmpty,
    );
  });

  test('the time line is the OLDEST shown quote, never the newest', () {
    final data = _payload({
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
    final data = _payload({
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
    final mixed = _payload({
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

    final onlyClose = _payload({'coin_emami': close}, nowUtc: now);
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

  test('the user order is kept and capped at six', () {
    final ids = HomeWidgetService.sanitize([
      'coin_emami',
      'ir_usd',
      'nope',
      'ir_usd',
      'fx_irr',
      'gold_18k',
      'usdt_irt',
      'ir_eur',
      'btc_usd',
      'xau_usd',
    ]);
    expect(ids, [
      'coin_emami',
      'ir_usd',
      'gold_18k',
      'usdt_irt',
      'ir_eur',
      'btc_usd',
    ]);
    expect(HomeWidgetService.sanitize(['nope', 'fx_irr']), _ids);
  });

  test('selection, mode and enabled round-trip and are mirrored', () async {
    HomeWidgetService.resetForTest();
    final data = MemoryWidgetDataStore();
    HomeWidgetService.data = data;
    addTearDown(HomeWidgetService.resetForTest);
    final store = InMemoryKeyValueStore();

    expect(await HomeWidgetService.loadSelection(store), _ids);
    await HomeWidgetService.saveSelection(store, ['btc_usd', 'ir_usd']);
    await HomeWidgetService.saveMode(store, WidgetRefreshMode.live);
    await HomeWidgetService.setEnabled(store, true);
    await store.setString('proxy_config', '{"host":"p"}');
    await HomeWidgetService.mirrorConfig(store);

    final c = await HomeWidgetService.loadConfig(store);
    expect(c.ids, ['btc_usd', 'ir_usd']);
    expect(c.mode, WidgetRefreshMode.live);
    expect(c.enabled, isTrue);
    expect(await HomeWidgetService.readMirroredConfig(), c);
    expect(data.values['cfg_proxy'], '{"host":"p"}');

    await HomeWidgetService.resetSelection(store);
    expect(await HomeWidgetService.loadSelection(store), _ids);
    expect((await HomeWidgetService.readMirroredConfig()).ids, _ids);
  });

  test('a USD-quoted pick pulls in the dollar rate, Toman picks do not', () {
    expect(HomeWidgetService.rateDependencies(_ids), isEmpty);
    expect(HomeWidgetService.rateDependencies(['btc_usd']), {
      'ir_usd',
      'usdt_irt',
    });
    expect(HomeWidgetService.rateDependencies(['fx_eur']), {
      'ir_usd',
      'usdt_irt',
    });
    expect(HomeWidgetService.rateDependencies(['bourse_index']), isEmpty);
  });

  test('change pill comes from the source change, never invented', () {
    expect(HomeWidgetService.changeLabel(0.42), '▲ ۰٫۴۲٪');
    expect(HomeWidgetService.changeLabel(-1.3), '▼ ۱٫۳۰٪');
    expect(HomeWidgetService.changeLabel(0), '');
    final data = _payload({
      'ir_usd': PriceQuote(
        id: 'ir_usd',
        symbol: 'USD/IRR-FM',
        name: 'USD',
        nameFa: 'دلار آمریکا (بازار آزاد)',
        category: AssetCategory.iranianCurrency,
        price: 214000,
        changePercent: -0.5,
        unit: 'تومان',
        currency: 'IRR',
        timestamp: DateTime.utc(2026, 9, 1, 10),
        source: 'TGJU',
        status: QuoteStatus.live,
      ),
    }, nowUtc: DateTime.utc(2026, 9, 1, 10, 5));
    final r = _row(data, 'ir_usd')!;
    expect(r['d'], -1);
    expect(r['c'], '▼ ۰٫۵۰٪');
    expect(r['l'], 'دلار آمریکا');
    expect(r['s'], 'بازار آزاد');
    expect(r['g'], r'$');
    expect(r['t'], 'green');
    expect(r['st'], 0);
  });

  test('an old or delayed price is flagged stale for the widget', () {
    final now = DateTime.utc(2026, 9, 1, 12);
    final data = _payload({
      'ir_usd': _q('ir_usd', price: 1, ts: DateTime.utc(2026, 9, 1, 11, 59)),
      'gold_18k': _q('gold_18k', price: 2, ts: DateTime.utc(2026, 9, 1, 9)),
      'coin_emami': _q(
        'coin_emami',
        price: 3,
        ts: DateTime.utc(2026, 9, 1, 11, 59),
        status: QuoteStatus.delayed,
      ),
    }, nowUtc: now);
    expect(_row(data, 'ir_usd')!['st'], 0);
    expect(_row(data, 'gold_18k')!['st'], 1);
    expect(_row(data, 'coin_emami')!['st'], 1);
  });

  group('sparkline series', () {
    test('only real observations, one per 30-minute bucket, 24 h max', () {
      final series = <String, List<List<num>>>{};
      final t0 = DateTime.utc(2026, 9, 1, 10);
      for (var i = 0; i < 4; i++) {
        HomeWidgetService.updateSeries(
          series,
          {
            'ir_usd': _q(
              'ir_usd',
              price: 100.0 + i,
              ts: t0.add(Duration(minutes: 10 * i)),
            ),
          },
          ['ir_usd'],
          nowUtc: t0.add(Duration(minutes: 10 * i)),
        );
      }
      // 10:00, 10:10, 10:20 share a bucket (last price wins); 10:30 is new.
      expect(series['ir_usd']!.length, 2);
      expect(series['ir_usd']!.first[1], 102);
      expect(series['ir_usd']!.last[1], 103);

      // A day later the old points have aged out.
      HomeWidgetService.updateSeries(
        series,
        {
          'ir_usd': _q(
            'ir_usd',
            price: 200,
            ts: t0.add(const Duration(hours: 30)),
          ),
        },
        ['ir_usd'],
        nowUtc: t0.add(const Duration(hours: 30)),
      );
      expect(series['ir_usd']!.length, 1);
    });

    test('unusable, previous-close and deselected assets add nothing', () {
      final series = <String, List<List<num>>>{
        'btc_usd': [
          [1, 2],
        ],
      };
      final changed = HomeWidgetService.updateSeries(
        series,
        {
          'ir_usd': _q('ir_usd', price: 0),
          'gold_18k': _q(
            'gold_18k',
            price: 5,
            status: QuoteStatus.previousClose,
          ),
        },
        ['ir_usd', 'gold_18k'],
        nowUtc: DateTime.utc(2026, 9, 1, 10),
      );
      expect(series['ir_usd'] ?? const [], isEmpty);
      expect(series['gold_18k'] ?? const [], isEmpty);
      expect(series.containsKey('btc_usd'), isFalse);
      expect(changed, isFalse);
    });

    test('normalized for drawing; fewer than two points draws nothing', () {
      expect(HomeWidgetService.sparkOf(null), '');
      expect(
        HomeWidgetService.sparkOf([
          [1, 5],
        ]),
        '',
      );
      expect(
        HomeWidgetService.sparkOf([
          [1, 10],
          [2, 20],
          [3, 15],
        ]),
        '0.00,1.00,0.50',
      );
      expect(
        HomeWidgetService.sparkOf([
          [1, 7],
          [2, 7],
        ]),
        '0.50,0.50',
      );
    });
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
    late MemoryWidgetDataStore data;
    late InMemoryKeyValueStore store;

    setUp(() async {
      HomeWidgetService.resetForTest();
      data = MemoryWidgetDataStore();
      HomeWidgetService.data = data;
      store = InMemoryKeyValueStore();
      await HomeWidgetService.setEnabled(store, true);
      data.saves = 0;
    });

    tearDown(HomeWidgetService.resetForTest);

    final all = {
      'ir_usd': _q('ir_usd', price: 214000),
      'gold_18k': _q('gold_18k', price: 22195800),
      'coin_emami': _q('coin_emami', price: 221505000),
    };

    List<String> shown() => [
      for (final r in _rows(data.values)) r['id'] as String,
    ];

    test('a quote missing this cycle is dropped, not left stale', () async {
      await HomeWidgetService.publish(store, all);
      expect(shown(), _ids);

      await HomeWidgetService.publish(store, {
        'ir_usd': _q('ir_usd', price: 215000),
        'coin_emami': _q('coin_emami', price: 221505000),
      });
      expect(shown(), ['ir_usd', 'coin_emami']);
    });

    test('the user selection and order drive what is published', () async {
      await HomeWidgetService.saveSelection(store, ['coin_emami', 'ir_usd']);
      await HomeWidgetService.publish(store, all);
      expect(shown(), ['coin_emami', 'ir_usd']);
    });

    test('an unchanged payload is not rewritten', () async {
      await HomeWidgetService.publish(store, all);
      final calls = data.saves;
      expect(data.redraws, 1);

      await HomeWidgetService.publish(store, all);
      expect(data.saves, calls);
      expect(data.redraws, 1);

      await HomeWidgetService.publish(store, {
        ...all,
        'ir_usd': _q('ir_usd', price: 215000),
      });
      expect(data.redraws, 2);
    });

    test('a failed write is retried next time, not remembered', () async {
      data.fail = true;
      await HomeWidgetService.publish(store, all);
      expect(data.redraws, 0);

      data.fail = false;
      await HomeWidgetService.publish(store, all);
      expect(data.redraws, 1);
    });

    test('nothing usable writes nothing at all', () async {
      await HomeWidgetService.publish(store, const {});
      expect(data.saves, 0);
      expect(data.redraws, 0);
    });

    test('disabled writes nothing', () async {
      await HomeWidgetService.setEnabled(store, false);
      data.saves = 0;
      await HomeWidgetService.publish(store, all);
      expect(data.redraws, 0);
      expect(data.saves, 0);
    });

    test('live mode raises the «زنده» flag', () async {
      await HomeWidgetService.saveMode(store, WidgetRefreshMode.live);
      await HomeWidgetService.publish(store, all);
      expect(data.values['w_live'], '1');
    });

    test('the series persists so sparklines survive restarts', () async {
      await HomeWidgetService.publish(store, all);
      expect(data.values[HomeWidgetService.seriesKey], contains('ir_usd'));
    });
  });
}
