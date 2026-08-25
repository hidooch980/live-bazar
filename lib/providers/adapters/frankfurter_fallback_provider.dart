import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../config/asset_catalog.dart';
import '../../domain/entities/price_quote.dart';
import '../iprice_provider.dart';

/// Verified secondary source: https://api.frankfurter.dev/v1/latest
/// ECB reference rates — public, keyless, documented.
/// Covers a subset (ECB currencies); used as fallback only.
class FrankfurterFallbackProvider implements IPriceProvider {
  FrankfurterFallbackProvider({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppConstants.requestTimeout,
              receiveTimeout: AppConstants.requestTimeout,
            ),
          );

  static const _endpoint = 'https://api.frankfurter.dev/v1/latest';

  static const _map = <String, String>{
    'fx_eur': 'EUR',
    'fx_gbp': 'GBP',
    'fx_try': 'TRY',
    'fx_cny': 'CNY',
    'fx_cad': 'CAD',
    'fx_aud': 'AUD',
    'fx_chf': 'CHF',
    'fx_jpy': 'JPY',
  };

  final Dio _dio;

  @override
  String get id => 'frankfurter';

  @override
  String get displayName => 'Frankfurter (ECB)';

  @override
  Duration get minRefreshInterval => AppConstants.globalCurrencyMinInterval;

  @override
  Set<String> get supportedAssets => _map.keys.toSet();

  @override
  bool get isEnabled => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        _endpoint,
        queryParameters: {'base': 'USD'},
      );
      final body = res.data;
      if (body == null) {
        return ProviderResult(
          quotes: [],
          error: const AppException(AppErrorCode.invalidData, 'Empty body'),
        );
      }
      final ratesRaw = body['rates'];
      if (ratesRaw is! Map) {
        return ProviderResult(
          quotes: [],
          error: const AppException(AppErrorCode.invalidData, 'Missing rates'),
        );
      }
      final rates = Map<String, dynamic>.from(ratesRaw);
      var ts = _serverTime(res) ?? DateTime.now().toUtc();
      final dateStr = body['date'];
      if (dateStr is String) {
        ts = DateTime.tryParse(dateStr)?.toUtc() ?? ts;
      }

      final quotes = <PriceQuote>[];
      for (final entry in _map.entries) {
        if (!assetIds.contains(entry.key)) continue;
        final rate = (rates[entry.value] as num?)?.toDouble();
        if (rate == null || rate <= 0) continue;
        final def = AssetCatalog.byId(entry.key)!;
        quotes.add(
          PriceQuote(
            id: def.id,
            symbol: def.symbol,
            name: def.name,
            nameFa: def.nameFa,
            category: def.category,
            price: 1 / rate,
            unit: def.unit,
            currency: def.currency,
            timestamp: ts,
            source: displayName,
            status: QuoteStatus.fallback,
            confidence: 0.9,
          ),
        );
      }
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return ProviderResult(
        quotes: [],
        error: AppException(
          e.response?.statusCode == 429
              ? AppErrorCode.rateLimited
              : AppErrorCode.network,
          'Frankfurter request failed',
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
      final res = await _dio.get<Map<dynamic, dynamic>>(
        _endpoint,
        queryParameters: {'base': 'USD', 'symbols': 'EUR'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  DateTime? _serverTime(Response<dynamic> res) =>
      DateTime.tryParse(res.headers.value('date') ?? '')?.toUtc();
}
