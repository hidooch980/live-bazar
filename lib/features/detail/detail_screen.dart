import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../core/utils/price_display.dart';
import '../../domain/entities/price_quote.dart';
import '../../services/historical_snapshot_service.dart';
import '../../services/market_score_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/quote_tile.dart';

/// PRICE DETAIL (§26): everything we really know about ONE asset.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = AssetCatalog.byId(assetId);
    final market = ref.watch(marketControllerProvider);
    final quote = market.snapshot?.quotes[assetId];
    final history = ref.watch(historyProvider);
    final isFav = ref.watch(watchlistProvider).contains(assetId);

    return Scaffold(
      appBar: AppBar(
        title: Text(def?.nameFa ?? assetId),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? AppTheme.gold : null,
            ),
            onPressed: () =>
                ref.read(watchlistControllerProvider.notifier).toggle(assetId),
          ),
        ],
      ),
      body: quote == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 56,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      def?.enabled ?? false
                          ? 'هنوز داده‌ای برای این دارایی دریافت نشده است'
                          : 'این دارایی در نسخه اول غیرفعال است (منبع تأییدشده ندارد)',
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _PriceHeader(
                  quote: quote,
                  useToman: ref.watch(tomanModeProvider),
                  rate: tomanRateOf(market.snapshot),
                ),
                const SizedBox(height: 8),
                _ScoreCard(quote: quote),
                const SizedBox(height: 8),
                _HistoryCard(history: history, assetId: assetId),
                const SizedBox(height: 8),
                _FactsCard(quote: quote),
              ],
            ),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({
    required this.quote,
    required this.useToman,
    required this.rate,
  });

  final PriceQuote quote;
  final bool useToman;
  final TomanRate? rate;

  @override
  Widget build(BuildContext context) {
    final up = quote.changePercent >= 0;
    final color = up ? AppTheme.green : AppTheme.red;
    final local = quote.timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0').faString;
    final mm = local.minute.toString().padLeft(2, '0').faString;

    String primary;
    String? secondary;
    final t = useToman ? PriceDisplay.toman(quote, rate) : null;
    if (t != null) {
      primary = '${PriceDisplay.tomanText(t)} ${PriceDisplay.tomanUnit}';
      secondary = '${quote.price.faPrice()} ${quote.currency}';
    } else {
      primary =
          '${quote.price.faPrice()} ${quote.unit.isNotEmpty ? quote.unit : quote.currency}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${quote.nameFa} — ${quote.symbol}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusBadge(status: quote.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              primary,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            if (secondary != null) ...[
              const SizedBox(height: 4),
              Text(
                secondary,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${up ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}٪ '
                      '(${quote.change >= 0 ? '+' : ''}'
                      '${quote.change.faPrice()})'
                  .faString,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'زمان واقعی منبع: $hh:$mm — ${quote.source}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.quote});

  final PriceQuote quote;

  @override
  Widget build(BuildContext context) {
    final score = MarketScore.compute(quote);
    final trendLabel = switch (score.trend) {
      ScoreTrend.up => 'صعودی',
      ScoreTrend.down => 'نزولی',
      ScoreTrend.flat => 'خنثی',
    };
    final volLabel = switch (score.volatility) {
      Volatility.low => 'کم',
      Volatility.medium => 'متوسط',
      Volatility.high => 'زیاد',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'امتیاز بازار',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _cell('${score.value.faDigits}/۱۰۰', 'امتیاز'),
                _cell(trendLabel, 'روند'),
                _cell(volLabel, 'نوسان'),
                _cell(
                  '${(score.confidence * 100).toStringAsFixed(0)}٪'.faString,
                  'اطمینان',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'فقط اطلاعات آماری است — توصیه خرید/فروش/سرمایه‌گذاری نیست.',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.assetId});

  final HistoricalSnapshotService history;
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final series = history.series(assetId);
    if (series.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'چارت: داده تاریخی محلی هنوز کافی نیست — با کارکرد اپلیکیشن انباشته می‌شود. هیچ داده ساختگی نمایش داده نمی‌شود.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
        ),
      );
    }
    final prices = series.map((p) => p.p).toList();
    final high = prices.reduce((a, b) => a > b ? a : b);
    final low = prices.reduce((a, b) => a < b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _cell('بیشترین', high.faPrice()),
            _cell('کمترین', low.faPrice()),
            _cell('نقاط ثبت‌شده', series.length.faDigits),
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, String value) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.quote});

  final PriceQuote quote;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(
              'خرید / فروش',
              '${quote.buy?.faPrice() ?? '—'} / ${quote.sell?.faPrice() ?? '—'}',
            ),
            Divider(color: hint.withValues(alpha: 0.2)),
            _row('واحد', quote.unit.isEmpty ? quote.currency : quote.unit),
            Divider(color: hint.withValues(alpha: 0.2)),
            _row('ارز پایه', quote.currency),
            Divider(color: hint.withValues(alpha: 0.2)),
            _row('منبع', quote.source),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
