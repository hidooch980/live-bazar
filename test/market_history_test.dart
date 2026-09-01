import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/services/market_history_service.dart';

/// Shape-accurate excerpt of
/// api.tgju.org/v1/market/indicator/summary-table-data/<key>:
/// [open, low, high, close, changeHtml, percentHtml, gregorian, jalali],
/// newest first.
List<dynamic> _rows() => [
  [
    '2,076,950',
    '2,067,600',
    '2,099,200',
    '2,093,000',
    '<span class="high">32900</span>',
    '<span class="high">1.6%</span>',
    '2026/08/31',
    '1405/06/09',
  ],
  [
    '2,027,000',
    '2,026,950',
    '2,062,200',
    '2,060,100',
    '<span class="high">54100</span>',
    '<span class="high">2.7%</span>',
    '2026/08/29',
    '1405/06/07',
  ],
  [
    '2,002,950',
    '2,001,600',
    '2,022,200',
    '2,006,000',
    '-',
    '-',
    '2026/08/27',
    '1405/06/05',
  ],
  // Unusable rows must be skipped, never guessed at.
  ['-', '-', '-', '-', '', '', '2026/08/26', '1405/06/04'],
  ['1', '1', '1', '1', '', '', 'not-a-date', ''],
  ['too', 'short'],
];

void main() {
  test('rows parse oldest-first with Rial converted to Toman', () {
    final candles = MarketHistoryService.parseRows(_rows(), 'ir_usd');

    expect(candles.length, 3); // three usable rows
    expect(candles.first.date, DateTime.utc(2026, 8, 27));
    expect(candles.last.date, DateTime.utc(2026, 8, 31));
    // 2,093,000 Rial -> Toman
    expect(candles.last.close, 209300);
    expect(candles.last.open, 207695);
    expect(candles.last.low, 206760);
    expect(candles.last.high, 209920);
    expect(candles.last.jalali, '1405/06/09');
  });

  test('USD-quoted assets keep the published value', () {
    final candles = MarketHistoryService.parseRows([
      [
        '4,442.11',
        '4,401.52',
        '4,468.94',
        '4,447.11',
        '',
        '',
        '2026/08/31',
        'x',
      ],
    ], 'xau_usd');
    expect(candles.single.close, 4447.11);
  });

  test('index points are not divided either', () {
    final candles = MarketHistoryService.parseRows([
      [
        '6,513,590.05',
        '6,513,590.05',
        '6,549,574.33',
        '6,547,963.76',
        '',
        '',
        '2026/08/31',
        'x',
      ],
    ], 'bourse_index');
    expect(candles.single.close, 6547963.76);
  });

  test('an unknown asset yields nothing rather than a wrong scale', () {
    expect(MarketHistoryService.parseRows(_rows(), 'no_such_asset'), isEmpty);
  });

  test('assets the source publishes a table for are discoverable', () {
    expect(MarketHistoryService.hasHistory('ir_usd'), isTrue);
    expect(MarketHistoryService.hasHistory('gold_18k'), isTrue);
    expect(MarketHistoryService.hasHistory('bourse_index'), isTrue);
    expect(MarketHistoryService.indicatorKeyFor('coin_emami'), 'sekee');
    // Crypto and global FX have no TGJU table — the chart falls back to
    // locally accumulated points for those.
    expect(MarketHistoryService.hasHistory('btc_usd'), isFalse);
    expect(MarketHistoryService.hasHistory('fx_eur'), isFalse);
  });

  test('cache round-trips and is reused within the TTL', () async {
    final store = InMemoryKeyValueStore();
    var clock = DateTime.utc(2026, 9, 1, 12);
    final service = MarketHistoryService(store: store, now: () => clock);

    final candles = MarketHistoryService.parseRows(_rows(), 'ir_usd');
    // Prime the cache the way a successful fetch would.
    await service.writeCacheForTest('ir_usd', candles);

    final fresh = await service.readCacheForTest('ir_usd');
    expect(fresh, isNotNull);
    expect(fresh!.length, 3);
    expect(fresh.last.close, 209300);
    expect(fresh.last.jalali, '1405/06/09');

    clock = clock.add(MarketHistoryService.cacheTtl * 2);
    expect(await service.readCacheForTest('ir_usd'), isNull, reason: 'expired');
    // Expired is not lost: a failed refresh can still serve it.
    expect(
      await service.readCacheForTest('ir_usd', ignoreTtl: true),
      isNotNull,
    );
  });

  test('a corrupt cache entry is ignored, not thrown', () async {
    final store = InMemoryKeyValueStore();
    await store.setString('daily_ir_usd', '{not json');
    final service = MarketHistoryService(store: store);
    expect(await service.readCacheForTest('ir_usd'), isNull);
  });
}
