import '../providers/iprice_provider.dart';

/// Registry of all price providers with priority and fallback order.
///
/// Lower [Priority] number = tried first.
class ProviderEntry {
  ProviderEntry({
    required this.provider,
    required this.priority,
    this.enabledOverride = true,
  });

  final IPriceProvider provider;
  final int priority;
  bool enabledOverride;

  bool get isActive => enabledOverride && provider.isEnabled;
}

class ProviderRegistry {
  final List<ProviderEntry> _entries = [];

  void register(ProviderEntry entry) => _entries.add(entry);

  /// Providers able to serve at least one of [assetIds], active only,
  /// ordered by priority.
  List<IPriceProvider> chainFor(Set<String> assetIds) {
    final chain =
        _entries
            .where(
              (e) =>
                  e.isActive &&
                  e.provider.supportedAssets.intersection(assetIds).isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
    return chain.map((e) => e.provider).toList(growable: false);
  }

  IPriceProvider? primaryFor(String assetId) {
    for (final p in chainFor({assetId})) {
      if (p.supportedAssets.contains(assetId)) return p;
    }
    return null;
  }

  List<ProviderEntry> get entries => List.unmodifiable(_entries);

  void setEnabled(String providerId, bool enabled) {
    for (final e in _entries) {
      if (e.provider.id == providerId) e.enabledOverride = enabled;
    }
  }
}
