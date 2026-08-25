import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Generic local persistence used by watchlist / alerts / portfolio /
/// history. Hive-backed; JSON-encoded values keep schema evolution trivial.
abstract interface class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  List<String> keys();
}

class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore._();

  static const boxName = 'molido_local_state';

  static Future<KeyValueStore> open() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(boxName);
    return HiveKeyValueStore._();
  }

  Box<dynamic> get _box => Hive.box<dynamic>(boxName);

  @override
  Future<String?> getString(String key) async {
    final v = _box.get(key);
    return v is String ? v : null;
  }

  @override
  Future<void> setString(String key, String value) => _box.put(key, value);

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  List<String> keys() =>
      _box.keys.map((e) => e.toString()).toList(growable: false);
}

/// In-memory variant for tests.
class InMemoryKeyValueStore implements KeyValueStore {
  final _map = <String, String>{};

  @override
  Future<String?> getString(String key) async => _map[key];

  @override
  Future<void> setString(String key, String value) async => _map[key] = value;

  @override
  Future<void> remove(String key) async => _map.remove(key);

  @override
  List<String> keys() => _map.keys.toList(growable: false);
}

// ---- JSON helpers shared by the services ----

String encodeList(List<Map<String, dynamic>> items) => jsonEncode(items);

List<Map<String, dynamic>> decodeList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}
