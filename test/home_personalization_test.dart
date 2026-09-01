import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/features/home/customize_home_screen.dart';
import 'package:live_bazar/features/home/home_layout.dart';
import 'package:live_bazar/state/app_providers.dart';

ProviderContainer _container(KeyValueStore store) {
  final c = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<HomeLayout> _loaded(ProviderContainer c) async {
  c.read(homeLayoutProvider); // build() kicks off the async store read
  await Future<void>.delayed(Duration.zero);
  return c.read(homeLayoutProvider);
}

void main() {
  test('a hidden section is persisted and restored on next launch', () async {
    final store = InMemoryKeyValueStore();
    final first = _container(store);

    await first
        .read(homeLayoutProvider.notifier)
        .toggle(HomeSection.globalCurrency);
    expect(
      first.read(homeLayoutProvider).isVisible(HomeSection.globalCurrency),
      isFalse,
    );
    expect(
      await store.getString(HomeLayoutController.storeKey),
      contains('globalCurrency:0'),
    );

    // A fresh launch reading the same local store.
    final relaunch = await _loaded(_container(store));
    expect(relaunch.isVisible(HomeSection.globalCurrency), isFalse);
    expect(relaunch.isVisible(HomeSection.iranCurrency), isTrue);
  });

  test('a reordered dashboard survives a relaunch', () async {
    final store = InMemoryKeyValueStore();
    final first = _container(store);
    // Drag "کریپتو" to the top.
    final cryptoIndex = HomeSection.values.indexOf(HomeSection.crypto);
    await first.read(homeLayoutProvider.notifier).reorder(cryptoIndex, 0);

    final relaunch = await _loaded(_container(store));
    expect(relaunch.order.first, HomeSection.crypto);
    expect(relaunch.order.toSet(), HomeSection.values.toSet());
  });

  test('reset returns to the shipped defaults', () async {
    final store = InMemoryKeyValueStore();
    final c = _container(store);
    final notifier = c.read(homeLayoutProvider.notifier);
    await notifier.toggle(HomeSection.gold);
    await notifier.toggle(HomeSection.coin);
    await notifier.reorder(0, 4);
    expect(c.read(homeLayoutProvider), isNot(HomeLayout.defaults));

    await notifier.reset();
    expect(c.read(homeLayoutProvider), HomeLayout.defaults);
    expect(await _loaded(_container(store)), HomeLayout.defaults);
  });

  testWidgets('customize screen lists every section and toggles one', (
    tester,
  ) async {
    final store = InMemoryKeyValueStore();
    // Tall surface so the lazy list builds every section card.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: CustomizeHomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in HomeSection.values) {
      expect(
        find.text(section.titleFa),
        findsOneWidget,
        reason: '${section.name} missing from the personalization list',
      );
    }

    // Every switch starts on; turning one off writes the preference.
    final goldSwitch = find.ancestor(
      of: find.text(HomeSection.gold.titleFa),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(goldSwitch).value, isTrue);

    await tester.tap(goldSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(goldSwitch).value, isFalse);
    expect(
      await store.getString(HomeLayoutController.storeKey),
      contains('gold:0'),
    );
  });
}
