import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Central TIMEZONE definition («تعریف ساعت»).
///
/// Initializes the IANA tz database once and sets the app's default local
/// location to Tehran (primary audience), so notifications, timestamps and
/// future scheduled alerts all share one consistent clock.
class TimeZoneService {
  static const defaultLocation = 'Asia/Tehran';

  bool _initialized = false;
  String _location = defaultLocation;

  /// Safe to call multiple times.
  Future<void> init({String location = defaultLocation}) async {
    if (_initialized && _location == location) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(location));
      _location = location;
    } catch (_) {
      // Unknown id -> keep UTC default rather than crash.
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
      _location = 'Etc/UTC';
    }
    _initialized = true;
  }

  bool get isInitialized => _initialized;
  String get currentLocation => _location;

  /// Current wall-clock time in the configured location.
  tz.TZDateTime now() => tz.TZDateTime.now(tz.getLocation(_location));

  String get offsetLabel {
    final l = tz.getLocation(_location);
    final off = l.currentTimeZone.offset;
    final sign = off.isNegative ? '-' : '+';
    final h = (off.inMinutes.abs() ~/ 60).toString().padLeft(2, '0');
    final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }
}
