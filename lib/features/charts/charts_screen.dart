import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../services/historical_snapshot_service.dart';
import '../../state/app_providers.dart';

/// CHARTS (§27) built ONLY from locally accumulated REAL observations (§19).
class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  String? _assetId;
  Duration _range = const Duration(hours: 1);

  static const _ranges = <(Duration, String)>[
    (Duration(hours: 1), '۱س'),
    (Duration(hours: 6), '۶س'),
    (Duration(days: 1), '۱ر'),
    (Duration(days: 7), '۱ه'),
    (Duration(days: 30), '۱م'),
  ];

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketControllerProvider);
    final history = ref.read(historyProvider);
    final quotes = market.snapshot?.quotes ?? const {};

    final options = [
      for (final d in AssetCatalog.all.where((d) => d.enabled))
        if (quotes.containsKey(d.id)) (d.id, d.nameFa),
    ];
    _assetId ??= options.isNotEmpty ? options.first.$1 : null;

    final series = _assetId == null
        ? const <PricePoint>[]
        : history.series(_assetId!, range: _range).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('چارت')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _assetId,
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
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (d, label) in _ranges)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _range == d,
                      onSelected: (_) => setState(() => _range = d),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: series.length < 2
                ? _empty(context)
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: LineChart(_chart(series)),
                  ),
          ),
          if (series.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${series.length.faDigits} نقطه واقعی ثبت‌شده محلی — بدون داده ساختگی',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
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
            'با بازه نگه‌داشتن اپلیکیشن، داده‌های واقعی به‌صورت محلی انباشته می‌شوند. هیچ تاریخچه ساختگی نمایش داده نمی‌شود.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    ),
  );

  LineChartData _chart(List<PricePoint> series) {
    final spots = [
      for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].p),
    ];
    final first = series.first.p;
    final last = series.last.p;
    final lineColor = last >= first ? AppTheme.green : AppTheme.red;

    return LineChartData(
      minY: spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.999,
      maxY: spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.001,
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
                s.y.toStringAsFixed(4).faString,
                TextStyle(color: lineColor, fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }
}
