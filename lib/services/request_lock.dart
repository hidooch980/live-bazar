import 'dart:async';

/// Prevents overlapping identical operations (MASTER PROMPT §5).
///
/// If [run] is called while another guarded block with the same key is
/// still executing, the call JOINS the existing in-flight future instead
/// of starting a duplicate request. Failures never propagate as crashes —
/// joiners receive null.
class RequestLock {
  final Map<String, Future<Object?>> _inFlight = {};

  bool isLocked(String key) => _inFlight.containsKey(key);

  int get activeCount => _inFlight.length;

  /// Runs [operation] under [key].
  ///
  /// Returns the operation's result, or null if this invocation joined an
  /// existing in-flight request that ultimately failed.
  Future<T?> run<T>(String key, Future<T> Function() operation) {
    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then((value) => value as T?, onError: (Object _) => null);
    }
    final Future<Object?> fut = Future<Object?>(() async => await operation())
        .catchError((Object e) => null);
    _inFlight[key] = fut;
    unawaited(fut.whenComplete(() => _inFlight.remove(key)));
    return fut.then((value) => value as T?, onError: (Object _) => null);
  }
}
