import '../domain/entities/price_quote.dart';

/// MOLIDO MARKET PULSE (§16) — informational aggregate of the market.
class MarketPulse {
  const MarketPulse({
    required this.rising,
    required this.falling,
    required this.unchanged,
    this.biggestGain,
    this.biggestLoss,
  });

  final int rising;
  final int falling;
  final int unchanged;
  final PriceQuote? biggestGain;
  final PriceQuote? biggestLoss;

  PulseDirection get direction {
    if (rising > falling) return PulseDirection.up;
    if (falling > rising) return PulseDirection.down;
    return PulseDirection.neutral;
  }

  static MarketPulse compute(Iterable<PriceQuote> quotes) {
    var rising = 0, falling = 0, unchanged = 0;
    PriceQuote? gain;
    PriceQuote? loss;
    for (final q in quotes) {
      if (q.changePercent > 0.0001) {
        rising++;
        if (gain == null || q.changePercent > gain.changePercent) {
          gain = q;
        }
      } else if (q.changePercent < -0.0001) {
        falling++;
        if (loss == null || q.changePercent < loss.changePercent) {
          loss = q;
        }
      } else {
        unchanged++;
      }
    }
    return MarketPulse(
      rising: rising,
      falling: falling,
      unchanged: unchanged,
      biggestGain: gain,
      biggestLoss: loss,
    );
  }
}

enum PulseDirection { up, down, neutral }
