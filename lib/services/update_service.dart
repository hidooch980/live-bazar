import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/network/http_config.dart';

/// Result of an update check against GitHub Releases.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    this.latestVersion,
    this.apkUrl,
    this.releaseNotes,
  });

  final String currentVersion;
  final String? latestVersion;
  final String? apkUrl;
  final String? releaseNotes;

  bool get hasUpdate =>
      latestVersion != null &&
      apkUrl != null &&
      _isNewer(latestVersion!, currentVersion);
}

/// Compares dotted versions: 0.1.2 > 0.1.1 > 0.1.0.
@visibleForTesting
bool isNewerVersion(String candidate, String current) =>
    _isNewer(candidate, current);

bool _isNewer(String candidate, String current) {
  List<int> parse(String v) => v
      .replaceFirst(RegExp(r'^v'), '')
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final a = parse(candidate);
  final b = parse(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// GITHUB-ONLY auto-update (MASTER PROMPT §1: no backend).
///
/// 1. Reads the latest GitHub Release (tag + APK asset).
/// 2. Compares against the installed version.
/// 3. Downloads the APK (with progress) and hands it to the Android
///    package installer via the platform channel.
/// The user ALWAYS confirms — no silent installs.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? MarketHttp.instance.createClient();

  static const repo = 'hidooch980/live-bazar';
  static const _installChannel = MethodChannel('molido/install_apk');

  final Dio _dio;

  PackageInfo? _info;
  String get currentVersion => _info?.version ?? '0.0.0';

  Future<void> warmup() async {
    _info ??= await PackageInfo.fromPlatform();
  }

  /// Checks the latest GitHub release.
  Future<UpdateCheckResult> check() async {
    await warmup();
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        'https://api.github.com/repos/$repo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final body = res.data;
      if (body == null) {
        return UpdateCheckResult(currentVersion: currentVersion);
      }
      final tag = body['tag_name'] as String?;
      final notes = body['body'] as String?;
      String? apkUrl;
      final assets = body['assets'];
      if (assets is List) {
        for (final a in assets) {
          final m = Map<String, dynamic>.from(a as Map);
          final name = (m['name'] as String?) ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = m['browser_download_url'] as String?;
            break;
          }
        }
      }
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: tag,
        apkUrl: apkUrl,
        releaseNotes: notes,
      );
    } catch (_) {
      return UpdateCheckResult(currentVersion: currentVersion);
    }
  }

  /// Downloads [url] and returns the local file path.
  ///
  /// Uses `<cache>/molido_update/` which matches the FileProvider
  /// declaration in AndroidManifest (see res/xml/file_paths.xml).
  Future<String> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}molido_update');
    await dir.create(recursive: true);
    // Remove stale installers.
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.apk')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    final path = '${dir.path}${Platform.pathSeparator}molido-update.apk';
    await _dio.download(
      url,
      path,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    return path;
  }

  /// Hands the downloaded APK to the Android package installer.
  Future<bool> install(String apkPath) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _installChannel.invokeMethod<bool>('install', {
        'path': apkPath,
      });
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }
}
