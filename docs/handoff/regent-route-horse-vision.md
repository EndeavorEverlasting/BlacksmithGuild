# Regent, Route Council, Horse Atlas, Herd Ledger vision

This slice defines the read-only strategy spine that sits ahead of visible
campaign automation. It was implemented serially in this session; no parallel
subagents were used.

## Core ruling

- The Regent prevents blind automation.
- The Route Council prevents one-engine tunnel vision.
- The Horse Atlas prevents blind travel.
- The Herd Ledger prevents dumb horse decisions.
- The Governor chooses activity only after these systems can explain the state.

## Runtime roles

### The Regent

`CampaignRuntimeRegent` is the runtime state authority. It snapshots the current
campaign surface, phase, health, last governor decision, activity result, and
stagnation class. It recommends recovery vocabulary, but it never enables
mutation; `MutationAllowed` remains false and bounded execution still depends on
explicit `DevToolsConfig` gates.

### The Route Council

`CampaignRouteCouncil` gathers weighted votes from food, trade, horse, and
safety engines and emits a single `CampaignRouteCouncilDecision`. Safety votes
can veto travel with an exact reason. Food-critical votes override horse/trade
unless safety blocks movement. Horse-profit votes are allowed only when food,
safety, and capacity basics are covered. The council writes
`BlacksmithGuild_RouteCouncil.json` as read-only evidence and does not travel,
buy, sell, or mutate state.

### The Horse Atlas

`HorseMarketAtlasService` scans settlements in read-only mode, ranks horse
destinations, and writes `BlacksmithGuild_HorseAtlas.json`. The atlas is meant to
answer where horse-related opportunities might be before the Governor chooses
travel. The default mode is `LayOfLandScan`; `DiscoveredOnly` exists as the
restricted-mode design stub. Runtime output includes destination candidates,
top destination, settlement/animal/price/stock/freshness entry fields, and a
local-verification-required marker before any buy/sell step. It captures the
cheapest pack animal, recruitment mount candidate, war/upgrade mount candidate,
and profit candidate using read-only market pricing.

### The Herd Ledger

`HerdLedgerService` forecasts pack, mount, herd-penalty, capacity-buffer, and
spendable-gold posture for the player party. It writes
`BlacksmithGuild_HerdLedger.json` and recommends hold/buy/sell posture without
changing inventory or gold. Unknown classifications block mutation. Low-capacity
states protect pack-animal reserve, and war/noble reserve is protected from
sell posture. Profit posture only appears after basic safety, food, and capacity
coverage. If no exact route load exists, the ledger writes conservative trade,
smithing, food, and loot-buffer forecasts instead of pretending certainty.

### Governor integration

`CampaignRuntimeGovernor` now attaches Regent/Route/Horse evidence to the
decision JSON. If bounded execution is disabled, route-council winners are
reported as deferred activity with an exact `nextAction`. Missing or stale horse
atlas evidence recommends `RefreshHorseAtlas` / `ScanHorseAtlas`; missing or
stale herd evidence recommends `AnalyzeHerdLedger`. Horse destinations are
surfaced with local verification required before buy/sell.

## Dev commands

- `ShowRuntimeRegentState`
- `ConveneRouteCouncil`
- `ShowRouteCouncil`
- `ScanHorseAtlas`
- `ShowHorseAtlas`
- `RankHorseDestinations`
- `AnalyzeHerdLedger`
- `ShowHerdLedger`

The commands are mirrored in `DevCommandRegistry.cs`, `DevCommandBus.cs`, and
`scripts/dev-command-names.ps1`.

## Safety invariants

- Runtime JSON files are local-only and ignored by git.
- The new services are read-only intelligence producers.
- `CampaignRuntimeGovernorAutonomousMode` defaults to false.
- `CampaignRuntimeGovernorAllowBoundedExecution` defaults to false.
- Direct inventory/gold mutation defaults remain false.
- Verifier coverage lives in `scripts/verify-regent-route-horse-contract.ps1`.