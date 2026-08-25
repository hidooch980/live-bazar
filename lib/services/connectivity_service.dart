import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/market_refresh_engine.dart';

/// Bridges connectivity changes to the [MarketRefreshEngine].
///
/// Network restored -> immediate refresh (MASTER PROMPT §6).
class ConnectivityService {
  ConnectivityService(this._engine, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final MarketRefreshEngine _engine;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = true;

  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        if (_wasOffline) {
          _engine.onNetworkRestored();
        }
      } else {
        _engine.markOffline();
      }
      _wasOffline = !online;
    });
    // Initial state probe.
    _connectivity.checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _wasOffline = !online;
      if (!online) _engine.markOffline();
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
