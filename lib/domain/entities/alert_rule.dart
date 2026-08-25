import 'package:flutter/foundation.dart';

enum AlertType { priceAbove, priceBelow, percentUp, percentDown }

/// A LOCAL-ONLY price alert (§23). Never uploaded anywhere.
@immutable
class AlertRule {
  const AlertRule({
    required this.id,
    required this.assetId,
    required this.type,
    required this.threshold,
    this.isActive = true,
    this.triggeredAt,
  });

  final String id;
  final String assetId;
  final AlertType type;
  final double threshold;
  final bool isActive;
  final DateTime? triggeredAt;

  bool wasTriggeredSince(DateTime since) =>
      triggeredAt != null && triggeredAt!.isAfter(since);

  AlertRule copyWith({bool? isActive, DateTime? triggeredAt}) => AlertRule(
    id: id,
    assetId: assetId,
    type: type,
    threshold: threshold,
    isActive: isActive ?? this.isActive,
    triggeredAt: triggeredAt ?? this.triggeredAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'assetId': assetId,
    'type': type.name,
    'threshold': threshold,
    'isActive': isActive,
    'triggeredAt': triggeredAt?.toIso8601String(),
  };

  static AlertRule fromJson(Map<String, dynamic> json) => AlertRule(
    id: json['id'] as String,
    assetId: json['assetId'] as String,
    type: AlertType.values.byName(json['type'] as String),
    threshold: (json['threshold'] as num).toDouble(),
    isActive: (json['isActive'] as bool?) ?? true,
    triggeredAt: json['triggeredAt'] == null
        ? null
        : DateTime.parse(json['triggeredAt'] as String),
  );

  /// Evaluates one rule against a quote. Pure function — fully testable.
  static bool isMet(
    AlertRule rule, {
    required double price,
    required double changePercent,
  }) {
    switch (rule.type) {
      case AlertType.priceAbove:
        return price >= rule.threshold;
      case AlertType.priceBelow:
        return price <= rule.threshold;
      case AlertType.percentUp:
        return changePercent >= rule.threshold;
      case AlertType.percentDown:
        return changePercent <= -rule.threshold.abs();
    }
  }
}
