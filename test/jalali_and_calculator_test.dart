import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/core/utils/jalali_date.dart';
import 'package:live_bazar/features/calculator/calculator_screen.dart';

void main() {
  group('JalaliDate', () {
    test('Nowruz maps to 1 Farvardin', () {
      final j = JalaliDate.fromGregorian(DateTime(2026, 3, 21));
      expect(j.year, 1405);
      expect(j.month, 1);
      expect(j.day, 1);
    });

    test('a mid-year date', () {
      final j = JalaliDate.fromGregorian(DateTime(2026, 9, 7));
      expect((j.year, j.month, j.day), (1405, 6, 16));
      expect(j.monthFa, 'شهریور');
    });

    test('the day before Nowruz is the last day of Esfand', () {
      final j = JalaliDate.fromGregorian(DateTime(2026, 3, 20));
      expect(j.year, 1404);
      expect(j.month, 12);
      expect(j.day, 29);
    });

    test('weekday: 2026-09-07 is a Monday, i.e. دوشنبه', () {
      expect(
        JalaliDate.fromGregorian(DateTime(2026, 9, 7)).weekdayFa,
        'دوشنبه',
      );
    });

    test('leap years follow the 33-year cycle', () {
      expect(JalaliDate.isLeapYear(1403), isTrue);
      expect(JalaliDate.isLeapYear(1404), isFalse);
    });
  });

  group('parseAmountInput', () {
    test('accepts Persian digits and separators', () {
      expect(parseAmountInput('۱۲۳'), 123);
      expect(parseAmountInput('1,250'), 1250);
      expect(parseAmountInput('۱٫۵'), 1.5);
      expect(parseAmountInput(' 2 '), 2);
    });

    test('rejects empty, zero, negative and junk', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('0'), isNull);
      expect(parseAmountInput('-3'), isNull);
      expect(parseAmountInput('abc'), isNull);
    });
  });
}
