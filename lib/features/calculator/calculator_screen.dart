import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../core/utils/price_display.dart';
import '../../domain/entities/price_quote.dart';
import '../../state/app_providers.dart';
import '../../widgets/asset_search_sheet.dart';

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
///
/// Below 0.0001 the decimals grow with the magnitude so at least four
/// significant digits survive: a fixed ten decimals printed 9.14e-10 as
/// «۰.۰۰۰۰۰۰۰۰۰۹» and anything under 5e-11 as all zeros.
String formatConversionResult(double v) {
  final abs = v.abs();
  final int fraction;
  if (abs >= 1000) {
    fraction = 0;
  } else if (abs >= 1) {
    fraction = 4;
  } else if (abs >= 0.0001 || abs == 0) {
    fraction = 8;
  } else {
    final magnitude = (math.log(abs) / math.ln10).floor();
    fraction = (3 - magnitude).clamp(10, 20);
  }
  return v.faPrice(fraction: fraction).faString;
}

/// Thousands separators a user may type or paste: ASCII comma, Arabic
/// comma «،» and the Arabic thousands mark «٬».
final _thousands = RegExp('[,،٬]');

/// Amount as a human types it: Persian or Arabic-Indic digits, thousands
/// separators, a Persian decimal mark, or a trailing/leading space.
///
/// Returns null for anything that is not a usable positive amount, so the
/// screen can say what is wrong instead of silently showing nothing.
///
/// A separator is only accepted where a thousands separator belongs.
/// Stripping it anywhere read a decimal comma — «1,5» — as fifteen.
double? parseAmountInput(String raw) {
  final normalized = toAsciiDigits(raw)
      .replaceAll('٫', '.')
      .replaceAll(RegExp(r'\s'), '');
  if (normalized.isEmpty) return null;
  final parts = normalized.split('.');
  if (parts.length > 2) return null;
  final whole = parts.first;
  if (whole.contains(_thousands) &&
      !RegExp(r'^\d{1,3}([,،٬]\d{3})+$').hasMatch(whole)) {
    return null;
  }
  final plain = parts.length == 2
      ? '${whole.replaceAll(_thousands, '')}.${parts[1]}'
      : whole.replaceAll(_thousands, '');
  if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(plain)) return null;
  final v = double.tryParse(plain);
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}

/// Assets the converter may offer, in catalog order: enabled, tradable,
/// expressible in Toman or USD, and carrying a quote the app would show.
///
/// A dataConflict / unavailable quote is still on the snapshot (the
/// anomaly gate keeps it, flagged) but must never be converted with; and
/// `fx_irr` is a rate, not a price, so it can never convert to anything.
List<String> calculatorAssetIds(Map<String, PriceQuote> quotes) => [
  for (final d in AssetCatalog.all.where((d) => d.enabled && d.tradable))
    if (quotes[d.id] case final q?)
      if (q.price > 0 &&
          q.status.isDisplayable &&
          PriceDisplay.unitOf(q) != QuoteUnit.none)
        d.id,
];

/// Keeps a remembered pair valid when a side drops out of [ids], without
/// ever collapsing both sides onto the same asset when another exists.
(String, String) resolveSelection(List<String> ids, String from, String to) {
  if (ids.isEmpty) return (from, to);
  String other(String avoid) =>
      ids.firstWhere((id) => id != avoid, orElse: () => ids.first);
  final fromOk = ids.contains(from);
  final toOk = ids.contains(to);
  if (fromOk && toOk) return (from, to);
  if (toOk) return (other(to), to);
  final f = fromOk ? from : ids.first;
  return (f, other(f));
}

/// The plain Toman entry: the unit itself, not a market quote. One Toman
/// is one Toman — nothing is estimated — and every other asset converts
/// to it through the same Toman-rate chain as the rest of the app.
const tomanAssetId = 'toman';

const tomanDefinition = AssetDefinition(
  id: tomanAssetId,
  symbol: 'IRT',
  name: 'Toman',
  nameFa: 'تومان',
  category: AssetCategory.iranianCurrency,
  unit: 'تومان',
  currency: 'IRR',
);

PriceQuote tomanQuote(DateTime nowUtc) => PriceQuote(
  id: tomanAssetId,
  symbol: 'IRT',
  name: 'Toman',
  nameFa: 'تومان',
  category: AssetCategory.iranianCurrency,
  price: 1,
  change: 0,
  changePercent: 0,
  unit: 'تومان',
  currency: 'IRR',
  timestamp: nowUtc,
  source: 'واحد پول',
  status: QuoteStatus.live,
);

/// Shown next to a result built from a price that is not current, so a
/// delayed, stale or previous-close figure never reads as live. Null when
/// the price is current.
@visibleForTesting
String? priceAgeNote(PriceQuote q, DateTime nowUtc) {
  if (q.id == tomanAssetId) return null;
  final age = faAgeLabel(nowUtc.difference(q.timestamp.toUtc()));
  return switch (q.status) {
    QuoteStatus.previousClose => '${q.nameFa}: قیمت پایانی جلسه قبل',
    QuoteStatus.delayed => '${q.nameFa}: آخرین قیمت منبع، $age',
    QuoteStatus.stale ||
    QuoteStatus.cached ||
    QuoteStatus.fallback => '${q.nameFa}: قیمت قدیمی، $age',
    _ when nowUtc.difference(q.timestamp.toUtc()) > const Duration(hours: 1) =>
      '${q.nameFa}: $age',
    _ => null,
  };
}

/// «1,5» is someone typing a decimal comma: say how to write it instead of
/// a bare «نامعتبر».
@visibleForTesting
String? amountInputHint(String raw) {
  if (parseAmountInput(raw) != null) return null;
  if (!raw.contains(_thousands)) return null;
  return 'برای اعشار از «٫» استفاده کن (مثلاً ۱٫۵)';
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
    final nowUtc = DateTime.now().toUtc();
    final market = <_Option>[
      for (final id in calculatorAssetIds(snap?.quotes ?? const {}))
        _Option(AssetCatalog.byId(id)!, snap!.quotes[id]!),
    ];
    final options = [
      if (market.isNotEmpty) _Option(tomanDefinition, tomanQuote(nowUtc)),
      ...market,
    ];
    final byId = {for (final o in options) o.def.id: o.quote};

    if (snap == null || market.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ماشین‌حساب')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              calculatorEmptyMessage(
                hasSnapshot: snap != null && snap.quotes.isNotEmpty,
                offline: state.isOffline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // A remembered selection can disappear from the snapshot (a source
    // dropped out). Fall back to something that exists rather than
    // rendering a picker with a value not in its item list, which throws —
    // and never onto the asset already on the other side.
    final (from0, to0) = resolveSelection(
      [for (final o in options) o.def.id],
      _from,
      _to,
    );
    _from = from0;
    _to = to0;

    final rate = tomanRateOf(snap);
    final from = byId[_from]!;
    final to = byId[_to]!;
    final amountText = _amountCtrl.text;
    final amount = parseAmountInput(amountText);
    final unitRatio = PriceDisplay.crossRate(from, to, rate);

    final String? error;
    if (amountText.trim().isEmpty) {
      error = 'مقدار را وارد کنید';
    } else if (amount == null) {
      error =
          amountInputHint(amountText) ??
          'مقدار نامعتبر است — یک عدد بزرگ‌تر از صفر وارد کنید';
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
              FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩.,٫،٬ ]')),
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
                              '${conversionUnitLabel(to)}',
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
                    for (final note in [
                      priceAgeNote(from, nowUtc),
                      if (_to != _from) priceAgeNote(to, nowUtc),
                    ].nonNulls) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              note,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// What the result is counted in: units of the target asset itself.
///
/// The result is a COUNT of [q] — «۹۹٫۹۵» free-market dollars for one gram
/// of gold — so it is never Toman, even when [q] is priced in Toman. A pair
/// symbol is cut to the unit actually counted ('USD/IRR-FM' → 'USD',
/// 'BTC/USD' → 'BTC').
@visibleForTesting
String conversionUnitLabel(PriceQuote q) =>
    q.id == tomanAssetId ? 'تومان' : q.symbol.split('/').first;

/// The no-options message. Data that ARRIVED but is all unusable (every
/// row rejected or unpriced) is not «در حال دریافت».
@visibleForTesting
String calculatorEmptyMessage({
  required bool hasSnapshot,
  required bool offline,
}) {
  if (hasSnapshot) {
    return 'داده بازار رسید، اما فعلاً هیچ قیمت معتبری برای تبدیل نیست — '
        'کمی بعد دوباره امتحان کن';
  }
  return offline
      ? 'آفلاین — داده معتبری برای تبدیل موجود نیست'
      : 'در حال دریافت داده بازار...';
}

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
            for (final q in [from, to])
              if (q.id != tomanAssetId)
                Text(
                  '${q.nameFa}: ${q.source} — '
                  '${q.status == QuoteStatus.previousClose ? 'قیمت پایانی' : faAgeLabel(now.difference(q.timestamp.toUtc()))}',
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

  AssetSearchOption get search => AssetSearchOption(
    id: def.id,
    nameFa: def.nameFa,
    symbol: def.symbol,
    name: def.name,
  );
}

/// Tap-to-open searchable picker.
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
        final picked = await showAssetSearchSheet(
          context,
          title: label,
          options: [for (final o in options) o.search],
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(selected.search.label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
