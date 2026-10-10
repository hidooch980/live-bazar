// Renders PNG previews of the v0.7.0 UI for review. Skipped unless
// MOLIDO_SCREENSHOTS names an output directory:
//   MOLIDO_SCREENSHOTS=/workspace flutter test test/screenshots_test.dart
// The numbers are TEST FIXTURES (each image says so), not market data.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/app/theme.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/features/share/price_share_card.dart';
import 'package:live_bazar/features/widget_settings/home_widget_settings_screen.dart';
import 'package:live_bazar/features/widget_settings/widget_preview.dart';
import 'package:live_bazar/services/home_widget_service.dart';
import 'package:live_bazar/state/app_providers.dart';

import 'support/v070_fakes.dart';

final _out = Platform.environment['MOLIDO_SCREENSHOTS'];

Future<void> _fonts() async {
  final vazir = FontLoader('Vazirmatn');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Vazirmatn-$w.ttf').readAsBytesSync();
    vazir.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await vazir.load();
  final symbols = FontLoader('MolidoSymbols');
  for (final f in ['DejaVuSans.ttf', 'DejaVuSans-Bold.ttf']) {
    final file = File('/usr/share/fonts/truetype/dejavu/$f');
    if (file.existsSync()) {
      symbols.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await symbols.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/workspace/sdk/flutter';
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2.5);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

final _now = DateTime.now().toUtc();

Map<String, PriceQuote> _fixtures() {
  PriceQuote q(String id, double p, double ch) =>
      catalogQuote(id, p, ts: _now, changePercent: ch);
  return {
    'ir_usd': q('ir_usd', 214000, 0.42),
    'gold_18k': q('gold_18k', 21950000, -0.31),
    'coin_emami': q('coin_emami', 221500000, 0.85),
    'usdt_irt': q('usdt_irt', 214805, 0.38),
    'ir_eur': q('ir_eur', 249600, -0.12),
    'xau_usd': q('xau_usd', 4000, 0.67),
  };
}

Map<String, List<List<num>>> _series(Map<String, PriceQuote> qs) {
  final out = <String, List<List<num>>>{};
  var seed = 7;
  for (final e in qs.entries) {
    final up = e.value.changePercent >= 0;
    var p = e.value.price;
    final pts = <List<num>>[];
    for (var i = 0; i < 24; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final wiggle = ((seed % 100) - 50) / 5000;
      p *= 1 + wiggle + (up ? 0.002 : -0.002);
      pts.add([i, p]);
    }
    out[e.key] = pts;
  }
  return out;
}

Widget _caption() => const Padding(
  padding: EdgeInsets.only(top: 10),
  child: Text(
    'پیش‌نمایش — اعداد آزمایشی (fixture)',
    textDirection: TextDirection.rtl,
    style: TextStyle(
      color: Colors.white70,
      fontSize: 11,
      fontFamily: 'Vazirmatn',
    ),
  ),
);

void main() {
  final skip = _out == null ? 'set MOLIDO_SCREENSHOTS=<dir>' : null;

  setUpAll(() async {
    if (_out != null) await _fonts();
  });

  testWidgets('widget sizes', skip: skip != null, (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final qs = _fixtures();
    final ids = qs.keys.toList();
    final rows = HomeWidgetService.rows(qs, ids, series: _series(qs));
    final updated = HomeWidgetService.timeLine(qs.values);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: Colors.black,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 400,
                child: WallpaperBackdrop(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 170,
                          height: 170,
                          child: WidgetPreview(
                            rows: rows,
                            size: WidgetPreviewSize.small,
                            updated: updated,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 170,
                        child: WidgetPreview(
                          rows: rows,
                          size: WidgetPreviewSize.medium,
                          updated: updated,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 400,
                        child: WidgetPreview(
                          rows: rows,
                          size: WidgetPreviewSize.large,
                          updated: updated,
                          live: true,
                        ),
                      ),
                      _caption(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _shoot(tester, key, 'v070-widget-sizes.png');
  });

  testWidgets('widget settings screen', skip: skip != null, (tester) async {
    tester.view.physicalSize = const Size(420, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    HomeWidgetService.resetForTest();
    HomeWidgetService.data = MemoryWidgetDataStore();
    final store = InMemoryKeyValueStore();
    await HomeWidgetService.setEnabled(store, true);
    await HomeWidgetService.saveSelection(store, _fixtures().keys.toList());
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            marketControllerProvider.overrideWith(
              () => FakeMarket(_fixtures()),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            builder: (context, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const HomeWidgetSettingsScreen(),
          ),
        ),
      ),
    );
    await _shoot(tester, key, 'v070-widget-settings.png');
    HomeWidgetService.resetForTest();
  });

  testWidgets('share card', skip: skip != null, (tester) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final entries = shareCardEntries(_fixtures(), shareDefaultAssets);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: Colors.black,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: PriceShareCard(
                      entries: entries,
                      date: shareCardDate(_now),
                    ),
                  ),
                  _caption(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _shoot(tester, key, 'v070-share-card.png');
  });
}
