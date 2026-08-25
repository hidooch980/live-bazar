import '../data/cache/local_state_store.dart';
import '../domain/entities/price_quote.dart';

/// One LOCAL holding (§24): asset id + quantity. Never uploaded.
class Holding {
  const Holding({required this.assetId, required this.quantity});

  final String assetId;
  final double quantity;

  Map<String, dynamic> toJson() => {'assetId': assetId, 'q': quantity};

  static Holding fromJson(Map<String, dynamic> j) => Holding(
    assetId: j['assetId'] as String,
    quantity: (j['q'] as num).toDouble(),
  );
}

/// Computed valuation of the whole portfolio.
class PortfolioValuation {
  const PortfolioValuation({
    required this.totalValue,
    required this.dailyChange,
    required this.lines,
  });

  /// Total value expressed in USD (all V1 quotes are USD-denominated).
  final double totalValue;

  /// Sum of value * real changePercent per line.
  final double dailyChange;
  final List<PortfolioLine> lines;
}

class PortfolioLine {
  const PortfolioLine({
    required this.holding,
    required this.quote,
    required this.value,
    required this.dailyChange,
  });

  final Holding holding;
  final PriceQuote quote;
  final double value;
  final double dailyChange;
}

/// LOCAL-ONLY portfolio (§24). Nothing is ever uploaded.
class PortfolioService {
  static const _key = 'portfolio_holdings';

  final KeyValueStore store;
  List<Holding> _holdings = [];

  PortfolioService(this.store);

  Future<void> load() async {
    _holdings = decodeList(await store.getString(_key))
        .map(Holding.fromJson)
        .toList();
  }

  List<Holding> get holdings => List.unmodifiable(_holdings);

  Future<void> setQuantity(String assetId, double quantity) async {
    if (quantity <= 0) {
      _holdings.removeWhere((h) => h.assetId == assetId);
    } else {
      final i = _holdings.indexWhere((h) => h.assetId == assetId);
      if (i >= 0) {
        _holdings[i] = Holding(assetId: assetId, quantity: quantity);
      } else {
        _holdings.add(Holding(assetId: assetId, quantity: quantity));
      }
    }
    await persist();
  }

  Future<void> remove(String assetId) async {
    _holdings.removeWhere((h) => h.assetId == assetId);
    await persist();
  }

  Future<void> persist() => store.setString(
    _key,
    encodeList(_holdings.map((h) => h.toJson()).toList()),
  );

  /// Values the portfolio using the latest valid quotes only.
  PortfolioValuation value(Map<String, PriceQuote> quotes) {
    var total = 0.0;
    var daily = 0.0;
    final lines = <PortfolioLine>[];
    for (final h in _holdings) {
      final q = quotes[h.assetId];
      if (q == null || !q.status.isDisplayable) continue;
      final v = q.price * h.quantity;
      total += v;
      daily += v * q.changePercent / 100;
      lines.add(
        PortfolioLine(holding: h, quote: q, value: v, dailyChange: daily),
      );
    }
    return PortfolioValuation(
      totalValue: total,
      dailyChange: daily,
      lines: lines,
    );
  }
}
