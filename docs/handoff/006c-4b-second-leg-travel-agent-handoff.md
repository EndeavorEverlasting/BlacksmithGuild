# 006C-4b — Second-Leg Auto-Travel (Buy Town → Sell Town)

**Branch:** `feat/006c-4b-second-leg-travel` (stacked on `feat/006c-4-sell-loop`)  
**Status:** CODE SHIPPED — USER live cert pending (map-ready gate)

---

## Shipped

| Deliverable | Detail |
|-------------|--------|
| Guild loop second leg | After buy, auto-rides to `SellSettlement` for spread missions |
| Map trade route second leg | `TravelToSellTarget` + `ExecuteSell:Success` in cert steps |
| Mission helpers | `NeedsSecondLegSellTravel`, `TryBuildSellLegTravelMission` |
| Config | `GuildLoopAutoTravelToSellTown`, `MapTradeAutoTravelToSellTown` (default `true`) |
| Cert JSON | `sellExecution` block on `BlacksmithGuild_MapTradeCert.json` |

---

## PASS rubric

| Check | PASS when |
|-------|-----------|
| Build | `dotnet build -c Release` — 0 errors |
| Guild loop | `TravelToSellTown: Success` then `TryVanillaSell: Success` |
| Map trade | Steps include `TravelToSellTarget:` + `ExecuteSell:Success` |
| Delta | `sellExecution.goldDelta > 0`, `quantitySold > 0` |

---

## USER cert (after map-ready)

```powershell
git checkout feat/006c-4b-second-leg-travel
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

---

## Output paths

- `BlacksmithGuild_AutonomousGuildLoop.json` — `TravelToSellTown`, `sellExecution`
- `BlacksmithGuild_MapTradeCert.json` — `TravelToSellTarget`, `sellExecution`
- `BlacksmithGuild_MarketIntel.json` — `spreadRows` (buy town ≠ sell town)

---

## Known gaps

- Live cert blocked until crash fix (Agent B/C on `fix/continue-map-crash-bisect`)
- Same-town spreads skip second leg (correct)
- Config `false` reverts to 006C-4 honest Blocked at buy town

---

## Agent C stash note

Agent C WIP is stashed on `main` as `agent-c-wip-main` — do not merge into 006C-4b branch.
