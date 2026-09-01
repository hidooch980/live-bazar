import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../core/utils/price_display.dart';
import '../../state/app_providers.dart';

/// CALCULATOR (§25): converts between enabled assets using the latest
/// VALID market data only.
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

/// Enough decimals to stay meaningful across nine orders of magnitude:
/// one coin is ~1035 dollars, one dollar is ~0.00097 coins.
String _formatResult(double v) {
  final abs = v.abs();
  final fraction = abs >= 1000
      ? 0
      : abs >= 1
      ? 4
      : abs >= 0.0001
      ? 8
      : 10;
  return v.faPrice(fraction: fraction).faString;
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  String _from = 'fx_usd';
  String _to = 'fx_eur';
  final _amountCtrl = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketControllerProvider);
    final snap = state.snapshot;
    final options = <(String, String)>[
      for (final d in AssetCatalog.all.where((d) => d.enabled && d.tradable))
        if (snap?.quotes[d.id] != null) (d.id, '${d.nameFa} (${d.symbol})'),
    ];

    double? result;
    if (snap != null) {
      final f = snap.quotes[_from];
      final t = snap.quotes[_to];
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
      if (f != null && t != null && amount != null) {
        // The two sides are NOT in the same unit: fx_* and crypto are
        // quoted in USD, everything from the Iranian market in Toman.
        // Dividing the raw prices asked what 1.0 USD is in units of
        // 214,000 Toman and answered 0.0000. Normalize both to Toman
        // first — the same real rate the rest of the app displays with.
        final rate = tomanRateOf(snap);
        final fromToman = PriceDisplay.toman(f, rate);
        final toToman = PriceDisplay.toman(t, rate);
        if (fromToman != null && toToman != null && toToman > 0) {
          result = amount * (fromToman / toToman);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ماشین‌حساب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              for (final (id, label) in options.take(6))
                ButtonSegment(
                  value: id,
                  label: Text(label, overflow: TextOverflow.ellipsis),
                ),
            ],
            showSelectedIcon: false,
            selected: {_from},
            onSelectionChanged: (s) => setState(() => _from = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مقدار',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Icon(
            Icons.swap_vert,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _to,
            items: [
              for (final (id, label) in options)
                DropdownMenuItem(value: id, child: Text(label)),
            ],
            decoration: const InputDecoration(
              labelText: 'به',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _to = v ?? _to),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text('نتیجه'),
                  const SizedBox(height: 8),
                  Text(
                    result == null
                        ? 'داده معتبر موجود نیست'
                        : _formatResult(result),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
