import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../home_widget_service.dart';
import 'widget_refresh.dart';

/// Entry point the native side wakes through home_widget's background
/// broadcast: `molido://widget/refresh?reason=screen_on|live`.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  final reason = switch (uri?.queryParameters['reason']) {
    'live' => WidgetRefreshReason.liveTick,
    'periodic' => WidgetRefreshReason.periodic,
    _ => WidgetRefreshReason.screenOn,
  };
  await WidgetRefresher.run(reason: reason);
}

/// Starts/stops the opt-in live foreground service (Android).
abstract final class WidgetLiveService {
  static const _channel = MethodChannel('molido/widget_live');

  /// Whether the live service should be running for [config].
  @visibleForTesting
  static bool shouldRun(WidgetConfig config) =>
      config.enabled && config.mode == WidgetRefreshMode.live;

  /// Brings the service in line with [config]. Must be called while the
  /// app is in the foreground: Android 12+ refuses to start a foreground
  /// service from the background.
  static Future<void> apply(WidgetConfig config) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(shouldRun(config) ? 'start' : 'stop');
    } on PlatformException catch (e) {
      debugPrint('[widget-live] $e');
    } on MissingPluginException {
      // Widget tests / non-Android hosts.
    }
  }

  /// Registers [widgetBackgroundCallback] with home_widget.
  static Future<void> registerCallback() async {
    try {
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (e) {
      debugPrint('[widget-bg] register: $e');
    }
  }
}
