import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../config/asset_catalog.dart';
import '../core/network/http_config.dart';
import '../data/cache/local_state_store.dart';
import '../domain/entities/alert_rule.dart';
import '../providers/adapters/crypto_provider.dart';
import '../providers/adapters/global_currency_provider.dart';
import '../providers/adapters/iranian_market_provider.dart';
import '../providers/iprice_provider.dart';
import 'alert_service.dart';
import 'notification_service.dart';
import 'timezone_service.dart';

/// BACKGROUND PRICE ALERTS.
///
/// A price alert that only fires while the app is open is not an alert.
/// The foreground engine deliberately stops on pause (§6), so alert rules
/// were never evaluated once the user left the app.
///
/// This worker closes that gap WITHOUT reintroducing unlimited background
/// polling: Android's minimum periodic interval is 15 minutes, the task
/// only runs when the user has switched it on, and it does exactly one
/// fetch-evaluate-notify pass per wake-up.
///
/// It runs in its own isolate: no Riverpod, no engine, no UI. It talks to
/// the same providers and the same local store the app uses, so a rule
/// fired here is a rule the app agrees was met.
abstract final class BackgroundAlertWorker {
  static const taskName = 'molido-price-alerts';
  static const uniqueName = 'molido-price-alerts-periodic';

  /// Android will not schedule a periodic task more often than this.
  static const interval = Duration(minutes: 15);

  /// Persisted opt-in. Off by default: background work is the user's call.
  static const enabledKey = 'background_alerts_enabled';

  static Future<void> initialize() async {
    await Workmanager().initialize(backgroundAlertDispatcher);
  }

  static Future<void> enable() async {
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: interval,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> disable() async {
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  /// Applies the stored preference at startup so a reinstall or an OS
  /// cleanup cannot silently leave alerts unscheduled.
  static Future<bool> restore(KeyValueStore store) async {
    final on = (await store.getString(enabledKey)) == '1';
    if (on) {
      await enable();
    } else {
      await disable();
    }
    return on;
  }

  static Future<void> setEnabled(KeyValueStore store, bool value) async {
    await store.setString(enabledKey, value ? '1' : '0');
    if (value) {
      await enable();
    } else {
      await disable();
    }
  }
}

/// Entry point for the background isolate. Must be top-level.
@pragma('vm:entry-point')
void backgroundAlertDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != BackgroundAlertWorker.taskName) return true;
    try {
      await runBackgroundAlertCheck();
      return true;
    } catch (e) {
      debugPrint('[bg-alerts] $e');
      // Returning true avoids WorkManager's exponential backoff for what
      // is almost always a transient network failure; the next periodic
      // wake-up is only 15 minutes away.
      return true;
    }
  });
}

/// One fetch-evaluate-notify pass. Split out so it is testable and so the
/// dispatcher stays a thin shell.
@visibleForTesting
Future<int> runBackgroundAlertCheck({
  List<IPriceProvider>? providers,
  KeyValueStore? store,
  NotificationService? notifications,
}) async {
  final localStore = store ?? await HiveKeyValueStore.open();

  final alerts = AlertService(localStore);
  await alerts.load();
  final active = alerts.rules.where((r) => r.isActive).toList();
  if (active.isEmpty) return 0;

  // Only fetch what an active rule actually needs.
  final wanted = active.map((r) => r.assetId).toSet();

  await MarketHttp.instance.load(localStore);
  final chain =
      providers ??
      [IranianMarketProvider(), CryptoProvider(), GlobalCurrencyProvider()];

  final quotes = <String, ({double price, double changePercent})>{};
  for (final provider in chain) {
    final needed = provider.supportedAssets.intersection(wanted);
    if (needed.isEmpty) continue;
    final result = await provider.getLatestPrices(needed);
    if (!result.isSuccess) continue;
    for (final q in result.quotes) {
      if (q.price <= 0) continue;
      if (AssetCatalog.byId(q.id) == null) continue;
      quotes[q.id] = (price: q.price, changePercent: q.changePercent);
    }
  }
  if (quotes.isEmpty) return 0;

  final fired = await alerts.evaluate(quotes: quotes);
  if (fired.isEmpty) return 0;

  final notifier = notifications ?? NotificationService();
  await notifier.init(timeZone: TimeZoneService());
  for (final rule in fired) {
    final def = AssetCatalog.byId(rule.assetId);
    await notifier.showAlert(
      rule: rule,
      assetName: def?.nameFa ?? rule.assetId,
      body: _bodyFor(rule),
    );
  }
  return fired.length;
}

String _bodyFor(AlertRule rule) => switch (rule.type) {
  AlertType.priceAbove => 'قیمت به بالای ${rule.threshold} رسید',
  AlertType.priceBelow => 'قیمت به زیر ${rule.threshold} رسید',
  AlertType.percentUp => 'رشد ${rule.threshold.toStringAsFixed(1)}٪ ثبت شد',
  AlertType.percentDown =>
    'افت ${rule.threshold.abs().toStringAsFixed(1)}٪ ثبت شد',
};
