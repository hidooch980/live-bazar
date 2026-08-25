import '../../core/errors/app_exception.dart';
import '../iprice_provider.dart';

/// Placeholder for sources that require server-side credentials or have no
/// official public API (Iranian free market, gold/coins, commodities).
///
/// Per MASTER PROMPT §10 & §33 these stay DISABLED in the no-backend V1 and
/// the UI must show DATA UNAVAILABLE / SERVER_REQUIRED — never fabricated
/// data.
class ServerRequiredProvider implements IPriceProvider {
  const ServerRequiredProvider({
    required this.id,
    required this.displayName,
    required this.supportedAssets,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final Set<String> supportedAssets;

  @override
  Duration get minRefreshInterval => const Duration(hours: 24);

  @override
  bool get isEnabled => false; // SERVER_REQUIRED -> disabled in V1

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async =>
      ProviderResult(
        quotes: [],
        error: const AppException(
          AppErrorCode.serverRequired,
          'No verified keyless source in V1',
        ),
      );

  @override
  Future<bool> healthCheck() async => false;
}
