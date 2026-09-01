import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/config/asset_catalog.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/features/home/home_layout.dart';

void main() {
  test('defaults show every section, market blocks included', () {
    expect(HomeLayout.defaults.visible, HomeSection.values);
    expect(HomeLayout.defaults.hidden, isEmpty);
    for (final s in [
      HomeSection.iranCurrency,
      HomeSection.gold,
      HomeSection.coin,
      HomeSection.crypto,
    ]) {
      expect(HomeLayout.defaults.isVisible(s), isTrue);
    }
  });

  test('every market section maps to enabled catalog assets', () {
    for (final section in HomeSection.values) {
      final category = section.category;
      if (category == null) continue;
      final assets = AssetCatalog.all.where(
        (d) => d.enabled && d.category == category,
      );
      expect(
        assets,
        isNotEmpty,
        reason: '${section.name} would render an empty block',
      );
    }
  });

  test('every asset category has a home section', () {
    final covered = {
      for (final s in HomeSection.values)
        if (s.category != null) s.category!,
    };
    final used = AssetCatalog.all
        .where((d) => d.enabled)
        .map((d) => d.category);
    for (final c in used) {
      expect(covered, contains(c), reason: '$c is unreachable from home');
    }
  });

  test('encode/decode round-trips order and hidden blocks', () {
    final layout = HomeLayout(HomeSection.values, {
      HomeSection.diagnostics,
      HomeSection.globalCurrency,
    }).reordered(5, 0);

    final restored = HomeLayout.decode(layout.encode());
    expect(restored.order, layout.order);
    expect(restored.hidden, layout.hidden);
    expect(restored, layout);
  });

  test('reorder moves one section without losing any', () {
    final moved = HomeLayout.defaults.reordered(0, 3);
    expect(moved.order.length, HomeSection.values.length);
    expect(moved.order.toSet(), HomeSection.values.toSet());
    expect(moved.order[3], HomeSection.pulse);
    expect(moved.order.first, HomeSection.watchlist);
  });

  test('a section added in a later version is appended, not dropped', () {
    // Stored by an older build that only knew three sections.
    final restored = HomeLayout.decode('crypto:1,pulse:0,gold:1');
    expect(restored.order.take(3), [
      HomeSection.crypto,
      HomeSection.pulse,
      HomeSection.gold,
    ]);
    expect(restored.order.toSet(), HomeSection.values.toSet());
    expect(restored.hidden, {HomeSection.pulse});
    // Newly introduced sections default to visible.
    expect(restored.isVisible(HomeSection.iranCurrency), isTrue);
  });

  test('junk and duplicates never produce an unusable layout', () {
    expect(HomeLayout.decode(null), HomeLayout.defaults);
    expect(HomeLayout.decode(''), HomeLayout.defaults);
    expect(HomeLayout.decode('nope,???'), HomeLayout.defaults);
    final dupes = HomeLayout.decode('gold:1,gold:0,gold:1');
    expect(dupes.order.where((s) => s == HomeSection.gold).length, 1);
    expect(dupes.isVisible(HomeSection.gold), isTrue);
  });

  test('hiding every section is representable and survives a round-trip', () {
    final none = HomeLayout(HomeSection.values, HomeSection.values.toSet());
    expect(none.visible, isEmpty);
    expect(HomeLayout.decode(none.encode()).visible, isEmpty);
  });

  test('section titles are non-empty Persian labels', () {
    for (final s in HomeSection.values) {
      expect(s.titleFa.trim(), isNotEmpty);
    }
    expect(HomeSection.iranCurrency.titleFa, 'بازار آزاد');
    expect(HomeSection.gold.category, AssetCategory.gold);
  });
}
