import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../domain/entities/price_quote.dart';
import '../../services/market_pulse_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/quote_tile.dart';

/// HOME DASHBOARD (§30).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(marketControllerProvider);
    final snap = state.snapshot;
    final quotes = AssetCatalog.all
        .where((d) => d.enabled && snap!.quotes.containsKey(d.id))
        .map((d) => snap!.quotes[d.id]!)
        .toList();
    final pulse = MarketPulse.compute(quotes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بازار مولیدو'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(marketControllerProvider.notifier).refreshNow(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(marketControllerProvider.notifier).refreshNow(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _ConnectionHeader(
              offline: snap == null || quotes.isEmpty && state.refreshing,
            ),
            if (snap != null) ...[
              _LastUpdate(timestamp: snap.timestamp, latencyMs: snap.latencyMs),
              _PulseCard(pulse: pulse),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'شاخص‌های اصلی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              for (final id in ['fx_usd', 'fx_eur', 'btc_usd', 'usdt_usd'])
                if (snap.quotes[id] != null) QuoteTile(quote: snap.quotes[id]!),
              const _DisabledNotice(),
            ] else
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.gold),
                      const SizedBox(height: 16),
                      Text(
                        state.isOffline
                            ? 'آفلاین — داده کش‌شده‌ای موجود نیست'
                            : 'در حال دریافت داده بازار...',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bolt,
            color: offline ? Colors.grey : AppTheme.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'بررسی بازار: هر ${5.faDigits} ثانیه',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (offline ? Colors.grey : AppTheme.green).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              offline ? 'در انتظار' : 'آنلاین',
              style: TextStyle(
                color: offline ? Colors.grey : AppTheme.green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastUpdate extends StatelessWidget {
  const _LastUpdate({required this.timestamp, required this.latencyMs});

  final DateTime timestamp;
  final int latencyMs;

  @override
  Widget build(BuildContext context) {
    final local = timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0').faString;
    final mm = local.minute.toString().padLeft(2, '0').faString;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'آخرین به‌روزرسانی واقعی منبع: $hh:$mm — تأخیر ${latencyMs.faDigits} میلی‌ثانیه',
        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.pulse});

  final MarketPulse pulse;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نبض بازار',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _pulseChip(AppTheme.green, 'صعودی', pulse.rising),
                _pulseChip(AppTheme.red, 'نزولی', pulse.falling),
                _pulseChip(Colors.grey, 'بدون تغییر', pulse.unchanged),
              ],
            ),
            if (pulse.biggestGain != null || pulse.biggestLoss != null) ...[
              const Divider(height: 20),
              if (pulse.biggestGain != null)
                _moverRow('بیشترین رشد', pulse.biggestGain!, AppTheme.green),
              if (pulse.biggestLoss != null)
                _moverRow('بیشترین افت', pulse.biggestLoss!, AppTheme.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pulseChip(Color c, String label, int n) => Column(
    children: [
      Text(
        n.faDigits,
        style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900),
      ),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _moverRow(String label, PriceQuote q, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        Text(q.nameFa, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Text(
          '${q.changePercent >= 0 ? '+' : ''}${q.changePercent.toStringAsFixed(2)}٪'
              .faString,
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _DisabledNotice extends StatelessWidget {
  const _DisabledNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'بازار آزاد ایران، طلا و سکه در نسخه اول نیازمند منبع تأییدشده هستند و نمایش داده نمی‌شوند. هیچ داده جعلی نمایش داده نمی‌شود.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
