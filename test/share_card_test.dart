import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/features/share/price_share_card.dart';

import 'support/v070_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10, 11); // 14:30 Tehran

  test('only usable quotes, each with its own time', () {
    final entries = shareCardEntries(
      {
        'ir_usd': catalogQuote('ir_usd', 265100, ts: now),
        'gold_18k': catalogQuote(
          'gold_18k',
          26496400,
          ts: now,
          status: QuoteStatus.dataConflict,
        ),
        'coin_emami': catalogQuote(
          'coin_emami',
          290000000,
          ts: DateTime.utc(2026, 10, 9, 20, 30),
          status: QuoteStatus.previousClose,
        ),
      },
      shareDefaultAssets,
      nowUtc: now,
    );
    expect([for (final e in entries) e.row.id], ['ir_usd', 'coin_emami']);
    expect(entries[0].row.value, '۲۶۵,۱۰۰');
    expect(entries[0].time, isNot(contains('به‌روزرسانی')));
    expect(RegExp(r'[0-9]').hasMatch(entries[0].time), isFalse);
    expect(entries[1].time, 'قیمت پایانی جلسه قبل');
  });

  test('nothing usable, nothing to share', () {
    expect(
      shareCardEntries(
        {'ir_usd': catalogQuote('ir_usd', 0)},
        shareDefaultAssets,
        nowUtc: now,
      ),
      isEmpty,
    );
  });

  test('a single asset from the detail screen', () {
    final e = shareCardEntries(
      {
        'ir_usd': catalogQuote('ir_usd', 265100, ts: now),
        'btc_usd': catalogQuote('btc_usd', 60000, ts: now),
      },
      ['btc_usd'],
      nowUtc: now,
    );
    expect(e.single.row.id, 'btc_usd');
    expect(e.single.row.unit, 'تومان', reason: 'converted at the real rate');
  });

  test('Jalali date in Tehran', () {
    expect(shareCardDate(now), 'شنبه ۱۸ مهر ۱۴۰۵');
    // 23:00 UTC is already the next day in Tehran.
    expect(shareCardDate(DateTime.utc(2026, 10, 10, 23)), contains('۱۹ مهر'));
  });

  testWidgets('the card renders the brand, prices and the releases link', (
    tester,
  ) async {
    final entries = shareCardEntries(
      {'ir_usd': catalogQuote('ir_usd', 265100, ts: now)},
      shareDefaultAssets,
      nowUtc: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PriceShareCard(entries: entries, date: shareCardDate(now)),
        ),
      ),
    );
    expect(find.text('بازار مولیدو'), findsOneWidget);
    expect(find.text('۲۶۵,۱۰۰'), findsOneWidget);
    expect(find.textContaining(shareReleasesUrl), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
