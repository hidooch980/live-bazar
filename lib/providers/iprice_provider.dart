import '../core/errors/app_exception.dart';
import '../domain/entities/price_quote.dart';

/// Result of a single provider fetch cycle.
class ProviderResult {
  const ProviderResult({required this.quotes, this.error});

  final List<PriceQuote> quotes;
  final AppException? error;

  bool get isSuccess => error == null;
}

/// Contract every price source must implement.
///
/// Implementations MUST return only REAL data with the provider's real
/// timestamp. Never fabricate prices or timestamps.
abstract interface class IPriceProvider {
  String get id;
  String get displayName;

  /// Minimum allowed interval between two fetches (rate-limit protection).
  Duration get minRefreshInterval;

  /// Asset ids this provider can serve.
  Set<String> get supportedAssets;

  bool get isEnabled;

  /// Fetch the latest quotes for [assetIds]. Must never throw — return
  /// a [ProviderResult] carrying the error instead.
  Future<ProviderResult> getLatestPrices(Set<String> assetIds);

  /// Cheap liveness probe.
  Future<bool> healthCheck();
}
