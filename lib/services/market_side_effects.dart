import '../domain/entities/alert_rule.dart';
import '../domain/entities/market_snapshot.dart';
import '../domain/entities/price_quote.dart';
import 'alert_service.dart';
import 'historical_snapshot_service.dart';
import 'notification_service.dart';

/// Bridges engine snapshots into local side effects:
/// history accumulation (§19) + alert evaluation (§23).
class MarketSideEffects {
  MarketSideEffects({
    required this.history,
    required this.alerts,
    required this.notifications,
  });

  final HistoricalSnapshotService history;
  final AlertService alerts;
  final NotificationService notifications;

  Future<void> onSnapshot(MarketSnapshot snapshot) async {
    // 1) Record real observations for future charts.
    await history.record({
      for (final e in snapshot.quotes.entries)
        if (e.value.status.isDisplayable)
          e.key: PricePoint(e.value.timestamp, e.value.price),
    });

    // 2) Evaluate local alert rules; fire notifications for hits.
    final fired = await alerts.evaluate(
      quotes: {
        for (final e in snapshot.quotes.entries)
          e.key: (price: e.value.price, changePercent: e.value.changePercent),
      },
    );
    for (final rule in fired) {
      final q = snapshot.quotes[rule.assetId];
      if (q == null) continue;
      final body = switch (rule.type) {
        AlertType.priceAbove => 'قیمت به بالای ${rule.threshold} رسید',
        AlertType.priceBelow => 'قیمت به زیر ${rule.threshold} رسید',
        AlertType.percentUp =>
          'رشد ${rule.threshold.toStringAsFixed(1)}٪ ثبت شد',
        AlertType.percentDown =>
          'افت ${rule.threshold.abs().toStringAsFixed(1)}٪ ثبت شد',
      };
      await notifications.showAlert(
        rule: rule,
        assetName: q.nameFa,
        body: '$body — ${q.symbol}',
      );
    }
  }
}
