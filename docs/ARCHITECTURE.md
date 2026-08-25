# MOLIDO MARKET — Architecture

## 1. Infrastructure rule (§1)

No VPS / server / domain / backend / server DB / Firebase dependency.
Allowed: Flutter, Dart, Android, GitHub (Actions/Releases), verified public
APIs, local cache, Android local notifications.

## 2. Layers

```
lib/
  app/          MolidoApp shell, theme (RTL-first), bottom navigation
  core/         constants, typed errors, Persian-number utils
  config/       AssetCatalog — every supported asset + enabled flag
  domain/       PriceQuote, MarketSnapshot (immutable, JSON round-trippable)
  providers/    IPriceProvider contract + ProviderRegistry + adapters
  services/     MarketRefreshEngine, RequestLock, validation, anomaly,
                pulse/score, connectivity bridge
  data/         cache: MarketCache interface, Hive CE impl, in-memory impl
  state/        Riverpod wiring (engine -> UI state)
  features/     home, market, charts, calculator, settings
  widgets/      QuoteTile, StatusBadge
```

Dependency direction is strictly downward: UI never talks to HTTP directly
(§8). Flow: `UI → State → Engine → Provider → API`.

## 3. The single engine (§4–6)

`MarketRefreshEngine` owns the ONLY periodic timer (`Timer.periodic(5s)`).

- **Foreground:** cycle runs; each provider fires only when
  `now >= nextAllowedFetch[provider.id]` where
  `nextAllowedFetch = lastDispatch + provider.minRefreshInterval`
  → a 5s app check never violates per-provider rate limits (§3).
- **Background (`paused|hidden|detached`):** timer stopped. On `resumed`:
  immediate forced refresh, then cycle resumes.
- **Connectivity:** loss → offline mode skips network churn and serves cache;
  restoration triggers an immediate forced refresh.

## 4. Request lock (§5)

`RequestLock.run(key, op)` stores the in-flight future per key. A second call
with the same key JOINS it (same result) instead of duplicating work. Both the
whole-cycle (`market-refresh`) and each provider (`provider:<id>`) are locked.
Failures surface as `null`, never as crashes.

## 5. Data honesty pipeline

1. Adapter returns quotes with the REAL provider timestamp (HTTP `date`
   header, or the provider's own publication epoch).
2. `PriceValidationService.validate` rejects non-positive/non-finite prices,
   unknown ids, future timestamps, missing source/currency.
3. `AnomalyDetectionService.assess` compares against the previous valid value:
   >10% single-step move or timestamp regression → suspicious.
4. Suspicious data is REPLACED by the last valid value flagged
   `dataConflict`. Nothing fabricated ever enters state (§13–15).
5. Change% is computed only between two real observations with different
   timestamps; otherwise the quote is UNCHANGED.

## 6. Cache choice (§20)

**Hive CE** chosen because:
- pure Dart → zero native build complexity for CI APK builds,
- synchronous key/value reads → instant startup hydration
  (Cache → Immediate UI → Network),
- snapshots stored as JSON strings → painless schema evolution without codegen.

An `InMemoryMarketCache` implementation exists for tests/fallbacks.

## 7. Static snapshot & Actions (§35–36)

`data/latest.json` is written ONLY by GitHub Actions (`price-health.yml`,
every 30 min) from the same keyless endpoints, used as a last-resort fallback.
GitHub Actions is explicitly NOT treated as a real-time backend. The initial
file contains an empty quote set with status `NEVER_PUBLISHED` — no fake data.

## 8. AI-readiness (§32)

The repository/state layer already exposes clean snapshots that a future
MOLIDO MARKET AI module can consume. V1 ships zero AI features and never
simulates analysis output.

## 9. Deliberately disabled in V1

Iranian free-market FX, gold/coins, commodities/indices require either
server-side credentials or scraping of unofficial sources — both violate the
verification/security rules (§10, §33). They are declared in the catalog with
`enabled = false`; UI shows DATA UNAVAILABLE.
