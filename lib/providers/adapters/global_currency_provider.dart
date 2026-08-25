import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../config/asset_catalog.dart';
import '../../domain/entities/price_quote.dart';
import '../iprice_provider.dart';

/// Verified primary source: https://open.er-api.com/v6/latest/USD
/// (ExchangeRate-API open endpoint — public, keyless, documented.)
///
/// Rates are relative to USD; cross rates are derived: EUR/USD = 1/EUR.
/// The provider publishes a daily epoch (time_last_update_unix); the app
/// keeps checking every 5s but data stays valid until the epoch advances.
class GlobalCurrencyProvider implements IPriceProvider {
  GlobalCurrencyProvider({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppConstants.requestTimeout,
              receiveTimeout: AppConstants.requestTimeout,
            ),
          );

  static const _endpoint = 'https://open.er-api.com/v6/latest/USD';

  /// asset id -> ISO code served by this provider.
  static const _map = <String, String>{
    'fx_usd': 'USD',
    'fx_eur': 'EUR',
    'fx_gbp': 'GBP',
    'fx_aed': 'AED',
    'fx_try': 'TRY',
    'fx_cny': 'CNY',
    'fx_cad': 'CAD',
    'fx_aud': 'AUD',
    'fx_chf': 'CHF',
    'fx_jpy': 'JPY',
  };

  final Dio _dio;

  @override
  String get id => 'erapi';

  @override
  String get displayName => 'ExchangeRate-API';

  @override
  Duration get minRefreshInterval => AppConstants.globalCurrencyMinInterval;

  @override
  Set<String> get supportedAssets => _map.keys.toSet();

  @override
  bool get isEnabled => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(_endpoint);
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
      final usdPerUnit = <String, double>{};
      rates.forEach((k, v) {
        final r = (v as num?)?.toDouble();
        if (r != null && r > 0) usdPerUnit[k] = r;
      });

      final epochUnix = (body['time_last_update_unix'] as num?)?.toInt();
      // Real provider publication time (falls back to response date).
      var ts = epochUnix == null
          ? (_serverTime(res) ?? DateTime.now().toUtc())
          : DateTime.fromMillisecondsSinceEpoch(epochUnix * 1000, isUtc: true);

      final quotes = <PriceQuote>[];
      for (final entry in _map.entries) {
        if (!assetIds.contains(entry.key)) continue;
        final code = entry.value;
        double? price;
        if (code == 'USD') {
          price = 1.0;
        } else if (code == 'IRR') {
          price = usdPerUnit['IRR'];
        } else if (usdPerUnit.containsKey(code) && usdPerUnit[code]! > 0) {
          // units of USD per 1 unit of code
          price = 1 / usdPerUnit[code]!;
        } else {
          ts = ts;
        }
        if (price == null || price <= 0) continue;
        final def = AssetCatalog.byId(entry.key)!;
        quotes.add(
          PriceQuote(
            id: def.id,
            symbol: def.symbol,
            name: def.name,
            nameFa: def.nameFa,
            category: def.category,
            price: price,
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
          e.response?.statusCode == 429
              ? AppErrorCode.rateLimited
              : AppErrorCode.network,
          'ExchangeRate-API request failed',
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
      final res = await _dio.get<Map<dynamic, dynamic>>(_endpoint);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  DateTime? _serverTime(Response<dynamic> res) =>
      DateTime.tryParse(res.headers.value('date') ?? '')?.toUtc();
}
