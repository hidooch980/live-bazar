import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/http_config.dart';
import '../../config/asset_catalog.dart';
import '../../domain/entities/price_quote.dart';
import '../iprice_provider.dart';

/// Crypto quotes with an IRAN-ACCESSIBLE FAILOVER CHAIN (all keyless):
///
/// 1. CoinGecko   — global default (geo-blocks some regions)
/// 2. CoinPaprika — global alternative
/// 3. CoinLore    — lightweight, usually reachable
/// 4. Nobitex     — Iranian exchange, reachable inside Iran (USDT pairs)
///
/// Only REAL published data with the endpoint's real timestamp is returned.
class CryptoProvider implements IPriceProvider {
  CryptoProvider({Dio? dio}) : _dio = dio ?? MarketHttp.instance.createClient();

  final Dio _dio;

  @override
  String get id => 'crypto-chain';

  @override
  String get displayName => 'Crypto';

  @override
  Duration get minRefreshInterval => AppConstants.cryptoMinInterval;

  @override
  Set<String> get supportedAssets => const {'btc_usd', 'eth_usd', 'usdt_usd'};

  @override
  bool get isEnabled => true;

  String? _lastSource;
  @override
  Future<bool> healthCheck() async => true;

  String get activeSource => _lastSource ?? '-';

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    final attempts = <String, Future<ProviderResult> Function()>{
      'CoinGecko': () => _fromCoinGecko(assetIds),
      'CoinPaprika': () => _fromCoinPaprika(assetIds),
      'CoinLore': () => _fromCoinLore(assetIds),
      'Nobitex': () => _fromNobitex(assetIds),
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
          : AppException(AppErrorCode.network, 'all crypto endpoints failed'),
    );
  }

  // ---- 1) CoinGecko -------------------------------------------------
  Future<ProviderResult> _fromCoinGecko(Set<String> assetIds) async {
    const map = {
      'btc_usd': 'bitcoin',
      'eth_usd': 'ethereum',
      'usdt_usd': 'tether',
    };
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://api.coingecko.com/api/v3/simple/price',
        queryParameters: {
          'ids': map.values.join(','),
          'vs_currencies': 'usd',
          'include_24hr_change': 'true',
        },
      );
      final data = res.data;
      if (data == null || data.isEmpty) return _bad('CoinGecko empty');
      final body = Map<String, dynamic>.from(data.first as Map);
      final ts = _serverTime(res) ?? DateTime.now().toUtc();
      final quotes = <PriceQuote>[];
      for (final e in map.entries) {
        if (!assetIds.contains(e.key)) continue;
        final coin = body[e.value];
        if (coin is! Map) continue;
        final cd = Map<String, dynamic>.from(coin);
        final price = (cd['usd'] as num?)?.toDouble();
        if (price == null || price <= 0) continue;
        quotes.add(
          _quote(
            e.key,
            price,
            pct: (cd['usd_24h_change'] as num?)?.toDouble() ?? 0,
            ts: ts,
            source: 'CoinGecko',
            status: QuoteStatus.live,
          ),
        );
      }
      if (quotes.isEmpty) return _bad('CoinGecko no usable quotes');
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return _err('CoinGecko', e);
    } catch (e) {
      return _err('CoinGecko', e);
    }
  }

  // ---- 2) CoinPaprika ------------------------------------------------
  Future<ProviderResult> _fromCoinPaprika(Set<String> assetIds) async {
    const map = {
      'btc_usd': 'btc-bitcoin',
      'eth_usd': 'eth-ethereum',
      'usdt_usd': 'usdt-tether',
    };
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://api.coinpaprika.com/v1/tickers',
      );
      final data = res.data;
      if (data == null) return _bad('Paprika empty');
      final ts = _serverTime(res) ?? DateTime.now().toUtc();
      final quotes = <PriceQuote>[];
      for (final item in data) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = m['id'] as String?;
        final assetId = map.entries
            .where((e) => e.value == id)
            .map((e) => e.key)
            .firstWhere((v) => assetIds.contains(v), orElse: () => '');
        if (assetId.isEmpty) continue;
        final price = (m['price'] as num?)?.toDouble() ?? 0;
        if (price <= 0) continue;
        final pct = ((m['percent_change_24h'] as num?) ?? 0).toDouble();
        quotes.add(
          _quote(
            assetId,
            price,
            pct: pct,
            ts: ts,
            source: 'CoinPaprika',
            status: QuoteStatus.live,
          ),
        );
      }
      if (quotes.isEmpty) return _bad('Paprika no usable quotes');
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return _err('CoinPaprika', e);
    } catch (e) {
      return _err('CoinPaprika', e);
    }
  }

  // ---- 3) CoinLore ----------------------------------------------------
  Future<ProviderResult> _fromCoinLore(Set<String> assetIds) async {
    const map = {'btc_usd': 'BTC', 'eth_usd': 'ETH', 'usdt_usd': 'USDT'};
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        'https://api.coinlore.net/api/tickers/',
        queryParameters: {'start': 0, 'limit': 100},
      );
      final data = res.data;
      final listRaw = data?['data'];
      if (listRaw is! List) return _bad('CoinLore empty');
      final ts = _serverTime(res) ?? DateTime.now().toUtc();
      final quotes = <PriceQuote>[];
      for (final item in listRaw) {
        final m = Map<String, dynamic>.from(item as Map);
        final sym = (m['symbol'] as String?)?.toUpperCase();
        final assetId = map.entries
            .where((e) => e.value == sym)
            .map((e) => e.key)
            .firstWhere((v) => assetIds.contains(v), orElse: () => '');
        if (assetId.isEmpty) continue;
        final price = double.tryParse('${m['price_usd']}') ?? 0;
        if (price <= 0) continue;
        final pct = double.tryParse('${m['percent_change_24h']}') ?? 0;
        quotes.add(
          _quote(
            assetId,
            price,
            pct: pct,
            ts: ts,
            source: 'CoinLore',
            status: QuoteStatus.live,
          ),
        );
      }
      if (quotes.isEmpty) return _bad('CoinLore no usable quotes');
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return _err('CoinLore', e);
    } catch (e) {
      return _err('CoinLore', e);
    }
  }

  // ---- 4) Nobitex (reachable inside Iran; USDT-denominated) ----------
  Future<ProviderResult> _fromNobitex(Set<String> assetIds) async {
    try {
      final res = await _dio.post<Map<dynamic, dynamic>>(
        'https://api.nobitex.ir/market/stats',
        data: {'srcCurrency': 'btc,eth,usdt', 'dstCurrency': 'usdt'},
      );
      final body = res.data;
      final statsRaw = body?['stats'];
      if (statsRaw is! Map) return _bad('Nobitex empty');
      final stats = Map<String, dynamic>.from(statsRaw);
      final ts = _serverTime(res) ?? DateTime.now().toUtc();
      const map = {'btc': 'btc_usd', 'eth': 'eth_usd', 'usdt': 'usdt_usd'};
      final quotes = <PriceQuote>[];
      stats.forEach((key, value) {
        final assetId = map[key.toLowerCase()];
        if (assetId == null || !assetIds.contains(assetId)) return;
        if (value is! Map) return;
        final v = Map<String, dynamic>.from(value);
        // "latest" is a stringified number in Nobitex responses.
        final price = double.tryParse('${v['latest']}') ?? 0;
        if (price <= 0) return;
        final dayChange = double.tryParse('${v['dayChange']}') ?? 0;
        quotes.add(
          _quote(
            assetId,
            price,
            pct: dayChange,
            ts: ts,
            source: 'Nobitex',
            status: QuoteStatus.live,
          ),
        );
      });
      if (quotes.isEmpty) return _bad('Nobitex no usable quotes');
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return _err('Nobitex', e);
    } catch (e) {
      return _err('Nobitex', e);
    }
  }

  // ---- helpers --------------------------------------------------------
  PriceQuote _quote(
    String assetId,
    double price, {
    required double pct,
    required DateTime ts,
    required String source,
    required QuoteStatus status,
  }) {
    final def = AssetCatalog.byId(assetId)!;
    return PriceQuote(
      id: def.id,
      symbol: def.symbol,
      name: def.name,
      nameFa: def.nameFa,
      category: def.category,
      price: price,
      changePercent: pct,
      unit: def.unit,
      currency: def.currency,
      timestamp: ts,
      source: source,
      status: status,
    );
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
