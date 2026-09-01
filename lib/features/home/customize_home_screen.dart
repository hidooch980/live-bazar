import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import 'home_layout.dart';

/// PERSONALIZATION («شخصی‌سازی خانه»): choose which blocks the dashboard
/// shows and in what order. Stored locally — nothing leaves the device.
class CustomizeHomeScreen extends ConsumerWidget {
  const CustomizeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);
    final controller = ref.read(homeLayoutProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شخصی‌سازی خانه'),
        actions: [
          TextButton.icon(
            onPressed: controller.reset,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('پیش‌فرض'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'با کلید کنار هر بخش آن را روشن یا خاموش کن، و با نگه‌داشتن دستگیره جابه‌جایش کن. '
              'ترتیب همین‌جا ترتیب صفحه خانه است.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: layout.order.length,
              onReorderItem: controller.reorder,
              itemBuilder: (context, index) {
                final section = layout.order[index];
                final visible = layout.isVisible(section);
                return Card(
                  key: ValueKey(section),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: SwitchListTile(
                    value: visible,
                    onChanged: (_) => controller.toggle(section),
                    secondary: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          _iconOf(section),
                          size: 18,
                          color: visible
                              ? AppTheme.gold
                              : Theme.of(context).hintColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          section.titleFa,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _describe(section),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconOf(HomeSection s) => switch (s) {
    HomeSection.pulse => Icons.monitor_heart_outlined,
    HomeSection.watchlist => Icons.star_outline,
    HomeSection.iranCurrency => Icons.attach_money,
    HomeSection.gold => Icons.workspace_premium_outlined,
    HomeSection.coin => Icons.monetization_on_outlined,
    HomeSection.crypto => Icons.currency_bitcoin,
    HomeSection.globalCurrency => Icons.public,
    HomeSection.bourse => Icons.show_chart,
    HomeSection.commodity => Icons.local_gas_station_outlined,
    HomeSection.diagnostics => Icons.health_and_safety_outlined,
  };

  static String _describe(HomeSection s) {
    final category = s.category;
    if (category != null) {
      final names = AssetCatalog.all
          .where((d) => d.enabled && d.category == category)
          .map((d) => d.nameFa)
          .take(4)
          .join('، ');
      return names.isEmpty ? 'دارایی فعالی ندارد' : names;
    }
    return switch (s) {
      HomeSection.pulse => 'صعودی/نزولی و بیشترین رشد و افت',
      HomeSection.watchlist => 'دارایی‌هایی که ستاره زده‌ای',
      HomeSection.diagnostics => 'وضعیت زنده هر منبع داده',
      _ => '',
    };
  }
}
