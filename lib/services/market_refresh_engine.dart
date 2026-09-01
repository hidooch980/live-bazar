import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../data/cache/market_cache.dart';
import '../domain/entities/market_snapshot.dart';
import '../domain/entities/price_quote.dart';
import '../providers/provider_registry.dart';
import 'request_lock.dart';
import 'validation/anomaly_detection_service.dart';
import 'validation/price_validation_service.dart';

/// THE single market polling engine (MASTER PROMPT §4).
///
/// - ONE Timer for the whole app, [AppConstants.marketCheckInterval] cadence.
/// - Each provider is only hit when its own minRefreshInterval allows
///   (rate-limit protection §3).
/// - Requests are guarded by [RequestLock]: no overlapping/duplicate calls.
/// - Foreground-only: callers must stop()/start() on lifecycle changes.
class MarketRefreshEngine {
  MarketRefreshEngine({
    required ProviderRegistry registry,
    required MarketCache cache,
    RequestLock? lock,
    PriceValidationService? validation,
    Duration interval = AppConstants.marketCheckInterval,
    DateTime Function()? now,
  }) : _providers = registry,
       _store = cache,
       _lock = lock ?? RequestLock(),
       _validation = validation ?? const PriceValidationService(),
       _cadence = interval,
       _now = now ?? (() => DateTime.now().toUtc());

  final ProviderRegistry _providers;
  final MarketCache _store;
  final RequestLock _lock;
  final PriceValidationService _validation;
  final Duration _cadence;
  final DateTime Function() _now;

  Timer? _timer;
  bool _running = false;

  MarketSnapshot? _latest;

  final _controller = StreamController<MarketSnapshot>.broadcast();
  Stream<MarketSnapshot> get snapshotStream => _controller.stream;
  MarketSnapshot? get latest => _latest;
  bool get isRunning => _running;

  /// provider id -> next allowed fetch time (rate-limit bookkeeping).
  @visibleForTesting
  final Map<String, DateTime> nextAllowedFetch = {};

  /// Live diagnostics for the settings/dashboard UI:
  /// provider id -> ('ok'|'failed'|'empty'|'-') + last attempt time.
  final Map<String, String> providerStatus = {};
  DateTime? lastCycleAt;

  /// Starts the centralized cycle. Safe to call multiple times.
  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(_cadence, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  /// Called on lifecycle transitions:
  /// resumed -> immediate refresh + resume cycle; paused -> stop cycle.
  Future<void> onForegroundChanged(bool foreground) async {
    if (foreground) {
      await refresh(force: true);
      start();
    } else {
      stop(); // no unlimited background polling (§6)
    }
  }

  /// Network restored -> immediate refresh (§6).
  Future<void> onNetworkRestored() async {
    await refresh(force: true);
  }

  void markOffline() {
    // Informational only: providers fail gracefully; the cycle keeps
    // running so recovery is automatic and cache stays fresh.
  }

  /// One guarded market check across all due providers.
  ///
  /// Returns the new snapshot or null when skipped/locked.
  Future<MarketSnapshot?> refresh({bool force = false}) {
    return _lock.run<MarketSnapshot?>('market-refresh', () async {
      final t0 = DateTime.now();
      final merged = Map<String, PriceQuote>.from(_latest?.quotes ?? {});
      final sourceStatus = <String, String>{};
      var anySuccess = false;
      var anyFailure = false;

      final futures = <Future<bool?>>[];
      for (final entry in _providers.entries.where((e) => e.isActive)) {
        final provider = entry.provider;
        final allowedAt =
            nextAllowedFetch[provider.id] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!force && allowedAt.isAfter(_now())) {
          continue; // respect per-provider rate limit
        }
        nextAllowedFetch[provider.id] = _now().add(provider.minRefreshInterval);

        futures.add(
          _lock.run<bool>('provider:${provider.id}', () async {
            providerStatus[provider.id] = 'checking';
            final result = await provider.getLatestPrices(
              provider.supportedAssets,
            );
            if (result.isSuccess && result.quotes.isNotEmpty) {
              anySuccess = true;
              sourceStatus[provider.id] = 'ok';
              providerStatus[provider.id] = 'ok';
              for (final q in result.quotes) {
                final verdict = _validation.validate(q);
                if (!verdict.isValid) {
                  debugPrint('[engine] rejected ${q.id}: ${verdict.reason}');
                  continue;
                }
                merged[q.id] = _annotate(q, merged[q.id]);
              }
            } else if (!result.isSuccess) {
              anyFailure = true;
              sourceStatus[provider.id] = 'failed';
              providerStatus[provider.id] = 'failed: ${result.error!.message}';
              debugPrint(
                '[engine] provider ${provider.id} failed: ${result.error!.message}',
              );
            } else {
              sourceStatus[provider.id] = 'empty';
              providerStatus[provider.id] = 'empty';
            }
            return true;
          }),
        );
      }

      // Nothing fetched this tick (all providers within their window)?
      if (futures.isEmpty) return null;
      await Future.wait(futures);
      lastCycleAt = _now();

      final latency = DateTime.now().difference(t0).inMilliseconds;
      final snapshot = MarketSnapshot(
        snapshotId: 'snap-${t0.millisecondsSinceEpoch}',
        timestamp: _now(),
        quotes: Map.unmodifiable(merged),
        sourceStatus: Map.unmodifiable(sourceStatus),
        latencyMs: latency,
      );

      if (anySuccess || !anyFailure || _latest == null) {
        _latest = snapshot;
      }
      await _store.saveSnapshot(_latest!);

      // Broadcast unconditionally: with no listeners the event is simply
      // dropped, and late subscribers re-read [latest] anyway.
      _controller.add(_latest!);
      return _latest;
    });
  }

  /// Loads cached data at startup BEFORE any network call (§20).
  Future<void> hydrateFromCache() async {
    final snap = await _store.loadLastSnapshot();
    if (snap != null && _latest == null) {
      _latest = snap;
    }
  }

  /// Adds change metrics and anomaly state vs the previous valid quote.
  PriceQuote _annotate(PriceQuote incoming, PriceQuote? previous) {
    var q = incoming;
    // Only derive the change metric when the provider publishes none —
    // otherwise the real daily move (crypto 24h, TGJU intraday) would be
    // overwritten by the delta between two polls seconds apart.
    if (previous != null &&
        previous.price > 0 &&
        incoming.changePercent == 0 &&
        incoming.timestamp != previous.timestamp) {
      final change = incoming.price - previous.price;
      final pct = change / previous.price * 100;
      q = q.copyWith(change: change, changePercent: pct);
    }
    const anomalySvc = AnomalyDetectionService();
    final state = anomalySvc.assess(candidate: q, previousValid: previous);
    switch (state) {
      case AnomalyState.valid:
        // A thinly traded asset can publish a real but hours-old price —
        // label it STALE instead of passing it off as LIVE (§13).
        return q.copyWith(
          status: _validation.isStale(q) ? QuoteStatus.stale : QuoteStatus.live,
        );
      case AnomalyState.suspicious:
        // Keep last valid value; flag conflict rather than trusting it.
        if (previous != null) {
          return previous.copyWith(status: QuoteStatus.dataConflict);
        }
        return q.copyWith(status: QuoteStatus.dataConflict);
      case AnomalyState.rejected:
        return previous ?? q.copyWith(status: QuoteStatus.dataConflict);
    }
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
  }
}
