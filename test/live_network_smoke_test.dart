import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/providers/adapters/crypto_provider.dart';
import 'package:live_bazar/providers/adapters/global_currency_provider.dart';
import 'package:live_bazar/providers/adapters/iranian_market_provider.dart';

// Manual network smoke test — runs against the real public APIs.
// SKIPPED in CI (runners may be geo-blocked). Execute explicitly, after
// deleting the `skip:` line of the test you want:
//   flutter test test/live_network_smoke_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test mocks HttpClient by default; real sockets are required here.
  setUpAll(() => HttpOverrides.global = null);

  test(
    'LIVE: CoinGecko reachable from Dart/dio',
    skip: 'manual network test — run locally',
    () async {
      final r = await CryptoProvider().getLatestPrices({'btc_usd'});
      // ignore: avoid_print
      print(
        'coingecko ok=${r.isSuccess} quotes=${r.quotes.length} '
        'err=${r.error?.message}',
      );
      expect(r.quotes, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'LIVE: ExchangeRate-API reachable from Dart/dio',
    skip: 'manual network test — run locally',
    () async {
      final r = await GlobalCurrencyProvider().getLatestPrices({
        'fx_eur',
        'fx_usd',
      });
      // ignore: avoid_print
      print(
        'erapi ok=${r.isSuccess} quotes=${r.quotes.length} '
        'err=${r.error?.message}',
      );
      expect(r.quotes, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'LIVE: TGJU Iranian market feed reachable and FRESH',
    skip: 'manual network test — run locally',
    () async {
      final r = await IranianMarketProvider().getLatestPrices(
        IranianMarketProvider.indicatorMap.values.toSet(),
      );
      // ignore: avoid_print
      print(
        'tgju ok=${r.isSuccess} quotes=${r.quotes.length} '
        'err=${r.error?.message}',
      );
      expect(r.quotes, isNotEmpty);

      // The dollar trades continuously: if the CDN cache-buster ever stops
      // working this age jumps to ~50 minutes and the test fails.
      final usd = r.quotes.firstWhere((q) => q.id == 'ir_usd');
      final age = DateTime.now().toUtc().difference(usd.timestamp);
      // ignore: avoid_print
      print('ir_usd = ${usd.price} ${usd.unit}, age = ${age.inSeconds}s');
      expect(age, lessThan(const Duration(minutes: 10)));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
