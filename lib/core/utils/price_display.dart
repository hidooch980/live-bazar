import '../../domain/entities/price_quote.dart';
import 'fa_number.dart';

/// The unit a quote's price is expressed in — not the asset's own name.
enum QuoteUnit { toman, usd, none }

/// Which real quote the Toman conversion rate came from, so the UI can say
/// so instead of presenting a number with no provenance.
enum TomanRateSource {
  /// The free-market dollar — what people actually transact at.
  freeMarket,

  /// The 24/7 Tether/Toman rate, used once the bazaar has closed.
  tether,

  /// The official published USD/IRR rate. Last resort: it currently sits
  /// about a third below the free market, so it is only used when nothing
  /// better is on the snapshot.
  official,
}

/// The Toman-per-USD rate actually used, and where it came from.
class TomanRate {
  const TomanRate(this.tomanPerUsd, this.source, this.timestamp);

  final double tomanPerUsd;
  final TomanRateSource source;
  final DateTime timestamp;

  String get labelFa => switch (source) {
    TomanRateSource.freeMarket => 'بازار آزاد',
    TomanRateSource.tether => 'تتر',
    TomanRateSource.official => 'نرخ رسمی',
  };
}

/// Display-currency conversion (REAL cross-rate arithmetic only).
///
/// Rial-denominated quotes are already in Toman. USD-denominated ones are
/// multiplied by a REAL Toman-per-USD rate taken from the snapshot.
///
/// Which rate matters enormously: the official published USD/IRR rate has
/// been running roughly a third below the free market, so converting with
/// it understated every USD asset on screen by about that much. The free
/// market is used when it is on the snapshot, the 24/7 Tether rate when
/// the bazaar has closed and Tether is the fresher of the two, and the
/// official rate only when neither exists.
abstract final class PriceDisplay {
  /// 1 Toman = 10 Rial.
  static const rialPerToman = 10;

  /// Picks the best real conversion rate available on a snapshot.
  ///
  /// [freeMarket] and [tether] are Toman-denominated quotes (`ir_usd`,
  /// `usdt_irt`); [official] is the IRR-per-USD quote (`fx_irr`).
  static TomanRate? rateFrom({
    PriceQuote? freeMarket,
    PriceQuote? tether,
    PriceQuote? official,
  }) {
    final candidates = <TomanRate>[
      if (_usable(freeMarket))
        TomanRate(
          freeMarket!.price,
          TomanRateSource.freeMarket,
          freeMarket.timestamp,
        ),
      if (_usable(tether))
        TomanRate(tether!.price, TomanRateSource.tether, tether.timestamp),
    ];
    if (candidates.isNotEmpty) {
      // Whichever the market published most recently: the free-market rate
      // during trading hours, Tether overnight.
      candidates.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return candidates.first;
    }
    if (_usable(official)) {
      return TomanRate(
        official!.price / rialPerToman,
        TomanRateSource.official,
        official.timestamp,
      );
    }
    return null;
  }

  static bool _usable(PriceQuote? q) =>
      q != null && q.price > 0 && q.status.isDisplayable;

  /// What a quote's [PriceQuote.price] is actually expressed in.
  ///
  /// [PriceQuote.currency] names the ASSET, not the unit of its price:
  /// `fx_eur` carries 'EUR' while its price is USD per euro, and `fx_irr`
  /// carries 'IRR' while its price is Rial per USD. Reading that field as
  /// the denomination is what made the converter refuse دلار→یورو and
  /// what would have read fx_irr's Rial figure as Toman.
  static QuoteUnit unitOf(PriceQuote quote) {
    // A rate, not a price of anything: only ever used to build a
    // TomanRate, never displayed or converted as a value.
    if (quote.id == 'fx_irr') return QuoteUnit.none;
    // Global currencies are quoted USD-per-unit whatever they are called.
    if (quote.category == AssetCategory.currency) return QuoteUnit.usd;
    if (quote.currency == 'IRR') return QuoteUnit.toman;
    if (quote.currency == 'USD') return QuoteUnit.usd;
    return QuoteUnit.none; // index points and anything else
  }

  /// Returns the price in TOMAN, or null when it cannot be expressed.
  static double? toman(PriceQuote quote, TomanRate? rate) {
    switch (unitOf(quote)) {
      case QuoteUnit.toman:
        return quote.price;
      case QuoteUnit.usd:
        if (rate == null || rate.tomanPerUsd <= 0) return null;
        return quote.price * rate.tomanPerUsd;
      case QuoteUnit.none:
        return null;
    }
  }

  /// How many units of [to] one unit of [from] buys.
  ///
  /// Same-unit pairs divide directly: the denomination cancels and no
  /// Toman rate is needed, which is what keeps دلار→یورو working before
  /// any Iranian quote has arrived. Only a mixed pair needs the rate.
  static double? crossRate(PriceQuote from, PriceQuote to, TomanRate? rate) {
    final fromUnit = unitOf(from);
    final toUnit = unitOf(to);
    if (fromUnit == QuoteUnit.none || toUnit == QuoteUnit.none) return null;
    if (fromUnit == toUnit) {
      return to.price > 0 ? from.price / to.price : null;
    }
    final f = toman(from, rate);
    final t = toman(to, rate);
    if (f == null || t == null || t <= 0) return null;
    return f / t;
  }

  /// Persian-formatted Toman text with grouping.
  static String tomanText(double toman) {
    if (toman >= 1000) return toman.faPrice(fraction: 0);
    return toman.faPrice(fraction: 1);
  }

  /// Unit label for display mode.
  static const tomanUnit = 'تومان';
}
