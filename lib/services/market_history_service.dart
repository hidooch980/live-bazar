import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../config/asset_catalog.dart';
import '../core/network/http_config.dart';
import '../core/utils/fa_number.dart';
import '../core/utils/price_display.dart';
import '../data/cache/local_state_store.dart';
import '../providers/adapters/iranian_market_provider.dart';

/// One published trading day. Values are already in the asset's display
/// unit (Toman for Rial-quoted assets), exactly like a live quote.
class DailyCandle {
  const DailyCandle({
    required this.date,
    required this.open,
    required this.low,
    required this.high,
    required this.close,
    required this.jalali,
  });

  final DateTime date;
  final double open;
  final double low;
  final double high;
  final double close;

  /// Persian date string as the source published it ('1405/06/09').
  final String jalali;

  Map<String, dynamic> toJson() => {
    'd': date.millisecondsSinceEpoch,
    'o': open,
    'l': low,
    'h': high,
    'c': close,
    'j': jalali,
  };

  static DailyCandle fromJson(Map<String, dynamic> j) => DailyCandle(
    date: DateTime.fromMillisecondsSinceEpoch((j['d'] as num).toInt()),
    open: (j['o'] as num).toDouble(),
    low: (j['l'] as num).toDouble(),
    high: (j['h'] as num).toDouble(),
    close: (j['c'] as num).toDouble(),
    jalali: (j['j'] as String?) ?? '',
  );
}

/// Real daily history for the assets TGJU publishes a table for.
///
/// The dashboard's own [HistoricalSnapshotService] only ever holds what
/// accumulated while the app was open — minutes, sometimes hours. This
/// service fetches the source's published daily table instead (thousands
/// of real trading days) so a chart has something to draw on first run.
///
/// Still no fabrication: every candle is a published OHLC row carrying the
/// source's own date. Assets without a TGJU table (crypto, global FX) are
/// simply not served here — the caller falls back to local points.
class MarketHistoryService {
  MarketHistoryService({
    required this.store,
    Dio? dio,
    DateTime Function()? now,
  }) : _dio = dio ?? MarketHttp.instance.createClient(),
       _now = now ?? (() => DateTime.now().toUtc());

  final KeyValueStore store;
  final Dio _dio;
  final DateTime Function() _now;

  static const _prefix = 'daily_';

  /// Daily rows change once a day; re-fetching sooner is wasted bandwidth.
  static const cacheTtl = Duration(hours: 6);

  /// Keeps ~5 years per asset so the cache cannot grow without bound.
  static const maxCandles = 2000;

  static const _endpoint =
      'https://api.tgju.org/v1/market/indicator/summary-table-data';

  final _memory = <String, List<DailyCandle>>{};

  /// The TGJU indicator key backing [assetId], or null when the source
  /// publishes no table for it.
  static String? indicatorKeyFor(String assetId) {
    for (final e in IranianMarketProvider.indicatorMap.entries) {
      if (e.value == assetId) return e.key;
    }
    return null;
  }

  static bool hasHistory(String assetId) => indicatorKeyFor(assetId) != null;

  /// Cached-first daily candles, oldest first. Empty when unavailable.
  Future<List<DailyCandle>> daily(String assetId) async {
    final cached = _memory[assetId];
    if (cached != null) return cached;

    final stored = await _readCache(assetId);
    if (stored != null) {
      _memory[assetId] = stored;
      return stored;
    }

    final fetched = await _fetch(assetId);
    if (fetched.isEmpty) {
      // Serve a stale cache rather than an empty chart when the network
      // is the thing that failed.
      final stale = await _readCache(assetId, ignoreTtl: true);
      if (stale != null) {
        _memory[assetId] = stale;
        return stale;
      }
      return const [];
    }
    _memory[assetId] = fetched;
    await _writeCache(assetId, fetched);
    return fetched;
  }

  Future<List<DailyCandle>> _fetch(String assetId) async {
    final key = indicatorKeyFor(assetId);
    if (key == null) return const [];
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>('$_endpoint/$key');
      final rows = res.data?['data'];
      if (rows is! List) return const [];
      return parseRows(rows, assetId);
    } catch (_) {
      return const [];
    }
  }

  /// Rows arrive newest-first as
  /// `[open, low, high, close, changeHtml, percentHtml, 'YYYY/MM/DD', jalali]`.
  @visibleForTesting
  static List<DailyCandle> parseRows(List<dynamic> rows, String assetId) {
    final def = AssetCatalog.byId(assetId);
    if (def == null) return const [];
    final divisor = def.currency == 'IRR' ? PriceDisplay.rialPerToman : 1;

    final out = <DailyCandle>[];
    for (final row in rows) {
      if (row is! List || row.length < 7) continue;
      final open = parseMarketNumber(row[0]);
      final low = parseMarketNumber(row[1]);
      final high = parseMarketNumber(row[2]);
      final close = parseMarketNumber(row[3]);
      if (open == null || low == null || high == null || close == null) {
        continue;
      }
      final date = _gregorian(row[6]);
      if (date == null) continue;
      out.add(
        DailyCandle(
          date: date,
          open: open / divisor,
          low: low / divisor,
          high: high / divisor,
          close: close / divisor,
          jalali: row.length > 7 ? '${row[7]}' : '',
        ),
      );
    }
    out.sort((a, b) => a.date.compareTo(b.date)); // oldest first
    if (out.length > maxCandles) {
      return out.sublist(out.length - maxCandles);
    }
    return out;
  }

  static DateTime? _gregorian(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  @visibleForTesting
  Future<List<DailyCandle>?> readCacheForTest(
    String assetId, {
    bool ignoreTtl = false,
  }) => _readCache(assetId, ignoreTtl: ignoreTtl);

  @visibleForTesting
  Future<void> writeCacheForTest(String assetId, List<DailyCandle> candles) =>
      _writeCache(assetId, candles);

  Future<List<DailyCandle>?> _readCache(
    String assetId, {
    bool ignoreTtl = false,
  }) async {
    final raw = await store.getString('$_prefix$assetId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
        (decoded['at'] as num).toInt(),
        isUtc: true,
      );
      if (!ignoreTtl && _now().difference(fetchedAt) > cacheTtl) return null;
      final list = decoded['c'];
      if (list is! List) return null;
      return [
        for (final e in list)
          DailyCandle.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String assetId, List<DailyCandle> candles) async {
    await store.setString(
      '$_prefix$assetId',
      jsonEncode({
        'at': _now().millisecondsSinceEpoch,
        'c': [for (final c in candles) c.toJson()],
      }),
    );
  }
}
