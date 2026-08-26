import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/http_config.dart';
import '../../services/backup_service.dart';
import '../../services/timezone_service.dart';
import '../../state/app_providers.dart';
import '../update/update_flow.dart';

/// SETTINGS (§28, §34): privacy-first, local-only.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeZone = ref.watch(timeZoneProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _Header('درباره'),
          const ListTile(
            leading: Icon(Icons.storefront),
            title: Text('${AppConstants.appNameFa} — ${AppConstants.appName}'),
            subtitle: Text(AppConstants.taglineFa),
          ),
          const _Header('ساعت و منطقه زمانی'),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('منطقه زمانی پیش‌فرض'),
            subtitle: Text(
              '${timeZone.currentLocation} (UTC${timeZone.offsetLabel}) — ساعت محلی: ${_nowLabel(timeZone)}',
            ),
          ),
          const _ProxySection(),
          const _Header('حریم خصوصی'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('بدون حساب کاربری'),
            subtitle: Text(
              'هیچ داده‌ای از دستگاه شما ارسال نمی‌شود. پورتفولیو، علاقه‌مندی‌ها و هشدارها فقط محلی هستند.',
            ),
          ),
          const _Header('منابع داده (زنجیره جایگزین خودکار)'),
          const ListTile(
            leading: Icon(Icons.currency_bitcoin),
            title: Text('کریپتو'),
            subtitle: Text(
              'CoinGecko ← CoinPaprika ← CoinLore ← Nobitex\nاولین منبع پاسخ‌ده استفاده می‌شود',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.currency_exchange),
            title: Text('ارز جهانی'),
            subtitle: Text(
              'ExchangeRate-API ← jsDelivr-FX ← Frankfurter (ECB)\nاولین منبع پاسخ‌ده استفاده می‌شود',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.block),
            title: Text('بازار آزاد ایران، طلا و سکه'),
            subtitle: Text(
              'غیرفعال در نسخه اول: منبع رسمی بدون کلید موجود نیست (SERVER_REQUIRED)',
            ),
          ),
          const _Header('سیکل به‌روزرسانی'),
          const ListTile(
            leading: Icon(Icons.timer_outlined),
            title: Text('بررسی بازار هر ۵ ثانیه (فقط پیش‌زمینه فعال)'),
            subtitle: Text(
              'هر منبع با فاصله مجاز خودش فراخوانی می‌شود؛ هیچ درخواست تکراری یا موازی ارسال نمی‌شود.',
            ),
          ),
          const _Header('نمایش قیمت'),
          SwitchListTile(
            secondary: const Icon(Icons.currency_exchange),
            title: const Text('نمایش قیمت‌ها به تومان'),
            subtitle: const Text(
              'تبدیل زنده با نرخ رسمی USD/IRR از منابع — بدون داده جعلی',
            ),
            value: ref.watch(tomanModeProvider),
            onChanged: (v) => ref.read(tomanModeProvider.notifier).set(v),
          ),
          const _Header('پشتیبان‌گیری (کاملاً محلی)'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('خروجی پشتیبان (فایل JSON)'),
            subtitle: const Text('علاقه‌مندی‌ها + پورتفولیو + هشدارها'),
            onTap: () async {
              final ok = await ref.read(backupServiceProvider).shareExport();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'فایل پشتیبان ساخته شد — آن را ذخیره کنید'
                          : 'اشتراک‌گذاری در دسترس نیست',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('بازیابی از متن JSON'),
            subtitle: const Text('محتوای فایل پشتیبان را اینجا بچسبانید'),
            onTap: () => _restoreDialog(context, ref),
          ),
          const _Header('بروزرسانی برنامه'),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('بررسی بروزرسانی (از GitHub Releases)'),
            subtitle: const Text('دانلود و نصب فقط با تأیید شما انجام می‌شود'),
            onTap: () => runUpdateFlow(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );
}

/// In-app outbound HTTP proxy («تنظیمات پروکسی») — LOCAL-ONLY config.
class _ProxySection extends ConsumerStatefulWidget {
  const _ProxySection();

  @override
  ConsumerState<_ProxySection> createState() => _ProxySectionState();
}

class _ProxySectionState extends ConsumerState<_ProxySection> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final p = MarketHttp.instance.proxy;
    _enabled = p.enabled;
    _host = TextEditingController(text: p.host);
    _port = TextEditingController(text: p.port > 0 ? '${p.port}' : '');
  }

  Future<void> _save() async {
    final config = ProxyConfig(
      enabled: _enabled,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 0,
    );
    await MarketHttp.instance.save(ref.read(localStoreProvider), config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            config.isValid
                ? 'پروکسی ذخیره شد — در چرخه بعدی اعمال می‌شود'
                : 'پروکسی غیرفعال شد',
          ),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MarketHttp.instance.proxy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header('پروکسی خروجی (برای شبکه‌های محدود)'),
        SwitchListTile(
          secondary: const Icon(Icons.vpn_key_outlined),
          title: const Text('اتصال از طریق پروکسی HTTP'),
          subtitle: const Text(
            'مثلاً 127.0.0.1:8888 — تنظیمات فقط روی همین دستگاه ذخیره می‌شود',
          ),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _host,
                  decoration: const InputDecoration(
                    labelText: 'هاست',
                    hintText: '127.0.0.1',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'پورت',
                    hintText: '8888',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('ذخیره')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            p.isValid ? 'فعال: ${p.host}:${p.port}' : 'غیرفعال',
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }
}

String _nowLabel(TimeZoneService tz) {
  final now = tz.now();
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(localStoreProvider)),
);

void _restoreDialog(BuildContext context, WidgetRef ref) {
  final ctrl = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('بازیابی پشتیبان'),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '{"app": "MOLIDO MARKET", ...}',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () async {
            final store = ref.read(localStoreProvider);
            final backup = BackupService(store);
            try {
              final n = await backup.importJson(ctrl.text);
              // Reload live services so UI reflects restored data.
              await ref.read(watchlistProvider).load();
              await ref.read(portfolioProvider).load();
              await ref.read(alertsProvider).load();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('بازیابی انجام شد ($n بخش)')),
                );
              }
            } on FormatException {
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('متن JSON معتبر نیست')),
                );
              }
            }
          },
          child: const Text('بازیابی'),
        ),
      ],
    ),
  );
}
