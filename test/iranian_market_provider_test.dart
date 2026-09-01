import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/config/asset_catalog.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/providers/adapters/iranian_market_provider.dart';

/// Shape-accurate excerpt of call1.tgju.org/ajax.json.
Map<String, dynamic> _feed() => {
  'current': {
    'price_dollar_rl': {
      'p': '2,130,050',
      'h': '2,132,200',
      'l': '2,099,600',
      'd': '37,050',
      'dp': 1.77,
      'dt': 'high',
      't_en': '13:56:26',
      'ts': '2026-09-01 13:56:26',
    },
    'geram18': {
      'p': '222,072,000',
      'd': '110,000',
      'dp': 0.05,
      'dt': 'low',
      'ts': '2026-09-01 13:56:24',
    },
    'ons': {
      'p': '4,368.85',
      'd': '78.26',
      'dp': 1.79,
      'dt': 'low',
      'ts': '2026-09-01 13:55:15',
    },
    'sekee': {'p': '۲,۲۱۹,۸۵۰,۰۰۰', 'dp': 0, 'dt': '', 'ts': ''},
    'nim': {'p': '-', 'dp': 0, 'dt': ''},
    'price_jpy': {
      'p': '131,750',
      'dp': 0.4,
      'dt': 'high',
      'ts': '2026-09-01 13:56:26',
    },
    'bourse': {
      'p': '6,583,932.3',
      'dp': 1.1,
      'dt': 'high',
      'ts': '2026-09-01 13:56:26',
    },
    'oil_brent': {
      'p': '94.218',
      'dp': 0.6,
      'dt': 'low',
      'ts': '2026-09-01 13:55:15',
    },
    'nim_blubber': {
      'p': '38,000,000',
      'dp': 0.2,
      'dt': 'high',
      'ts': '2026-09-01 13:56:24',
    },
    'gold_futures': {'p': '960,590,000', 'dp': 0.21, 'dt': 'high'},
  },
};

void main() {
  final provider = IranianMarketProvider();
  final fallback = DateTime.utc(2026, 9, 1, 10, 30);

  List<PriceQuote> parse([Set<String>? ids]) => provider.parseFeed(
    _feed(),
    ids ?? provider.supportedAssets,
    fallbackTimestamp: fallback,
  );

  test('every catalog asset the provider claims is enabled', () {
    for (final id in provider.supportedAssets) {
      final def = AssetCatalog.byId(id);
      expect(def, isNotNull, reason: '$id missing from catalog');
      expect(def!.enabled, isTrue, reason: '$id must be enabled');
    }
  });

  test('Rial indicators are published to the UI in Toman', () {
    final usd = parse().firstWhere((q) => q.id == 'ir_usd');
    expect(usd.price, 213005); // 2,130,050 Rial -> Toman
    expect(usd.unit, 'تومان');
    expect(usd.source, 'TGJU');
    expect(usd.status, QuoteStatus.live);

    final gold = parse().firstWhere((q) => q.id == 'gold_18k');
    expect(gold.price, 22207200);
  });

  test('USD ounces keep the published USD value', () {
    final ounce = parse().firstWhere((q) => q.id == 'xau_usd');
    expect(ounce.price, 4368.85);
    expect(ounce.currency, 'USD');
  });

  test('direction flag signs the daily change', () {
    final usd = parse().firstWhere((q) => q.id == 'ir_usd');
    expect(usd.changePercent, 1.77); // dt: high
    expect(usd.change, 3705); // 37,050 Rial -> Toman

    final gold = parse().firstWhere((q) => q.id == 'gold_18k');
    expect(gold.changePercent, -0.05); // dt: low
    expect(gold.change, -11000);
  });

  test('Tehran wall-clock timestamps are converted to UTC', () {
    final usd = parse().firstWhere((q) => q.id == 'ir_usd');
    expect(usd.timestamp.isUtc, isTrue);
    expect(usd.timestamp, DateTime.utc(2026, 9, 1, 10, 26, 26));
  });

  test('Persian digits parse; unusable rows are skipped, not faked', () {
    final quotes = parse();
    // Persian-digit price still parses.
    expect(
      quotes.firstWhere((q) => q.id == 'coin_emami').price,
      221985000, // 2,219,850,000 Rial -> Toman
    );
    // Missing/blank timestamp falls back to the response time — never a
    // fabricated "now" inside the quote.
    expect(quotes.firstWhere((q) => q.id == 'coin_emami').timestamp, fallback);
    // '-' placeholder yields no quote at all.
    expect(quotes.where((q) => q.id == 'coin_half'), isEmpty);
  });

  test('only requested assets are returned', () {
    final quotes = parse({'ir_usd'});
    expect(quotes.map((q) => q.id), ['ir_usd']);
  });

  test('a feed without the current table yields nothing', () {
    expect(
      provider.parseFeed(
        {'last': []},
        provider.supportedAssets,
        fallbackTimestamp: fallback,
      ),
      isEmpty,
    );
  });

  test('index points and USD barrels are never divided by 10', () {
    final quotes = parse();
    final bourse = quotes.firstWhere((q) => q.id == 'bourse_index');
    expect(bourse.price, 6583932.3);
    expect(bourse.currency, 'IDX');
    expect(bourse.unit, 'واحد');

    final brent = quotes.firstWhere((q) => q.id == 'oil_brent');
    expect(brent.price, 94.218);
    expect(brent.currency, 'USD');
  });

  test('the yen is carried per 100 units, as the feed publishes it', () {
    final jpy = parse().firstWhere((q) => q.id == 'ir_jpy');
    expect(jpy.price, 13175); // 131,750 Rial for 100 yen -> Toman
    // The name must carry the multiple, or the number reads 100x wrong.
    expect(jpy.nameFa, contains('۱۰۰'));
  });

  test('TGJU-published coin bubbles come through in Toman', () {
    final bubble = parse().firstWhere((q) => q.id == 'coin_half_bubble');
    expect(bubble.price, 3800000);
    expect(bubble.source, 'TGJU');
  });

  test('non-holdable observations stay out of portfolio and converter', () {
    for (final id in [
      'bourse_index',
      'coin_half_bubble',
      'coin_quarter_bubble',
    ]) {
      expect(AssetCatalog.byId(id)!.tradable, isFalse, reason: id);
    }
    for (final id in ['ir_usd', 'gold_18k', 'coin_emami', 'oil_brent']) {
      expect(AssetCatalog.byId(id)!.tradable, isTrue, reason: id);
    }
  });

  test('number parsing rejects junk', () {
    expect(IranianMarketProvider.parseNumber('1,234.5'), 1234.5);
    expect(IranianMarketProvider.parseNumber('۰'), isNull);
    expect(IranianMarketProvider.parseNumber('-'), isNull);
    expect(IranianMarketProvider.parseNumber(''), isNull);
    expect(IranianMarketProvider.parseNumber(null), isNull);
  });
}
