import 'package:flutter/foundation.dart';

import 'price_quote.dart';

/// A validated, point-in-time view of the whole market.
@immutable
class MarketSnapshot {
  const MarketSnapshot({
    required this.snapshotId,
    required this.timestamp,
    required this.quotes,
    required this.sourceStatus,
    this.latencyMs = 0,
  });

  final String snapshotId;
  final DateTime timestamp;
  final Map<String, PriceQuote> quotes;

  /// provider id -> ok | degraded | failed
  final Map<String, String> sourceStatus;
  final int latencyMs;

  bool get isEmpty => quotes.isEmpty;

  MarketSnapshot copyWith({Map<String, PriceQuote>? quotes}) => MarketSnapshot(
    snapshotId: snapshotId,
    timestamp: timestamp,
    quotes: quotes ?? this.quotes,
    sourceStatus: sourceStatus,
    latencyMs: latencyMs,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'snapshotId': snapshotId,
    'timestamp': timestamp.toIso8601String(),
    'latencyMs': latencyMs,
    'sourceStatus': sourceStatus,
    'quotes': quotes.map((k, v) => MapEntry(k, v.toJson())),
  };

  static MarketSnapshot fromJson(Map<String, dynamic> json) {
    final rawQuotes = (json['quotes'] as Map<String, dynamic>? ?? {});
    return MarketSnapshot(
      snapshotId: (json['snapshotId'] as String?) ?? 'unknown',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now().toUtc(),
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      sourceStatus: ((json['sourceStatus'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      quotes: rawQuotes.map(
        (k, v) => MapEntry(
          k,
          PriceQuote.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
    );
  }
}
