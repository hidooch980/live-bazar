import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/services/request_lock.dart';

void main() {
  group('RequestLock', () {
    test('joins in-flight request instead of duplicating', () async {
      final lock = RequestLock();
      var executions = 0;

      Future<int> slow() => Future<int>.delayed(
        const Duration(milliseconds: 80),
        () => ++executions,
      );

      final f1 = lock.run('k', slow);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final f2 = lock.run('k', slow);

      expect(await f1, 1);
      expect(await f2, 1); // joined the same in-flight result
      expect(executions, 1);
      expect(lock.activeCount, 0);
    });

    test('allows sequential re-entry after completion', () async {
      final lock = RequestLock();
      var n = 0;
      await lock.run('k', () async => ++n);
      final r = await lock.run('k', () async => ++n);
      expect(r, 2);
      expect(lock.activeCount, 0);
    });

    test('joiner gets null when the original operation fails', () async {
      final lock = RequestLock();

      Future<int> boom() => Future<int>.delayed(
        const Duration(milliseconds: 50),
        () => throw Exception('boom'),
      );

      final f1 = lock.run('k', boom);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final f2 = lock.run('k', boom);

      expect(await f1, isNull); // failure -> null, no crash
      expect(await f2, isNull);
    });
  });
}
