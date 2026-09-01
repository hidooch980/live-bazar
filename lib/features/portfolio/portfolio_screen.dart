import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../core/utils/price_display.dart';
import '../../state/app_providers.dart';

/// PORTFOLIO (§24): local-only holdings valued against latest VALID quotes.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketControllerProvider);
    final holdings = ref.watch(portfolioControllerProvider);
    final portfolio = ref.read(portfolioProvider);

    final valuation = portfolio.value(market.snapshot?.quotes ?? const {});
    final useToman = ref.watch(tomanModeProvider);
    final rate = tomanRateOf(market.snapshot);

    String totalText;
    String unitText;
    if (useToman && rate != null) {
      final t = valuation.totalValue * rate.tomanPerUsd;
      totalText = PriceDisplay.tomanText(t);
      unitText = PriceDisplay.tomanUnit;
    } else {
      totalText = valuation.totalValue.toStringAsFixed(2).faString;
      unitText = 'دلار';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('پورتفولیو من')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('ارزش کل ($unitText)'),
                  const SizedBox(height: 8),
                  Text(
                    totalText,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (valuation.dailyChange != 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${valuation.dailyChange >= 0 ? '+' : ''}'
                              '${valuation.dailyChange.toStringAsFixed(2)} دلار روزانه'
                          .faString,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: valuation.dailyChange >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'افزودن/ویرایش دارایی',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final def in AssetCatalog.all.where(
            (d) => d.enabled && d.tradable,
          ))
            _HoldingEditor(defId: def.id, nameFa: def.nameFa),
          const SizedBox(height: 16),
          if (holdings.isEmpty)
            const Center(child: Text('دارایی‌ای ثبت نشده است')),
        ],
      ),
    );
  }
}

class _HoldingEditor extends ConsumerStatefulWidget {
  const _HoldingEditor({required this.defId, required this.nameFa});

  final String defId;
  final String nameFa;

  @override
  ConsumerState<_HoldingEditor> createState() => _HoldingEditorState();
}

class _HoldingEditorState extends ConsumerState<_HoldingEditor> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final current = ref
        .read(portfolioProvider)
        .holdings
        .where((h) => h.assetId == widget.defId)
        .map((h) => h.quantity)
        .firstWhere((q) => true, orElse: () => 0);
    _ctrl = TextEditingController(text: current == 0 ? '' : '$current');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.nameFa),
      subtitle: const Text('مقدار خود را وارد کنید'),
      trailing: SizedBox(
        width: 120,
        child: TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => ref
              .read(portfolioControllerProvider.notifier)
              .setQuantity(widget.defId, double.tryParse(v) ?? 0),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
