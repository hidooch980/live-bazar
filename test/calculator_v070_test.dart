import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/features/calculator/calculator_screen.dart';
import 'package:live_bazar/state/app_providers.dart';

import 'support/v070_fakes.dart';

Future<void> _pump(WidgetTester tester, Map<String, PriceQuote> quotes) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketControllerProvider.overrideWith(() => FakeMarket(quotes)),
      ],
      child: const MaterialApp(home: CalculatorScreen()),
    ),
  );
  await tester.pump();
}

Future<void> _pick(WidgetTester tester, String side, String name) async {
  await tester.tap(find.widgetWithText(InputDecorator, side));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name).first);
  await tester.pumpAndSettle();
}

String _result(WidgetTester tester) {
  final card = find.ancestor(
    of: find.text('نتیجه'),
    matching: find.byType(Card),
  );
  final texts = tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  );
  return texts.elementAt(1).data!;
}

void main() {
  final usd = catalogQuote('ir_usd', 100000);
  final gold = catalogQuote('gold_18k', 9000000);
  final btc = catalogQuote('btc_usd', 60000);

  group('plain Toman entry', () {
    testWidgets('is offered first and converts both ways', (tester) async {
      await _pump(tester, {'ir_usd': usd, 'gold_18k': gold});
      await _pick(tester, 'از', 'تومان');
      await tester.enterText(find.byType(TextField), '۱۸۰۰۰۰۰۰');
      await tester.pump();
      // 18,000,000 Toman buys exactly two grams at 9,000,000.
      expect(_result(tester), '۲.۰۰۰۰ GOLD-18K');

      await tester.tap(find.byTooltip('جابه‌جایی'));
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      expect(_result(tester), '۱۸,۰۰۰,۰۰۰ تومان');
    });

    testWidgets('a USD asset converts to Toman through the rate', (
      tester,
    ) async {
      await _pump(tester, {'ir_usd': usd, 'btc_usd': btc, 'gold_18k': gold});
      await _pick(tester, 'از', 'بیت‌کوین');
      await _pick(tester, 'به', 'تومان');
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(_result(tester), '۶,۰۰۰,۰۰۰,۰۰۰ تومان');
    });

    test('is the unit itself, never a market quote', () {
      final t = tomanQuote(DateTime.utc(2026));
      expect(t.price, 1);
      expect(conversionUnitLabel(t), 'تومان');
      expect(priceAgeNote(t, DateTime.utc(2027)), isNull);
    });
  });

  group('price age next to the result', () {
    final now = DateTime.utc(2026, 10, 10, 12);
    test('current prices add no note', () {
      expect(priceAgeNote(catalogQuote('ir_usd', 1, ts: now), now), isNull);
    });
    test('delayed, stale and previous-close say so', () {
      final old = now.subtract(const Duration(hours: 3));
      expect(
        priceAgeNote(
          catalogQuote('ir_usd', 1, ts: old, status: QuoteStatus.delayed),
          now,
        ),
        contains('۳ ساعت پیش'),
      );
      expect(
        priceAgeNote(
          catalogQuote('ir_usd', 1, ts: old, status: QuoteStatus.stale),
          now,
        ),
        contains('قدیمی'),
      );
      expect(
        priceAgeNote(
          catalogQuote(
            'gold_18k',
            1,
            ts: old,
            status: QuoteStatus.previousClose,
          ),
          now,
        ),
        contains('پایانی'),
      );
    });

    testWidgets('is shown under the result', (tester) async {
      await _pump(tester, {
        'ir_usd': usd,
        'gold_18k': catalogQuote(
          'gold_18k',
          9000000,
          ts: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
          status: QuoteStatus.delayed,
        ),
      });
      expect(find.textContaining('آخرین قیمت منبع'), findsOneWidget);
    });
  });

  group('decimal-comma hint', () {
    test('only for a comma that cannot be a thousands separator', () {
      expect(amountInputHint('1,5'), contains('٫'));
      expect(amountInputHint('۱،۵'), contains('٫'));
      expect(amountInputHint('1,500'), isNull);
      expect(amountInputHint('abc'), isNull);
      expect(amountInputHint('1٫5'), isNull);
    });

    testWidgets('replaces the bare «نامعتبر» error', (tester) async {
      await _pump(tester, {'ir_usd': usd, 'gold_18k': gold});
      await tester.enterText(find.byType(TextField), '1,5');
      await tester.pump();
      expect(find.textContaining('برای اعشار از'), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('data that arrived but is all unusable is not «loading»', (
      tester,
    ) async {
      await _pump(tester, {
        'ir_usd': catalogQuote(
          'ir_usd',
          100000,
          status: QuoteStatus.dataConflict,
        ),
        'gold_18k': catalogQuote('gold_18k', 0),
      });
      expect(find.textContaining('در حال دریافت'), findsNothing);
      expect(find.textContaining('هیچ قیمت معتبری'), findsOneWidget);
    });

    test('messages', () {
      expect(
        calculatorEmptyMessage(hasSnapshot: false, offline: false),
        contains('در حال دریافت'),
      );
      expect(
        calculatorEmptyMessage(hasSnapshot: false, offline: true),
        contains('آفلاین'),
      );
    });
  });
}
