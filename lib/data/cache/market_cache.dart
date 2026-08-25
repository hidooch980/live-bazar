import '../../domain/entities/market_snapshot.dart';

/// Persistence contract for market state (offline support §21).
abstract interface class MarketCache {
  /// Loads the last persisted snapshot or null.
  Future<MarketSnapshot?> loadLastSnapshot();

  /// Persists [snapshot], replacing any previous one.
  Future<void> saveSnapshot(MarketSnapshot snapshot);

  /// Marks cache as produced while offline (UI shows CACHED badge).
  Future<bool> get isOfflineFlag;

  Future<void> setOfflineFlag(bool value);

  Future<void> clear();
}

/// Simple in-memory implementation — used in tests and as fallback before
/// Hive is initialized.
class InMemoryMarketCache implements MarketCache {
  MarketSnapshot? _last;
  bool _offline = false;

  @override
  Future<MarketSnapshot?> loadLastSnapshot() async => _last;

  @override
  Future<void> saveSnapshot(MarketSnapshot snapshot) async => _last = snapshot;

  @override
  Future<bool> get isOfflineFlag async => _offline;

  @override
  Future<void> setOfflineFlag(bool value) async => _offline = value;

  @override
  Future<void> clear() async {
    _last = null;
    _offline = false;
  }
}
