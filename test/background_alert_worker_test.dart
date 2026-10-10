import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/config/asset_catalog.dart';
import 'package:live_bazar/core/errors/app_exception.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/alert_rule.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/providers/iprice_provider.dart';
import 'package:live_bazar/services/alert_service.dart';
import 'package:live_bazar/services/background_alert_worker.dart';
import 'package:live_bazar/services/home_widget_service.dart';
import 'package:live_bazar/services/notification_service.dart';
import 'package:live_bazar/services/widget/widget_refresh.dart';

/// Records what would have been shown, without touching the platform.
class _RecordingNotifier implements NotificationService {
  final fired = <({String asset, String body})>[];

  @override
  Future<void> init({Object? timeZone}) async {}

  @override
  bool get isReady => true;

  @override
  Future<void> showAlert({
    required AlertRule rule,
    required String assetName,
    required String body,
  }) async => fired.add((asset: assetName, body: body));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubProvider implements IPriceProvider {
  _StubProvider(
    this.id,
    this.supportedAssets,
    this._prices, {
    this.fails = false,
  });

  @override
  final String id;
  @override
  final Set<String> supportedAssets;
  final Map<String, double> _prices;
  final bool fails;

  Set<String>? lastRequested;

  @override
  String get displayName => id;
  @override
  Duration get minRefreshInterval => Duration.zero;
  @override
  bool get isEnabled => true;
  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    lastRequested = assetIds;
    if (fails) {
      return const ProviderResult(
        quotes: [],
        error: AppException(AppErrorCode.network, 'stub down'),
      );
    }
    return ProviderResult(
      quotes: [
        for (final e in _prices.entries)
          if (assetIds.contains(e.key))
            PriceQuote(
              id: e.key,
              symbol: AssetCatalog.byId(e.key)?.symbol ?? e.key,
              name: e.key,
              nameFa: AssetCatalog.byId(e.key)?.nameFa ?? e.key,
              category:
                  AssetCatalog.byId(e.key)?.category ??
                  AssetCategory.iranianCurrency,
              price: e.value,
              unit: AssetCatalog.byId(e.key)?.unit ?? 'تومان',
              currency: AssetCatalog.byId(e.key)?.currency ?? 'IRR',
              timestamp: DateTime.utc(2026, 9, 1),
              source: 'stub',
              status: QuoteStatus.live,
            ),
      ],
    );
  }
}

Future<AlertService> _withRule(
  KeyValueStore store,
  String assetId,
  AlertType type,
  double threshold,
) async {
  // Rules are only evaluated in the background once the user opted in.
  await store.setString(BackgroundAlertWorker.enabledKey, '1');
  final alerts = AlertService(store);
  await alerts.load();
  await alerts.create(assetId: assetId, type: type, threshold: threshold);
  return alerts;
}

void main() {
  test('a met rule notifies while the app is closed', () async {
    final store = InMemoryKeyValueStore();
    await _withRule(store, 'ir_usd', AlertType.priceAbove, 200000);
    final notifier = _RecordingNotifier();

    final count = await runBackgroundAlertCheck(
      store: store,
      notifications: notifier,
      providers: [
        _StubProvider('ir', {'ir_usd'}, {'ir_usd': 214000}),
      ],
    );

    expect(count, 1);
    expect(notifier.fired.single.asset, 'دلار آمریکا (بازار آزاد)');
    expect(notifier.fired.single.body, contains('بالای'));
  });

  test('an unmet rule stays silent', () async {
    final store = InMemoryKeyValueStore();
    await _withRule(store, 'ir_usd', AlertType.priceAbove, 300000);
    final notifier = _RecordingNotifier();

    final count = await runBackgroundAlertCheck(
      store: store,
      notifications: notifier,
      providers: [
        _StubProvider('ir', {'ir_usd'}, {'ir_usd': 214000}),
      ],
    );

    expect(count, 0);
    expect(notifier.fired, isEmpty);
  });

  test('only assets an active rule needs are fetched', () async {
    final store = InMemoryKeyValueStore();
    await _withRule(store, 'gold_18k', AlertType.priceBelow, 1);
    final provider = _StubProvider(
      'ir',
      {'ir_usd', 'gold_18k', 'coin_emami'},
      {'gold_18k': 22000000},
    );

    await runBackgroundAlertCheck(
      store: store,
      notifications: _RecordingNotifier(),
      providers: [provider],
    );

    expect(provider.lastRequested, {'gold_18k'});
  });

  test('no rules means no network work at all', () async {
    final store = InMemoryKeyValueStore();
    final provider = _StubProvider('ir', {'ir_usd'}, {'ir_usd': 214000});

    final count = await runBackgroundAlertCheck(
      store: store,
      notifications: _RecordingNotifier(),
      providers: [provider],
    );

    expect(count, 0);
    expect(provider.lastRequested, isNull, reason: 'provider must not be hit');
  });

  test('a rule re-arms rather than notifying every 15 minutes', () async {
    final store = InMemoryKeyValueStore();
    await _withRule(store, 'ir_usd', AlertType.priceAbove, 200000);
    final notifier = _RecordingNotifier();
    final providers = [
      _StubProvider('ir', {'ir_usd'}, {'ir_usd': 214000}),
    ];

    final first = await runBackgroundAlertCheck(
      store: store,
      notifications: notifier,
      providers: providers,
    );
    // Second wake-up, same still-true condition: the AlertService cooldown
    // must keep it quiet, and it must survive being reloaded from disk.
    final second = await runBackgroundAlertCheck(
      store: store,
      notifications: notifier,
      providers: providers,
    );

    expect(first, 1);
    expect(second, 0, reason: 'cooldown must persist across wake-ups');
    expect(notifier.fired.length, 1);
  });

  test('a provider failure notifies nothing rather than guessing', () async {
    final store = InMemoryKeyValueStore();
    await _withRule(store, 'ir_usd', AlertType.priceAbove, 200000);
    final notifier = _RecordingNotifier();

    final count = await runBackgroundAlertCheck(
      store: store,
      notifications: notifier,
      providers: [
        _StubProvider('ir', {'ir_usd'}, {'ir_usd': 214000}, fails: true),
      ],
    );

    expect(count, 0);
    expect(notifier.fired, isEmpty);
  });

  test('the opt-in preference round-trips through the local store', () async {
    final store = InMemoryKeyValueStore();
    expect(await store.getString(BackgroundAlertWorker.enabledKey), isNull);
    await store.setString(BackgroundAlertWorker.enabledKey, '1');
    expect(await store.getString(BackgroundAlertWorker.enabledKey), '1');
    // Android's floor for periodic work; anything smaller is silently
    // raised by the platform, so claiming faster would be a lie.
    expect(BackgroundAlertWorker.interval, const Duration(minutes: 15));
  });

  group('the widget no longer depends on the alerts switch', () {
    late MemoryWidgetDataStore sink;

    setUp(() {
      HomeWidgetService.resetForTest();
      WidgetRefresher.resetForTest();
      sink = MemoryWidgetDataStore();
      HomeWidgetService.data = sink;
    });

    tearDown(HomeWidgetService.resetForTest);

    test('either opt-in keeps the periodic task scheduled', () async {
      final store = InMemoryKeyValueStore();
      expect(await BackgroundAlertWorker.isNeeded(store), isFalse);

      await HomeWidgetService.setEnabled(store, true);
      expect(await BackgroundAlertWorker.isNeeded(store), isTrue);

      await HomeWidgetService.setEnabled(store, false);
      await store.setString(BackgroundAlertWorker.enabledKey, '1');
      expect(await BackgroundAlertWorker.isNeeded(store), isTrue);

      await store.setString(BackgroundAlertWorker.enabledKey, '0');
      expect(await BackgroundAlertWorker.isNeeded(store), isFalse);
    });

    test('widget alone: fetches only widget assets and publishes', () async {
      final store = InMemoryKeyValueStore();
      await HomeWidgetService.setEnabled(store, true);
      final ir = _StubProvider(
        'ir',
        {'ir_usd', 'gold_18k', 'coin_emami', 'ir_eur'},
        {'ir_usd': 214000, 'gold_18k': 22195800, 'coin_emami': 221505000},
      );
      final crypto = _StubProvider('crypto', {'btc_usd'}, {'btc_usd': 60000});

      final count = await runBackgroundAlertCheck(
        store: store,
        notifications: _RecordingNotifier(),
        providers: [ir, crypto],
      );

      expect(count, 0);
      expect(ir.lastRequested, {'ir_usd', 'gold_18k', 'coin_emami'});
      expect(crypto.lastRequested, isNull, reason: 'not a widget asset');
      expect(sink.values['w_rows'], contains('"v":"۲۱۴,۰۰۰"'));
      expect(sink.values['w_updated'], startsWith('به‌روزرسانی'));
    });

    test('rules are not evaluated when only the widget is on', () async {
      final store = InMemoryKeyValueStore();
      await _withRule(store, 'gold_18k', AlertType.priceAbove, 1);
      // The user turned background alerts back off; the widget stays on.
      await store.setString(BackgroundAlertWorker.enabledKey, '0');
      await HomeWidgetService.setEnabled(store, true);
      final notifier = _RecordingNotifier();
      final ir = _StubProvider(
        'ir',
        {'ir_usd', 'gold_18k', 'coin_emami'},
        {'ir_usd': 214000, 'gold_18k': 22195800, 'coin_emami': 221505000},
      );

      final count = await runBackgroundAlertCheck(
        store: store,
        notifications: notifier,
        providers: [ir],
      );

      expect(count, 0);
      expect(notifier.fired, isEmpty);
      expect(sink.values['w_rows'], contains('"v":"۲۲,۱۹۵,۸۰۰"'));
    });

    test('fetches the user selection plus the rate it needs', () async {
      final store = InMemoryKeyValueStore();
      await HomeWidgetService.setEnabled(store, true);
      await HomeWidgetService.saveSelection(store, ['btc_usd', 'coin_emami']);
      final ir = _StubProvider(
        'ir',
        {'ir_usd', 'usdt_irt', 'gold_18k', 'coin_emami'},
        {'ir_usd': 100000, 'usdt_irt': 101000, 'coin_emami': 221505000},
      );
      final crypto = _StubProvider('crypto', {'btc_usd'}, {'btc_usd': 60000});

      await runBackgroundAlertCheck(
        store: store,
        notifications: _RecordingNotifier(),
        providers: [ir, crypto],
      );

      expect(ir.lastRequested, {'ir_usd', 'usdt_irt', 'coin_emami'});
      expect(crypto.lastRequested, {'btc_usd'});
      final rows = sink.values['w_rows']!;
      // Bitcoin first, as chosen, converted at the real free-market rate.
      expect(rows.indexOf('btc_usd'), lessThan(rows.indexOf('coin_emami')));
      expect(rows, contains('"v":"۶,۰۰۰,۰۰۰,۰۰۰"'));
      expect(rows, isNot(contains('"id":"ir_usd"')), reason: 'rate only');
    });

    test('a first run after upgrading seeds the mirror from Hive', () async {
      final store = InMemoryKeyValueStore();
      await store.setString(HomeWidgetService.enabledKey, '1');
      expect(sink.values, isEmpty);
      final ir = _StubProvider(
        'ir',
        {'ir_usd', 'gold_18k', 'coin_emami'},
        {'ir_usd': 214000, 'gold_18k': 22195800, 'coin_emami': 221505000},
      );
      await runBackgroundAlertCheck(
        store: store,
        notifications: _RecordingNotifier(),
        providers: [ir],
      );
      expect(sink.values['cfg_enabled'], '1');
      expect(sink.values['w_rows'], isNotNull);
    });
  });
}
