import 'package:live_bazar/core/errors/app_exception.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/providers/iprice_provider.dart';

/// Deterministic fake used by engine & lock tests.
class FakeProvider implements IPriceProvider {
  FakeProvider({
    required this.id,
    required this.supportedAssets,
    this.minInterval = const Duration(seconds: 30),
    this.behavior,
  });

  @override
  final String id;
  @override
  final Set<String> supportedAssets;

  final Duration minInterval;

  @override
  Duration get minRefreshInterval => minInterval;

  /// Controls what the next call returns (async-capable).
  Future<ProviderResult> Function(int callNumber)? behavior;

  int callCount = 0;

  @override
  bool get isEnabled => true;

  @override
  String get displayName => id;

  void succeedWith(double price, DateTime ts) {
    behavior = (_) async => ProviderResult(
      quotes: [_quote(price: price, ts: ts)],
    );
  }

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    callCount++;
    final b = behavior;
    if (b == null) {
      return const ProviderResult(
        quotes: [],
        error: AppException(AppErrorCode.unknown, 'no behavior'),
      );
    }
    return b(callCount);
  }

  @override
  Future<bool> healthCheck() async => true;
}

PriceQuote _quote({
  required double price,
  required DateTime ts,
  String id = 'fx_eur',
}) {
  return PriceQuote(
    id: id,
    symbol: 'EUR',
    name: 'Euro',
    nameFa: 'یورو',
    category: AssetCategory.currency,
    price: price,
    unit: '',
    currency: 'EUR',
    timestamp: ts,
    source: 'fake',
    status: QuoteStatus.live,
  );
}

PriceQuote quoteFor(
  String id, {
  required double price,
  required DateTime ts,
  String symbol = 'X',
}) {
  return PriceQuote(
    id: id,
    symbol: symbol,
    name: id,
    nameFa: id,
    category: AssetCategory.currency,
    price: price,
    unit: '',
    currency: 'USD',
    timestamp: ts,
    source: 'fake',
    status: QuoteStatus.live,
  );
}
