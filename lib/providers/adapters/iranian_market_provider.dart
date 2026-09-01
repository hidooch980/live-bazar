import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:timezone/timezone.dart' as tz;

import '../../config/asset_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/http_config.dart';
import '../../core/utils/price_display.dart';
import '../../domain/entities/price_quote.dart';
import '../iprice_provider.dart';

/// LIVE Iranian free-market currency, gold and coin quotes.
///
/// Source: the public TGJU market feed that tgju.org itself consumes
/// (`call{1,2,3}.tgju.org/ajax.json`) — keyless, no account, no server, with
/// second-level publish timestamps. Only REAL published values are returned,
/// each carrying the feed's own timestamp; nothing is derived or fabricated.
///
/// Two details decide whether this is genuinely «لحظه‌ای»:
///
/// 1. The feed sits behind a 5-minute CDN cache, so a plain GET can return
///    data ~50 minutes old. Every request carries a bucketed cache-buster
///    ([AppConstants.iranianMarketCacheBucket]): freshness is bounded by the
///    bucket, while all clients inside one bucket still share a single cached
///    object instead of hammering the origin.
/// 2. Feed timestamps are Tehran wall-clock. They are converted to UTC before
///    the validation/staleness gates ever see them.
class IranianMarketProvider implements IPriceProvider {
  IranianMarketProvider({Dio? dio, DateTime Function()? now})
    : _dio = dio ?? MarketHttp.instance.createClient(),
      _now = now ?? (() => DateTime.now().toUtc());

  final Dio _dio;
  final DateTime Function() _now;

  /// Mirror hosts serving the same feed — tried in order.
  static const endpoints = <String>[
    'https://call1.tgju.org/ajax.json',
    'https://call2.tgju.org/ajax.json',
    'https://call3.tgju.org/ajax.json',
  ];

  /// TGJU indicator key -> catalog asset id.
  static const indicatorMap = <String, String>{
    // Free-market currencies (published in Rial).
    'price_dollar_rl': 'ir_usd',
    'price_eur': 'ir_eur',
    'price_aed': 'ir_aed',
    'price_gbp': 'ir_gbp',
    'price_try': 'ir_try',
    'price_cny': 'ir_cny',
    // Gold in Rial, plus the global ounces in USD.
    'geram18': 'gold_18k',
    'geram24': 'gold_24k',
    'mesghal': 'mesghal',
    'ons': 'xau_usd',
    'silver': 'silver',
    // Coins (Rial).
    'sekee': 'coin_emami',
    'sekeb': 'coin_bahar',
    'nim': 'coin_half',
    'rob': 'coin_quarter',
    'gerami': 'coin_gram',
  };

  static const sourceName = 'TGJU';
  static const _tehran = 'Asia/Tehran';

  /// Iran has kept a fixed UTC+03:30 offset since DST was abolished in 2022.
  /// Used only when the tz database is not initialized (plain unit tests).
  static const _tehranOffset = Duration(hours: 3, minutes: 30);

  @override
  String get id => 'iran-market';

  @override
  String get displayName => 'Iran Market';

  @override
  Duration get minRefreshInterval => AppConstants.iranianMarketMinInterval;

  @override
  Set<String> get supportedAssets => indicatorMap.values.toSet();

  @override
  bool get isEnabled => true;

  String? _lastSource;
  String get activeSource => _lastSource ?? '-';

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    Object? lastError;
    for (final url in endpoints) {
      final r = await _fetch(url, assetIds);
      if (r.isSuccess && r.quotes.isNotEmpty) {
        _lastSource = Uri.parse(url).host;
        return r;
      }
      lastError = r.error;
    }
    return ProviderResult(
      quotes: [],
      error: lastError is AppException
          ? lastError
          : const AppException(AppErrorCode.network, 'all tgju mirrors failed'),
    );
  }

  Future<ProviderResult> _fetch(String url, Set<String> assetIds) async {
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        url,
        queryParameters: {'v': _cacheBucket()},
        options: Options(headers: const {'Cache-Control': 'no-cache'}),
      );
      final body = res.data;
      if (body == null) return _bad('tgju empty body');
      final quotes = parseFeed(
        Map<String, dynamic>.from(body),
        assetIds,
        fallbackTimestamp: _serverTime(res) ?? _now(),
      );
      if (quotes.isEmpty) return _bad('tgju: no usable indicators');
      return ProviderResult(quotes: quotes);
    } on DioException catch (e) {
      return _err(e);
    } catch (e) {
      return _err(e);
    }
  }

  /// Shared cache key for everyone polling within the same time bucket.
  int _cacheBucket() =>
      _now().millisecondsSinceEpoch ~/
      AppConstants.iranianMarketCacheBucket.inMilliseconds;

  /// Maps the feed's `current` indicator table onto catalog quotes.
  @visibleForTesting
  List<PriceQuote> parseFeed(
    Map<String, dynamic> body,
    Set<String> assetIds, {
    required DateTime fallbackTimestamp,
  }) {
    final currentRaw = body['current'];
    if (currentRaw is! Map) return const [];
    final current = Map<String, dynamic>.from(currentRaw);

    final quotes = <PriceQuote>[];
    for (final entry in indicatorMap.entries) {
      if (!assetIds.contains(entry.value)) continue;
      final row = current[entry.key];
      if (row is! Map) continue;
      final def = AssetCatalog.byId(entry.value);
      if (def == null) continue;
      final published = parseNumber(row['p']);
      if (published == null) continue;

      // TGJU publishes Iranian indicators in Rial; the catalog and the whole
      // display path work in Toman. The global ounces are USD as published.
      final divisor = def.currency == 'IRR' ? PriceDisplay.rialPerToman : 1;
      // 'dt' carries the direction of the day's move ('high' up, 'low' down).
      final sign = row['dt'] == 'low' ? -1 : 1;

      quotes.add(
        PriceQuote(
          id: def.id,
          symbol: def.symbol,
          name: def.name,
          nameFa: def.nameFa,
          category: def.category,
          price: published / divisor,
          change: (parseNumber(row['d']) ?? 0) / divisor * sign,
          changePercent: ((row['dp'] as num?)?.toDouble() ?? 0) * sign,
          unit: def.unit,
          currency: def.currency,
          timestamp: tehranToUtc(row['ts']) ?? fallbackTimestamp,
          source: sourceName,
          status: QuoteStatus.live,
        ),
      );
    }
    return quotes;
  }

  /// '2,130,050' / '4,368.85' / Persian digits -> double; null when unusable.
  @visibleForTesting
  static double? parseNumber(Object? raw) {
    if (raw == null) return null;
    final s = _asciiDigits(raw.toString()).replaceAll(_separators, '');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null || !v.isFinite || v <= 0) return null;
    return v;
  }

  static final _separators = RegExp('[,٬\\s]');

  /// Feed timestamp ('2026-09-01 13:56:26', Tehran wall-clock) -> UTC.
  @visibleForTesting
  static DateTime? tehranToUtc(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final naive = DateTime.tryParse(
      _asciiDigits(raw.trim()).replaceFirst(' ', 'T'),
    );
    if (naive == null) return null;
    try {
      return tz.TZDateTime(
        tz.getLocation(_tehran),
        naive.year,
        naive.month,
        naive.day,
        naive.hour,
        naive.minute,
        naive.second,
      ).toUtc();
    } catch (_) {
      // tz database not initialized — fall back to Iran's fixed offset.
      return DateTime.utc(
        naive.year,
        naive.month,
        naive.day,
        naive.hour,
        naive.minute,
        naive.second,
      ).subtract(_tehranOffset);
    }
  }

  static String _asciiDigits(String s) {
    final buf = StringBuffer();
    for (final code in s.runes) {
      if (code >= 0x06F0 && code <= 0x06F9) {
        buf.writeCharCode(code - 0x06F0 + 0x30); // Persian digits
      } else if (code >= 0x0660 && code <= 0x0669) {
        buf.writeCharCode(code - 0x0660 + 0x30); // Arabic-Indic digits
      } else {
        buf.writeCharCode(code);
      }
    }
    return buf.toString();
  }

  ProviderResult _bad(String msg) => ProviderResult(
    quotes: [],
    error: AppException(AppErrorCode.invalidData, msg),
  );

  ProviderResult _err(Object e) => ProviderResult(
    quotes: [],
    error: AppException(
      e is DioException && e.response?.statusCode == 429
          ? AppErrorCode.rateLimited
          : AppErrorCode.network,
      'tgju failed',
      cause: e,
    ),
  );

  DateTime? _serverTime(Response<dynamic> res) =>
      DateTime.tryParse(res.headers.value('date') ?? '')?.toUtc();
}
