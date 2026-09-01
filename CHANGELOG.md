# Changelog

All notable changes to MOLIDO MARKET are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [0.5.1] — 2026-09-02

### Fixed
- **Every Toman price repeated itself under an «IRR» label.** A row read
  «۲۱۴,۰۰۰ تومان» with «IRR ۲۱۴,۰۰۰» beneath it — the same number, labelled
  as Rial, which is a tenth of a Toman. Worst on دینار عراق, where rounding
  made the two lines differ («۱۵۳.۱ تومان» / «IRR ۱۵۳») and look like two
  prices. An IRR-denominated quote already IS the Toman figure, so it no
  longer gets a second line.
- **The chart opened on an empty frame.** It defaulted to the first catalog
  asset (`fx_usd` — no published table) and to the ۱ ساعت range (no local
  points yet on a fresh install), so the first thing anyone saw was «داده
  کافی نیست» even though years of real history were one tap away. It now
  opens on an asset that has published history, at a daily range.

## [0.5.0] — 2026-09-01

### Added
- **تتر (تومان) — ۲۴ ساعته.** Every Iranian-market row freezes when the
  bazaar closes at 20:00; the Tether/Toman rate does not. It is now a live
  asset in بازار آزاد, so there is a real, moving Toman price on screen at
  night. Measured against the closed market the same evening: تتر ۲۱۴,۸۰۵
  vs a frozen dollar at ۲۱۴,۰۰۰ — 0.38% apart.

### Fixed
- **Prices shown in Toman were about a third too low.** The USD→Toman
  conversion used `fx_irr`, the OFFICIAL published rate, which was quoting
  ۱۴۶,۸۸۲ تومان while the free market was at ۲۱۴,۰۰۰ — so every
  USD-denominated asset (both gold ounces, all crypto, the whole portfolio
  total) was understated by ~32%. The rate now comes from the free-market
  dollar while the bazaar trades, from the 24/7 Tether rate once it closes,
  and from the official rate only if neither is on the snapshot.

## [0.4.1] — 2026-09-01

### Fixed
- **همه‌ی قیمت‌ها شب‌ها «قدیمی» می‌شدند.** After the Iranian market closes at
  20:00 the feed keeps answering, it just answers with the 19:59 print — so
  every row turned orange «قدیمی» all night and read as a broken app. That
  was two separate mistakes:
  - A quote we DID just fetch is not stale. `QuoteStatus.delayed` now covers
    "the source itself is quiet" (closed market, thinly traded asset) and the
    badge shows the real age — «۲ ساعت پیش» — instead of a verdict. `stale`
    is reserved for what it should always have meant: we could not refresh
    it. That case previously kept claiming «زنده» forever; a carried-over
    quote whose provider failed is now downgraded.
  - The header reported `max(source timestamps)` as «آخرین به‌روزرسانی واقعی
    منبع», so one 24/7 asset (the global ounce) held it at the current minute
    while every Iranian row underneath was hours old — the screen
    contradicted itself. It now reports when the APP last checked, and says
    each price carries its own time.

## [0.4.0] — 2026-09-01

### Added
- **۱۴ دارایی تازه از همان فید.** The TGJU response already carried 963
  indicators while the app read 16 of them. Now also live, at no extra
  network cost: شاخص کل بورس, نفت برنت و WTI, آبشده نقدی, سکه امامی
  خرده‌فروشی, حباب نیم و ربع سکه, and the free-market rates for
  کانادا/استرالیا/سوئیس/ژاپن/روسیه/عراق/افغانستان.
- New `شاخص` and `نفت و کالا` categories, with matching market tabs and
  home blocks (switchable and reorderable like every other block).
- `AssetDefinition.tradable`: a market index or a coin bubble is a real
  published number but not a position, so the portfolio and the converter
  leave those out while alerts and charts still cover them.
- **نمودار با تاریخچه‌ی واقعی.** Charts used to draw only what accumulated
  while the app happened to be open, so a fresh install showed an empty
  frame. Long ranges (۱ ماه / ۳ ماه / ۱ سال / همه) now come from the
  source's published daily OHLC table — about 7 years per asset after the
  2000-candle cap — while ۱ ساعت / ۶ ساعت / ۱ روز still use the local
  observations. The footer always says which of the two is on screen and
  how many real records it holds; crypto and global FX have no published
  table and keep the local-only path.
- **هشدار قیمت در پس‌زمینه.** Alert rules were only ever evaluated on an
  engine snapshot, and the engine stops when the app is paused (§6) — so a
  price alert only fired while you were already looking at the app. An
  opt-in WorkManager task (Settings › هشدارها) now runs one
  fetch-evaluate-notify pass every 15 minutes, Android's floor for
  periodic work. Off by default, it only fetches the assets an active rule
  actually names, and does no network work at all when there are no rules.

- **ویجت صفحه اصلی اندروید.** دلار، طلای ۱۸ و سکه امامی روی صفحه گوشی,
  without opening the app. Opt-in (Settings › ویجت صفحه اصلی), refreshed
  from the foreground engine while the app is open and by the background
  worker while it is closed. The widget always carries its own
  «به‌روزرسانی HH:MM» line and omits any asset whose quote is unusable,
  so it can never pass a stale number off as current.


### Notes on units — each verified against the live feed
- The yen is published **per 100 units**; its name says so, otherwise the
  number reads 100× wrong.
- Index points and USD-per-barrel are not Rial and are never divided by 10;
  the divisor keys off the catalog currency, and `bourse_index` uses `IDX`
  so it stays out of every Toman conversion path.
- حباب is published by TGJU itself — this app does not compute it.

## [0.3.1] — 2026-09-01

### Fixed
- **Releases are now signed with a stable release key.** Every APK so far was
  debug-signed with a keystore the CI runner generated fresh on each run, so
  no two releases shared a certificate and in-app updates always failed with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Verified across v0.1.3 vs v0.2.0:
  cert SHA-256 `e63ff593…` vs `f1574e5c…`.
- The workflow's keystore step could never have worked: it derived the AES key
  from `KEYSTORE_SECRET` while also treating that same value as the base64 of
  its own ciphertext — a circular definition with no constructible input.
  Replaced with the standard scheme: `KEYSTORE_BASE64` + `KEYSTORE_PASSWORD`
  repository secrets, nothing key-related in the repo.
- The release job now refuses to publish when the signing secret is missing,
  instead of silently shipping a debug-signed APK, and runs `apksigner verify
  --print-certs` so the published certificate is visible in the build log.
- `.gitignore` now covers `android/key.properties`, `android/keystore/` and
  every `*.p12`/`*.jks`/`*.keystore`.

### Upgrade note
- **یک بار** باید نسخه‌ی قدیمی را حذف و این نسخه را دستی نصب کنی: امضای برنامه
  عوض شده و اندروید اجازه‌ی نصب روی نسخه‌ی قبلی را نمی‌دهد. از این نسخه به بعد
  آپدیت داخل اپ بدون حذف کار می‌کند.

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
