import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../services/timezone_service.dart';
import '../../state/app_providers.dart';

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
          const _Header('حریم خصوصی'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('بدون حساب کاربری'),
            subtitle: Text(
              'هیچ داده‌ای از دستگاه شما ارسال نمی‌شود. پورتفولیو، علاقه‌مندی‌ها و هشدارها فقط محلی هستند.',
            ),
          ),
          const _Header('منابع داده'),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('CoinGecko — کریپتو'),
            subtitle: Text('عمومی، بدون کلید، تأییدشده'),
          ),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('ExchangeRate-API — ارز جهانی'),
            subtitle: Text('عمومی، بدون کلید، تأییدشده'),
          ),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('Frankfurter (ECB) — پشتیبان ارز'),
            subtitle: Text('عمومی، بدون کلید، تأییدشده'),
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

String _nowLabel(TimeZoneService tz) {
  final now = tz.now();
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
