import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/entities/alert_rule.dart';
import 'timezone_service.dart';

/// Thin wrapper around Android LOCAL notifications (§23).
///
/// No backend, no push. Non-Android platforms are no-ops so widget tests
/// stay simple. Requires [TimeZoneService] to be initialized first
/// («تعریف ساعت») so any future scheduled alerts use a consistent clock.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'molido_price_alerts';
  static const _channelName = 'هشدارهای قیمت بازار مولیدو';

  Future<void> init({TimeZoneService? timeZone}) async {
    if (_ready) return;
    // «تعریف ساعت»: tz database + local location BEFORE any scheduling.
    await (timeZone ?? TimeZoneService()).init();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  bool get isReady => _ready;

  static const _summaryChannelId = 'molido_daily_summary';
  static const _summaryChannelName = 'خلاصه روزانه بازار';

  /// The opt-in end-of-day summary: one quiet notification, its own
  /// channel so the user can silence it without silencing price alerts.
  Future<void> showSummary({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _summaryChannelId,
        _summaryChannelName,
        importance: Importance.defaultImportance,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _plugin.show(
      id: 0x5d41,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Fires an immediate LOCAL notification for a triggered [rule].
  Future<void> showAlert({
    required AlertRule rule,
    required String assetName,
    required String body,
  }) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: rule.id.hashCode & 0x7fffffff,
      title: assetName,
      body: body,
      notificationDetails: details,
    );
  }

  /// Wall-clock time in the configured timezone (for UI display).
  String nowLabel(TimeZoneService timeZone) {
    final now = timeZone.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
