import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../config/asset_catalog.dart';
import '../../core/network/http_config.dart';
import '../../data/cache/local_state_store.dart';
import '../../domain/entities/price_quote.dart';
import '../../providers/adapters/crypto_provider.dart';
import '../../providers/adapters/global_currency_provider.dart';
import '../../providers/adapters/iranian_market_provider.dart';
import '../../providers/iprice_provider.dart';
import '../home_widget_service.dart';

/// Why a background widget refresh was asked for.
enum WidgetRefreshReason {
  /// The user unlocked the phone (low-power mode). Throttled.
  screenOn,

  /// A tick of the opt-in live foreground service.
  liveTick,

  /// The 15-minute WorkManager wake-up.
  periodic,
}

/// Read-only [KeyValueStore] over the config mirrored into the widget's
/// key space — enough for [MarketHttp.load] to pick up the user's proxy
/// without opening Hive in a background isolate.
class _MirrorStore implements KeyValueStore {
  _MirrorStore(this.data);
  final WidgetDataStore data;

  @override
  Future<String?> getString(String key) => key == 'proxy_config'
      ? data.read(HomeWidgetService.cfgProxyKey)
      : Future.value();

  @override
  Future<void> setString(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}

  @override
  List<String> keys() => const [];
}

/// BACKGROUND WIDGET REFRESH (app closed).
///
/// One pass: fetch only the widget's assets (plus the dollar/Tether rate
/// when a USD-quoted asset needs converting), never calling a provider
/// sooner than its own [IPriceProvider.minRefreshInterval]. A provider
/// that is inside its window, or that fails, contributes its last REAL
/// quote with its original timestamp — the widget's time line is the
/// oldest shown time, so a carried-over row can never look newer than it
/// is. A failed refresh marks the carried rows stale.
abstract final class WidgetRefresher {
  /// Unlocking the phone twice in a minute is not two reasons to fetch.
  static const screenOnThrottle = Duration(minutes: 2);

  static const lastRefreshKey = 'bg_last_refresh';
  static const carriedKey = 'bg_quotes';

  static final _lastFetch = <String, DateTime>{};
  static Map<String, PriceQuote>? _carried;
  static List<IPriceProvider>? _chain;
  static bool _busy = false;
  static bool _httpLoaded = false;

  @visibleForTesting
  static void resetForTest() {
    _lastFetch.clear();
    _carried = null;
    _chain = null;
    _busy = false;
    _httpLoaded = true; // tests inject providers; no proxy to load
  }

  /// Returns true when the widget was (re)published.
  static Future<bool> run({
    required WidgetRefreshReason reason,
    List<IPriceProvider>? providers,
    DateTime Function()? now,
  }) async {
    if (_busy) return false; // a slow tick must not stack up behind itself
    _busy = true;
    try {
      return await _run(reason, providers, now ?? DateTime.now);
    } catch (e) {
      debugPrint('[widget-bg] $e');
      return false;
    } finally {
      _busy = false;
    }
  }

  static Future<bool> _run(
    WidgetRefreshReason reason,
    List<IPriceProvider>? providers,
    DateTime Function() clock,
  ) async {
    final data = HomeWidgetService.data;
    final config = await HomeWidgetService.readMirroredConfig();
    if (!config.enabled) return false;
    if (reason == WidgetRefreshReason.liveTick &&
        config.mode != WidgetRefreshMode.live) {
      return false;
    }
    final nowUtc = clock().toUtc();
    if (reason == WidgetRefreshReason.screenOn) {
      final last = DateTime.tryParse(await data.read(lastRefreshKey) ?? '');
      if (last != null && nowUtc.difference(last) < screenOnThrottle) {
        return false;
      }
    }

    if (!_httpLoaded) {
      await MarketHttp.instance.load(_MirrorStore(data));
      _httpLoaded = true;
    }
    final chain =
        providers ??
        (_chain ??= [
          IranianMarketProvider(),
          CryptoProvider(),
          GlobalCurrencyProvider(),
        ]);

    final carried = _carried ??= await _loadCarried(data);
    final wanted = {
      ...config.ids,
      ...HomeWidgetService.rateDependencies(config.ids),
    };
    for (final provider in chain) {
      final needed = provider.supportedAssets.intersection(wanted);
      if (needed.isEmpty) continue;
      final last = _lastFetch[provider.id];
      if (last != null &&
          nowUtc.difference(last) < provider.minRefreshInterval) {
        continue; // inside its rate-limit window: keep the last real quote
      }
      _lastFetch[provider.id] = nowUtc;
      final result = await provider.getLatestPrices(needed);
      if (!result.isSuccess) {
        for (final id in needed) {
          final q = carried[id];
          if (q != null) carried[id] = q.copyWith(status: QuoteStatus.stale);
        }
        continue;
      }
      absorb(carried, result.quotes);
    }
    carried.removeWhere((id, _) => !wanted.contains(id));
    await HomeWidgetService.publishWith(config, carried, nowUtc: nowUtc);
    await data.save(carriedKey, _encode(carried));
    await data.save(lastRefreshKey, nowUtc.toIso8601String());
    return true;
  }

  /// Merges freshly fetched quotes. A fetched row that is not usable never
  /// overwrites a real one.
  @visibleForTesting
  static void absorb(Map<String, PriceQuote> into, Iterable<PriceQuote> qs) {
    for (final q in qs) {
      if (q.price <= 0 || AssetCatalog.byId(q.id) == null) continue;
      into[q.id] = q;
    }
  }

  /// The 15-minute worker already fetched; publish what it got for the
  /// widget's assets, through the same carry-over rules.
  static Future<void> publishFetched(
    WidgetConfig config,
    Map<String, PriceQuote> fetched, {
    DateTime? nowUtc,
  }) async {
    final data = HomeWidgetService.data;
    final carried = _carried ??= await _loadCarried(data);
    absorb(carried, fetched.values);
    final now = nowUtc ?? DateTime.now().toUtc();
    await HomeWidgetService.publishWith(config, carried, nowUtc: now);
    try {
      await data.save(carriedKey, _encode(carried));
      await data.save(lastRefreshKey, now.toIso8601String());
    } catch (_) {}
  }

  static String _encode(Map<String, PriceQuote> m) =>
      jsonEncode([for (final q in m.values) q.toJson()]);

  static Future<Map<String, PriceQuote>> _loadCarried(
    WidgetDataStore data,
  ) async {
    try {
      final raw = await data.read(carriedKey);
      if (raw == null || raw.isEmpty) return {};
      return {
        for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          m['id'] as String: PriceQuote.fromJson(m),
      };
    } catch (_) {
      return {};
    }
  }
}
