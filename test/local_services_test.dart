import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/alert_rule.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/services/alert_service.dart';
import 'package:live_bazar/services/historical_snapshot_service.dart';
import 'package:live_bazar/services/portfolio_service.dart';
import 'package:live_bazar/services/timezone_service.dart';
import 'package:live_bazar/services/watchlist_service.dart';

PriceQuote _q(String id, double price, {double pct = 0, DateTime? ts}) =>
    PriceQuote(
      id: id,
      symbol: id.toUpperCase(),
      name: id,
      nameFa: id,
      category: AssetCategory.currency,
      price: price,
      unit: '',
      currency: 'USD',
      changePercent: pct,
      timestamp: ts ?? DateTime.utc(2026, 8, 1),
      source: 't',
      status: QuoteStatus.live,
    );

void main() {
  group('WatchlistService (§22)', () {
    test('add / remove / toggle / reorder persists order', () async {
      final svc = WatchlistService(InMemoryKeyValueStore());
      await svc.load();
      expect(svc.ids, isEmpty);

      await svc.add('fx_eur');
      await svc.add('btc_usd');
      expect(svc.ids, ['fx_eur', 'btc_usd']);

      await svc.reorder('fx_eur', 1); // move to end
      expect(svc.ids, ['btc_usd', 'fx_eur']);

      await svc.toggle('btc_usd'); // remove
      expect(svc.contains('btc_usd'), isFalse);

      // Reload from the SAME store -> state survives.
      final reloaded = WatchlistService(svc.store);
      await reloaded.load();
      expect(reloaded.ids, ['fx_eur']);
    });
  });

  group('AlertService & AlertRule (§23)', () {
    test('rule fires only when condition met', () {
      const above = AlertRule(
        id: '1',
        assetId: 'a',
        type: AlertType.priceAbove,
        threshold: 100,
      );
      expect(AlertRule.isMet(above, price: 101, changePercent: 0), isTrue);
      expect(AlertRule.isMet(above, price: 99, changePercent: 0), isFalse);

      const down = AlertRule(
        id: '2',
        assetId: 'a',
        type: AlertType.percentDown,
        threshold: 3,
      );
      expect(AlertRule.isMet(down, price: 1, changePercent: -3.5), isTrue);
      expect(AlertRule.isMet(down, price: 1, changePercent: -2.9), isFalse);
    });

    test('evaluate fires once then re-arms after cooldown', () async {
      final svc = AlertService(InMemoryKeyValueStore());
      final t0 = DateTime.utc(2026, 8, 1, 10);
      await svc.create(
        assetId: 'fx_eur',
        type: AlertType.priceAbove,
        threshold: 100,
      );

      var fired = await svc.evaluate(
        quotes: {'fx_eur': (price: 105, changePercent: 0)},
        now: t0,
      );
      expect(fired.length, 1);

      // Still within cooldown -> no refire.
      fired = await svc.evaluate(
        quotes: {'fx_eur': (price: 106, changePercent: 0)},
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(fired, isEmpty);

      // After cooldown -> fires again.
      fired = await svc.evaluate(
        quotes: {'fx_eur': (price: 107, changePercent: 0)},
        now: t0.add(const Duration(minutes: 31)),
      );
      expect(fired.length, 1);

      // Persisted.
      final reloaded = AlertService(svc.store);
      await reloaded.load();
      expect(reloaded.rules.length, 1);
    });
  });

  group('PortfolioService (§24)', () {
    test('values holdings with latest valid quotes only', () async {
      final svc = PortfolioService(InMemoryKeyValueStore());
      await svc.setQuantity('fx_eur', 10);
      await svc.setQuantity('btc_usd', 0.5);
      await svc.load();
      expect(svc.holdings.length, 2);

      final v = svc.value({
        'fx_eur': _q('fx_eur', 1.1, pct: 2),
        'btc_usd': _q('btc_usd', 50000, pct: -4),
      });
      expect(v.totalValue, closeTo(11 + 25000, 0.001));
      expect(v.dailyChange, closeTo(11 * 0.02 - 25000 * 0.04, 0.001));

      // Setting quantity <= 0 removes the line.
      await svc.setQuantity('fx_eur', 0);
      expect(svc.holdings.length, 1);
    });

    test('skips non-displayable quotes instead of crashing', () async {
      final svc = PortfolioService(InMemoryKeyValueStore());
      await svc.setQuantity('gold_18k', 5); // disabled asset, no quote
      final v = svc.value({'other': _q('other', 3)});
      expect(v.totalValue, 0);
      expect(v.lines, isEmpty);
    });
  });

  group('HistoricalSnapshotService (§19)', () {
    test(
      'records real points, dedupes timestamps, aggregates to minutes',
      () async {
        final store = InMemoryKeyValueStore();
        var fakeNow = DateTime.utc(2026, 8, 1, 10);
        final svc = HistoricalSnapshotService(store, now: () => fakeNow);

        final t = DateTime.utc(2026, 8, 1, 10);
        await svc.record({'fx_eur': PricePoint(t, 1.0)});
        await svc.record({
          'fx_eur': PricePoint(t, 1.05), // same epoch again -> ignored
        });
        expect(svc.series('fx_eur').length, 1);

        await svc.record({
          'fx_eur': PricePoint(t.add(const Duration(seconds: 5)), 1.01),
        });
        expect(svc.series('fx_eur').length, 2);

        // Advance past one minute -> aggregated persistence kicks in.
        fakeNow = t.add(const Duration(minutes: 1));
        await svc.record({'fx_eur': PricePoint(fakeNow, 1.02)});
        final raw = await store.getString('hist_fx_eur');
        expect(raw, isNotNull);
      },
    );

    test('range filter keeps only requested window', () async {
      final store = InMemoryKeyValueStore();
      final base = DateTime.utc(2026, 8, 1, 12);
      final svc = HistoricalSnapshotService(store, now: () => base);
      for (var i = 0; i < 6; i++) {
        await svc.record({
          'x': PricePoint(
            base.subtract(Duration(minutes: 5 * (5 - i))),
            1 + i * 0.001,
          ),
        });
      }
      expect(
        svc.series('x', range: const Duration(minutes: 15)).length,
        lessThanOrEqualTo(4),
      );
    });
  });

  group('TimeZoneService («تعریف ساعت»)', () {
    test('initializes database and resolves Tehran (+03:30)', () async {
      final tzSvc = TimeZoneService();
      expect(tzSvc.isInitialized, isFalse);
      await tzSvc.init();
      expect(tzSvc.isInitialized, isTrue);
      expect(tzSvc.currentLocation, 'Asia/Tehran');
      expect(tzSvc.offsetLabel, '+03:30');
      expect(tzSvc.now().timeZoneName, isNotEmpty);
    });

    test('falls back to UTC for unknown location id', () async {
      final tzSvc = TimeZoneService();
      await tzSvc.init(location: 'Not/ARealZone');
      expect(tzSvc.currentLocation, 'Etc/UTC');
      expect(tzSvc.offsetLabel, '+00:00');
    });
  });
}
