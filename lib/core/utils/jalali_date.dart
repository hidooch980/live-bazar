import 'fa_number.dart';

/// Iranian (Jalali/Shamsi) calendar date — «تاریخ و روز ایران».
///
/// Pure arithmetic on the proleptic Gregorian day number, so it needs no
/// package and works in plain Dart tests. The 33-year leap cycle used here
/// is the one the Iranian civil calendar follows and matches the official
/// calendar for the whole range this app can display.
class JalaliDate {
  const JalaliDate(this.year, this.month, this.day, this.weekday);

  final int year;
  final int month;

  /// 1–31.
  final int day;

  /// 0 = شنبه … 6 = جمعه.
  final int weekday;

  static const monthsFa = <String>[
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const weekdaysFa = <String>[
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  /// Converts a Gregorian date (interpreted as a calendar date, not an
  /// instant) to its Jalali equivalent.
  factory JalaliDate.fromGregorian(DateTime date) {
    final jdn = _gregorianToJdn(date.year, date.month, date.day);
    // Gregorian weekday: Monday = 1 … Sunday = 7. Saturday starts the
    // Iranian week, so shift by two.
    final weekday = (date.weekday + 1) % 7;
    var jYear = date.year - 621;
    var nowruz = _jalaliNewYearJdn(jYear);
    if (jdn < nowruz) {
      jYear -= 1;
      nowruz = _jalaliNewYearJdn(jYear);
    }
    final dayOfYear = jdn - nowruz; // 0-based
    final int jMonth;
    final int jDay;
    if (dayOfYear < 186) {
      jMonth = dayOfYear ~/ 31 + 1;
      jDay = dayOfYear % 31 + 1;
    } else {
      final rest = dayOfYear - 186;
      jMonth = rest ~/ 30 + 7;
      jDay = rest % 30 + 1;
    }
    return JalaliDate(jYear, jMonth, jDay, weekday);
  }

  /// The Iranian date in Tehran right now, from an already Tehran-local
  /// [DateTime]. Callers pass the clock they trust; nothing is guessed here.
  factory JalaliDate.of(DateTime tehranLocal) =>
      JalaliDate.fromGregorian(tehranLocal);

  String get monthFa => monthsFa[month - 1];
  String get weekdayFa => weekdaysFa[weekday];

  /// «شنبه ۱۶ شهریور ۱۴۰۵»
  String get longFa => '$weekdayFa ${day.faDigits} $monthFa ${year.faDigits}';

  /// «۱۴۰۵/۰۶/۱۶»
  String get shortFa =>
      '${year.faDigits}/${month.toString().padLeft(2, '0').faString}/'
      '${day.toString().padLeft(2, '0').faString}';

  @override
  String toString() => '$year-$month-$day';

  // ---- calendar arithmetic ------------------------------------------

  /// True when the Jalali [year] has 366 days.
  static bool isLeapYear(int year) => _leapOffset(year) == 0;

  /// Julian day number of 1 Farvardin of [jYear].
  static int _jalaliNewYearJdn(int jYear) {
    // 1 Farvardin 1 = 19 March 622 CE (Julian) = JDN 1948320. Verified
    // against the published Nowruz dates of 1395, 1398, 1400, 1402–1406
    // and 1410.
    var jdn = 1948320;
    var y = 1;
    // Cheap closed form: 33-year cycles hold exactly 12053 days.
    final cycles = (jYear - 1) ~/ 33;
    jdn += cycles * 12053;
    y += cycles * 33;
    while (y < jYear) {
      jdn += isLeapYear(y) ? 366 : 365;
      y++;
    }
    return jdn;
  }

  /// 0 for a leap year. Position inside the 33-year cycle whose leap years
  /// are the ones leaving remainder 1, 5, 9, 13, 17, 22, 26 or 30.
  static int _leapOffset(int year) {
    const leaps = [1, 5, 9, 13, 17, 22, 26, 30];
    final r = year % 33;
    final m = r <= 0 ? r + 33 : r;
    return leaps.contains(m) ? 0 : 1;
  }

  static int _gregorianToJdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        (153 * mm + 2) ~/ 5 +
        365 * yy +
        yy ~/ 4 -
        yy ~/ 100 +
        yy ~/ 400 -
        32045;
  }
}
