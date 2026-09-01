# Changelog

All notable changes to MOLIDO MARKET are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [0.3.0] — 2026-09-01

### Added
- **صفحه خانه بازارها را نشان می‌دهد.** The dashboard now has real market
  blocks — بازار آزاد, طلا, سکه, کریپتو and ارز جهانی — each listing every
  enabled asset of its category instead of the four hardcoded headline
  symbols.
- **شخصی‌سازی خانه (home personalization).** A new screen (tune icon on the
  dashboard, or Settings › شخصی‌سازی) turns any block on/off and drag-reorders
  them. Stored locally like every other preference; «پیش‌فرض» restores the
  shipped layout. Unknown/missing entries in a stored layout are tolerated, so
  a block added by a later app version appears instead of resetting the
  user's choices.

### Fixed
- **A preference changed during startup was silently reverted.** Both the home
  layout and the Toman/USD toggle load from disk asynchronously; a choice made
  while that read was still in flight got clobbered by the stale value. Loads
  now carry a generation stamp and are dropped once superseded.
- Removed the dashboard notice claiming the Iranian market, gold and coins are
  unavailable — untrue since 0.2.0 — and the matching Settings entry, which
  still described the market as `SERVER_REQUIRED`.

## [0.2.0] — 2026-09-01

### Added
- **بازار ایران، لحظه‌ای (live Iranian market).** New `IranianMarketProvider`
  serves the free-market dollar/euro/dirham/pound/lira/yuan, gold 18K & 24K,
  mesghal, the global gold & silver ounces and all five coins from the public
  keyless TGJU feed (`call{1,2,3}.tgju.org/ajax.json`, three mirrors with
  failover). Polled every 15s with the feed's own second-level timestamps —
  still zero backend.
- Iranian, gold and coin assets are `enabled` in the catalog; they no longer
  render as DATA UNAVAILABLE.
- Live freshness smoke test for the feed (`live_network_smoke_test.dart`).
- Two traps the feed sets, handled in the adapter: it sits behind a 5-minute
  CDN cache (a plain GET can hand back ~50-minute-old prices, so requests
  carry a 10s-bucketed cache-buster), and its timestamps are Tehran
  wall-clock (converted to UTC before the validation/staleness gates).

### Fixed
- **CoinGecko never worked:** `/simple/price` returns a JSON object but the
  adapter asked Dio for a `List`, so the primary crypto source threw on every
  call and silently fell through to CoinPaprika.
- **Change % was overwritten every poll.** The engine replaced the provider's
  real daily move with the delta between two polls seconds apart, so the UI
  showed ~0% for everything after the first refresh. It is now derived only
  when the provider publishes no change metric.
- A real but hours-old price (quarter coin, gram coin) is labeled STALE
  instead of LIVE.

## [0.1.3] — 2026-08-25

### Added
- **Live Toman display:** every price converts in real time via the
  official published USD/IRR rate (er-api / jsDelivr — real source data,
  never fabricated). Tap «تومان/دلار» on the Home header to switch;
  preference persists. USD value shown as secondary text.
- New `fx_irr` asset (official IRR rate) served by the FX chain.
- **Asset detail screen (§26):** price header (Toman + USD), change/%,
  real source timestamp, Market Score card (statistical-only disclaimer),
  session high/low from accumulated local history, buy/sell and source
  facts. Opened by tapping any quote.
- **Local backup/restore (§34):** export watchlist + portfolio + alerts as
  a JSON file via the Android share sheet; restore by pasting the JSON.
  Nothing leaves the device unless the user shares it themselves.

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
