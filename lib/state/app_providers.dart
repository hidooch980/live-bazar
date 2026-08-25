import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache/market_cache.dart';
import '../domain/entities/market_snapshot.dart';
import '../providers/adapters/crypto_provider.dart';
import '../providers/adapters/frankfurter_fallback_provider.dart';
import '../providers/adapters/global_currency_provider.dart';
import '../providers/adapters/server_required_provider.dart';
import '../providers/provider_registry.dart';
import '../services/market_refresh_engine.dart';

/// DI wiring — overridden in main() with the real async-initialized engine.

final marketCacheProvider = Provider<MarketCache>(
  (ref) => throw UnimplementedError('override in main'),
);

final refreshEngineProvider = Provider<MarketRefreshEngine>(
  (ref) => throw UnimplementedError('override in main'),
);

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
  // Disabled in V1 (SERVER_REQUIRED) — registered for architecture completeness.
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

/// Connection status exposed to UI.
enum ConnectionStateX { online, offline }

class MarketState {
  const MarketState({
    required this.snapshot,
    required this.connection,
    this.refreshing = false,
  });

  final MarketSnapshot? snapshot;
  final ConnectionStateX connection;
  final bool refreshing;

  MarketState copyWith({
    MarketSnapshot? snapshot,
    ConnectionStateX? connection,
    bool? refreshing,
  }) => MarketState(
    snapshot: snapshot ?? this.snapshot,
    connection: connection ?? this.connection,
    refreshing: refreshing ?? this.refreshing,
  );

  bool get isOffline => connection == ConnectionStateX.offline;
}

/// Bridges the imperative [MarketRefreshEngine] into Riverpod state.
class MarketController extends Notifier<MarketState> {
  @override
  MarketState build() {
    final engine = ref.watch(refreshEngineProvider);
    engine.snapshotStream.listen((snap) {
      state = state.copyWith(snapshot: snap, refreshing: false);
    });
    return MarketState(
      snapshot: engine.latest,
      connection: ConnectionStateX.online,
    );
  }

  Future<void> refreshNow() async {
    state = state.copyWith(refreshing: true);
    await ref.read(refreshEngineProvider).refresh(force: true);
    state = state.copyWith(refreshing: false);
  }

  void setOnline(bool online) {
    state = state.copyWith(
      connection: online ? ConnectionStateX.online : ConnectionStateX.offline,
    );
  }
}

final marketControllerProvider =
    NotifierProvider<MarketController, MarketState>(MarketController.new);
