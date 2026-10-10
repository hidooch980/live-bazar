import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Hands a file to the Android share sheet (FileProvider-backed, same
/// channel as the backup export).
abstract final class ShareService {
  static const _channel = MethodChannel('molido/install_apk');

  /// Writes [png] to the cache `share/` folder (the FileProvider path) and
  /// opens the share sheet. Returns false where sharing is unavailable.
  static Future<bool> sharePng(Uint8List png, {required String subject}) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/share');
    await dir.create(recursive: true);
    // One card at a time: old cards are not kept around.
    for (final f in dir.listSync().whereType<File>()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/molido-prices-$stamp.png');
    await file.writeAsBytes(png, flush: true);
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('share', {
            'path': file.path,
            'mime': 'image/png',
            'subject': subject,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }
}
