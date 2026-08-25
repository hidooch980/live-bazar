/// Persian digit + number formatting helpers (no intl dependency here so
/// it can be used from plain Dart tests).
extension FaNumber on num {
  String get faDigits => toString().replaceAllMapped(
    RegExp(r'\d'),
    (m) => const [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ][int.parse(m.group(0)!)],
  );

  String faPrice({int fraction = 0}) {
    final s = toStringAsFixed(fraction);
    final parts = s.split('.');
    final intPart = _group(parts[0]);
    return fraction > 0 ? '$intPart.${parts[1]}'.faString : intPart.faString;
  }

  String get faCompact {
    if (this >= 1e9) {
      return '${(this / 1e9).toStringAsFixed(2)} میلیارد'.faString;
    }
    if (this >= 1e6) {
      return '${(this / 1e6).toStringAsFixed(1)} میلیون'.faString;
    }
    if (this >= 1e3) return '${(this / 1e3).toStringAsFixed(1)} هزار'.faString;
    return faPrice();
  }
}

extension FaStringX on String {
  String get faString => replaceAllMapped(
    RegExp(r'\d'),
    (m) => const [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ][int.parse(m.group(0)!)],
  );
}

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buf.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buf.write(',');
    }
  }
  return buf.toString();
}
