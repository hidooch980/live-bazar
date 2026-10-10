import 'package:live_bazar/config/asset_catalog.dart';
import 'package:live_bazar/core/errors/app_exception.dart';
import 'package:live_bazar/domain/entities/alert_rule.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/providers/iprice_provider.dart';
import 'package:live_bazar/services/notification_service.dart';
import 'package:live_bazar/state/app_providers.dart';

/// A quote shaped like the real one for [id] (catalog name, unit, currency).
PriceQuote catalogQuote(
  String id,
  double price, {
  DateTime? ts,
  QuoteStatus status = QuoteStatus.live,
  double changePercent = 0,
}) {
  final d = AssetCatalog.byId(id)!;
  return PriceQuote(
    id: id,
    symbol: d.symbol,
    name: d.name,
    nameFa: d.nameFa,
    category: d.category,
    price: price,
    changePercent: changePercent,
    unit: d.unit,
    currency: d.currency,
    timestamp: ts ?? DateTime.now().toUtc(),
    source: 'TGJU',
    status: status,
  );
}

class StubProvider implements IPriceProvider {
  StubProvider(
    this.id,
    this.supportedAssets,
    this.prices, {
    this.minRefreshInterval = const Duration(seconds: 5),
    this.ts,
  });

  @override
  final String id;
  @override
  final Set<String> supportedAssets;
  @override
  final Duration minRefreshInterval;
  Map<String, double> prices;
  DateTime? ts;
  bool fails = false;
  int calls = 0;
  Set<String>? lastRequested;

  @override
  String get displayName => id;
  @override
  bool get isEnabled => true;

  @override
  Future<ProviderResult> getLatestPrices(Set<String> assetIds) async {
    calls++;
    lastRequested = assetIds;
    if (fails) {
      return const ProviderResult(
        quotes: [],
        error: AppException(AppErrorCode.network, 'stub down'),
      );
    }
    return ProviderResult(
      quotes: [
        for (final e in prices.entries)
          if (assetIds.contains(e.key))
            catalogQuote(e.key, e.value, ts: ts, changePercent: 0.42),
      ],
    );
  }

  @override
  Future<bool> healthCheck() async => true;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingNotifier implements NotificationService {
  final summaries = <({String title, String body})>[];

  @override
  Future<void> init({Object? timeZone}) async {}

  @override
  bool get isReady => true;

  @override
  Future<void> showSummary({
    required String title,
    required String body,
  }) async => summaries.add((title: title, body: body));

  @override
  Future<void> showAlert({
    required AlertRule rule,
    required String assetName,
    required String body,
  }) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Snap implements MarketSnapshotLike {
  Snap(this.quotes);
  @override
  final Map<String, PriceQuote> quotes;
  @override
  int get latencyMs => 0;
}

class FakeMarket extends MarketController {
  FakeMarket(this._initial);
  final Map<String, PriceQuote> _initial;

  @override
  MarketState build() =>
      MarketState(snapshot: Snap(_initial), connection: ConnectionMode.online);
}
