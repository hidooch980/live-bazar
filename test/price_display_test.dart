import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/core/utils/price_display.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';

PriceQuote _usdQuote(double price) => PriceQuote(
  id: 'btc_usd',
  symbol: 'BTC/USD',
  name: 'Bitcoin',
  nameFa: 'بیت‌کوین',
  category: AssetCategory.crypto,
  price: price,
  unit: '',
  currency: 'USD',
  timestamp: DateTime.utc(2026, 8, 1),
  source: 't',
  status: QuoteStatus.live,
);

PriceQuote _irrQuote(double irrPerUsd) => PriceQuote(
  id: 'fx_irr',
  symbol: 'USD/IRR',
  name: 'IRR',
  nameFa: 'ریال',
  category: AssetCategory.currency,
  price: irrPerUsd,
  unit: 'ریال',
  currency: 'IRR',
  timestamp: DateTime.utc(2026, 8, 1),
  source: 't',
  status: QuoteStatus.live,
);

void main() {
  test('toman conversion uses real IRR rate / 10', () {
    // 50,000 USD BTC × 1,000,000 IRR/USD ÷ 10 = 5,000,000,000 Toman.
    final t = PriceDisplay.toman(_usdQuote(50000), _irrQuote(1000000));
    expect(t, 5000000000);
  });

  test('returns null without a live IRR quote (no fabrication)', () {
    expect(PriceDisplay.toman(_usdQuote(100), null), isNull);
    expect(PriceDisplay.toman(_usdQuote(100), _irrQuote(0)), isNull);
  });

  test('IRR-denominated quotes pass through unchanged', () {
    final t = PriceDisplay.toman(_irrQuote(1000000), _irrQuote(1000000));
    expect(t, 1000000);
  });

  test('tomanText formats huge numbers with grouping', () {
    expect(PriceDisplay.tomanText(5000000000), '۵,۰۰۰,۰۰۰,۰۰۰');
  });
}
