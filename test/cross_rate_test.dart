import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/core/utils/price_display.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';

/// The converter divides one asset by another. The two sides are not in
/// the same unit — fx_* and crypto are quoted in USD, everything from the
/// Iranian market in Toman — so both must be normalized before dividing.
/// Raw division answered "1 USD = 0.0000 free-market dollars".
PriceQuote _q(String id, double price, String currency) => PriceQuote(
  id: id,
  symbol: id,
  name: id,
  nameFa: id,
  category: AssetCategory.currency,
  price: price,
  unit: currency == 'IRR' ? 'تومان' : '',
  currency: currency,
  timestamp: DateTime.utc(2026, 9, 2),
  source: 't',
  status: QuoteStatus.live,
);

// Values observed on the device, 2026-09-02.
final _freeDollar = _q('ir_usd', 214000, 'IRR');
final _coin = _q('coin_emami', 221505000, 'IRR');
final _usd = _q('fx_usd', 1, 'USD');
final _eur = _q('fx_eur', 1.1609, 'USD');
final _rate = PriceDisplay.rateFrom(freeMarket: _freeDollar)!;

/// Mirrors the converter: same denomination divides directly, a mixed
/// pair normalizes through Toman first.
double? _convert(
  PriceQuote from,
  PriceQuote to,
  double amount, {
  TomanRate? rate,
  bool useRate = true,
}) {
  if (from.currency == to.currency) {
    return to.price > 0 ? amount * (from.price / to.price) : null;
  }
  final r = useRate ? (rate ?? _rate) : null;
  final f = PriceDisplay.toman(from, r);
  final t = PriceDisplay.toman(to, r);
  if (f == null || t == null || t <= 0) return null;
  return amount * (f / t);
}

void main() {
  test('a USD asset into a Toman asset is ~1, not ~0', () {
    final r = _convert(_usd, _freeDollar, 1)!;
    expect(r, closeTo(1, 0.001));
    // The old raw-price division produced this instead.
    expect(_usd.price / _freeDollar.price, lessThan(0.00001));
  });

  test('a Toman asset into a USD asset inverts correctly', () {
    // One Emami coin at 221,505,000 تومان with the dollar at 214,000.
    expect(_convert(_coin, _usd, 1)!, closeTo(1035.07, 0.01));
  });

  test('one dollar buys a small fraction of a coin, and says so', () {
    final r = _convert(_usd, _coin, 1)!;
    expect(r, closeTo(0.000966, 0.000001));
    // Four fixed decimals rendered this as "۰.۰۰۰۰"; the result needs
    // enough precision to still mean something.
    expect(r.toStringAsFixed(4), '0.0010');
    expect(r.toStringAsFixed(8), startsWith('0.00096'));
  });

  test('USD to USD is unaffected by which rate is in play', () {
    expect(_convert(_usd, _eur, 1)!, closeTo(1 / 1.1609, 1e-9));
    // A different Toman rate must cancel out entirely.
    final other = PriceDisplay.rateFrom(tether: _q('usdt_irt', 250000, 'IRR'))!;
    final f = PriceDisplay.toman(_usd, other)!;
    final t = PriceDisplay.toman(_eur, other)!;
    expect(f / t, closeTo(1 / 1.1609, 1e-9));
  });

  test('Toman to Toman needs no rate at all', () {
    expect(_convert(_coin, _freeDollar, 1)!, closeTo(1035.07, 0.01));
    final f = PriceDisplay.toman(_coin, null)!;
    final t = PriceDisplay.toman(_freeDollar, null)!;
    expect(f / t, closeTo(1035.07, 0.01));
  });

  test('a same-currency pair needs no Toman rate at all', () {
    // Regression: routing USD->USD through the Toman rate made دلار→یورو
    // fail outright whenever the Iranian feed had not arrived yet.
    expect(_convert(_usd, _eur, 1, useRate: false)!, closeTo(1 / 1.1609, 1e-9));
    expect(
      _convert(_coin, _freeDollar, 1, useRate: false)!,
      closeTo(1035.07, 0.01),
    );
  });

  test('an unconvertible side yields nothing rather than a wrong number', () {
    // No rate on the snapshot: a USD side cannot be expressed in Toman.
    expect(PriceDisplay.toman(_usd, null), isNull);
    final index = _q('bourse_index', 6583932, 'IDX');
    expect(_convert(index, _freeDollar, 1), isNull);
  });
}
