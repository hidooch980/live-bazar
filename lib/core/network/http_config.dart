import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;

import '../constants/app_constants.dart';
import '../../data/cache/local_state_store.dart';

/// User-configurable outbound HTTP proxy («تنظیمات پروکسی»).
///
/// Lets users behind restrictive networks route market traffic through a
/// local/remote HTTP proxy (e.g. 127.0.0.1:8888). Stored LOCAL-ONLY.
@immutable
class ProxyConfig {
  const ProxyConfig({
    this.enabled = false,
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
  });

  final bool enabled;
  final String host;
  final int port;
  final String username;
  final String password;

  bool get isValid => enabled && host.isNotEmpty && port > 0;

  ProxyConfig copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? username,
    String? password,
  }) => ProxyConfig(
    enabled: enabled ?? this.enabled,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };

  static ProxyConfig fromJson(Map<String, dynamic> j) => ProxyConfig(
    enabled: (j['enabled'] as bool?) ?? false,
    host: (j['host'] as String?) ?? '',
    port: (j['port'] as num?)?.toInt() ?? 0,
    username: (j['username'] as String?) ?? '',
    password: (j['password'] as String?) ?? '',
  );
}

/// Shared HTTP layer for all market providers.
///
/// - Applies the user proxy (if any) to every client.
/// - Central place for timeouts/UA so diagnostics stay consistent.
class MarketHttp {
  MarketHttp._();
  static final MarketHttp instance = MarketHttp._();

  static const _storeKey = 'proxy_config';

  ProxyConfig _proxy = const ProxyConfig();
  ProxyConfig get proxy => _proxy;

  Future<void> load(KeyValueStore store) async {
    final raw = await store.getString(_storeKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _proxy = ProxyConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      _proxy = const ProxyConfig();
    }
  }

  Future<void> save(KeyValueStore store, ProxyConfig config) async {
    _proxy = config;
    await store.setString(_storeKey, jsonEncode(config.toJson()));
  }

  /// Creates a Dio client honoring the current proxy config.
  Dio createClient() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        headers: {
          'User-Agent':
              'MolidoMarket/1.1 (+https://github.com/hidooch980/live-bazar)',
        },
      ),
    );
    if (!kIsWeb && _proxy.isValid) {
      final p = _proxy;
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) => 'PROXY ${p.host}:${p.port}';
        if (p.username.isNotEmpty) {
          final creds = HttpClientBasicCredentials(p.username, p.password);
          client.authenticateProxy = (host, port, scheme, realm) async {
            client.addProxyCredentials(host, port, realm ?? '', creds);
            return true;
          };
        }
        client.connectionTimeout = AppConstants.requestTimeout;
        return client;
      };
    }
    return dio;
  }
}
