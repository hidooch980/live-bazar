# Changelog

All notable changes to MOLIDO MARKET are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [0.1.0] — 2026-08-25

### Added
- Centralized `MarketRefreshEngine`: single 5-second foreground cycle (§4–6).
- `RequestLock`: overlapping/duplicate request protection (§5).
- Provider architecture: `IPriceProvider`, `ProviderRegistry`, priority chains,
  fallback order (§8–9).
- Verified keyless sources: CoinGecko (crypto), ExchangeRate-API (FX primary),
  Frankfurter/ECB (FX fallback) (§10).
- Iranian free-market, gold & coin assets declared but DISABLED
  (`SERVER_REQUIRED`) — honest DATA UNAVAILABLE in UI (§7, §10, §33).
- `PriceQuote` / `MarketSnapshot` normalized models with full status model (§11–12).
- Validation engine + anomaly detection (>10% jump guard, timestamp regression,
  conflict flagging) (§13–15).
- Market Pulse & Market Score (statistical only — never advice) (§16–17).
- Historical aggregation helper with bounded buckets (§19).
- Offline-first cache: Hive CE-backed snapshot store; startup = Cache → UI → Network (§20–21).
- Persian RTL UI: Home dashboard, Market tabs/search/sort, Charts placeholder
  (honest "history unavailable"), Calculator, Settings (§28–31).
- GitHub Actions: flutter-ci, release APK on tags, price-health static snapshot
  (`data/latest.json`), dependency check (§35–36).
- Unit/integration-style test suite covering the critical five-second contract (§37–38).
