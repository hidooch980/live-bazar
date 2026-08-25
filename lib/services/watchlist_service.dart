import '../data/cache/local_state_store.dart';

/// MOLIDO WATCHLIST (§22): ordered local favorites. Nothing leaves the
/// device.
class WatchlistService {
  static const _key = 'watchlist_ids';

  final KeyValueStore store;
  List<String> _ids = [];

  WatchlistService(this.store);

  Future<void> load() async {
    final raw = await store.getString(_key);
    if (raw == null || raw.isEmpty) {
      _ids = [];
      return;
    }
    try {
      final decoded = raw.split(',');
      _ids = decoded.where((e) => e.isNotEmpty).toList();
    } catch (_) {
      _ids = [];
    }
  }

  List<String> get ids => List.unmodifiable(_ids);

  bool contains(String assetId) => _ids.contains(assetId);

  Future<void> add(String assetId) async {
    if (_ids.contains(assetId)) return;
    _ids.add(assetId);
    await _persist();
  }

  Future<void> remove(String assetId) async {
    _ids.remove(assetId);
    await _persist();
  }

  Future<void> toggle(String assetId) async =>
      contains(assetId) ? remove(assetId) : add(assetId);

  /// Reorder: move [assetId] to [index].
  Future<void> reorder(String assetId, int index) async {
    if (!_ids.remove(assetId)) return;
    index = index.clamp(0, _ids.length);
    _ids.insert(index, assetId);
    await _persist();
  }

  Future<void> _persist() => store.setString(_key, _ids.join(','));
}
