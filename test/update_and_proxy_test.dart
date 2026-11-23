import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/core/network/http_config.dart';
import 'package:live_bazar/services/update_service.dart';

void main() {
  group('version comparison (auto-update)', () {
    test('newer patch wins', () {
      expect(isNewerVersion('v0.1.2', '0.1.1'), isTrue);
      expect(isNewerVersion('0.1.2', '0.1.1'), isTrue);
    });

    test('minor/major bumps win', () {
      expect(isNewerVersion('v0.2.0', '0.1.9'), isTrue);
      expect(isNewerVersion('v1.0.0', '0.9.9'), isTrue);
    });

    test('build metadata does not change release ordering', () {
      expect(isNewerVersion('v0.7.3+19', '0.7.2+18'), isTrue);
      expect(isNewerVersion('0.7.2+99', 'v0.7.2+18'), isFalse);
    });

    test('same or older returns false', () {
      expect(isNewerVersion('v0.1.1', '0.1.1'), isFalse);
      expect(isNewerVersion('v0.1.0', '0.1.1'), isFalse);
      expect(isNewerVersion('0.0.9', '0.1.0'), isFalse);
    });
  });

  group('ProxyConfig', () {
    test('json roundtrip', () {
      const proxy = ProxyConfig(
        enabled: true,
        host: '127.0.0.1',
        port: 8888,
        username: 'u',
        password: 'p',
      );
      final back = ProxyConfig.fromJson(proxy.toJson());
      expect(back.enabled, proxy.enabled);
      expect(back.host, proxy.host);
      expect(back.port, proxy.port);
      expect(back.isValid, isTrue);
    });

    test('invalid when disabled or missing host/port', () {
      expect(const ProxyConfig().isValid, isFalse);
      expect(
        const ProxyConfig(enabled: true, host: '', port: 0).isValid,
        isFalse,
      );
      expect(
        const ProxyConfig(enabled: true, host: 'h', port: 80).isValid,
        isTrue,
      );
    });
  });

  group('UpdateCheckResult', () {
    test('hasUpdate requires newer tag AND apk url', () {
      const current = '0.1.1';
      expect(
        UpdateCheckResult(
          currentVersion: current,
          latestVersion: 'v0.1.2',
          apkUrl: 'https://example.com/app.apk',
        ).hasUpdate,
        isTrue,
      );
      expect(
        UpdateCheckResult(
          currentVersion: current,
          latestVersion: 'v0.1.2',
        ).hasUpdate,
        isFalse,
      );
      expect(
        UpdateCheckResult(
          currentVersion: current,
          latestVersion: 'v0.1.1',
          apkUrl: 'https://example.com/app.apk',
        ).hasUpdate,
        isFalse,
      );
    });

    test('failed check is distinguishable from up-to-date', () {
      const result = UpdateCheckResult(
        currentVersion: '0.7.1',
        errorMessage: 'GitHub unavailable',
      );
      expect(result.errorMessage, isNotNull);
      expect(result.hasUpdate, isFalse);
    });
  });
}
