import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/services/market_pulse_service.dart';
import 'package:live_bazar/services/market_score_service.dart';
import 'package:live_bazar/services/validation/anomaly_detection_service.dart';
import 'package:live_bazar/services/validation/price_validation_service.dart';

PriceQuote _q(
  String id,
  double price, {
  double changePercent = 0,
  DateTime? ts,
}) => PriceQuote(
  id: id,
  symbol: id.toUpperCase(),
  name: id,
  nameFa: id,
  category: AssetCategory.currency,
  price: price,
  unit: '',
  currency: 'USD',
  changePercent: changePercent,
  timestamp: ts ?? DateTime.utc(2026, 8, 1),
  source: 'test',
  status: QuoteStatus.live,
);

void main() {
  group('PriceQuote', () {
    test('json roundtrip preserves all fields', () {
      final q = _q('fx_eur', 1.08, changePercent: -1.5);
      final back = PriceQuote.fromJson(q.toJson());
      expect(back.id, q.id);
      expect(back.price, q.price);
      expect(back.changePercent, q.changePercent);
      expect(back.timestamp, q.timestamp);
      expect(back.status, q.status);
      expect(back.category, q.category);
    });
  });

  group('PriceValidationService', () {
    const svc = PriceValidationService();

    test('accepts a healthy quote', () {
      expect(svc.validate(_q('fx_eur', 1.08)).isValid, isTrue);
    });

    test('rejects non-positive prices', () {
      expect(svc.validate(_q('fx_eur', 0)).isValid, isFalse);
      expect(svc.validate(_q('fx_eur', -2)).isValid, isFalse);
    });

    test('rejects unknown asset ids', () {
      expect(svc.validate(_q('nope', 1)).isValid, isFalse);
    });

    test('rejects future timestamps', () {
      final q = PriceQuote(
        id: 'fx_eur',
        symbol: 'EUR',
        name: 'e',
        nameFa: 'e',
        category: AssetCategory.currency,
        price: 1,
        unit: '',
        currency: 'USD',
        timestamp: DateTime.now().toUtc().add(const Duration(hours: 2)),
        source: 't',
        status: QuoteStatus.live,
      );
      expect(svc.validate(q).isValid, isFalse);
    });

    test('conflict detection on >5% disagreement', () {
      final a = _q('fx_eur', 1.00);
      final b = _q('fx_eur', 1.10);
      expect(svc.isConflict(a, b), isTrue);
      expect(svc.isConflict(a, _q('fx_eur', 1.01)), isFalse);
    });
  });

  group('AnomalyDetectionService', () {
    const svc = AnomalyDetectionService();
    final base = _q('fx_eur', 100, ts: DateTime.utc(2026, 8, 1, 10));

    test('valid for first observation', () {
      expect(
        svc.assess(candidate: base, previousValid: null),
        AnomalyState.valid,
      );
    });

    test('suspicious on big jump', () {
      final next = _q(
        'fx_eur',
        150,
        ts: base.timestamp.add(const Duration(minutes: 1)),
      );
      expect(
        svc.assess(candidate: next, previousValid: base),
        AnomalyState.suspicious,
      );
    });

    test('valid on normal move', () {
      final next = _q(
        'fx_eur',
        101,
        ts: base.timestamp.add(const Duration(minutes: 1)),
      );
      expect(
        svc.assess(candidate: next, previousValid: base),
        AnomalyState.valid,
      );
    });

    test('suspicious on timestamp regression', () {
      final next = _q(
        'fx_eur',
        101,
        ts: base.timestamp.subtract(const Duration(minutes: 5)),
      );
      expect(
        svc.assess(candidate: next, previousValid: base),
        AnomalyState.suspicious,
      );
    });
  });

  group('MarketPulse', () {
    test('counts rising/falling/unchanged and extremes (§16)', () {
      final pulse = MarketPulse.compute([
        _q('a', 1, changePercent: 2),
        _q('b', 1, changePercent: 5),
        _q('c', 1, changePercent: -3),
        _q('d', 1),
      ]);
      expect(pulse.rising, 2);
      expect(pulse.falling, 1);
      expect(pulse.unchanged, 1);
      expect(pulse.biggestGain!.id, 'b');
      expect(pulse.biggestLoss!.id, 'c');
      expect(pulse.direction, PulseDirection.up);
    });
  });

  group('MarketScore & aggregation', () {
    test('score bounded 0..100 and never advice-like output', () {
      final s = MarketScore.compute(_q('fx_usd', 1, changePercent: 2));
      expect(s.value, inInclusiveRange(0, 100));
      expect(s.trend, ScoreTrend.up);
    });

    test('historical aggregator buckets observations (§19)', () {
      final t = DateTime.utc(2026, 8, 1, 10);
      final points = <(DateTime, double)>[
        (t, 1),
        (t.add(const Duration(seconds: 5)), 2),
        (t.add(const Duration(seconds: 9)), 3),
        (t.add(const Duration(seconds: 61)), 4),
      ];
      final agg = HistoricalAggregator.aggregate(
        points,
        const Duration(minutes: 1),
      );
      // Bucket1 keeps LAST observation (price 3), bucket2 has price 4.
      expect(agg.length, 2);
      expect(agg.first.$2, 3);
      expect(agg.last.$2, 4);
    });
  });
}
