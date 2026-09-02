import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/core/utils/price_display.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';

PriceQuote _q(
  String id, {
  required double price,
  required String currency,
  QuoteStatus status = QuoteStatus.live,
  DateTime? ts,
  AssetCategory category = AssetCategory.currency,
}) => PriceQuote(
  id: id,
  symbol: id,
  name: id,
  nameFa: id,
  category: category,
  price: price,
  unit: currency == 'IRR' ? 'تومان' : '',
  currency: currency,
  timestamp: ts ?? DateTime.utc(2026, 9, 1, 12),
  source: 't',
  status: status,
);

// Real values observed on 2026-09-01 at 22:59 Tehran.
PriceQuote _freeMarket({DateTime? ts, QuoteStatus? status}) => _q(
  'ir_usd',
  price: 214000,
  currency: 'IRR',
  ts: ts ?? DateTime.utc(2026, 9, 1, 16, 29, 59), // 19:59:59 Tehran
  status: status ?? QuoteStatus.delayed,
  category: AssetCategory.iranianCurrency,
);
PriceQuote _tether({DateTime? ts}) => _q(
  'usdt_irt',
  price: 214792,
  currency: 'IRR',
  ts: ts ?? DateTime.utc(2026, 9, 1, 19, 29), // 22:59 Tehran
  category: AssetCategory.iranianCurrency,
);
PriceQuote _official() =>
    _q('fx_irr', price: 1468820, currency: 'IRR'); // 146,882 Toman

void main() {
  group('rate selection', () {
    test('free market wins while the bazaar is the fresher print', () {
      final rate = PriceDisplay.rateFrom(
        freeMarket: _freeMarket(ts: DateTime.utc(2026, 9, 1, 10)),
        tether: _tether(ts: DateTime.utc(2026, 9, 1, 9)),
        official: _official(),
      );
      expect(rate!.source, TomanRateSource.freeMarket);
      expect(rate.tomanPerUsd, 214000);
      expect(rate.labelFa, 'بازار آزاد');
    });

    test('tether takes over once the bazaar has closed', () {
      // 19:59:59 vs 22:59 Tehran — the real situation at night.
      final rate = PriceDisplay.rateFrom(
        freeMarket: _freeMarket(),
        tether: _tether(),
        official: _official(),
      );
      expect(rate!.source, TomanRateSource.tether);
      expect(rate.tomanPerUsd, 214792);
    });

    test('the official rate is a last resort, not a default', () {
      final rate = PriceDisplay.rateFrom(official: _official());
      expect(rate!.source, TomanRateSource.official);
      expect(rate.tomanPerUsd, 146882);
      // It sits ~32% below the market — the reason it must not win.
      expect(rate.tomanPerUsd / 214000, lessThan(0.7));
    });

    test('an undisplayable quote is not used as a rate', () {
      final rate = PriceDisplay.rateFrom(
        freeMarket: _freeMarket(status: QuoteStatus.dataConflict),
        tether: _tether(),
      );
      expect(rate!.source, TomanRateSource.tether);

      expect(
        PriceDisplay.rateFrom(
          freeMarket: _q(
            'ir_usd',
            price: 0,
            currency: 'IRR',
            category: AssetCategory.iranianCurrency,
          ),
        ),
        isNull,
      );
      expect(PriceDisplay.rateFrom(), isNull);
    });
  });

  group('conversion', () {
    test('USD assets use the real market rate, not the official one', () {
      final rate = PriceDisplay.rateFrom(
        freeMarket: _freeMarket(),
        tether: _tether(),
        official: _official(),
      );
      final ounce = _q(
        'xau_usd',
        price: 4400,
        currency: 'USD',
        category: AssetCategory.gold,
      );

      final shown = PriceDisplay.toman(ounce, rate)!;
      expect(shown, 4400 * 214792);

      // What the old official-rate path produced, for contrast: a third low.
      final official = PriceDisplay.rateFrom(official: _official());
      expect(PriceDisplay.toman(ounce, official)! / shown, lessThan(0.7));
    });

    test('IRR-denominated quotes pass through unchanged', () {
      final rate = PriceDisplay.rateFrom(tether: _tether());
      expect(PriceDisplay.toman(_freeMarket(), rate), 214000);
      // ...even with no rate at all: they are already Toman.
      expect(PriceDisplay.toman(_freeMarket(), null), 214000);
    });

    test('no rate means no number, never a guess', () {
      final usd = _q(
        'xau_usd',
        price: 100,
        currency: 'USD',
        category: AssetCategory.gold,
      );
      expect(PriceDisplay.toman(usd, null), isNull);
      // A non-USD, non-IRR quote (the bourse index) is never converted.
      final index = _q(
        'bourse_index',
        price: 6583932,
        currency: 'IDX',
        category: AssetCategory.marketIndex,
      );
      expect(
        PriceDisplay.toman(index, PriceDisplay.rateFrom(tether: _tether())),
        isNull,
      );
    });

    test('tomanText formats huge numbers with grouping', () {
      expect(PriceDisplay.tomanText(5000000000), '۵,۰۰۰,۰۰۰,۰۰۰');
    });
  });
}
