import '../../config/asset_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/price_quote.dart';

/// Gatekeeper: invalid data must NEVER reach the UI state (§13).
class ValidationResult {
  const ValidationResult(this.isValid, this.reason);

  final bool isValid;
  final String reason;
}

class PriceValidationService {
  const PriceValidationService();

  ValidationResult validate(PriceQuote q) {
    if (q.price.isNaN || q.price.isInfinite) {
      return const ValidationResult(false, 'non-finite price');
    }
    if (q.price <= 0) {
      return const ValidationResult(false, 'price must be > 0');
    }
    if (AssetCatalog.byId(q.id) == null) {
      return const ValidationResult(false, 'unknown asset id');
    }
    if (q.timestamp.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    )) {
      return const ValidationResult(false, 'timestamp in the future');
    }
    if (q.source.trim().isEmpty) {
      return const ValidationResult(false, 'missing source');
    }
    if (q.currency.trim().isEmpty) {
      return const ValidationResult(false, 'missing currency');
    }
    return const ValidationResult(true, 'ok');
  }

  bool isStale(PriceQuote q, {Duration? threshold}) {
    final t = threshold ?? AppConstants.staleThreshold;
    return DateTime.now().toUtc().difference(q.timestamp.toUtc()) > t;
  }

  /// True when two sources materially disagree for the same asset (§14).
  bool isConflict(PriceQuote a, PriceQuote b, {double tolerance = 0.05}) {
    if (a.price <= 0 || b.price <= 0) return true;
    final rel =
        ((a.price - b.price).abs()) / (a.price > b.price ? a.price : b.price);
    return rel > tolerance;
  }
}
