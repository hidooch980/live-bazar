import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../services/market_history_service.dart';
import '../../state/app_providers.dart';

/// A chart range, drawn either from the source's published daily table or
/// from observations this app accumulated locally (§19).
class _Range {
  const _Range(this.label, this.days, {this.intraday = const Duration()});

  final String label;

  /// Trading days to show from the daily table; 0 = everything published.
  final int days;

  /// Non-zero for intraday ranges served from local observations.
  final Duration intraday;

  bool get isDaily => intraday == const Duration();
}

/// CHARTS (§27).
///
/// Long ranges use the REAL published daily table from the source; short
/// ranges use the locally accumulated observations (§19). Neither path
/// ever fabricates a point, and the footer always says which one is on
/// screen and how many real records it holds.
class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  String? _assetId;
  _Range _range = _daily.first;

  static const _intraday = <_Range>[
    _Range('۱ ساعت', 0, intraday: Duration(hours: 1)),
    _Range('۶ ساعت', 0, intraday: Duration(hours: 6)),
    _Range('۱ روز', 0, intraday: Duration(days: 1)),
  ];

  static const _daily = <_Range>[
    _Range('۱ ماه', 30),
    _Range('۳ ماه', 90),
    _Range('۱ سال', 365),
    _Range('همه', 0),
  ];

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketControllerProvider);
    final quotes = market.snapshot?.quotes ?? const {};

    final options = [
      for (final d in AssetCatalog.all.where((d) => d.enabled))
        if (quotes.containsKey(d.id)) (d.id, d.nameFa),
    ];
    _assetId ??= options.isNotEmpty ? options.first.$1 : null;
    final assetId = _assetId;
    final hasDaily =
        assetId != null && MarketHistoryService.hasHistory(assetId);

    // An asset with no published table can only offer intraday ranges.
    if (!hasDaily && _range.isDaily) _range = _intraday.first;

    return Scaffold(
      appBar: AppBar(title: const Text('چارت')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              initialValue: assetId,
              items: [
                for (final (id, name) in options)
                  DropdownMenuItem(value: id, child: Text(name)),
              ],
              decoration: const InputDecoration(
                labelText: 'دارایی',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _assetId = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final r in [..._intraday, if (hasDaily) ..._daily])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: _range.label == r.label,
                      onSelected: (_) => setState(() => _range = r),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: assetId == null
                ? _empty(context, daily: false)
                : _range.isDaily
                ? _dailyChart(context, assetId)
                : _intradayChart(context, assetId),
          ),
        ],
      ),
    );
  }

  // ---- daily (published source table) --------------------------------
  Widget _dailyChart(BuildContext context, String assetId) {
    return FutureBuilder<List<DailyCandle>>(
      future: ref.read(marketHistoryProvider).daily(assetId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          );
        }
        final all = snap.data ?? const <DailyCandle>[];
        final candles = _range.days == 0 || _range.days >= all.length
            ? all
            : all.sublist(all.length - _range.days);
        if (candles.length < 2) return _empty(context, daily: true);

        final closes = [for (final c in candles) c.close];
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LineChart(_chart(closes)),
              ),
            ),
            _footer(
              context,
              '${candles.length.faDigits} روز معاملاتی واقعی از منبع'
              ' — ${candles.first.jalali} تا ${candles.last.jalali}',
            ),
          ],
        );
      },
    );
  }

  // ---- intraday (locally accumulated observations) --------------------
  Widget _intradayChart(BuildContext context, String assetId) {
    final series = ref
        .read(historyProvider)
        .series(assetId, range: _range.intraday)
        .toList();
    if (series.length < 2) return _empty(context, daily: false);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(_chart([for (final p in series) p.p])),
          ),
        ),
        _footer(
          context,
          '${series.length.faDigits} نقطه واقعی ثبت‌شده محلی — بدون داده ساختگی',
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
    ),
  );

  Widget _empty(BuildContext context, {required bool daily}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          const Text(
            'داده کافی برای این بازه موجود نیست',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            daily
                ? 'تاریخچه روزانه این دارایی از منبع در دسترس نیست. هیچ تاریخچه ساختگی نمایش داده نمی‌شود.'
                : 'با باز نگه‌داشتن اپلیکیشن، داده‌های واقعی به‌صورت محلی انباشته می‌شوند. هیچ تاریخچه ساختگی نمایش داده نمی‌شود.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    ),
  );

  LineChartData _chart(List<double> values) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final lineColor = values.last >= values.first
        ? AppTheme.green
        : AppTheme.red;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo).abs() * 0.05;

    return LineChartData(
      minY: lo - (pad == 0 ? lo.abs() * 0.001 : pad),
      maxY: hi + (pad == 0 ? hi.abs() * 0.001 : pad),
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 2,
          color: lineColor,
          dotData: const FlDotData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(
                s.y >= 1000 ? s.y.faPrice() : s.y.toStringAsFixed(2).faString,
                TextStyle(color: lineColor, fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }
}
