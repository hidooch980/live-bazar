import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../domain/entities/alert_rule.dart';
import '../../state/app_providers.dart';

/// PRICE ALERTS (§23): local rules evaluated while the app is running.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(alertsControllerProvider);
    final available = AssetCatalog.all
        .where((d) => d.enabled)
        .map((d) => (d.id, d.nameFa))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('هشدارهای قیمت')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref, available),
        icon: const Icon(Icons.add),
        label: const Text('هشدار جدید'),
      ),
      body: rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(height: 12),
                    const Text('هنوز هشداری نساخته‌اید'),
                  ],
                ),
              ),
            )
          : ListView(
              children: [
                for (final r in rules)
                  ListTile(
                    leading: Icon(_iconOf(r.type)),
                    title: Text(_title(r)),
                    subtitle: Text(r.isActive ? 'فعال' : 'غیرفعال'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: r.isActive,
                          onChanged: (_) => ref
                              .read(alertsControllerProvider.notifier)
                              .toggleActive(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(alertsControllerProvider.notifier)
                              .remove(r.id),
                        ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'هشدارها فقط وقتی اپلیکیشن در حال اجراست بررسی می‌شوند؛ تضمین بررسی ۵ ثانیه‌ای در پس‌زمینه وجود ندارد.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
    );
  }

  void _showCreateSheet(
    BuildContext context,
    WidgetRef ref,
    List<(String, String)> assets,
  ) {
    var assetId = assets.first.$1;
    var type = AlertType.priceAbove;
    final thresholdCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: assetId,
                items: [
                  for (final (id, name) in assets)
                    DropdownMenuItem(value: id, child: Text(name)),
                ],
                decoration: const InputDecoration(
                  labelText: 'دارایی',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setSheetState(() => assetId = v ?? assetId),
              ),
              const SizedBox(height: 12),
              SegmentedButton<AlertType>(
                segments: const [
                  ButtonSegment(
                    value: AlertType.priceAbove,
                    label: Text('بالاتر از'),
                  ),
                  ButtonSegment(
                    value: AlertType.priceBelow,
                    label: Text('پایین‌تر از'),
                  ),
                  ButtonSegment(
                    value: AlertType.percentUp,
                    label: Text('رشد ٪'),
                  ),
                  ButtonSegment(
                    value: AlertType.percentDown,
                    label: Text('افت ٪'),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (s) => setSheetState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thresholdCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'مقدار آستانه',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final threshold = double.tryParse(thresholdCtrl.text);
                  if (threshold == null) return;
                  ref
                      .read(alertsControllerProvider.notifier)
                      .create(assetId, type, threshold);
                  Navigator.of(ctx).pop();
                },
                child: const Text('ذخیره هشدار'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconOf(AlertType t) => switch (t) {
    AlertType.priceAbove => Icons.arrow_upward,
    AlertType.priceBelow => Icons.arrow_downward,
    AlertType.percentUp => Icons.trending_up,
    AlertType.percentDown => Icons.trending_down,
  };

  String _title(AlertRule r) {
    final asset = AssetCatalog.byId(r.assetId);
    final name = asset?.nameFa ?? r.assetId;
    final cond = switch (r.type) {
      AlertType.priceAbove => 'بالاتر از ${r.threshold.faPrice()}',
      AlertType.priceBelow => 'پایین‌تر از ${r.threshold.faPrice()}',
      AlertType.percentUp =>
        'رشد ≥ ${r.threshold.toStringAsFixed(1)}٪'.faString,
      AlertType.percentDown =>
        'افت ≥ ${r.threshold.abs().toStringAsFixed(1)}٪'.faString,
    };
    return '$name — $cond';
  }
}
