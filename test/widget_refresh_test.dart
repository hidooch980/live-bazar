import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/services/home_widget_service.dart';
import 'package:live_bazar/services/widget/widget_background.dart';
import 'package:live_bazar/services/widget/widget_refresh.dart';

import 'support/v070_fakes.dart';

void main() {
  late MemoryWidgetDataStore data;
  late InMemoryKeyValueStore store;
  late StubProvider ir;
  late StubProvider crypto;
  var now = DateTime.utc(2026, 10, 10, 9);

  setUp(() async {
    HomeWidgetService.resetForTest();
    WidgetRefresher.resetForTest();
    data = MemoryWidgetDataStore();
    HomeWidgetService.data = data;
    store = InMemoryKeyValueStore();
    now = DateTime.utc(2026, 10, 10, 9);
    ir = StubProvider(
      'ir',
      {'ir_usd', 'usdt_irt', 'gold_18k', 'coin_emami'},
      {'ir_usd': 100000, 'gold_18k': 9000000, 'coin_emami': 90000000},
      ts: now,
    );
    crypto = StubProvider(
      'crypto',
      {'btc_usd'},
      {'btc_usd': 60000},
      minRefreshInterval: const Duration(seconds: 30),
      ts: now,
    );
    await HomeWidgetService.setEnabled(store, true);
  });

  tearDown(HomeWidgetService.resetForTest);

  Future<bool> run(WidgetRefreshReason r) =>
      WidgetRefresher.run(reason: r, providers: [ir, crypto], now: () => now);

  test('does nothing while the widget is off', () async {
    await HomeWidgetService.setEnabled(store, false);
    expect(await run(WidgetRefreshReason.screenOn), isFalse);
    expect(ir.calls, 0);
  });

  test('screen-on refresh is throttled to one per two minutes', () async {
    expect(await run(WidgetRefreshReason.screenOn), isTrue);
    expect(data.values['w_rows'], contains('gold_18k'));
    now = now.add(const Duration(seconds: 50));
    expect(await run(WidgetRefreshReason.screenOn), isFalse);
    expect(ir.calls, 1);
    now = now.add(const Duration(minutes: 2));
    expect(await run(WidgetRefreshReason.screenOn), isTrue);
    expect(ir.calls, 2);
  });

  test('a live tick is ignored unless live mode is on', () async {
    expect(await run(WidgetRefreshReason.liveTick), isFalse);
    await HomeWidgetService.saveMode(store, WidgetRefreshMode.live);
    expect(await run(WidgetRefreshReason.liveTick), isTrue);
  });

  test('each provider is called no sooner than its own rate limit', () async {
    await HomeWidgetService.saveMode(store, WidgetRefreshMode.live);
    await HomeWidgetService.saveSelection(store, ['btc_usd', 'gold_18k']);
    await run(WidgetRefreshReason.liveTick);
    expect((ir.calls, crypto.calls), (1, 1));
    // TGJU (5 s) again, crypto (30 s) not yet.
    now = now.add(const Duration(seconds: 10));
    await run(WidgetRefreshReason.liveTick);
    expect((ir.calls, crypto.calls), (2, 1));
    // Inside TGJU's window: no call at all.
    now = now.add(const Duration(seconds: 2));
    await run(WidgetRefreshReason.liveTick);
    expect((ir.calls, crypto.calls), (2, 1));
    // The skipped provider's row is still shown, from its last real quote.
    expect(data.values['w_rows'], contains('btc_usd'));
    now = now.add(const Duration(seconds: 30));
    await run(WidgetRefreshReason.liveTick);
    expect((ir.calls, crypto.calls), (3, 2));
  });

  test('a failed fetch keeps the real old quote, marked stale', () async {
    await run(WidgetRefreshReason.periodic);
    expect(data.values['w_rows'], contains('"st":0'));
    final firstLine = data.values['w_updated'];

    ir.fails = true;
    now = now.add(const Duration(minutes: 20));
    await run(WidgetRefreshReason.periodic);
    expect(data.values['w_rows'], isNot(contains('"st":0')));
    // The time line still names the ORIGINAL publish time.
    expect(data.values['w_updated'], firstLine);
  });

  test('carried quotes survive an isolate restart', () async {
    await run(WidgetRefreshReason.periodic);
    WidgetRefresher.resetForTest();
    HomeWidgetService.resetForTest();
    HomeWidgetService.data = data;
    ir.fails = true;
    now = now.add(const Duration(minutes: 1));
    await run(WidgetRefreshReason.periodic);
    expect(data.values['w_rows'], contains('gold_18k'));
  });

  test('live service runs only when enabled AND in live mode', () {
    expect(
      WidgetLiveService.shouldRun(
        const WidgetConfig(
          enabled: true,
          ids: ['ir_usd'],
          mode: WidgetRefreshMode.live,
        ),
      ),
      isTrue,
    );
    expect(
      WidgetLiveService.shouldRun(
        const WidgetConfig(
          enabled: false,
          ids: ['ir_usd'],
          mode: WidgetRefreshMode.live,
        ),
      ),
      isFalse,
    );
    expect(
      WidgetLiveService.shouldRun(
        const WidgetConfig(enabled: true, ids: ['ir_usd']),
      ),
      isFalse,
    );
  });

  test('refresh mode parsing defaults to low-power', () {
    expect(WidgetRefreshMode.parse(null), WidgetRefreshMode.lowPower);
    expect(WidgetRefreshMode.parse('junk'), WidgetRefreshMode.lowPower);
    expect(WidgetRefreshMode.parse('live'), WidgetRefreshMode.live);
  });
}
