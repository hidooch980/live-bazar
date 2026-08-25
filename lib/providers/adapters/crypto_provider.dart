import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../config/asset_catalog.dart';
import '../../domain/entities/price_quote.dart';
import '../iprice_provider.dart';

/// Verified source: https://api.coingecko.com/api/v3/simple/price
/// Public, keyless, documented. Rate limits respected via minRefreshInterval.
class CryptoProvider implements IPriceProvider {
  CryptoProvider({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppConstants.requestTimeout,
              receiveTimeout: AppConstants.requestTimeout,
            ),
          );

  static const _endpoint = 'https://api.coingecko.com/api/v3/simple/price';

  static const _map = <String, String>{
    'btc_usd': 'bitcoin',
    'eth_usd': 'ethereum',
    'usdt_usd': 'tether',
  };

  final Dio _dio;

  @override
  String get id => 'coingecko';

  @override
  String get displayName => 'CoinGecko';

  @override
  Duration get minRefreshInterval => AppConstants.cryptoMinInterval;

  @override
  Set<String> get supportedAssets => _map.keys.toSet();

  @override
  bool get isEnabled => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    final wanted = _map.entries.where((e) => assetIds.contains(e.key)).toList();
    if (wanted.isEmpty) {
      return const ProviderResult(quotes: []);
    }
    try {
      final ids = wanted.map((e) => e.value).join(',');
      final res = await _dio.get<List<dynamic>>(
        _endpoint,
        queryParameters: {
          'ids': ids,
          'vs_currencies': 'usd',
          'include_24hr_change': 'true',
        },
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        return ProviderResult(
          quotes: [],
          error: const AppException(AppErrorCode.invalidData, 'Empty response'),
        );
      }
      final body = Map<String, dynamic>.from(data.first as Map);
      // Observation time = real server response time.
      final ts = _serverTime(res) ?? DateTime.now().toUtc();
      final quotes = <PriceQuote>[];
      for (final entry in wanted) {
        final coin = body[entry.value];
        if (coin is! Map) continue;
        final coinData = Map<String, dynamic>.from(coin);
        final price = (coinData['usd'] as num?)?.toDouble();
        if (price == null || price <= 0) continue;
        final def = AssetCatalog.byId(entry.key)!;
        final changePct = (coinData['usd_24h_change'] as num?)?.toDouble() ?? 0;
        quotes.add(
          PriceQuote(
            id: def.id,
            symbol: def.symbol,
            name: def.name,
            nameFa: def.nameFa,
            category: def.category,
            price: price,
            changePercent: changePct,
            unit: def.unit,
            currency: def.currency,
            timestamp: ts,
            source: displayName,
            status: QuoteStatus.live,
          ),
        );
      }
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return ProviderResult(
        quotes: [],
        error: AppException(
          e.type == DioExceptionType.badResponse &&
                  e.response?.statusCode == 429
              ? AppErrorCode.rateLimited
              : AppErrorCode.network,
          'CoinGecko request failed',
          cause: e,
        ),
      );
    } catch (e) {
      return ProviderResult(
        quotes: [],
        error: AppException(AppErrorCode.unknown, 'Unexpected', cause: e),
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final res = await _dio.get<List<dynamic>>(
        _endpoint,
        queryParameters: {'ids': 'bitcoin', 'vs_currencies': 'usd'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  DateTime? _serverTime(Response<dynamic> res) {
    final h = res.headers.value('date');
    return h == null ? null : DateTime.tryParse(h)?.toUtc();
  }
}
