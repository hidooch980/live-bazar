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

    test('same or older returns false', () {
      expect(isNewerVersion('v0.1.1', '0.1.1'), isFalse);
      expect(isNewerVersion('v0.1.0', '0.1.1'), isFalse);
      expect(isNewerVersion('0.0.9', '0.1.0'), isFalse);
    });
  });

  group('ProxyConfig', () {
    test('json roundtrip', () {
      const p = ProxyConfig(
        enabled: true,
        host: '127.0.0.1',
        port: 8888,
        username: 'u',
        password: 'p',
      );
      final back = ProxyConfig.fromJson(p.toJson());
      expect(back.enabled, p.enabled);
      expect(back.host, p.host);
      expect(back.port, p.port);
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
      const cur = '0.1.1';
      expect(
        UpdateCheckResult(
          currentVersion: cur,
          latestVersion: 'v0.1.2',
          apkUrl: 'x',
        ).hasUpdate,
        isTrue,
      );
      expect(
        UpdateCheckResult(
          currentVersion: cur,
          latestVersion: 'v0.1.2',
        ).hasUpdate,
        isFalse,
      );
      expect(
        UpdateCheckResult(
          currentVersion: cur,
          latestVersion: 'v0.1.1',
          apkUrl: 'x',
        ).hasUpdate,
        isFalse,
      );
    });
  });
}
