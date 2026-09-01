import '../domain/entities/price_quote.dart';

/// Static catalog of supported assets.
///
/// Only assets with a VERIFIED data source may be [enabled].
/// Iranian free-market, gold and coin quotes come from the public keyless
/// TGJU feed (see IranianMarketProvider) with the feed's own timestamps.
/// Anything without such a source stays disabled (DATA UNAVAILABLE).
class AssetDefinition {
  const AssetDefinition({
    required this.id,
    required this.symbol,
    required this.name,
    required this.nameFa,
    required this.category,
    required this.unit,
    required this.currency,
    this.enabled = true,
    this.tradable = true,
  });

  final String id;
  final String symbol;
  final String name;
  final String nameFa;
  final AssetCategory category;
  final String unit;
  final String currency;
  final bool enabled;

  /// False for observations you cannot hold: a market index or a coin
  /// bubble is a real published number, but it is not a position, so the
  /// portfolio and the converter leave it out.
  final bool tradable;
}

abstract final class AssetCatalog {
  // ---- GLOBAL CURRENCY (verified: open.er-api.com + jsDelivr + ECB) ----
  static const globalCurrencies = <AssetDefinition>[
    _usd,
    _eur,
    _gbp,
    _aed,
    _try_,
    _cny,
    _irr,
    _cad,
    _aud,
    _chf,
    _jpy,
  ];

  // ---- IRANIAN FREE MARKET (verified keyless: TGJU live feed) ----
  static const iranianMarket = <AssetDefinition>[
    AssetDefinition(
      id: 'ir_usd',
      symbol: 'USD/IRR-FM',
      name: 'US Dollar (Free Market)',
      nameFa: 'دلار آمریکا (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_eur',
      symbol: 'EUR/IRR-FM',
      name: 'Euro (Free Market)',
      nameFa: 'یورو (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_aed',
      symbol: 'AED/IRR-FM',
      name: 'UAE Dirham (Free Market)',
      nameFa: 'درهم امارات (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_gbp',
      symbol: 'GBP/IRR-FM',
      name: 'British Pound (Free Market)',
      nameFa: 'پوند انگلیس (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_try',
      symbol: 'TRY/IRR-FM',
      name: 'Turkish Lira (Free Market)',
      nameFa: 'لیر ترکیه (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_cny',
      symbol: 'CNY/IRR-FM',
      name: 'Chinese Yuan (Free Market)',
      nameFa: 'یوان چین (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_cad',
      symbol: 'CAD/IRR-FM',
      name: 'Canadian Dollar (Free Market)',
      nameFa: 'دلار کانادا (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_aud',
      symbol: 'AUD/IRR-FM',
      name: 'Australian Dollar (Free Market)',
      nameFa: 'دلار استرالیا (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_chf',
      symbol: 'CHF/IRR-FM',
      name: 'Swiss Franc (Free Market)',
      nameFa: 'فرانک سوئیس (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    // TGJU publishes the yen per 100 units — the name says so, because the
    // number on screen is the price of 100 yen, not one.
    AssetDefinition(
      id: 'ir_jpy',
      symbol: 'JPY100/IRR-FM',
      name: 'Japanese Yen per 100 (Free Market)',
      nameFa: 'ین ژاپن، هر ۱۰۰ ین (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_rub',
      symbol: 'RUB/IRR-FM',
      name: 'Russian Ruble (Free Market)',
      nameFa: 'روبل روسیه (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_iqd',
      symbol: 'IQD/IRR-FM',
      name: 'Iraqi Dinar (Free Market)',
      nameFa: 'دینار عراق (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'ir_afn',
      symbol: 'AFN/IRR-FM',
      name: 'Afghan Afghani (Free Market)',
      nameFa: 'افغانی افغانستان (بازار آزاد)',
      category: AssetCategory.iranianCurrency,
      unit: 'تومان',
      currency: 'IRR',
    ),
  ];

  // ---- GOLD & COINS (verified keyless: TGJU live feed) ----
  static const goldAndCoins = <AssetDefinition>[
    AssetDefinition(
      id: 'gold_18k',
      symbol: 'GOLD-18K',
      name: 'Gold 18K',
      nameFa: 'طلای ۱۸ عیار',
      category: AssetCategory.gold,
      unit: 'گرم',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'gold_24k',
      symbol: 'GOLD-24K',
      name: 'Gold 24K',
      nameFa: 'طلای ۲۴ عیار',
      category: AssetCategory.gold,
      unit: 'گرم',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'mesghal',
      symbol: 'MESGHAL',
      name: 'Mesghal Gold',
      nameFa: 'مثقال طلا',
      category: AssetCategory.gold,
      unit: 'مثقال',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'xau_usd',
      symbol: 'XAU/USD',
      name: 'Gold Ounce / USD',
      nameFa: 'انس جهانی طلا',
      category: AssetCategory.gold,
      unit: 'اونس',
      currency: 'USD',
    ),
    AssetDefinition(
      id: 'silver',
      symbol: 'XAG/USD',
      name: 'Silver Ounce / USD',
      nameFa: 'انس جهانی نقره',
      category: AssetCategory.gold,
      unit: 'اونس',
      currency: 'USD',
    ),
    AssetDefinition(
      id: 'gold_abshodeh',
      symbol: 'ABSHODEH',
      name: 'Melted Gold (spot)',
      nameFa: 'آبشده نقدی',
      category: AssetCategory.gold,
      unit: 'مثقال',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'coin_emami',
      symbol: 'COIN-EMAMI',
      name: 'Emami Coin',
      nameFa: 'سکه امامی',
      category: AssetCategory.coin,
      unit: 'عدد',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'coin_bahar',
      symbol: 'COIN-BAHAR',
      name: 'Bahare Azadi Coin',
      nameFa: 'سکه بهاره آزادی',
      category: AssetCategory.coin,
      unit: 'عدد',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'coin_half',
      symbol: 'COIN-HALF',
      name: 'Half Coin',
      nameFa: 'نیم سکه',
      category: AssetCategory.coin,
      unit: 'عدد',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'coin_quarter',
      symbol: 'COIN-QUARTER',
      name: 'Quarter Coin',
      nameFa: 'ربع سکه',
      category: AssetCategory.coin,
      unit: 'عدد',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'coin_gram',
      symbol: 'COIN-GRAM',
      name: 'Gram Gold Coin',
      nameFa: 'سکه گرمی',
      category: AssetCategory.coin,
      unit: 'عدد',
      currency: 'IRR',
    ),
    AssetDefinition(
      id: 'coin_emami_retail',
      symbol: 'COIN-EMAMI-RETAIL',
      name: 'Emami Coin (retail)',
      nameFa: 'سکه امامی (خرده‌فروشی)',
      category: AssetCategory.coin,
      unit: 'عدد',
      currency: 'IRR',
    ),
    // «حباب» is published by TGJU itself — the premium over intrinsic gold
    // value. Real quoted data, not something this app computes. Not a
    // position you can hold, so it stays out of the portfolio/converter.
    AssetDefinition(
      id: 'coin_half_bubble',
      symbol: 'COIN-HALF-BUBBLE',
      name: 'Half Coin bubble',
      nameFa: 'حباب نیم سکه',
      category: AssetCategory.coin,
      unit: 'تومان',
      currency: 'IRR',
      tradable: false,
    ),
    AssetDefinition(
      id: 'coin_quarter_bubble',
      symbol: 'COIN-QUARTER-BUBBLE',
      name: 'Quarter Coin bubble',
      nameFa: 'حباب ربع سکه',
      category: AssetCategory.coin,
      unit: 'تومان',
      currency: 'IRR',
      tradable: false,
    ),
  ];

  // ---- CRYPTO (verified: CoinGecko public API) ----
  static const crypto = <AssetDefinition>[
    AssetDefinition(
      id: 'btc_usd',
      symbol: 'BTC/USD',
      name: 'Bitcoin',
      nameFa: 'بیت‌کوین',
      category: AssetCategory.crypto,
      unit: '',
      currency: 'USD',
    ),
    AssetDefinition(
      id: 'eth_usd',
      symbol: 'ETH/USD',
      name: 'Ethereum',
      nameFa: 'اتریوم',
      category: AssetCategory.crypto,
      unit: '',
      currency: 'USD',
    ),
    AssetDefinition(
      id: 'usdt_usd',
      symbol: 'USDT/USD',
      name: 'Tether',
      nameFa: 'تتر',
      category: AssetCategory.crypto,
      unit: '',
      currency: 'USD',
    ),
  ];

  // ---- INDEX (verified keyless: TGJU live feed) ----
  // Index points, NOT Rial: currency 'IDX' keeps it out of every
  // Rial->Toman conversion path.
  static const indices = <AssetDefinition>[
    AssetDefinition(
      id: 'bourse_index',
      symbol: 'TEDPIX',
      name: 'Tehran Stock Exchange index',
      nameFa: 'شاخص کل بورس',
      category: AssetCategory.marketIndex,
      unit: 'واحد',
      currency: 'IDX',
      tradable: false,
    ),
  ];

  // ---- COMMODITY (verified keyless: TGJU live feed, USD per barrel) ----
  static const commodities = <AssetDefinition>[
    AssetDefinition(
      id: 'oil_brent',
      symbol: 'BRENT',
      name: 'Brent crude',
      nameFa: 'نفت برنت',
      category: AssetCategory.commodity,
      unit: 'بشکه',
      currency: 'USD',
    ),
    AssetDefinition(
      id: 'oil_wti',
      symbol: 'WTI',
      name: 'WTI crude',
      nameFa: 'نفت وست تگزاس',
      category: AssetCategory.commodity,
      unit: 'بشکه',
      currency: 'USD',
    ),
  ];

  static const all = <AssetDefinition>[
    ...globalCurrencies,
    ...iranianMarket,
    ...goldAndCoins,
    ...crypto,
    ...indices,
    ...commodities,
  ];

  static AssetDefinition? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static const _usd = AssetDefinition(
    id: 'fx_usd',
    symbol: 'USD',
    name: 'US Dollar',
    nameFa: 'دلار آمریکا',
    category: AssetCategory.currency,
    unit: '',
    currency: 'USD',
  );
  static const _eur = AssetDefinition(
    id: 'fx_eur',
    symbol: 'EUR',
    name: 'Euro',
    nameFa: 'یورو',
    category: AssetCategory.currency,
    unit: '',
    currency: 'EUR',
  );
  static const _gbp = AssetDefinition(
    id: 'fx_gbp',
    symbol: 'GBP',
    name: 'British Pound',
    nameFa: 'پوند انگلیس',
    category: AssetCategory.currency,
    unit: '',
    currency: 'GBP',
  );
  static const _aed = AssetDefinition(
    id: 'fx_aed',
    symbol: 'AED',
    name: 'UAE Dirham',
    nameFa: 'درهم امارات',
    category: AssetCategory.currency,
    unit: '',
    currency: 'AED',
  );
  static const _try_ = AssetDefinition(
    id: 'fx_try',
    symbol: 'TRY',
    name: 'Turkish Lira',
    nameFa: 'لیر ترکیه',
    category: AssetCategory.currency,
    unit: '',
    currency: 'TRY',
  );
  static const _cny = AssetDefinition(
    id: 'fx_cny',
    symbol: 'CNY',
    name: 'Chinese Yuan',
    nameFa: 'یوان چین',
    category: AssetCategory.currency,
    unit: '',
    currency: 'CNY',
  );
  static const _cad = AssetDefinition(
    id: 'fx_cad',
    symbol: 'CAD',
    name: 'Canadian Dollar',
    nameFa: 'دلار کانادا',
    category: AssetCategory.currency,
    unit: '',
    currency: 'CAD',
  );
  static const _aud = AssetDefinition(
    id: 'fx_aud',
    symbol: 'AUD',
    name: 'Australian Dollar',
    nameFa: 'دلار استرالیا',
    category: AssetCategory.currency,
    unit: '',
    currency: 'AUD',
  );
  static const _chf = AssetDefinition(
    id: 'fx_chf',
    symbol: 'CHF',
    name: 'Swiss Franc',
    nameFa: 'فرانک سوئیس',
    category: AssetCategory.currency,
    unit: '',
    currency: 'CHF',
  );
  static const _jpy = AssetDefinition(
    id: 'fx_jpy',
    symbol: 'JPY',
    name: 'Japanese Yen',
    nameFa: 'ین ژاپن',
    category: AssetCategory.currency,
    unit: '',
    currency: 'JPY',
  );

  /// Official published IRR rate (real source data; NOT free-market).
  static const _irr = AssetDefinition(
    id: 'fx_irr',
    symbol: 'USD/IRR',
    name: 'Iranian Rial (official)',
    nameFa: 'ریال ایران (رسمی)',
    category: AssetCategory.currency,
    unit: 'ریال',
    currency: 'IRR',
  );
}
