import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/price_quote.dart';

/// Detects abnormal observations against the last valid value (§15).
class AnomalyDetectionService {
  const AnomalyDetectionService();

  AnomalyState assess({
    required PriceQuote candidate,
    required PriceQuote? previousValid,
    double jumpFraction = AppConstants.anomalyJumpFraction,
  }) {
    final last = previousValid;
    if (last == null ||
        candidate.timestamp == last.timestamp ||
        candidate.price == last.price) {
      return AnomalyState.valid;
    }

    // Timestamp regression => suspicious.
    if (candidate.timestamp.isBefore(last.timestamp)) {
      return AnomalyState.suspicious;
    }

    final rel = ((candidate.price - last.price).abs()) / last.price;
    if (rel > jumpFraction) {
      // Large single-step move: caller should prefer fallback / last valid.
      return AnomalyState.suspicious;
    }
    return AnomalyState.valid;
  }

  @visibleForTesting
  static String describe(AnomalyState s) => s.name;
}
