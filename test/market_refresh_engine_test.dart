import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/config/asset_catalog.dart';
import 'package:live_bazar/core/errors/app_exception.dart';
import 'package:live_bazar/data/cache/market_cache.dart';
import 'package:live_bazar/domain/entities/market_snapshot.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/providers/iprice_provider.dart';
import 'package:live_bazar/providers/provider_registry.dart';
import 'package:live_bazar/services/market_refresh_engine.dart';
import 'package:live_bazar/state/app_providers.dart';

import 'fakes/fake_provider.dart';

MarketRefreshEngine _engine(
  List<IPriceProvider> providers, {
  DateTime Function()? now,
  MarketCache? cache,
}) {
  final registry = ProviderRegistry();
  var priority = 1;
  for (final p in providers) {
    registry.register(ProviderEntry(provider: p, priority: priority++));
  }
  return MarketRefreshEngine(
    registry: registry,
    cache: cache ?? InMemoryMarketCache(),
    now: now ?? (() => DateTime.now().toUtc()),
  );
}

void main() {
  final t0 = DateTime.utc(2026, 8, 1, 12);

  test('merges valid quotes into snapshot', () async {
    final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'})
      ..succeedWith(1.1, t0);
    final engine = _engine([fx]);

    final snap = await engine.refresh(force: true);
    expect(snap, isNotNull);
    expect(snap!.quotes['fx_eur'], isNotNull);
    expect(snap.quotes['fx_eur']!.price, 1.1);
    expect(snap.sourceStatus['fx'], 'ok');
    await engine.dispose();
  });

  test('rejects invalid data (price <= 0) — never reaches UI state', () async {
    final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'})
      ..behavior = (_) async =>
          ProviderResult(quotes: [quoteFor('fx_eur', price: -5, ts: t0)]);
    final engine = _engine([fx]);

    final snap = await engine.refresh(force: true);
    expect(snap!.quotes.containsKey('fx_eur'), isFalse);
    expect(snap.isEmpty, isTrue);
    await engine.dispose();
  });

  test('provider failure does not crash the cycle', () async {
    final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'})
      ..behavior = (_) async => const ProviderResult(
        quotes: [],
        error: AppException(AppErrorCode.network, 'down'),
      );
    final engine = _engine([fx]);

    final snap = await engine.refresh(force: true);
    expect(snap, isNotNull);
    expect(snap!.sourceStatus['fx'], 'failed');
    expect(engine.latest, isNotNull); // snapshot still emitted
    await engine.dispose();
  });

  test(
    'per-provider rate limit respected across rapid refreshes (§3)',
    () async {
      var fakeNow = t0;
      final fx = FakeProvider(
        id: 'fx',
        supportedAssets: {'fx_eur'},
        minInterval: const Duration(seconds: 30),
      )..succeedWith(1.1, t0);
      final engine = _engine([fx], now: () => fakeNow);

      await engine.refresh(); // due -> call #1
      fakeNow = t0.add(const Duration(seconds: 5));
      await engine.refresh(); // NOT due -> skipped
      expect(fx.callCount, 1);

      fakeNow = t0.add(const Duration(seconds: 31));
      await engine.refresh(); // due again -> call #2
      expect(fx.callCount, 2);
      await engine.dispose();
    },
  );

  test('no overlapping requests: slow provider called once (§5)', () async {
    final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'})
      ..behavior = (_) => Future<ProviderResult>.delayed(
        const Duration(milliseconds: 100),
        () => ProviderResult(quotes: [quoteFor('fx_eur', price: 1.1, ts: t0)]),
      );
    final engine = _engine([fx]);

    final results = await Future.wait([
      engine.refresh(),
      engine.refresh(), // joins the in-flight refresh
    ]);
    expect(fx.callCount, 1);
    expect(results.first, isNotNull);
    await engine.dispose();
  });

  test('change% computed when provider timestamp advances', () async {
    final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'});
    var price = 1.0;
    var ts = t0;
    fx.behavior = (_) async => ProviderResult(
      quotes: [quoteFor('fx_eur', price: price, ts: ts)],
    );
    var fakeNow = t0;
    final engine = _engine([fx], now: () => fakeNow);

    await engine.refresh();
    price = 1.02; // +2%
    ts = t0.add(const Duration(minutes: 1));
    fakeNow = ts; // advance past min interval
    final snap = await engine.refresh();

    expect(snap!.quotes['fx_eur']!.changePercent, closeTo(2.0, 0.001));
    await engine.dispose();
  });

  test(
    'anomalous jump (>10%) keeps last valid value with conflict flag',
    () async {
      final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'});
      var price = 1.0;
      var ts = t0;
      fx.behavior = (_) async => ProviderResult(
        quotes: [quoteFor('fx_eur', price: price, ts: ts)],
      );
      var fakeNow = t0;
      final engine = _engine([fx], now: () => fakeNow);

      await engine.refresh();
      price = 2.0; // +100% in one step -> anomaly
      ts = t0.add(const Duration(minutes: 1));
      fakeNow = ts;
      final snap = await engine.refresh();

      final q = snap!.quotes['fx_eur']!;
      expect(q.price, 1.0); // last valid retained
      expect(q.status, QuoteStatus.dataConflict);
      await engine.dispose();
    },
  );

  test(
    'hydrateFromCache restores offline data before network (§20/21)',
    () async {
      final cache = InMemoryMarketCache();
      await cache.saveSnapshot(
        MarketSnapshot(
          snapshotId: 's1',
          timestamp: t0,
          quotes: {'fx_eur': quoteFor('fx_eur', price: 0.9, ts: t0)},
          sourceStatus: const {'fx': 'ok'},
        ),
      );
      final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'});
      final engine = _engine([fx], cache: cache);

      await engine.hydrateFromCache();
      expect(engine.latest!.quotes['fx_eur']!.price, 0.9);
      expect(fx.callCount, 0); // no network needed yet
      await engine.dispose();
    },
  );

  test(
    'a real but old provider timestamp is labeled STALE, not LIVE',
    () async {
      final old = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final fx = FakeProvider(id: 'fx', supportedAssets: {'fx_eur'})
        ..behavior = (_) async =>
            ProviderResult(quotes: [quoteFor('fx_eur', price: 1.1, ts: old)]);
      final engine = _engine([fx]);

      final snap = await engine.refresh(force: true);
      expect(snap!.quotes['fx_eur']!.status, QuoteStatus.stale);
      expect(
        snap.quotes['fx_eur']!.price,
        1.1,
      ); // still shown, honestly labeled
      await engine.dispose();
    },
  );

  test('enabled assets and registered live sources match exactly (§7/§10)', () {
    final served = <String>{
      for (final entry in buildRegistry().entries.where((e) => e.isActive))
        ...entry.provider.supportedAssets,
    };
    for (final def in AssetCatalog.all) {
      expect(
        def.enabled,
        served.contains(def.id),
        reason: '${def.id}: enabled must mean a live provider serves it',
      );
    }
    // The Iranian market is the reason the app exists — it must be live.
    expect(served, containsAll(<String>['ir_usd', 'gold_18k', 'coin_emami']));
  });
}
