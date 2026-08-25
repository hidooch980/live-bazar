import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/molido_app.dart';
import '../data/cache/hive_market_cache.dart';
import '../services/connectivity_service.dart';
import '../services/market_refresh_engine.dart';
import '../state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Local cache first: Cache -> Immediate UI -> Network (§20).
  final cache = await HiveMarketCache.open();

  // 2) THE single market engine (§4) with the centralized 5s cycle.
  final engine = MarketRefreshEngine(registry: buildRegistry(), cache: cache);
  await engine.hydrateFromCache();
  engine.start();

  // 3) Connectivity bridge: network restored -> immediate refresh (§6).
  ConnectivityService(engine).start();

  runApp(
    ProviderScope(
      overrides: [
        marketCacheProvider.overrideWithValue(cache),
        refreshEngineProvider.overrideWithValue(engine),
      ],
      child: const MolidoApp(),
    ),
  );
}
