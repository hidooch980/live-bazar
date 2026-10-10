import 'package:home_widget/home_widget.dart';

/// The key/value space the Android widget reads (home_widget's
/// SharedPreferences), plus the redraw broadcast.
///
/// Background paths (the screen-on refresh, the live service, the
/// 15-minute worker) talk to the widget ONLY through this, never through
/// Hive: Hive is not safe to open from two isolates at once, while
/// SharedPreferences commits are atomic per key.
abstract interface class WidgetDataStore {
  Future<String?> read(String key);

  /// A null value removes the key.
  Future<void> save(String key, String? value);

  /// Asks every widget size to redraw from what was saved.
  Future<void> redraw();
}

/// The real thing, backed by the home_widget plugin.
class PluginWidgetDataStore implements WidgetDataStore {
  const PluginWidgetDataStore();

  /// One provider per widget size; all render from the same payload.
  static const providers = <String>[
    'MolidoWidgetSmallProvider',
    'MolidoWidgetProvider', // medium — the 0.4.0 widget, kept for upgrades
    'MolidoWidgetLargeProvider',
  ];

  @override
  Future<String?> read(String key) => HomeWidget.getWidgetData<String>(key);

  @override
  Future<void> save(String key, String? value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> redraw() async {
    for (final p in providers) {
      await HomeWidget.updateWidget(androidName: p);
    }
  }
}

/// In-memory variant for tests.
class MemoryWidgetDataStore implements WidgetDataStore {
  final values = <String, String>{};
  int saves = 0;
  int redraws = 0;
  bool fail = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> save(String key, String? value) async {
    if (fail) throw StateError('no widget host');
    saves++;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> redraw() async {
    if (fail) throw StateError('no widget host');
    redraws++;
  }
}
