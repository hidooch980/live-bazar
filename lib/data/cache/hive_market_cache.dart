import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/market_snapshot.dart';
import 'market_cache.dart';

/// Hive-backed [MarketCache].
///
/// Why Hive CE: pure-Dart, zero native build deps, fast key/value reads at
/// startup, works offline on Android without platform channels beyond
/// path_provider. Snapshots are stored JSON-encoded (schema evolution is
/// trivial; no codegen needed).
class HiveMarketCache implements MarketCache {
  HiveMarketCache._();

  static Future<HiveMarketCache> open() async {
    await Hive.initFlutter();
    final quotes = await Hive.openBox<dynamic>(AppConstants.cacheBoxQuotes);
    final meta = await Hive.openBox<dynamic>(AppConstants.cacheBoxMeta);
    return HiveMarketCache._()
      .._quotes = quotes
      .._meta = meta;
  }

  late final Box<dynamic> _quotes;
  late final Box<dynamic> _meta;

  @override
  Future<MarketSnapshot?> loadLastSnapshot() async {
    try {
      final raw = _meta.get(AppConstants.cacheKeyLastSnapshot);
      if (raw is! String) return null;
      return MarketSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(MarketSnapshot snapshot) async {
    await _meta.put(
      AppConstants.cacheKeyLastSnapshot,
      jsonEncode(snapshot.toJson()),
    );
  }

  @override
  Future<bool> get isOfflineFlag async =>
      _meta.get('offline_flag', defaultValue: false) as bool? ?? false;

  @override
  Future<void> setOfflineFlag(bool value) async =>
      _meta.put('offline_flag', value);

  @override
  Future<void> clear() async {
    await _quotes.clear();
    await _meta.clear();
  }
}
