# Changelog

All notable changes to MOLIDO MARKET are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [0.1.2] — 2026-08-25

### Added
- **In-app auto-update (GitHub-only):** checks the latest GitHub Release
  on startup (once per session), shows a Persian confirm dialog, downloads
  the APK with progress, and hands it to the Android installer.
  Manual check lives in Settings → «بروزرسانی برنامه».
- `REQUEST_INSTALL_PACKAGES` permission + FileProvider wiring for the
  downloaded APK handoff.
- **Free self-signed release certificate:** 30-year PKCS12 keystore,
  committed ENCRYPTED (AES-256/PBKDF2). CI decrypts it from the
  `KEYSTORE_SECRET` repository secret and signs release APKs; local builds
  use the gitignored `android/key.properties`. Debug-signed fallback when
  the secret is absent.

### Changed
- pubspec version aligned with git tags (0.1.2+3 ↔ v0.1.2).

## [0.1.1] — 2026-08-25

### Fixed
- **No live data on restricted networks (IR):** providers now use
  IRAN-ACCESSIBLE multi-endpoint failover chains:
  - Crypto: CoinGecko → CoinPaprika → CoinLore → Nobitex (USDT pairs)
  - FX: ExchangeRate-API → jsDelivr currency-api → Frankfurter (ECB)
- Engine no longer gates the polling cycle on connectivity state; failed
  cycles self-heal and cached data is always refreshed on recovery.
- Snapshot events broadcast unconditionally; first fetch now happens at
  startup BEFORE the first frame.

### Added
- In-app outbound HTTP proxy settings (host/port, optional auth) —
  LOCAL-ONLY, applied to every provider client.
- «وضعیت منابع» diagnostics card on Home: per-provider ok/failed/error text.
- Vazirmatn font bundled (Regular→ExtraBold) for proper Persian typography.
- Custom MOLIDO launcher icon (adaptive + legacy, all densities).

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
