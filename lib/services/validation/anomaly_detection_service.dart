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
    // Reject invalid observations before equality/first-sample shortcuts.
    if (!candidate.price.isFinite || candidate.price <= 0) {
      return AnomalyState.rejected;
    }
    if (last == null) return AnomalyState.valid;
    // A corrupt baseline must never reach the relative-change division.
    if (!last.price.isFinite || last.price <= 0) {
      return AnomalyState.rejected;
    }
    // Timestamp regression => suspicious, even when the price is unchanged.
    if (candidate.timestamp.isBefore(last.timestamp)) {
      return AnomalyState.suspicious;
    }
    if (candidate.timestamp == last.timestamp ||
        candidate.price == last.price) {
      return AnomalyState.valid;
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
