import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/price_quote.dart';
import '../../state/app_providers.dart';

/// A block on the home dashboard. Order and visibility are user-owned
/// («شخصی‌سازی») and persisted LOCALLY like every other preference.
enum HomeSection {
  pulse('نبض بازار', null),
  watchlist('علاقه‌مندی‌ها', null),
  iranCurrency('بازار آزاد', AssetCategory.iranianCurrency),
  gold('طلا', AssetCategory.gold),
  coin('سکه', AssetCategory.coin),
  crypto('کریپتو', AssetCategory.crypto),
  globalCurrency('ارز جهانی', AssetCategory.currency),
  bourse('شاخص بورس', AssetCategory.marketIndex),
  commodity('نفت و کالا', AssetCategory.commodity),
  diagnostics('وضعیت منابع', null);

  const HomeSection(this.titleFa, this.category);

  final String titleFa;

  /// Market sections render every enabled asset of this category; the
  /// non-market blocks (pulse, watchlist, diagnostics) have none.
  final AssetCategory? category;

  static HomeSection? byName(String name) {
    for (final s in HomeSection.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Ordered, per-section visibility for the home dashboard.
///
/// [order] always contains every known section so a hidden block keeps its
/// position; [hidden] decides what is drawn.
@immutable
class HomeLayout {
  const HomeLayout(this.order, this.hidden);

  final List<HomeSection> order;
  final Set<HomeSection> hidden;

  /// Everything visible, ships with the market sections the app is for.
  static const HomeLayout defaults = HomeLayout(HomeSection.values, {});

  List<HomeSection> get visible =>
      order.where((s) => !hidden.contains(s)).toList(growable: false);

  bool isVisible(HomeSection s) => !hidden.contains(s);

  /// Moves the section at [fromIndex] to [toIndex]. Both indexes are
  /// post-removal, matching `ReorderableListView.onReorderItem`.
  HomeLayout reordered(int fromIndex, int toIndex) {
    final next = List<HomeSection>.of(order);
    next.insert(toIndex, next.removeAt(fromIndex));
    return HomeLayout(List.unmodifiable(next), hidden);
  }

  String encode() =>
      order.map((s) => '${s.name}:${hidden.contains(s) ? 0 : 1}').join(',');

  /// Tolerant of unknown/missing entries: a section added in a later app
  /// version is appended (visible) instead of invalidating the whole
  /// stored preference.
  static HomeLayout decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final order = <HomeSection>[];
    final hidden = <HomeSection>{};
    for (final part in raw.split(',')) {
      final bits = part.split(':');
      final section = HomeSection.byName(bits.first.trim());
      if (section == null || order.contains(section)) continue;
      order.add(section);
      if (bits.length > 1 && bits[1].trim() == '0') hidden.add(section);
    }
    if (order.isEmpty) return defaults;
    for (final s in HomeSection.values) {
      if (!order.contains(s)) order.add(s);
    }
    return HomeLayout(List.unmodifiable(order), Set.unmodifiable(hidden));
  }

  @override
  bool operator ==(Object other) =>
      other is HomeLayout &&
      listEquals(other.order, order) &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(order), Object.hashAll(hidden));
}

/// Persisted home layout. Defaults are used until the stored value loads,
/// so the first frame never waits on disk.
class HomeLayoutController extends Notifier<HomeLayout> {
  static const storeKey = 'home_layout';

  /// Bumped on every rebuild AND every save. A load that started before
  /// either must not clobber newer state: without this, a choice made while
  /// the initial read is still in flight is silently reverted to whatever
  /// was on disk when the screen opened.
  int _generation = 0;

  @override
  HomeLayout build() {
    final store = ref.watch(localStoreProvider);
    final generation = ++_generation;
    store.getString(storeKey).then((raw) {
      if (generation != _generation) return;
      final stored = HomeLayout.decode(raw);
      if (stored != state) state = stored;
    });
    return HomeLayout.defaults;
  }

  Future<void> _save(HomeLayout layout) async {
    _generation++;
    state = layout;
    await ref.read(localStoreProvider).setString(storeKey, layout.encode());
  }

  Future<void> toggle(HomeSection section) {
    final hidden = Set<HomeSection>.of(state.hidden);
    if (!hidden.remove(section)) hidden.add(section);
    return _save(HomeLayout(state.order, hidden));
  }

  Future<void> reorder(int fromIndex, int toIndex) =>
      _save(state.reordered(fromIndex, toIndex));

  Future<void> reset() => _save(HomeLayout.defaults);
}

final homeLayoutProvider = NotifierProvider<HomeLayoutController, HomeLayout>(
  HomeLayoutController.new,
);
