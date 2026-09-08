import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../core/utils/price_display.dart';
import '../../domain/entities/price_quote.dart';
import '../../state/app_providers.dart';

/// CALCULATOR (§25): converts between enabled assets using the latest
/// VALID market data only.
///
/// Every asset the snapshot carries is selectable through a searchable
/// picker — the old six-item SegmentedButton could not reach the other
/// eighty rows, so most pairs were simply unreachable.
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

/// Enough decimals to stay meaningful across nine orders of magnitude:
/// one coin is ~1035 dollars, one dollar is ~0.00097 coins.
String formatConversionResult(double v) {
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

/// Amount as a human types it: Persian or Arabic-Indic digits, thousands
/// separators, a Persian decimal mark, or a trailing/leading space.
///
/// Returns null for anything that is not a usable positive amount, so the
/// screen can say what is wrong instead of silently showing nothing.
double? parseAmountInput(String raw) {
  final normalized = toAsciiDigits(raw)
      .replaceAll('٫', '.')
      .replaceAll('،', '')
      .replaceAll(',', '')
      .replaceAll(RegExp(r'\s'), '');
  if (normalized.isEmpty) return null;
  final v = double.tryParse(normalized);
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  String _from = 'ir_usd';
  String _to = 'gold_18k';
  final _amountCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketControllerProvider);
    final snap = state.snapshot;
    final options = <_Option>[
      for (final d in AssetCatalog.all.where((d) => d.enabled && d.tradable))
        if (snap?.quotes[d.id] != null) _Option(d, snap!.quotes[d.id]!),
    ];

    if (snap == null || options.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ماشین‌حساب')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.isOffline
                  ? 'آفلاین — داده معتبری برای تبدیل موجود نیست'
                  : 'در حال دریافت داده بازار...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // A remembered selection can disappear from the snapshot (a source
    // dropped out). Fall back to something that exists rather than
    // rendering a dropdown with a value not in its item list, which throws.
    final ids = {for (final o in options) o.def.id};
    if (!ids.contains(_from)) _from = options.first.def.id;
    if (!ids.contains(_to)) {
      _to = options
          .firstWhere((o) => o.def.id != _from, orElse: () => options.first)
          .def
          .id;
    }

    final rate = tomanRateOf(snap);
    final from = snap.quotes[_from]!;
    final to = snap.quotes[_to]!;
    final amountText = _amountCtrl.text;
    final amount = parseAmountInput(amountText);
    final unitRatio = PriceDisplay.crossRate(from, to, rate);

    final String? error;
    if (amountText.trim().isEmpty) {
      error = 'مقدار را وارد کنید';
    } else if (amount == null) {
      error = 'مقدار نامعتبر است — یک عدد بزرگ‌تر از صفر وارد کنید';
    } else if (_from == _to) {
      error = null;
    } else if (unitRatio == null) {
      error = rate == null
          ? 'نرخ دلار بازار هنوز دریافت نشده — تبدیل این جفت ممکن نیست'
          : 'این دو دارایی با داده فعلی قابل تبدیل نیستند';
    } else {
      error = null;
    }

    final result = (amount != null && unitRatio != null)
        ? amount * unitRatio
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('ماشین‌حساب')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _AssetPickerField(
            label: 'از',
            options: options,
            selectedId: _from,
            onChanged: (id) => setState(() => _from = id),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩.,٫، ]')),
            ],
            decoration: InputDecoration(
              labelText: 'مقدار',
              border: const OutlineInputBorder(),
              errorText: error,
              suffixIcon: _amountCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'پاک کردن',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_amountCtrl.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final q in const [1, 10, 100, 1000])
                ActionChip(
                  label: Text(q.faDigits),
                  onPressed: () => setState(() {
                    _amountCtrl.text = '$q';
                    _amountCtrl.selection = TextSelection.collapsed(
                      offset: _amountCtrl.text.length,
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: IconButton.filledTonal(
              tooltip: 'جابه‌جایی',
              icon: const Icon(Icons.swap_vert),
              onPressed: () => setState(() {
                final f = _from;
                _from = _to;
                _to = f;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _AssetPickerField(
            label: 'به',
            options: options,
            selectedId: _to,
            onChanged: (id) => setState(() => _to = id),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text('نتیجه'),
                  const SizedBox(height: 8),
                  Text(
                    result == null
                        ? '—'
                        : '${formatConversionResult(result)} '
                              '${_unitLabel(to)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      to.nameFa,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (unitRatio != null)
            _DetailCard(from: from, to: to, unitRatio: unitRatio, rate: rate),
        ],
      ),
    );
  }
}

/// What the result is counted in: Toman for a free-market currency row,
/// otherwise units of the asset itself.
String _unitLabel(PriceQuote q) =>
    PriceDisplay.unitOf(q) == QuoteUnit.toman &&
        q.category == AssetCategory.iranianCurrency
    ? 'تومان'
    : q.symbol;

/// Where the numbers came from — a converted figure with no provenance is
/// exactly what this app promises never to show.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.from,
    required this.to,
    required this.unitRatio,
    required this.rate,
  });

  final PriceQuote from;
  final PriceQuote to;
  final double unitRatio;
  final TomanRate? rate;

  @override
  Widget build(BuildContext context) {
    final hint = TextStyle(fontSize: 12, color: Theme.of(context).hintColor);
    final now = DateTime.now().toUtc();
    final mixedUnits = PriceDisplay.unitOf(from) != PriceDisplay.unitOf(to);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${1.faDigits} ${from.nameFa} = '
              '${formatConversionResult(unitRatio)} ${to.nameFa}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${from.nameFa}: ${from.source} — '
              '${faAgeLabel(now.difference(from.timestamp.toUtc()))}',
              style: hint,
            ),
            Text(
              '${to.nameFa}: ${to.source} — '
              '${faAgeLabel(now.difference(to.timestamp.toUtc()))}',
              style: hint,
            ),
            if (mixedUnits && rate != null) ...[
              const SizedBox(height: 6),
              Text(
                'نرخ تبدیل دلار: ${PriceDisplay.tomanText(rate!.tomanPerUsd)} '
                'تومان (${rate!.labelFa})',
                style: hint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option {
  const _Option(this.def, this.quote);

  final AssetDefinition def;
  final PriceQuote quote;

  String get label => '${def.nameFa} (${def.symbol})';

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = toAsciiDigits(query).toLowerCase();
    return def.nameFa.contains(query) ||
        def.name.toLowerCase().contains(q) ||
        def.symbol.toLowerCase().contains(q) ||
        def.id.contains(q);
  }
}

/// Tap-to-open searchable picker. A dropdown with ninety Persian labels is
/// unusable on a phone; a search sheet finds «روپیه» in two keystrokes.
class _AssetPickerField extends StatelessWidget {
  const _AssetPickerField({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final List<_Option> options;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere((o) => o.def.id == selectedId);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _AssetSearchSheet(title: label, options: options),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(selected.label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _AssetSearchSheet extends StatefulWidget {
  const _AssetSearchSheet({required this.title, required this.options});

  final String title;
  final List<_Option> options;

  @override
  State<_AssetSearchSheet> createState() => _AssetSearchSheetState();
}

class _AssetSearchSheetState extends State<_AssetSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.options.where((o) => o.matches(_query)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '${widget.title} — جست‌وجو',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('موردی پیدا نشد'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final o = matches[i];
                        return ListTile(
                          title: Text(o.def.nameFa),
                          subtitle: Text(o.def.symbol),
                          onTap: () => Navigator.of(context).pop(o.def.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
