import 'package:flutter_test/flutter_test.dart';
import 'package:live_bazar/providers/adapters/crypto_provider.dart';
import 'package:live_bazar/providers/adapters/global_currency_provider.dart';

// Manual network smoke test — runs against the real public APIs.
// SKIPPED in CI (runners may be geo-blocked). Execute explicitly:
//   flutter test test/live_network_smoke_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
