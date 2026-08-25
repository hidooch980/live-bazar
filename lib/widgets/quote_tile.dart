import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/utils/fa_number.dart';
import '../domain/entities/price_quote.dart';

/// Compact row used across Home & Market screens.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote, this.onTap});

  final PriceQuote quote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final up = quote.changePercent >= 0;
    final color = up ? AppTheme.green : AppTheme.red;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          quote.nameFa,
          style: const TextStyle(fontWeight: FontWeight.w700),
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
            Text(
              '${quote.price.faPrice()} ${quote.unit.isNotEmpty ? quote.unit : quote.currency}',
              style: const TextStyle(fontWeight: FontWeight.w800),
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
