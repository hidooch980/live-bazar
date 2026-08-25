import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/asset_catalog.dart';
import '../../domain/entities/price_quote.dart';
import '../../state/app_providers.dart';
import '../../widgets/quote_tile.dart';

/// MARKET screen (§31): tabs + search + sort.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  AssetCategory? _tab;
  String _query = '';
  bool _sortByChange = true;

  static const _tabs = <(AssetCategory?, String)>[
    (null, 'همه'),
    (AssetCategory.currency, 'ارز'),
    (AssetCategory.iranianCurrency, 'بازار آزاد'),
    (AssetCategory.gold, 'طلا'),
    (AssetCategory.coin, 'سکه'),
    (AssetCategory.crypto, 'کریپتو'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketControllerProvider);
    final snap = state.snapshot;

    final items = <PriceQuote>[];
    if (snap != null) {
      for (final def in AssetCatalog.all) {
        if (_tab != null && def.category != _tab) continue;
        if (_query.isNotEmpty &&
            !def.nameFa.contains(_query) &&
            !def.symbol.toLowerCase().contains(_query.toLowerCase())) {
          continue;
        }
        final q = snap.quotes[def.id];
        if (q != null && q.status.isDisplayable) {
          items.add(q);
        } else if (!def.enabled) {
          // Disabled asset: show honest unavailable placeholder.
          items.add(
            PriceQuote(
              id: def.id,
              symbol: def.symbol,
              name: def.name,
              nameFa: def.nameFa,
              category: def.category,
              price: 0,
              unit: def.unit,
              currency: def.currency,
              timestamp: snap.timestamp,
              source: '—',
              status: QuoteStatus.unavailable,
            ),
          );
        }
      }
      if (_sortByChange) {
        items.sort(
          (a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('بازار'),
        actions: [
          IconButton(
            tooltip: 'مرتب‌سازی بر اساس بیشترین تغییر',
            onPressed: () => setState(() => _sortByChange = !_sortByChange),
            icon: Icon(_sortByChange ? Icons.sort_by_alpha : Icons.trending_up),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'جستجوی دارایی...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (cat, label) in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _tab == cat,
                      onSelected: (_) => setState(() => _tab = cat),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('داده‌ای برای نمایش نیست'))
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(marketControllerProvider.notifier)
                        .refreshNow(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (_, i) => QuoteTile(quote: items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
