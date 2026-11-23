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
    this.errorMessage,
  });

  final String currentVersion;
  final String? latestVersion;
  final String? apkUrl;
  final String? releaseNotes;
  final String? errorMessage;

  bool get hasUpdate =>
      latestVersion != null &&
      apkUrl != null &&
      _isNewer(latestVersion!, currentVersion);
}

/// Compares release versions, ignoring an optional leading v and build metadata.
@visibleForTesting
bool isNewerVersion(String candidate, String current) =>
    _isNewer(candidate, current);

bool _isNewer(String candidate, String current) {
  List<int> parse(String version) {
    final normalized = version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    return normalized
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  final a = parse(candidate);
  final b = parse(current);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// GitHub Releases updater. Installation always requires user confirmation.
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

  /// Checks the latest published, non-draft GitHub release.
  /// A failed request or a release without an APK is NOT reported as
  /// "up to date"; callers can show a useful diagnostic instead.
  Future<UpdateCheckResult> check() async {
    await warmup();
    try {
      final res = await _dio.get<Map<dynamic, dynamic>>(
        'https://api.github.com/repos/$repo/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
      final body = res.data;
      if (body == null) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          errorMessage: 'پاسخ انتشار GitHub خالی بود',
        );
      }

      final tag = body['tag_name'] as String?;
      if (tag == null || tag.trim().isEmpty) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          errorMessage: 'نسخه منتشرشده در GitHub پیدا نشد',
        );
      }

      String? apkUrl;
      final assets = body['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is! Map) continue;
          final name = asset['name'] as String? ?? '';
          final url = asset['browser_download_url'] as String?;
          if (name.toLowerCase().endsWith('.apk') &&
              url != null &&
              url.startsWith('https://')) {
            apkUrl = url;
            break;
          }
        }
      }

      if (apkUrl == null) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          latestVersion: tag,
          releaseNotes: body['body'] as String?,
          errorMessage: 'برای نسخه $tag فایل APK منتشر نشده است',
        );
      }

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: tag,
        apkUrl: apkUrl,
        releaseNotes: body['body'] as String?,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return UpdateCheckResult(
        currentVersion: currentVersion,
        errorMessage: status == null
            ? 'اتصال به GitHub برقرار نشد؛ اینترنت یا پروکسی را بررسی کنید'
            : 'GitHub پاسخ خطای $status داد؛ کمی بعد دوباره تلاش کنید',
      );
    } catch (_) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        errorMessage: 'بررسی نسخه با خطای پیش‌بینی‌نشده روبرو شد',
      );
    }
  }

  /// Downloads [url] and returns the local file path.
  Future<String> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}molido_update');
    await dir.create(recursive: true);
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.apk')) {
        try {
          await file.delete();
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
      final result = await _installChannel.invokeMethod<bool>('install', {
        'path': apkPath,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
