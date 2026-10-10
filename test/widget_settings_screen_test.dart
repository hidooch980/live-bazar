import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/features/widget_settings/home_widget_settings_screen.dart';
import 'package:live_bazar/features/widget_settings/widget_preview.dart';
import 'package:live_bazar/services/home_widget_service.dart';
import 'package:live_bazar/state/app_providers.dart';

import 'support/v070_fakes.dart';

void main() {
  late InMemoryKeyValueStore store;
  late MemoryWidgetDataStore data;

  setUp(() {
    HomeWidgetService.resetForTest();
    data = MemoryWidgetDataStore();
    HomeWidgetService.data = data;
    store = InMemoryKeyValueStore();
  });

  tearDown(HomeWidgetService.resetForTest);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          marketControllerProvider.overrideWith(
            () => FakeMarket({
              'ir_usd': catalogQuote('ir_usd', 265100),
              'gold_18k': catalogQuote('gold_18k', 26496400),
              'coin_emami': catalogQuote('coin_emami', 290000000),
            }),
          ),
        ],
        child: const MaterialApp(home: HomeWidgetSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('which sizes show which position', () {
    expect(WidgetPreviewSize.showing(0), WidgetPreviewSize.values);
    expect(WidgetPreviewSize.showing(2), [
      WidgetPreviewSize.medium,
      WidgetPreviewSize.large,
    ]);
    expect(WidgetPreviewSize.showing(5), [WidgetPreviewSize.large]);
  });

  testWidgets('defaults, with a live preview and size badges', (tester) async {
    await pump(tester);
    expect(find.text('ویجت صفحه اصلی'), findsOneWidget);
    expect(find.byType(WidgetPreview), findsOneWidget);
    expect(find.text('کوچک، متوسط، بزرگ'), findsOneWidget);
    expect(find.text('متوسط، بزرگ'), findsNWidgets(2));
    expect(find.textContaining('۲۶۵,۱۰۰'), findsWidgets);
  });

  testWidgets('switch, add, remove and mode are saved', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('widget-enabled')));
    await tester.pumpAndSettle();
    expect(await HomeWidgetService.isEnabled(store), isTrue);
    expect(data.values['cfg_enabled'], '1');

    await tester.tap(find.byKey(const ValueKey('widget-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'بیت');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'بیت‌کوین').first);
    await tester.pumpAndSettle();
    expect(await HomeWidgetService.loadSelection(store), [
      'ir_usd',
      'gold_18k',
      'coin_emami',
      'btc_usd',
    ]);
    expect(
      find.widgetWithText(ListTile, 'بزرگ'),
      findsOneWidget,
      reason: 'fourth: large only',
    );

    await tester.tap(find.byTooltip('حذف').first);
    await tester.pumpAndSettle();
    expect(await HomeWidgetService.loadSelection(store), [
      'gold_18k',
      'coin_emami',
      'btc_usd',
    ]);

    await tester.tap(find.byKey(const ValueKey('mode-live')));
    await tester.pumpAndSettle();
    expect(await HomeWidgetService.loadMode(store), WidgetRefreshMode.live);
    expect(data.values['cfg_mode'], 'live');
  });

  testWidgets('the last asset cannot be removed', (tester) async {
    await HomeWidgetService.saveSelection(store, ['ir_usd']);
    await pump(tester);
    await tester.tap(find.byTooltip('حذف'));
    await tester.pumpAndSettle();
    expect(await HomeWidgetService.loadSelection(store), ['ir_usd']);
  });
}
