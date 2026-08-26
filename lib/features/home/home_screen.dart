import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../config/asset_catalog.dart';
import '../../core/utils/fa_number.dart';
import '../../domain/entities/price_quote.dart';
import '../../services/market_pulse_service.dart';
import '../../state/app_providers.dart';
import '../../widgets/quote_tile.dart';
import '../alerts/alerts_screen.dart';
import '../portfolio/portfolio_screen.dart';

/// HOME DASHBOARD (§30).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(marketControllerProvider);
    final snap = state.snapshot;
    final quotes = snap == null
        ? const <PriceQuote>[]
        : [
            for (final d in AssetCatalog.all)
              if (d.enabled && snap.quotes.containsKey(d.id))
                snap.quotes[d.id]!,
          ];
    final pulse = MarketPulse.compute(quotes);
    final watchlistIds = ref.watch(watchlistControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بازار مولیدو'),
        actions: [
          IconButton(
            tooltip: 'پورتفولیو',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PortfolioScreen())),
          ),
          IconButton(
            tooltip: 'هشدارها',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
          ),
          IconButton(
            tooltip: 'به‌روزرسانی',
            icon: state.refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(marketControllerProvider.notifier).refreshNow(),
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
            _ConnectionHeader(busy: state.refreshing),
            if (snap != null) ...[
              _LastUpdate(
                timestamp: _latestTimestamp(quotes),
                latencyMs: snap.latencyMs,
              ),
              _PulseCard(pulse: pulse),
              _ProviderDiagnostics(
                status: Map.of(ref.watch(refreshEngineProvider).providerStatus),
              ),
              if (watchlistIds.isNotEmpty) ...[
                const _SectionTitle('علاقه‌مندی‌ها'),
                for (final id in watchlistIds)
                  if (snap.quotes[id] != null)
                    QuoteTile(
                      quote: snap.quotes[id]!,
                      isFavorite: true,
                      onToggleFavorite: () => ref
                          .read(watchlistControllerProvider.notifier)
                          .toggle(id),
                    ),
              ],
              const _SectionTitle('شاخص‌های اصلی'),
              for (final id in ['fx_usd', 'fx_eur', 'btc_usd', 'usdt_usd'])
                if (snap.quotes[id] != null)
                  QuoteTile(
                    quote: snap.quotes[id]!,
                    isFavorite: ref.watch(watchlistProvider).contains(id),
                    onToggleFavorite: () => ref
                        .read(watchlistControllerProvider.notifier)
                        .toggle(id),
                  ),
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

  DateTime? _latestTimestamp(List<PriceQuote> quotes) {
    DateTime? t;
    for (final q in quotes) {
      if (t == null || q.timestamp.isAfter(t)) t = q.timestamp;
    }
    return t;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),
  );
}

/// Live per-source status so users can SEE why data is (not) flowing.
class _ProviderDiagnostics extends StatelessWidget {
  const _ProviderDiagnostics({required this.status});

  final Map<String, String> status;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'وضعیت منابع',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final e in status.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      e.value == 'ok'
                          ? Icons.check_circle
                          : e.value.startsWith('failed')
                          ? Icons.error_outline
                          : Icons.hourglass_top,
                      size: 15,
                      color: e.value == 'ok'
                          ? AppTheme.green
                          : e.value.startsWith('failed')
                          ? AppTheme.red
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(e.key, style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        e.value,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionHeader extends ConsumerWidget {
  const _ConnectionHeader({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            color: busy ? AppTheme.gold : AppTheme.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'بررسی بازار: هر ${5.faDigits} ثانیه',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          const _TomanToggle(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (busy ? AppTheme.gold : AppTheme.green).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              busy ? 'در حال بررسی' : 'آنلاین',
              style: TextStyle(
                color: busy ? AppTheme.gold : AppTheme.green,
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

/// Tap to switch LIVE price display between Toman and USD.
class _TomanToggle extends ConsumerWidget {
  const _TomanToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toman = ref.watch(tomanModeProvider);
    return GestureDetector(
      onTap: () => ref.read(tomanModeProvider.notifier).set(!toman),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
        ),
        child: Text(
          toman ? 'تومان' : 'دلار',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _LastUpdate extends StatelessWidget {
  const _LastUpdate({required this.timestamp, required this.latencyMs});

  final DateTime? timestamp;
  final int latencyMs;

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox.shrink();
    final local = timestamp!.toLocal();
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
