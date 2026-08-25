import '../data/cache/local_state_store.dart';
import 'market_score_service.dart';

/// One real observation (never fabricated).
class PricePoint {
  const PricePoint(this.t, this.p);

  final DateTime t;
  final double p;

  Map<String, dynamic> toJson() => {'t': t.millisecondsSinceEpoch, 'p': p};

  static PricePoint fromJson(Map<String, dynamic> j) => PricePoint(
    DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt(), isUtc: true),
    (j['p'] as num).toDouble(),
  );
}

/// HISTORICAL SNAPSHOT ENGINE (§19).
///
/// - In-memory ring buffers: raw 5s observations, bounded per asset.
/// - Persisted 1-minute aggregates per asset via KeyValueStore.
/// - NEVER fabricates points; charts show only what really accumulated.
class HistoricalSnapshotService {
  /// Raw in-memory observations per asset id (bounded).
  static const rawCapacityPerAsset = 720; // ~1h at one point / 5s

  /// Persisted aggregated series cap per asset.
  static const persistedCapPerAsset = 1440; // 24h of 1-min buckets

  final KeyValueStore store;

  final _raw = <String, List<PricePoint>>{};
  DateTime Function() now;

  HistoricalSnapshotService(this.store, {DateTime Function()? now})
    : now = now ?? (() => DateTime.now().toUtc());

  Future<void> load() async {
    for (final key in store.keys().where((k) => k.startsWith(_prefix))) {
      final assetId = key.substring(_prefix.length);
      _raw[assetId] = decodeList(await store.getString(key))
          .map(PricePoint.fromJson)
          .toList();
    }
  }

  static const _prefix = 'hist_';

  /// Records every quote of a snapshot. Aggregates into the persisted
  /// series using [HistoricalAggregator] semantics.
  Future<void> record(Map<String, PricePoint> points) async {
    final t = now();
    for (final e in points.entries) {
      final list = _raw.putIfAbsent(e.key, () => []);
      // Skip duplicate timestamps (same provider epoch re-checked).
      if (list.isNotEmpty && list.last.t == e.value.t) continue;
      list.add(e.value);
      if (list.length > rawCapacityPerAsset) {
        list.removeRange(0, list.length - rawCapacityPerAsset);
      }
    }
    // Persist the 1-minute aggregated view once per minute.
    if (_lastPersist == null ||
        t.difference(_lastPersist!) >= const Duration(minutes: 1)) {
      await persistAll();
      _lastPersist = t;
    }
  }

  DateTime? _lastPersist;

  Future<void> persistAll() async {
    for (final entry in _raw.entries) {
      final agg = aggregateToMinutes(entry.value);
      await store.setString(
        '$_prefix${entry.key}',
        encodeList(agg.map((p) => p.toJson()).toList()),
      );
    }
  }

  List<PricePoint> aggregateToMinutes(List<PricePoint> raw) {
    final agg = HistoricalAggregator.aggregate(
      raw.map((p) => (p.t, p.p)).toList(growable: false),
      const Duration(minutes: 1),
    );
    return agg.map((e) => PricePoint(e.$1, e.$2)).toList();
  }

  /// Series for [assetId], optionally limited to [range] back from now.
  List<PricePoint> series(String assetId, {Duration? range}) {
    var list = _raw[assetId] ?? const <PricePoint>[];
    if (range != null) {
      final cutoff = now().subtract(range);
      list = list.where((pt) => pt.t.isAfter(cutoff)).toList(growable: false);
    }
    return List.unmodifiable(list);
  }

  bool hasData(String assetId, Duration range) =>
      series(assetId).any((pt) => pt.t.isAfter(now().subtract(range)));

  void clearMemory() => _raw.clear();
}
