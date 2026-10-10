import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/features/calculator/calculator_screen.dart';
import 'package:live_bazar/state/app_providers.dart';

PriceQuote _q(
  String id,
  double price, {
  String currency = 'IRR',
  String symbol = '',
  String nameFa = '',
  AssetCategory category = AssetCategory.iranianCurrency,
  QuoteStatus status = QuoteStatus.live,
}) => PriceQuote(
  id: id,
  symbol: symbol.isEmpty ? id : symbol,
  name: id,
  nameFa: nameFa.isEmpty ? id : nameFa,
  category: category,
  price: price,
  unit: currency == 'IRR' ? 'تومان' : '',
  currency: currency,
  timestamp: DateTime.now().toUtc(),
  source: 't',
  status: status,
);

final _usd = _q(
  'ir_usd',
  265100,
  symbol: 'USD/IRR-FM',
  nameFa: 'دلار آمریکا (بازار آزاد)',
);
final _eur = _q(
  'ir_eur',
  298360,
  symbol: 'EUR/IRR-FM',
  nameFa: 'یورو (بازار آزاد)',
);
final _gold = _q(
  'gold_18k',
  26496400,
  symbol: 'GOLD-18K',
  nameFa: 'طلای ۱۸ عیار',
  category: AssetCategory.gold,
);
final _btc = _q(
  'btc_usd',
  82906,
  currency: 'USD',
  symbol: 'BTC/USD',
  nameFa: 'بیت‌کوین',
  category: AssetCategory.crypto,
);
final _official = _q(
  'fx_irr',
  1468820,
  symbol: 'USD/IRR',
  nameFa: 'ریال ایران (رسمی)',
  category: AssetCategory.currency,
);

class _Snap implements MarketSnapshotLike {
  _Snap(this.quotes);
  @override
  final Map<String, PriceQuote> quotes;
  @override
  int get latencyMs => 0;
}

class _FakeMarket extends MarketController {
  _FakeMarket(this._initial);
  final Map<String, PriceQuote> _initial;

  @override
  MarketState build() =>
      MarketState(snapshot: _Snap(_initial), connection: ConnectionMode.online);

  void replace(Map<String, PriceQuote> quotes) => state = MarketState(
    snapshot: _Snap(quotes),
    connection: state.connection,
  );
}

Future<_FakeMarket> _pump(
  WidgetTester tester,
  Map<String, PriceQuote> quotes,
) async {
  final market = _FakeMarket(quotes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [marketControllerProvider.overrideWith(() => market)],
      child: const MaterialApp(home: CalculatorScreen()),
    ),
  );
  await tester.pump();
  return market;
}

String _resultText(WidgetTester tester) {
  // The result line is the first Text after «نتیجه».
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  return texts[texts.indexOf('نتیجه') + 1];
}

void main() {
  group('result unit label', () {
    testWidgets('counting free-market dollars is not labelled Toman', (
      tester,
    ) async {
      await _pump(tester, {'ir_usd': _usd, 'gold_18k': _gold});
      // Default ir_usd → gold_18k; swap to gold_18k → ir_usd.
      await tester.tap(find.byTooltip('جابه‌جایی'));
      await tester.pump();
      final result = _resultText(tester);
      // 1 g gold = 26,496,400 / 265,100 ≈ 99.95 DOLLARS, not Toman.
      expect(result, startsWith('۹۹.۹'));
      expect(result, isNot(contains('تومان')));
      expect(result, endsWith('USD'));
    });

    test('a pair symbol is reduced to the unit actually counted', () {
      expect(conversionUnitLabel(_btc), 'BTC');
      expect(conversionUnitLabel(_usd), 'USD');
      expect(conversionUnitLabel(_gold), 'GOLD-18K');
    });
  });

  group('which quotes the converter may use', () {
    testWidgets('a rejected (dataConflict) quote is not converted with', (
      tester,
    ) async {
      // A first-ever price the anomaly gate rejected stays on the snapshot
      // flagged dataConflict. The converter must not compute with it.
      final bogus = _q(
        'ir_usd',
        26510, // a dropped digit
        symbol: 'USD/IRR-FM',
        nameFa: 'دلار آمریکا (بازار آزاد)',
        status: QuoteStatus.dataConflict,
      );
      await _pump(tester, {'ir_usd': bogus, 'ir_eur': _eur, 'gold_18k': _gold});
      expect(find.text('دلار آمریکا (بازار آزاد) (USD/IRR-FM)'), findsNothing);
    });

    test('options exclude unusable quotes and the official rate', () {
      final ids = calculatorAssetIds({
        'ir_usd': _usd,
        'gold_18k': _gold,
        'fx_irr': _official,
        'ir_eur': _eur.copyWith(status: QuoteStatus.unavailable),
        'btc_usd': _btc.copyWith(price: 0),
      });
      expect(ids, ['ir_usd', 'gold_18k']);
    });

    testWidgets('the official rate is not offered (it converts to nothing)', (
      tester,
    ) async {
      await _pump(tester, {
        'ir_usd': _usd,
        'gold_18k': _gold,
        'fx_irr': _official,
      });
      await tester.tap(find.text('دلار آمریکا (بازار آزاد) (USD/IRR-FM)'));
      await tester.pumpAndSettle();
      expect(find.text('ریال ایران (رسمی)'), findsNothing);
    });
  });

  group('selection fallback', () {
    testWidgets('a vanished side never collapses onto the other side', (
      tester,
    ) async {
      final market = await _pump(tester, {
        'ir_usd': _usd,
        'ir_eur': _eur,
        'gold_18k': _gold,
      });
      await tester.tap(find.byTooltip('جابه‌جایی')); // gold → usd
      await tester.pump();
      market.replace({'ir_usd': _usd, 'ir_eur': _eur}); // gold disappears
      await tester.pump();
      // «از» must fall back to something other than «به» (ir_usd): the
      // first option, now the plain Toman entry.
      expect(find.text('تومان (IRT)'), findsOneWidget);
      expect(
        find.text('دلار آمریکا (بازار آزاد) (USD/IRR-FM)'),
        findsOneWidget,
      );
    });

    test('resolveSelection keeps the two sides distinct', () {
      expect(resolveSelection(['a', 'b', 'c'], 'gone', 'a'), ('b', 'a'));
      expect(resolveSelection(['a', 'b'], 'a', 'gone'), ('a', 'b'));
      expect(resolveSelection(['a', 'b'], 'b', 'a'), ('b', 'a'));
      expect(resolveSelection(['a'], 'x', 'y'), ('a', 'a'));
    });
  });

  group('parseAmountInput edge cases', () {
    test('a comma that is not a thousands separator is rejected', () {
      // Read as 15 before: a decimal comma silently became ten times more.
      expect(parseAmountInput('1,5'), isNull);
      expect(parseAmountInput('12,34'), isNull);
      expect(parseAmountInput('1,2345'), isNull);
      expect(parseAmountInput(',5'), isNull);
    });

    test('properly grouped thousands still parse', () {
      expect(parseAmountInput('1,250'), 1250);
      expect(parseAmountInput('۱٬۲۵۰٬۰۰۰'), 1250000); // Arabic thousands sep
      expect(parseAmountInput('۱،۲۵۰'), 1250);
      expect(parseAmountInput('12,345.5'), 12345.5);
      expect(parseAmountInput('۱۲,۳۴۵٫۵'), 12345.5);
    });

    test('other edge input', () {
      expect(parseAmountInput('.'), isNull);
      expect(parseAmountInput('٫'), isNull);
      expect(parseAmountInput('1.2.3'), isNull);
      expect(parseAmountInput('۰۰۷'), 7);
      expect(parseAmountInput('٫۵'), 0.5);
      expect(parseAmountInput('1e5'), isNull);
      expect(parseAmountInput('Infinity'), isNull);
      expect(parseAmountInput('NaN'), isNull);
    });
  });

  group('formatConversionResult', () {
    test('a tiny ratio keeps its significant digits', () {
      // 1 Syrian pound ≈ 20 Toman; 1 BTC ≈ 2.2e10 Toman → ≈ 9.1e-10.
      final s = formatConversionResult(9.14e-10);
      expect(s, contains('۹۱۴'));
      // Below 5e-11 used to print as an all-zero «۰.۰۰۰۰۰۰۰۰۰۰».
      expect(formatConversionResult(3.2e-11), contains('۳۲'));
    });

    test('a huge result is grouped digits, never exponent notation', () {
      final s = formatConversionResult(3.5e21);
      expect(s, isNot(contains('e')));
      expect(s, startsWith('۳,۵۰۰,'));
    });

    test('ordinary results are unchanged', () {
      expect(formatConversionResult(1035.07), '۱,۰۳۵');
      expect(formatConversionResult(99.95), '۹۹.۹۵۰۰');
      expect(formatConversionResult(0.000966), '۰.۰۰۰۹۶۶۰۰');
    });
  });
}
