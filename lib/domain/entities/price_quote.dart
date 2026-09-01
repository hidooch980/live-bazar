import 'package:flutter/foundation.dart';

enum QuoteStatus {
  live,
  unchanged,

  /// We hold the newest value the source publishes, but the source has not
  /// published in a while — an Iranian market that closed at 20:00, or a
  /// thinly traded coin. Nothing is wrong with the app or the fetch, so
  /// this must not be dressed up as a failure.
  delayed,
  stale,
  cached,
  fallback,
  error,
  unknown,
  unavailable,
  dataConflict,
  serverRequired,
}

enum AssetCategory {
  currency,
  iranianCurrency,
  gold,
  coin,
  crypto,
  marketIndex,
  commodity,
  global,
}

enum AnomalyState { valid, suspicious, rejected }

extension QuoteStatusX on QuoteStatus {
  bool get isDisplayable =>
      this != QuoteStatus.error &&
      this != QuoteStatus.unavailable &&
      this != QuoteStatus.dataConflict;
}

/// Normalized, provider-agnostic market observation.
///
/// [price]/[buy]/[sell] are in the asset's native unit; [currency] names the
/// denomination (IRR, USD, ...). [timestamp] is ALWAYS the real provider
/// timestamp — never fabricated.
@immutable
class PriceQuote {
  const PriceQuote({
    required this.id,
    required this.symbol,
    required this.name,
    required this.nameFa,
    required this.category,
    required this.price,
    required this.currency,
    required this.unit,
    required this.timestamp,
    required this.source,
    required this.status,
    this.buy,
    this.sell,
    this.change = 0,
    this.changePercent = 0,
    this.confidence = 1.0,
    this.anomaly = AnomalyState.valid,
  });

  final String id;
  final String symbol;
  final String name;
  final String nameFa;
  final AssetCategory category;
  final double price;
  final double? buy;
  final double? sell;
  final double change;
  final double changePercent;
  final String unit;
  final String currency;
  final DateTime timestamp;
  final String source;
  final QuoteStatus status;
  final double confidence;
  final AnomalyState anomaly;

  bool get isStale =>
      DateTime.now().toUtc().difference(timestamp.toUtc()) >
      const Duration(minutes: 30);

  PriceQuote copyWith({
    double? price,
    double? buy,
    double? sell,
    double? change,
    double? changePercent,
    DateTime? timestamp,
    String? source,
    QuoteStatus? status,
    double? confidence,
    AnomalyState? anomaly,
  }) {
    return PriceQuote(
      id: id,
      symbol: symbol,
      name: name,
      nameFa: nameFa,
      category: category,
      price: price ?? this.price,
      buy: buy ?? this.buy,
      sell: sell ?? this.sell,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      unit: unit,
      currency: currency,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      anomaly: anomaly ?? this.anomaly,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'symbol': symbol,
    'name': name,
    'nameFa': nameFa,
    'category': category.name,
    'price': price,
    'buy': buy,
    'sell': sell,
    'change': change,
    'changePercent': changePercent,
    'unit': unit,
    'currency': currency,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'status': status.name,
    'confidence': confidence,
    'anomaly': anomaly.name,
  };

  static PriceQuote fromJson(Map<String, dynamic> json) => PriceQuote(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    nameFa: (json['nameFa'] as String?) ?? json['name'] as String,
    category: AssetCategory.values.byName(json['category'] as String),
    price: (json['price'] as num).toDouble(),
    buy: (json['buy'] as num?)?.toDouble(),
    sell: (json['sell'] as num?)?.toDouble(),
    change: (json['change'] as num? ?? 0).toDouble(),
    changePercent: (json['changePercent'] as num? ?? 0).toDouble(),
    unit: (json['unit'] as String?) ?? '',
    currency: (json['currency'] as String?) ?? '',
    timestamp: DateTime.parse(json['timestamp'] as String),
    source: (json['source'] as String?) ?? 'unknown',
    status: QuoteStatus.values.byName((json['status'] as String?) ?? 'unknown'),
    confidence: (json['confidence'] as num? ?? 1).toDouble(),
    anomaly: AnomalyState.values.byName(
      (json['anomaly'] as String?) ?? 'valid',
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceQuote &&
          other.id == id &&
          other.symbol == symbol &&
          other.price == price &&
          other.timestamp == timestamp &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, symbol, price, timestamp, status);
}
