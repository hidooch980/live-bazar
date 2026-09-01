import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/molido_app.dart';
import '../core/network/http_config.dart';
import '../data/cache/hive_market_cache.dart';
import '../data/cache/local_state_store.dart';
import '../services/alert_service.dart';
import '../services/background_alert_worker.dart';
import '../services/connectivity_service.dart';
import '../services/historical_snapshot_service.dart';
import '../services/market_refresh_engine.dart';
import '../services/notification_service.dart';
import '../services/portfolio_service.dart';
import '../services/timezone_service.dart';
import '../services/watchlist_service.dart';
import '../state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0) «تعریف ساعت»: tz database + local location BEFORE everything.
  final timeZone = TimeZoneService();
  await timeZone.init();

  // 1) Local cache first: Cache -> Immediate UI -> Network (§20).
  final cache = await HiveMarketCache.open();
  final store = await HiveKeyValueStore.open();

  // 1b) Outbound HTTP layer (user proxy config, LOCAL-ONLY).
  await MarketHttp.instance.load(store);

  // 2) Local feature services (watchlist §22, alerts §23, portfolio §24).
  final watchlist = WatchlistService(store);
  final portfolio = PortfolioService(store);
  final alerts = AlertService(store);
  final history = HistoricalSnapshotService(store);
  await watchlist.load();
  await portfolio.load();
  await alerts.load();
  await history.load();

  // 3) THE single market engine (§4) with the centralized 5s cycle.
  final engine = MarketRefreshEngine(registry: buildRegistry(), cache: cache);
  await engine.hydrateFromCache();
  // First data on the very first frame (loading UI if slow).
  await engine.refresh(force: true);
  engine.start();

  // 4) Local notifications for price alerts (§23) — uses the tz clock.
  final notifications = NotificationService()..init(timeZone: timeZone);

  // 4b) Background alert checks, only if the user switched them on.
  // Re-applied every launch so an OS cleanup cannot silently unschedule
  // them (§23 — an alert that needs the app open is not an alert).
  await BackgroundAlertWorker.initialize();
  await BackgroundAlertWorker.restore(store);

  // 5) Connectivity bridge: network restored -> immediate refresh (§6).
  ConnectivityService(engine).start();

  runApp(
    ProviderScope(
      overrides: [
        marketCacheProvider.overrideWithValue(cache),
        refreshEngineProvider.overrideWithValue(engine),
        localStoreProvider.overrideWithValue(store),
        timeZoneProvider.overrideWithValue(timeZone),
        watchlistProvider.overrideWithValue(watchlist),
        portfolioProvider.overrideWithValue(portfolio),
        alertsProvider.overrideWithValue(alerts),
        historyProvider.overrideWithValue(history),
        notificationsProvider.overrideWithValue(notifications),
      ],
      child: const MolidoApp(),
    ),
  );
}
