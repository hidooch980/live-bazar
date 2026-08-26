import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/utils/fa_number.dart';
import '../core/utils/price_display.dart';
import '../domain/entities/price_quote.dart';
import '../features/detail/detail_screen.dart';
import '../state/app_providers.dart';

/// Compact row used across Home & Market screens.
///
/// Shows the LIVE price in Toman (converted via the real published
/// USD/IRR rate) with the USD value as secondary text.
class QuoteTile extends ConsumerWidget {
  const QuoteTile({
    super.key,
    required this.quote,
    this.onTap,
    this.isFavorite,
    this.onToggleFavorite,
  });

  final PriceQuote quote;
  final VoidCallback? onTap;
  final bool? isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Default tap behavior: open the detail screen (§26).
  static void openDetail(BuildContext context, PriceQuote quote) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(assetId: quote.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useToman = ref.watch(tomanModeProvider);
    final irr = irrQuoteOf(ref.watch(marketControllerProvider).snapshot);

    String primary;
    String? secondary;
    if (useToman) {
      final t = PriceDisplay.toman(quote, irr);
      if (t != null) {
        primary = '${PriceDisplay.tomanText(t)} ${PriceDisplay.tomanUnit}';
        secondary = '${quote.price.faPrice()} ${quote.currency}';
      } else {
        primary =
            '${quote.price.faPrice()} ${quote.unit.isNotEmpty ? quote.unit : quote.currency}';
      }
    } else {
      primary =
          '${quote.price.faPrice()} ${quote.unit.isNotEmpty ? quote.unit : quote.currency}';
    }

    final up = quote.changePercent >= 0;
    final color = up ? AppTheme.green : AppTheme.red;
    return Card(
      child: ListTile(
        onTap: onTap ?? () => openDetail(context, quote),
        title: Row(
          children: [
            if (onToggleFavorite != null && isFavorite != null)
              GestureDetector(
                onTap: onToggleFavorite,
                child: Icon(
                  isFavorite! ? Icons.star : Icons.star_border,
                  size: 20,
                  color: isFavorite!
                      ? AppTheme.gold
                      : Theme.of(context).hintColor,
                ),
              ),
            if (onToggleFavorite != null && isFavorite != null)
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                quote.nameFa,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            StatusBadge(status: quote.status),
            const SizedBox(width: 6),
            Text(
              quote.source,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(primary, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (secondary != null)
              Text(
                secondary,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).hintColor,
                ),
              ),
            if (quote.changePercent != 0)
              Text(
                '${up ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}٪'
                    .faString,
                style: TextStyle(color: color, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

/// Visual representation of [QuoteStatus] — never shows cached data as LIVE.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final QuoteStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      QuoteStatus.live => ('زنده', AppTheme.green),
      QuoteStatus.unchanged => ('بدون تغییر', Colors.grey),
      QuoteStatus.stale => ('قدیمی', Colors.orange),
      QuoteStatus.cached => ('کش‌شده', Colors.blueGrey),
      QuoteStatus.fallback => ('پشتیبان', Colors.indigo),
      QuoteStatus.dataConflict => ('تعارض داده', AppTheme.red),
      QuoteStatus.serverRequired => ('نیاز به سرور', Colors.brown),
      _ => ('ناموجود', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
