# Worker Cadence and Market Refresh

The automation does not assume that Bannerlord refreshes markets at midnight, every morning, or every three days. That schedule is not established by this repository. The runtime treats market information as an on-demand cache with explicit invalidation, not as a continuously polled feed.

## What runs while the player is playing

- Full shared session-state refresh is capped at ten times per real-time second across application, campaign, orchestrator, and hotkey tick paths.
- Unchanged lifecycle and post-load stabilization status writes are capped at once per real-time second.
- The Governor is disabled at startup. In Automation mode it can make one decision at most every 10 real-time seconds, and its observation path consumes only an already-fresh market cache.
- An idle MapTrade worker checks recursive branch state at most once every two real-time seconds and only in Automation. Repeated identical blockers do not rewrite route evidence.
- Active route, travel-safety, GuildLoop-arrival, and Cohesion checks run at most four times per real-time second while their work is active.
- Assistive movement proof samples at most four times per second, writes periodically at most once per second, and retains at most 64 samples.
- The half-second command-inbox poll checks file existence and modification time before refreshing or writing full runtime status; an absent or unchanged inbox performs no heavy status work.
- Market price enumeration does not run on every campaign tick. A workflow asks for a scan only when it needs market data.
- Horse-atlas price/roster inspection is explicit, capped to the 24 nearest eligible settlements, and its 24-hour freshness is measured in campaign time. Herd-ledger freshness is also campaign-time based.

These are elapsed-time gates, so a higher frame rate or faster campaign tick rate does not multiply expensive work.

All recurring workers enter through `RuntimeCadenceGate`. Its `BlacksmithGuild_RuntimeCadence.json` handoff reports each worker's configured interval plus attempted, executed, and throttled counts. `ShowRuntimeCadence` forces a fresh report without running the workers. New engines should register a named gate instead of growing another private tick counter.

## Market cache rules

`Ctrl+Alt+M` is an explicit forced scan. Autonomous MapTrade, GuildLoop, and mission selection use the cached scan while it remains fresh. The cache becomes stale when any of these conditions is observed:

- Bannerlord emits the campaign daily tick;
- a TBG trade completes;
- a bounded smithing action changes party inventory;
- the party changes settlement context;
- the party moves at least 10 map units from the scan origin; or
- the scan reaches 24 in-game hours old.

Staleness does not itself start a background scan. The next workflow that actually needs prices refreshes the cache. This bounds resource use even if Bannerlord's internal market update schedule differs from the conservative freshness policy.

Every market JSON report records campaign day, scan origin, cache policy, age/distance limits, scan execution count, elapsed milliseconds, pass count, settlements enumerated, towns visited, candidate items, and price lookups. Those fields let later agents distinguish a cheap cache reuse from a broad scan. The canonical policy is `.tbg/operator/worker-cadence.json`.

## Measure a representative session

Use the normal flow in `load-save-toggle-and-visible-trade-plan.md`. After the route has moved and either arrived or been stopped, inspect `BlacksmithGuild_TickCostProfiler.json` in the Bannerlord base path. Compare `count`, `slowCount`, `averageMs`, and `maxMs` for each segment.

A useful capture includes at least one minute idle in Hybrid, one minute idle in Automation, and one active route. Report measurements; do not infer the game's market refresh implementation from price changes alone.

Run the static contract without launching Bannerlord:

```powershell
pwsh -NoProfile -File .\scripts\verify-worker-cadence-contract.ps1
```
