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

/// Persian (۰-۹) and Arabic-Indic (٠-٩) digits -> ASCII.
String toAsciiDigits(String s) {
  final buf = StringBuffer();
  for (final code in s.runes) {
    if (code >= 0x06F0 && code <= 0x06F9) {
      buf.writeCharCode(code - 0x06F0 + 0x30);
    } else if (code >= 0x0660 && code <= 0x0669) {
      buf.writeCharCode(code - 0x0660 + 0x30);
    } else {
      buf.writeCharCode(code);
    }
  }
  return buf.toString();
}

final _numberSeparators = RegExp(r'[,٬\s]');

/// Market numbers as sources publish them: '2,130,050', '4,368.85', or
/// Persian digits. Returns null for anything unusable ('-', '', 0, junk)
/// so a caller can skip the row instead of inventing a value.
double? parseMarketNumber(Object? raw) {
  if (raw == null) return null;
  final s = toAsciiDigits(raw.toString()).replaceAll(_numberSeparators, '');
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}
