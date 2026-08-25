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
| [CoinGecko](https://api.coingecko.com) | BTC, ETH, USDT | none | ✅ enabled |
| [ExchangeRate-API](https://open.er-api.com) | USD/EUR/GBP/AED/TRY/CNY/CAD/AUD/CHF/JPY | none | ✅ primary FX |
| [Frankfurter (ECB)](https://frankfurter.dev) | ECB currencies subset | none | ✅ fallback FX |
| Iranian free-market / gold / coins | — | requires credentials | ⛔ `SERVER_REQUIRED` (disabled) |

Disabled sources show **DATA UNAVAILABLE** — never fake data.

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
- [ ] Watchlist, price alerts (local notifications), portfolio (§22–24)
- [ ] Charts from accumulated local history (§19, §27)
- [ ] MOLIDO MARKET AI modules (V2, never faked in V1) (§32)

## Disclaimer

Market Score / Market Pulse are statistical information only and are **not** buy/sell/trade/investment advice.

## License

MIT — see [LICENSE](LICENSE).
