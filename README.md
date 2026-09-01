# MOLIDO MARKET — بازار مولیدو

> بازار را لحظه‌به‌لحظه دنبال کن

Production-grade **Android** market app built with **Flutter** — no backend, no VPS, no server database. GitHub-only infrastructure.

## Philosophy

- **Zero backend (V1):** only verified public/keyless APIs + local cache.
- **Honest data:** real provider timestamps only. Never fabricated prices, history or AI analysis.
- **5-second market check:** ONE centralized engine while the app is foreground; every provider is polled within its own rate limit.
- **Privacy:** portfolio, watchlist and alerts are LOCAL ONLY. No account required.

## Verified data sources (V1)

| Source | Coverage | Key | Status |
|---|---|---|---|
| [TGJU](https://www.tgju.org) | بازار ایران: ۱۳ ارز آزاد، طلا ۱۸ و ۲۴، مثقال، آبشده، انس طلا و نقره، ۶ سکه + حباب نیم و ربع، شاخص کل بورس، نفت برنت و WTI | none | ✅ live (~15s) |
| [CoinGecko](https://api.coingecko.com) | BTC, ETH, USDT | none | ✅ enabled |
| [ExchangeRate-API](https://open.er-api.com) | USD/EUR/GBP/AED/TRY/CNY/CAD/AUD/CHF/JPY | none | ✅ primary FX |
| [Frankfurter (ECB)](https://frankfurter.dev) | ECB currencies subset | none | ✅ fallback FX |

Every quote carries its provider's REAL publish timestamp. A quote older than
30 minutes is labeled **قدیمی/STALE**, never LIVE; an asset with no working
source shows **DATA UNAVAILABLE** — never fake data.

## Architecture (one-minute tour)

```
UI → Riverpod state → MarketRefreshEngine → ProviderScheduler/RequestLock
    → IPriceProvider adapters → Validation → Anomaly detection
    → MarketSnapshot repository → Cache + UI
```

- `lib/services/market_refresh_engine.dart` — THE single 5s cycle (§4–6)
- `lib/services/request_lock.dart` — no overlapping/duplicate requests (§5)
- `lib/services/validation/` — invalid data never reaches UI (§13–15)
- `lib/providers/adapters/` — verified keyless sources (§8–10)
- `lib/providers/adapters/iranian_market_provider.dart` — بازار ایران live
  feed (CDN cache-buster + Tehran→UTC clock, see
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#9-iranian-market-feed-بازار-ایران))
- `lib/data/cache/hive_market_cache.dart` — offline-first storage (§20)

Why Hive CE: pure Dart (no native build deps), instant startup reads, simple JSON schema evolution. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Build & Test

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build apk --release     # CI builds releases on tags (v*)
```

## Roadmap (V1 → V2)

- [x] Central refresh engine + request lock + rate limits
- [x] Crypto + global currency quotes with validation/anomaly gates
- [x] Persian RTL dashboard, market tabs, calculator
- [x] داشبورد بازارمحور + شخصی‌سازی خانه (نمایش و ترتیب بخش‌ها)
- [x] بازار ایران زنده: دلار/ارز آزاد، طلا، مثقال، انس، سکه
- [ ] Watchlist, price alerts (local notifications), portfolio (§22–24)
- [ ] Charts from accumulated local history (§19, §27)
- [ ] MOLIDO MARKET AI modules (V2, never faked in V1) (§32)

## Disclaimer

Market Score / Market Pulse are statistical information only and are **not** buy/sell/trade/investment advice.

## License

MIT — see [LICENSE](LICENSE).
