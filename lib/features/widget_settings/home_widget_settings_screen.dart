import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../domain/entities/price_quote.dart';
import '../../services/home_widget_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/asset_search_sheet.dart';
import 'home_widget_config_controller.dart';
import 'widget_preview.dart';

/// «ویجت صفحه اصلی»: what the widget shows, in what order, and how it
/// refreshes while the app is closed.
class HomeWidgetSettingsScreen extends ConsumerStatefulWidget {
  const HomeWidgetSettingsScreen({super.key});

  @override
  ConsumerState<HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState
    extends ConsumerState<HomeWidgetSettingsScreen> {
  WidgetPreviewSize _previewSize = WidgetPreviewSize.medium;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(homeWidgetConfigProvider);
    final ctrl = ref.read(homeWidgetConfigProvider.notifier);
    final hint = TextStyle(fontSize: 12, color: Theme.of(context).hintColor);

    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ویجت صفحه اصلی')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ویجت صفحه اصلی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'دارایی‌ها و نحوه به‌روزرسانی ویجت‌ها را انتخاب کنید.',
            style: hint,
          ),
          const SizedBox(height: 12),
          _PreviewCard(
            ids: config.ids,
            live: config.mode == WidgetRefreshMode.live,
            size: _previewSize,
            onSize: (s) => setState(() => _previewSize = s),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              key: const ValueKey('widget-enabled'),
              secondary: const Icon(Icons.widgets_outlined),
              title: const Text('نمایش قیمت‌ها در ویجت'),
              subtitle: Text(config.enabled ? 'روشن' : 'خاموش'),
              value: config.enabled,
              onChanged: ctrl.setEnabled,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'با خاموش کردن، ویجت فقط نام اپ را نشان می‌دهد و درخواستی در '
              'پس‌زمینه ارسال نمی‌شود. ویجت را با فشار طولانی روی صفحه اصلی '
              'گوشی اضافه کنید (کوچک، متوسط یا بزرگ).',
              style: hint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'دارایی‌های ویجت',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: ctrl.move,
                  children: [
                    for (var i = 0; i < config.ids.length; i++)
                      _AssetRow(
                        key: ValueKey(config.ids[i]),
                        index: i,
                        id: config.ids[i],
                        canRemove: config.ids.length > 1,
                        onRemove: () => ctrl.remove(config.ids[i]),
                      ),
                  ],
                ),
                if (config.ids.length < HomeWidgetService.maxAssets)
                  TextButton.icon(
                    key: const ValueKey('widget-add'),
                    icon: const Icon(Icons.add),
                    label: Text(
                      'افزودن (حداکثر ${HomeWidgetService.maxAssets.faDigits})',
                    ),
                    onPressed: () async {
                      final picked = await showAssetSearchSheet(
                        context,
                        title: 'افزودن به ویجت',
                        options: [
                          for (final d in AssetCatalog.all)
                            if (d.enabled &&
                                d.id != 'fx_irr' &&
                                !config.ids.contains(d.id))
                              AssetSearchOption(
                                id: d.id,
                                nameFa: d.nameFa,
                                symbol: d.symbol,
                                name: d.name,
                              ),
                        ],
                      );
                      if (picked != null) await ctrl.add(picked);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'برای تغییر ترتیب، دستگیره ☰ را بکشید. ویجت کوچک اولی، متوسط '
              'سه‌تای اول و بزرگ هر شش دارایی را نشان می‌دهد. ظرفیت پر است '
              '(${config.ids.length.faDigits} از ${HomeWidgetService.maxAssets.faDigits}).',
              style: hint,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: ctrl.resetIds,
              child: const Text('بازگشت به پیش‌فرض (دلار، طلای ۱۸، امامی)'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نحوه به‌روزرسانی وقتی اپ بسته است',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<WidgetRefreshMode>(
              groupValue: config.mode,
              onChanged: (m) {
                if (m != null) ctrl.setMode(m);
              },
              child: const Column(
                children: [
                  RadioListTile<WidgetRefreshMode>(
                    key: ValueKey('mode-low'),
                    value: WidgetRefreshMode.lowPower,
                    secondary: Icon(Icons.battery_full, color: Colors.green),
                    title: Text('کم‌مصرف (پیش‌فرض)'),
                    subtitle: Text('با روشن شدن صفحه و هر ۱۵ دقیقه'),
                  ),
                  Divider(height: 1),
                  RadioListTile<WidgetRefreshMode>(
                    key: ValueKey('mode-live'),
                    value: WidgetRefreshMode.live,
                    secondary: Icon(Icons.bolt, color: AppTheme.gold),
                    title: Text('زنده'),
                    subtitle: Text(
                      'هر چند ثانیه با اعلان دائمی (مصرف باتری بیشتر)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'وقتی اپ باز است، ویجت همیشه هر چند ثانیه به‌روز می‌شود. حالت '
              '«زنده» فقط وقتی صفحه روشن است درخواست می‌فرستد، هر منبع را '
              'زودتر از سقف مجاز خودش صدا نمی‌زند، از اعلان قابل توقف است و '
              'ممکن است روی برخی گوشی‌ها (شیائومی، سامسونگ) توسط سیستم بسته '
              'شود. ساعت روی ویجت همیشه زمان واقعی قدیمی‌ترین قیمت است.',
              style: hint,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    super.key,
    required this.index,
    required this.id,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final String id;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final def = AssetCatalog.byId(id);
    final (glyph, tone) = HomeWidgetService.iconFor(
      id,
      def?.category ?? AssetCategory.currency,
    );
    final sizes = WidgetPreviewSize.showing(index);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'حذف',
              icon: Icon(
                Icons.remove_circle,
                color: canRemove ? Colors.redAccent : Colors.grey,
              ),
              onPressed: canRemove ? onRemove : null,
            ),
            Container(
              width: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                (index + 1).faDigits,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: toneColors[tone]!),
              ),
              child: Text(
                glyph,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamilyFallback: symbolFallback,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          def?.nameFa ?? id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          sizes.isEmpty
              ? 'در هیچ اندازه‌ای'
              : sizes.map((s) => s.labelFa).join('، '),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.drag_handle),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({
    required this.ids,
    required this.live,
    required this.size,
    required this.onSize,
  });

  final List<String> ids;
  final bool live;
  final WidgetPreviewSize size;
  final ValueChanged<WidgetPreviewSize> onSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(marketControllerProvider).snapshot;
    final history = ref.watch(historyProvider);
    final quotes = snap?.quotes ?? const {};
    final series = {
      for (final id in ids)
        id: HomeWidgetService.seriesFromPoints(
          history
              .series(id, range: const Duration(hours: 24))
              .map((p) => (p.t, p.p)),
        ),
    };
    final rows = HomeWidgetService.rows(quotes, ids, series: series);
    final updated = rows.isEmpty
        ? 'بدون داده'
        : HomeWidgetService.timeLine([for (final r in rows) quotes[r.id]!]);
    final height = switch (size) {
      WidgetPreviewSize.small => 170.0,
      WidgetPreviewSize.medium => 170.0,
      WidgetPreviewSize.large => 380.0,
    };
    return WallpaperBackdrop(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'پیش‌نمایش — ویجت ${size.labelFa}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: size == WidgetPreviewSize.small ? 170 : 360,
              height: height,
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        'هنوز قیمت معتبری برای پیش‌نمایش نیست',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : WidgetPreview(
                      rows: rows,
                      size: size,
                      updated: updated,
                      live: live,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: SegmentedButton<WidgetPreviewSize>(
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white,
                selectedForegroundColor: Colors.black87,
                selectedBackgroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              segments: [
                for (final s in WidgetPreviewSize.values)
                  ButtonSegment(value: s, label: Text(s.labelFa)),
              ],
              selected: {size},
              onSelectionChanged: (s) => onSize(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
