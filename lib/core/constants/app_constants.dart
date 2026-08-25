/// Global, immutable application constants.
abstract final class AppConstants {
  static const String appName = 'MOLIDO MARKET';
  static const String appNameFa = 'بازار مولیدو';
  static const String taglineFa = 'بازار را لحظه‌به‌لحظه دنبال کن';

  /// Central market check cadence while the app is in the foreground.
  static const Duration marketCheckInterval = Duration(seconds: 5);

  /// Per-provider minimum intervals (rate-limit protection).
  static const Duration cryptoMinInterval = Duration(seconds: 30);
  static const Duration globalCurrencyMinInterval = Duration(seconds: 60);
  static const Duration snapshotFallbackInterval = Duration(minutes: 15);

  static const Duration requestTimeout = Duration(seconds: 12);

  /// A quote older than this is flagged STALE.
  static const Duration staleThreshold = Duration(minutes: 30);

  /// Relative price move (as fraction) considered anomalous between checks.
  static const double anomalyJumpFraction = 0.10;

  static const String cacheBoxQuotes = 'molido_quotes';
  static const String cacheBoxMeta = 'molido_meta';
  static const String cacheKeyLastSnapshot = 'last_snapshot';
}
