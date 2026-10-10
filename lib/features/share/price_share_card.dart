import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/fa_number.dart';
import '../../core/utils/jalali_date.dart';
import '../../domain/entities/price_quote.dart';
import '../../services/daily_summary_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/share_service.dart';
import '../../state/app_providers.dart';
import '../widget_settings/widget_preview.dart' show symbolFallback, toneColors;

const shareReleasesUrl = 'github.com/hidooch980/live-bazar/releases';

/// The default card from the home header.
const shareDefaultAssets = <String>['ir_usd', 'gold_18k', 'coin_emami'];

/// One line of the card: a real quote, with its own time.
@immutable
class ShareCardEntry {
  const ShareCardEntry({required this.row, required this.time});
  final WidgetRow row;

  /// «۱۴:۳۲», «دیروز ۱۴:۳۲», or «قیمت پایانی جلسه قبل».
  final String time;
}

/// The card's lines for [ids]: only usable quotes (the widget's own rule —
/// a rejected, unpriced or unconvertible row is left out, never shown as
/// a guess), each with the source's own timestamp.
List<ShareCardEntry> shareCardEntries(
  Map<String, PriceQuote> quotes,
  List<String> ids, {
  DateTime? nowUtc,
}) {
  final now = nowUtc ?? DateTime.now().toUtc();
  return [
    for (final row in HomeWidgetService.rows(quotes, ids, nowUtc: now))
      ShareCardEntry(
        row: row,
        time: quotes[row.id]!.status == QuoteStatus.previousClose
            ? 'قیمت پایانی جلسه قبل'
            : HomeWidgetService.updatedLabel(
                quotes[row.id]!.timestamp,
                nowUtc: now,
              ).replaceFirst('به‌روزرسانی ', ''),
      ),
  ];
}

/// «شنبه ۱۸ مهر ۱۴۰۵», Tehran calendar day.
String shareCardDate(DateTime nowUtc) {
  final j = JalaliDate.fromGregorian(DailySummaryService.toTehran(nowUtc));
  return '${j.weekdayFa} ${j.day.faDigits} ${j.monthFa} ${j.year.faDigits}';
}

/// The branded image itself. Fixed width so the PNG looks the same on
/// every phone.
class PriceShareCard extends StatelessWidget {
  const PriceShareCard({super.key, required this.entries, required this.date});

  final List<ShareCardEntry> entries;
  final String date;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    const sub = Color(0xB3FFFFFF);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Vazirmatn',
          fontFamilyFallback: symbolFallback,
        ),
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1B1446), AppTheme.navy, Color(0xFF2A1033)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDE68A), Color(0xFFC8960C)],
                      ),
                    ),
                    child: const Text(
                      'م',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بازار مولیدو',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.gold,
                          ),
                        ),
                        Text(
                          'قیمت لحظه‌ای ارز، طلا و سکه',
                          style: TextStyle(fontSize: 10, color: sub),
                        ),
                      ],
                    ),
                  ),
                  Text(date, style: const TextStyle(fontSize: 11, color: sub)),
                ],
              ),
              const SizedBox(height: 16),
              for (final e in entries) _line(e),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white12),
              const SizedBox(height: 10),
              const Text(
                'هر قیمت با ساعت انتشار منبع خودش · قیمت‌ها به تومان · توصیه مالی نیست',
                style: TextStyle(fontSize: 9, color: sub),
              ),
              const SizedBox(height: 4),
              const Text(
                'دریافت رایگان: $shareReleasesUrl',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 10, color: AppTheme.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(ShareCardEntry e) {
    final r = e.row;
    final up = r.direction >= 0;
    final c = up ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: toneColors[r.tone] ?? toneColors['purple']!,
              ),
            ),
            child: Text(
              r.glyph,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 11, color: Colors.white60),
                    const SizedBox(width: 3),
                    Text(
                      e.time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    r.value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    r.unit,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
              if (r.change.isNotEmpty)
                Text(
                  r.change,
                  style: TextStyle(
                    fontSize: 10,
                    color: c,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Header/detail action: preview the card, then share it as a PNG.
Future<void> showShareCardSheet(
  BuildContext context,
  WidgetRef ref, {
  List<String> ids = shareDefaultAssets,
}) async {
  final snap = ref.read(marketControllerProvider).snapshot;
  final now = DateTime.now().toUtc();
  final entries = shareCardEntries(snap?.quotes ?? const {}, ids, nowUtc: now);
  if (entries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('فعلاً قیمت معتبری برای اشتراک نیست')),
    );
    return;
  }
  final key = GlobalKey();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: FittedBox(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: RepaintBoundary(
                      key: key,
                      child: PriceShareCard(
                        entries: entries,
                        date: shareCardDate(now),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('اشتراک‌گذاری تصویر'),
                onPressed: () async {
                  final png = await captureCard(key);
                  if (png == null) return;
                  final ok = await ShareService.sharePng(
                    png,
                    subject: 'قیمت‌های بازار مولیدو',
                  );
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('اشتراک‌گذاری ممکن نشد')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The card at 3× as PNG bytes.
Future<Uint8List?> captureCard(GlobalKey key) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
