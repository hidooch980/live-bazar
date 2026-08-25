import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache/local_state_store.dart';
import '../data/cache/market_cache.dart';
import '../domain/entities/alert_rule.dart';
import '../domain/entities/price_quote.dart';
import '../providers/adapters/crypto_provider.dart';
import '../providers/adapters/frankfurter_fallback_provider.dart';
import '../providers/adapters/global_currency_provider.dart';
import '../providers/adapters/server_required_provider.dart';
import '../providers/provider_registry.dart';
import '../services/alert_service.dart';
import '../services/historical_snapshot_service.dart';
import '../services/market_refresh_engine.dart';
import '../services/market_side_effects.dart';
import '../services/notification_service.dart';
import '../services/portfolio_service.dart';
import '../services/timezone_service.dart';
import '../services/watchlist_service.dart';

/// DI wiring — overridden in main() with the real async-initialized engine.

final marketCacheProvider = Provider<MarketCache>(
  (ref) => throw UnimplementedError('override in main'),
);

final refreshEngineProvider = Provider<MarketRefreshEngine>(
  (ref) => throw UnimplementedError('override in main'),
);

final localStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('override in main'),
);

final watchlistProvider = Provider<WatchlistService>(
  (ref) => WatchlistService(ref.watch(localStoreProvider)),
);

final portfolioProvider = Provider<PortfolioService>(
  (ref) => PortfolioService(ref.watch(localStoreProvider)),
);

final alertsProvider = Provider<AlertService>(
  (ref) => AlertService(ref.watch(localStoreProvider)),
);

final historyProvider = Provider<HistoricalSnapshotService>(
  (ref) => HistoricalSnapshotService(ref.watch(localStoreProvider)),
);

final notificationsProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final timeZoneProvider = Provider<TimeZoneService>(
  (ref) => throw UnimplementedError('override in main'),
);

final marketSideEffectsProvider = Provider<MarketSideEffects>(
  (ref) => MarketSideEffects(
    history: ref.watch(historyProvider),
    alerts: ref.watch(alertsProvider),
    notifications: ref.watch(notificationsProvider),
  ),
);

/// Connection status exposed to UI.
enum ConnectionMode { online, offline }

ProviderRegistry buildRegistry() {
  final registry = ProviderRegistry();
  // Priority 1: primary sources (verified, keyless).
  registry.register(
    ProviderEntry(provider: GlobalCurrencyProvider(), priority: 1),
  );
  registry.register(ProviderEntry(provider: CryptoProvider(), priority: 1));
  // Priority 2: fallbacks.
  registry.register(
    ProviderEntry(provider: FrankfurterFallbackProvider(), priority: 2),
  );
  // Disabled in V1 (SERVER_REQUIRED).
  registry.register(
    ProviderEntry(
      provider: const ServerRequiredProvider(
        id: 'iranian-market',
        displayName: 'Iranian Free Market',
        supportedAssets: {
          'ir_usd',
          'ir_eur',
          'ir_aed',
          'ir_gbp',
          'ir_try',
          'ir_cny',
        },
      ),
      priority: 9,
      enabledOverride: false,
    ),
  );
  registry.register(
    ProviderEntry(
      provider: const ServerRequiredProvider(
        id: 'iranian-gold',
        displayName: 'Iranian Gold & Coins',
        supportedAssets: {
          'gold_18k',
          'gold_24k',
          'mesghal',
          'xau_usd',
          'silver',
          'coin_emami',
          'coin_bahar',
          'coin_half',
          'coin_quarter',
          'coin_gram',
        },
      ),
      priority: 9,
      enabledOverride: false,
    ),
  );
  return registry;
}

class MarketState {
  const MarketState({
    required this.snapshot,
    required this.connection,
    this.refreshing = false,
  });

  final MarketSnapshotLike? snapshot;
  final ConnectionMode connection;
  final bool refreshing;

  MarketState copyWith({
    MarketSnapshotLike? snapshot,
    ConnectionMode? connection,
    bool? refreshing,
  }) => MarketState(
    snapshot: snapshot ?? this.snapshot,
    connection: connection ?? this.connection,
    refreshing: refreshing ?? this.refreshing,
  );

  bool get isOffline => connection == ConnectionMode.offline;
}

/// Minimal structural type so widgets don't import engine internals.
abstract interface class MarketSnapshotLike {
  Map<String, PriceQuote> get quotes;
  int get latencyMs;
}

class _SnapshotAdapter implements MarketSnapshotLike {
  _SnapshotAdapter(this.quotes, this.latencyMs);
  @override
  final Map<String, PriceQuote> quotes;
  @override
  final int latencyMs;
}

/// Bridges the imperative [MarketRefreshEngine] into Riverpod state.
class MarketController extends Notifier<MarketState> {
  @override
  MarketState build() {
    final engine = ref.watch(refreshEngineProvider);
    engine.snapshotStream.listen((snap) async {
      state = state.copyWith(
        snapshot: _SnapshotAdapter(snap.quotes, snap.latencyMs),
        refreshing: false,
      );

      // Side effects: history + local alerts + notifications.
      await ref.read(marketSideEffectsProvider).onSnapshot(snap);
    });
    return MarketState(
      snapshot: engine.latest == null
          ? null
          : _SnapshotAdapter(engine.latest!.quotes, engine.latest!.latencyMs),
      connection: ConnectionMode.online,
    );
  }

  Future<void> refreshNow() async {
    state = state.copyWith(refreshing: true);
    await ref.read(refreshEngineProvider).refresh(force: true);
    state = state.copyWith(refreshing: false);
  }

  void setOnline(bool online) {
    state = state.copyWith(
      connection: online ? ConnectionMode.online : ConnectionMode.offline,
    );
  }
}

final marketControllerProvider =
    NotifierProvider<MarketController, MarketState>(MarketController.new);

// ---- Watchlist / Portfolio / Alerts reactive views ----

class WatchlistController extends Notifier<List<String>> {
  @override
  List<String> build() => List.of(ref.watch(watchlistProvider).ids);

  Future<void> toggle(String assetId) async {
    await ref.read(watchlistProvider).toggle(assetId);
    state = List.of(ref.read(watchlistProvider).ids);
  }
}

final watchlistControllerProvider =
    NotifierProvider<WatchlistController, List<String>>(
      WatchlistController.new,
    );

class PortfolioController extends Notifier<List<Holding>> {
  @override
  List<Holding> build() => List.of(ref.watch(portfolioProvider).holdings);

  Future<void> setQuantity(String assetId, double qty) async {
    await ref.read(portfolioProvider).setQuantity(assetId, qty);
    state = List.of(ref.read(portfolioProvider).holdings);
  }

  Future<void> remove(String assetId) async {
    await ref.read(portfolioProvider).remove(assetId);
    state = List.of(ref.read(portfolioProvider).holdings);
  }
}

final portfolioControllerProvider =
    NotifierProvider<PortfolioController, List<Holding>>(
      PortfolioController.new,
    );

class AlertsController extends Notifier<List<AlertRule>> {
  @override
  List<AlertRule> build() => List.of(ref.watch(alertsProvider).rules);

  Future<void> create(String assetId, AlertType type, double threshold) async {
    await ref
        .read(alertsProvider)
        .create(assetId: assetId, type: type, threshold: threshold);
    state = List.of(ref.read(alertsProvider).rules);
  }

  Future<void> toggleActive(AlertRule rule) async {
    await ref.read(alertsProvider).setActive(rule.id, !rule.isActive);
    state = List.of(ref.read(alertsProvider).rules);
  }

  Future<void> remove(String id) async {
    await ref.read(alertsProvider).remove(id);
    state = List.of(ref.read(alertsProvider).rules);
  }
}

final alertsControllerProvider =
    NotifierProvider<AlertsController, List<AlertRule>>(AlertsController.new);
