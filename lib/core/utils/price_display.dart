import '../../domain/entities/price_quote.dart';
import 'fa_number.dart';

/// Display-currency conversion (REAL cross-rate arithmetic only).
///
/// Every V1 quote is USD-denominated, so Toman value =
///   priceUsd × (IRR-per-USD from the live fx_irr quote) ÷ 10.
/// The IRR rate itself comes from the verified providers (er-api /
/// jsDelivr) — the OFFICIAL published rate, clearly labeled. No free-market
/// fabrication.
abstract final class PriceDisplay {
  /// 1 Toman = 10 Rial.
  static const rialPerToman = 10;

  /// Returns the price in TOMAN, or null when no live IRR rate exists.
  static double? toman(PriceQuote quote, PriceQuote? irrQuote) {
    if (irrQuote == null || irrQuote.price <= 0) return null;
    if (quote.currency == 'IRR') return quote.price;
    // Only USD-denominated quotes exist in V1.
    if (quote.currency != 'USD') return null;
    return quote.price * irrQuote.price / rialPerToman;
  }

  /// Persian-formatted Toman text with grouping.
  static String tomanText(double toman) {
    if (toman >= 1000) return toman.faPrice(fraction: 0);
    return toman.faPrice(fraction: 1);
  }

  /// Unit label for display mode.
  static const tomanUnit = 'تومان';
}
