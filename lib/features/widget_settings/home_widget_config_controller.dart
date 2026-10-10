import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cache/local_state_store.dart';
import '../../services/background_alert_worker.dart';
import '../../services/home_widget_service.dart';
import '../../services/widget/widget_background.dart';
import '../../state/app_providers.dart';

/// The widget's configuration, as the settings screen edits it. Null
/// while loading.
final homeWidgetConfigProvider =
    NotifierProvider<HomeWidgetConfigController, WidgetConfig?>(
      HomeWidgetConfigController.new,
    );

class HomeWidgetConfigController extends Notifier<WidgetConfig?> {
  KeyValueStore get _store => ref.read(localStoreProvider);

  @override
  WidgetConfig? build() {
    HomeWidgetService.loadConfig(_store).then((c) => state = c);
    return null;
  }

  Future<void> setEnabled(bool value) async {
    await HomeWidgetService.setEnabled(_store, value);
    // The widget has its own claim on the 15-minute task.
    try {
      await BackgroundAlertWorker.restore(_store);
    } catch (e) {
      debugPrint('[widget] schedule: $e');
    }
    await _applied();
  }

  Future<void> setIds(List<String> ids) async {
    await HomeWidgetService.saveSelection(_store, ids);
    await _applied();
  }

  Future<void> add(String id) async {
    final ids = state?.ids ?? HomeWidgetService.defaultAssets;
    if (ids.contains(id) || ids.length >= HomeWidgetService.maxAssets) return;
    await setIds([...ids, id]);
  }

  /// The last asset cannot be removed: an empty widget is no widget.
  Future<void> remove(String id) async {
    final ids = state?.ids ?? HomeWidgetService.defaultAssets;
    if (ids.length <= 1) return;
    await setIds([...ids]..remove(id));
  }

  Future<void> move(int from, int to) async {
    final ids = [...?state?.ids];
    if (from < 0 || from >= ids.length) return;
    final id = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), id);
    await setIds(ids);
  }

  Future<void> resetIds() async {
    await HomeWidgetService.resetSelection(_store);
    await _applied();
  }

  Future<void> setMode(WidgetRefreshMode mode) async {
    await HomeWidgetService.saveMode(_store, mode);
    await _applied();
  }

  Future<void> _applied() async {
    final c = await HomeWidgetService.loadConfig(_store);
    state = c;
    await WidgetLiveService.apply(c);
    final snap = ref.read(marketControllerProvider).snapshot;
    if (snap != null && c.enabled) {
      await HomeWidgetService.publish(_store, snap.quotes);
    }
  }
}
