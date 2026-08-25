import '../data/cache/local_state_store.dart';
import '../domain/entities/alert_rule.dart';

/// LOCAL price alerts (§23). Evaluated while the app is running;
/// delivered via Android local notifications. No backend, and NO guarantee
/// of 5-second background checks — the UI must say so honestly.
class AlertService {
  static const _key = 'alert_rules';

  final KeyValueStore store;
  List<AlertRule> _rules = [];

  /// One-shot cooldown: a rule that fired within this window will not
  /// re-fire (prevents notification storms during every 5s cycle).
  static const rearmWindow = Duration(minutes: 30);

  AlertService(this.store);

  Future<void> load() async {
    _rules = decodeList(await store.getString(_key))
        .map(AlertRule.fromJson)
        .toList();
  }

  List<AlertRule> get rules => List.unmodifiable(_rules);

  List<AlertRule> activeFor(String assetId) => _rules
      .where((r) => r.assetId == assetId && r.isActive)
      .toList(growable: false);

  Future<AlertRule> create({
    required String assetId,
    required AlertType type,
    required double threshold,
  }) async {
    final rule = AlertRule(
      id: 'al-${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      type: type,
      threshold: threshold,
    );
    _rules.add(rule);
    await _persist();
    return rule;
  }

  Future<void> setActive(String id, bool active) async {
    _replace(_rules.firstWhere((r) => r.id == id).copyWith(isActive: active));
    await _persist();
  }

  Future<void> remove(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _persist();
  }

  void _replace(AlertRule updated) {
    final i = _rules.indexWhere((r) => r.id == updated.id);
    if (i >= 0) _rules[i] = updated;
  }

  /// Evaluates all ACTIVE rules against [quotes] (assetId -> quote values).
  ///
  /// Returns the rules that FIRED in this evaluation; marks them triggered
  /// with a re-arm cooldown.
  Future<List<AlertRule>> evaluate({
    required Map<String, ({double price, double changePercent})> quotes,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now().toUtc();
    final fired = <AlertRule>[];
    for (final rule in _rules.where((r) => r.isActive)) {
      final q = quotes[rule.assetId];
      if (q == null) continue;
      if (rule.triggeredAt != null &&
          t.difference(rule.triggeredAt!) < rearmWindow) {
        continue;
      }
      if (AlertRule.isMet(
        rule,
        price: q.price,
        changePercent: q.changePercent,
      )) {
        _replace(rule.copyWith(triggeredAt: t));
        fired.add(rule);
      }
    }
    if (fired.isNotEmpty) await _persist();
    return fired;
  }

  Future<void> _persist() =>
      store.setString(_key, encodeList(_rules.map((r) => r.toJson()).toList()));
}
