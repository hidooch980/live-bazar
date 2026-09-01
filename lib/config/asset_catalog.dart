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
  });

  final String id;
  final String symbol;
  final String name;
  final String nameFa;
  final AssetCategory category;
  final String unit;
  final String currency;
  final bool enabled;
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

  // ---- GLOBAL commodities/indices (no verified keyless source -> off) ----
  static const global = <AssetDefinition>[];

  static const all = <AssetDefinition>[
    ...globalCurrencies,
    ...iranianMarket,
    ...goldAndCoins,
    ...crypto,
    ...global,
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
