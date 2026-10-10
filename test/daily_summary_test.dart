import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/data/cache/local_state_store.dart';
import 'package:live_bazar/domain/entities/price_quote.dart';
import 'package:live_bazar/services/daily_summary_service.dart';

import 'support/v070_fakes.dart';

void main() {
  // 20:10 Tehran on 18 Mehr 1405 (Saturday).
  final evening = DateTime.utc(2026, 10, 10, 16, 40);

  group('schedule', () {
    test('next run is 20:05 Tehran today, or tomorrow once past', () {
      // 10:00 Tehran.
      expect(
        DailySummaryService.nextRunUtc(DateTime.utc(2026, 10, 10, 6, 30)),
        DateTime.utc(2026, 10, 10, 16, 35),
      );
      // 20:10 Tehran: tomorrow.
      expect(
        DailySummaryService.nextRunUtc(evening),
        DateTime.utc(2026, 10, 11, 16, 35),
      );
      // 01:00 Tehran is still the same Tehran day as 20:05 that evening,
      // though UTC is the previous date.
      expect(
        DailySummaryService.nextRunUtc(DateTime.utc(2026, 10, 9, 21, 30)),
        DateTime.utc(2026, 10, 10, 16, 35),
      );
    });

    test('only reports inside the evening window', () {
      expect(DailySummaryService.inWindow(evening), isTrue);
      expect(
        DailySummaryService.inWindow(DateTime.utc(2026, 10, 11, 4)),
        isFalse,
        reason: '07:30 Tehran next morning — a stale day',
      );
    });
  });

  group('compose', () {
    test('real change for the three, today only', () {
      final m = DailySummaryService.compose({
        'ir_usd': catalogQuote(
          'ir_usd',
          265100,
          ts: DateTime.utc(2026, 10, 10, 16),
          changePercent: 0.42,
        ),
        'gold_18k': catalogQuote(
          'gold_18k',
          26496400,
          ts: DateTime.utc(2026, 10, 10, 15),
          changePercent: -1.3,
        ),
        'coin_emami': catalogQuote(
          'coin_emami',
          290000000,
          ts: DateTime.utc(2026, 10, 10, 15),
        ),
      }, evening)!;
      expect(m.title, contains('خلاصه بازار امروز'));
      expect(m.title, contains('مهر'));
      final lines = m.body.split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], contains('۲۶۵,۱۰۰'));
      expect(lines[0], contains('▲ ۰٫۴۲٪'));
      expect(lines[1], contains('▼ ۱٫۳۰٪'));
      expect(lines[2], contains('بدون تغییر'));
    });

    test('yesterday, previous-close and unusable rows are left out', () {
      final m = DailySummaryService.compose({
        'ir_usd': catalogQuote(
          'ir_usd',
          265100,
          ts: DateTime.utc(2026, 10, 9, 16),
          changePercent: 0.4,
        ),
        'gold_18k': catalogQuote(
          'gold_18k',
          26496400,
          ts: DateTime.utc(2026, 10, 9, 20, 30),
          status: QuoteStatus.previousClose,
          changePercent: 1,
        ),
        'coin_emami': catalogQuote(
          'coin_emami',
          0,
          ts: DateTime.utc(2026, 10, 10, 15),
        ),
      }, evening);
      expect(m, isNull, reason: 'nothing real today: no notification');
    });
  });

  group('run', () {
    late InMemoryKeyValueStore store;
    late RecordingNotifier n;
    late StubProvider ir;

    setUp(() {
      store = InMemoryKeyValueStore();
      n = RecordingNotifier();
      ir = StubProvider(
        'ir',
        {'ir_usd', 'gold_18k', 'coin_emami', 'ir_eur'},
        {'ir_usd': 265100, 'gold_18k': 26496400, 'coin_emami': 290000000},
        ts: DateTime.utc(2026, 10, 10, 16),
      );
    });

    Future<bool> run([DateTime? at]) => DailySummaryService.run(
      store: store,
      providers: [ir],
      notifications: n,
      nowUtc: at ?? evening,
    );

    test('off by default: no fetch, no notification', () async {
      expect(await run(), isFalse);
      expect(ir.calls, 0);
      expect(n.summaries, isEmpty);
    });

    test('once per Tehran day, only the three assets', () async {
      await store.setString(DailySummaryService.enabledKey, '1');
      expect(await run(), isTrue);
      expect(ir.lastRequested, {'ir_usd', 'gold_18k', 'coin_emami'});
      expect(n.summaries, hasLength(1));
      expect(await run(evening.add(const Duration(minutes: 30))), isFalse);
      expect(n.summaries, hasLength(1));
    });

    test('a source failure sends nothing', () async {
      await store.setString(DailySummaryService.enabledKey, '1');
      ir.fails = true;
      expect(await run(), isFalse);
      expect(n.summaries, isEmpty);
    });
  });
}
