import 'dart:convert';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/cache/local_state_store.dart';
import '../domain/entities/alert_rule.dart';
import '../services/portfolio_service.dart';

/// LOCAL backup/restore of user data (§34 privacy: nothing leaves the
/// device unless the user shares the file themselves).
///
/// Covers: watchlist, portfolio holdings, alert rules.
class BackupService {
  static const _shareChannel = MethodChannel('molido/install_apk');

  final KeyValueStore store;

  BackupService(this.store);

  /// Builds the backup document from the CURRENT store contents.
  Future<String> exportJson() async {
    final watchlist = await store.getString('watchlist_ids') ?? '';
    final holdings = await store.getString('portfolio_holdings') ?? '[]';
    final alerts = await store.getString('alert_rules') ?? '[]';
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'MOLIDO MARKET',
      'schema': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'watchlist_ids': watchlist,
      'portfolio_holdings': holdings,
      'alert_rules': alerts,
    });
  }

  /// Restores from a backup document. Returns the number of restored
  /// sections (0..3). Throws [FormatException] on malformed input.
  Future<int> importJson(String raw) async {
    final doc = jsonDecode(raw);
    if (doc is! Map) throw const FormatException('not a JSON object');
    var restored = 0;
    final wl = doc['watchlist_ids'];
    if (wl is String) {
      await store.setString('watchlist_ids', wl);
      restored++;
    }
    final ph = doc['portfolio_holdings'];
    if (ph is String && _validJsonList(ph)) {
      await store.setString('portfolio_holdings', ph);
      restored++;
    }
    final ar = doc['alert_rules'];
    if (ar is String && _validJsonList(ar)) {
      // Validate every rule parses before persisting.
      decodeList(ar).map(AlertRule.fromJson).toList();
      await store.setString('alert_rules', ar);
      restored++;
    }
    return restored;
  }

  bool _validJsonList(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is List;
    } catch (_) {
      return false;
    }
  }

  /// Writes the backup to the app cache and opens the Android share
  /// sheet (FileProvider-backed). Returns false when sharing is not
  /// available (e.g. desktop tests).
  Future<bool> shareExport() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/backups');
    await dir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp(r'[:\-]'), '');
    final file = File('${dir.path}/molido-backup-$stamp.json');
    await file.writeAsString(await exportJson(), flush: true);
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _shareChannel.invokeMethod<bool>('share', {
        'path': file.path,
        'mime': 'application/json',
        'subject': 'MOLIDO MARKET backup',
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Convenience used by the restore dialog.
  static Holding holdingFromJson(Map<String, dynamic> j) => Holding.fromJson(j);
}
