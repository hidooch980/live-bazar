import 'dart:math' as math;

import '../domain/entities/price_quote.dart';

/// MOLIDO MARKET SCORE (§17) — 0..100 statistical indicator.
///
/// IMPORTANT: informational only. NEVER presented as buy/sell/trade advice.
class MarketScore {
  const MarketScore({
    required this.value,
    required this.trend,
    required this.momentum,
    required this.volatility,
    required this.confidence,
  });

  final int value;
  final ScoreTrend trend;
  final ScoreTrend momentum;
  final Volatility volatility;
  final double confidence;

  static MarketScore compute(PriceQuote q, {double? dailyRangeFraction}) {
    // Trend from signed change percent.
    final trend = _trendOf(q.changePercent);

    // Momentum proxy: same direction as trend (single-observation V1).
    final momentum = trend;

    // Volatility proxy: |change%| bands.
    final absPct = q.changePercent.abs();
    final vol = absPct >= 3
        ? Volatility.high
        : absPct >= 1
        ? Volatility.medium
        : Volatility.low;

    var score = 50.0 + q.changePercent.clamp(-10, 10) * 2.5;
    if (dailyRangeFraction != null) {
      score -= dailyRangeFraction * 100; // wide ranges dampen the score
    }
    final clamped = score.clamp(0, 100).round();

    return MarketScore(
      value: clamped,
      trend: trend,
      momentum: momentum,
      volatility: vol,
      confidence: q.confidence.clamp(0, 1).toDouble(),
    );
  }

  static ScoreTrend _trendOf(double pct) {
    if (pct > 0.05) return ScoreTrend.up;
    if (pct < -0.05) return ScoreTrend.down;
    return ScoreTrend.flat;
  }
}

enum ScoreTrend { up, down, flat }

enum Volatility { low, medium, high }

/// Simple historical aggregation helper (§19): collapses raw observations
/// into coarser buckets so storage stays bounded.
class HistoricalAggregator {
  /// Keeps roughly one observation per [bucket] duration.
  static List<PriceQuote> aggregate(
    List<PriceQuote> orderedAsc,
    Duration bucket,
  ) {
    if (orderedAsc.isEmpty) return const [];
    final out = <PriceQuote>[];
    DateTime? bucketStart;
    for (final q in orderedAsc) {
      final start = DateTime.fromMillisecondsSinceEpoch(
        (q.timestamp.millisecondsSinceEpoch ~/ bucket.inMilliseconds) *
            bucket.inMilliseconds,
        isUtc: true,
      );
      if (bucketStart == null || !start.isAtSameMomentAs(bucketStart)) {
        bucketStart = start;
        out.add(q);
      } else {
        // Same bucket: keep the LAST observation of the bucket.
        out[out.length - 1] = q;
      }
    }
    return List.unmodifiable(out);
  }

  static double volatilityPercent(List<PriceQuote> quotes) {
    if (quotes.length < 2) return 0;
    final rets = <double>[];
    for (var i = 1; i < quotes.length; i++) {
      final p0 = quotes[i - 1].price;
      if (p0 > 0) rets.add((quotes[i].price - p0) / p0);
    }
    if (rets.isEmpty) return 0;
    final mean = rets.reduce((a, b) => a + b) / rets.length;
    final variance =
        rets.map((r) => math.pow(r - mean, 2)).reduce((a, b) => a + b) /
        rets.length;
    return math.sqrt(variance) * 100;
  }
}
