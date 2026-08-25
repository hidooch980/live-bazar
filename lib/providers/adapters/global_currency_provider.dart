import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/http_config.dart';
import '../../config/asset_catalog.dart';
import '../../domain/entities/price_quote.dart';
import '../iprice_provider.dart';

/// Global FX quotes with an IRAN-ACCESSIBLE FAILOVER CHAIN (all keyless):
///
/// 1. ExchangeRate-API (open.er-api.com) — daily epoch, global default
/// 2. jsDelivr currency-api (@fawazahmed0) — CDN, usually reachable in IR
/// 3. Frankfurter (ECB) — European reference rates
///
/// All quotes are USD-terms cross rates derived from REAL published rates.
class GlobalCurrencyProvider implements IPriceProvider {
  GlobalCurrencyProvider({Dio? dio})
    : _dio = dio ?? MarketHttp.instance.createClient();

  final Dio _dio;

  static const _codes = <String, String>{
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

  @override
  String get id => 'fx-chain';

  @override
  String get displayName => 'FX';

  @override
  Duration get minRefreshInterval => AppConstants.globalCurrencyMinInterval;

  @override
  Set<String> get supportedAssets => _codes.keys.toSet();

  @override
  bool get isEnabled => true;

  String? _lastSource;
  String get activeSource => _lastSource ?? '-';

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    final attempts = <String, Future<ProviderResult> Function()>{
      'ExchangeRate-API': () => _fromErApi(assetIds),
      'jsDelivr-FX': () => _fromJsDelivr(assetIds),
      'Frankfurter': () => _fromFrankfurter(assetIds),
    };

    Object? lastError;
    for (final e in attempts.entries) {
      final r = await e.value();
      if (r.isSuccess && r.quotes.isNotEmpty) {
        _lastSource = e.key;
        return r;
      }
      lastError = r.error;
    }
    return ProviderResult(
      quotes: [],
      error: lastError is AppException
          ? lastError
          : const AppException(AppErrorCode.network, 'all fx endpoints failed'),
    );
  }

  // ---- 1) open.er-api.com -------------------------------------------
  Future<ProviderResult> _fromErApi(Set<String> assetIds) async {
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        'https://open.er-api.com/v6/latest/USD',
      );
      final body = res.data;
      final ratesRaw = body?['rates'];
      if (ratesRaw is! Map) return _bad('er-api missing rates');
      final rates = Map<String, dynamic>.from(ratesRaw);
      final epochUnix = (body?['time_last_update_unix'] as num?)?.toInt();
      var ts = epochUnix == null
          ? (_serverTime(res) ?? DateTime.now().toUtc())
          : DateTime.fromMillisecondsSinceEpoch(epochUnix * 1000, isUtc: true);
      // rates: units of X per 1 USD -> invert for USD-per-X.
      final usdPerUnit = <String, double>{};
      rates.forEach((k, v) {
        final r = (v as num?)?.toDouble();
        if (r != null && r > 0) usdPerUnit[k.toUpperCase()] = 1 / r;
      });
      usdPerUnit['USD'] = 1.0;
      return _build(
        usdPerUnit,
        assetIds,
        ts,
        'ExchangeRate-API',
        QuoteStatus.live,
        1.0,
      );
    } on DioException catch (e) {
      return _err('er-api', e);
    } catch (e) {
      return _err('er-api', e);
    }
  }

  // ---- 2) jsDelivr @fawazahmed0 currency-api -------------------------
  Future<ProviderResult> _fromJsDelivr(Set<String> assetIds) async {
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
      );
      final body = res.data;
      final ratesRaw = body?['usd'];
      if (ratesRaw is! Map) return _bad('jsdelivr missing usd map');
      final rates = Map<String, dynamic>.from(ratesRaw);
      final dateStr = body?['date'];
      var ts = _serverTime(res) ?? DateTime.now().toUtc();
      if (dateStr is String) {
        ts = DateTime.tryParse(dateStr)?.toUtc() ?? ts;
      }
      // rates: units of X per 1 USD -> invert for USD-per-X.
      final usdPerUnit = <String, double>{};
      rates.forEach((k, v) {
        final r = (v as num?)?.toDouble();
        if (r != null && r > 0) usdPerUnit[k.toUpperCase()] = 1 / r;
      });
      return _build(
        usdPerUnit,
        assetIds,
        ts,
        'jsDelivr-FX',
        QuoteStatus.live,
        0.95,
      );
    } on DioException catch (e) {
      return _err('jsdelivr', e);
    } catch (e) {
      return _err('jsdelivr', e);
    }
  }

  // ---- 3) frankfurter.dev (ECB) --------------------------------------
  Future<ProviderResult> _fromFrankfurter(Set<String> assetIds) async {
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        'https://api.frankfurter.dev/v1/latest',
        queryParameters: {'base': 'USD'},
      );
      final body = res.data;
      final ratesRaw = body?['rates'];
      if (ratesRaw is! Map) return _bad('frankfurter missing rates');
      final rates = Map<String, dynamic>.from(ratesRaw);
      final dateStr = body?['date'];
      var ts = _serverTime(res) ?? DateTime.now().toUtc();
      if (dateStr is String) {
        ts = DateTime.tryParse(dateStr)?.toUtc() ?? ts;
      }
      final usdPerUnit = <String, double>{};
      rates.forEach((k, v) {
        final r = (v as num?)?.toDouble();
        if (r != null && r > 0) usdPerUnit[k.toUpperCase()] = 1 / r;
      });
      return _build(
        usdPerUnit,
        assetIds,
        ts,
        'Frankfurter',
        QuoteStatus.fallback,
        0.9,
      );
    } on DioException catch (e) {
      return _err('frankfurter', e);
    } catch (e) {
      return _err('frankfurter', e);
    }
  }

  // ---- shared builder -------------------------------------------------
  ProviderResult _build(
    Map<String, double> usdPerUnit,
    Set<String> assetIds,
    DateTime ts,
    String source,
    QuoteStatus status,
    double confidence,
  ) {
    final quotes = <PriceQuote>[];
    for (final entry in _codes.entries) {
      if (!assetIds.contains(entry.key)) continue;
      final code = entry.value;
      double? price;
      if (code == 'USD') {
        price = 1.0;
      } else {
        price = usdPerUnit[code];
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
          source: source,
          status: status,
          confidence: confidence,
        ),
      );
    }
    if (quotes.isEmpty) {
      return ProviderResult(
        quotes: [],
        error: AppException(
          AppErrorCode.invalidData,
          '$source: no usable rates',
        ),
      );
    }
    return ProviderResult(quotes: quotes);
  }

  ProviderResult _bad(String msg) => ProviderResult(
    quotes: [],
    error: AppException(AppErrorCode.invalidData, msg),
  );

  ProviderResult _err(String src, Object e) => ProviderResult(
    quotes: [],
    error: AppException(
      e is DioException && e.response?.statusCode == 429
          ? AppErrorCode.rateLimited
          : AppErrorCode.network,
      '$src failed',
      cause: e,
    ),
  );

  DateTime? _serverTime(Response<dynamic> res) =>
      DateTime.tryParse(res.headers.value('date') ?? '')?.toUtc();
}
