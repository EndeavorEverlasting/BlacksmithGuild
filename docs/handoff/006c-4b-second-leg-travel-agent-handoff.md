# 006C-4b — Second-Leg Auto-Travel (Buy Town → Sell Town)

**Branch:** `feat/006c-4b-second-leg-travel` @ `ad0877e` (stacked on `feat/006c-4-sell-loop` @ `027ac31`)  
**Status:** CODE SHIPPED — build PASS — **USER live cert PENDING** (F7 gate FAIL in agent shell; USER verify required)  
**PR:** [#6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) (draft) → #5

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

## PASS rubric (Track B)

| Check | PASS when |
|-------|-----------|
| Build | `dotnet build -c Release` — 0 errors |
| F7 gate | `campaignReady: true`, `canPollFileInbox: true`, stable ≥60s |
| Guild loop | `TravelToSellTown: Success` then `TryVanillaSell: Success` |
| Map trade | Steps include `TravelToSellTarget:` + `ExecuteSell:Success` |
| Delta | `sellExecution.goldDelta > 0`, `quantitySold > 0` |

---

## USER cert (after F7 PASS)

```powershell
git checkout feat/006c-4b-second-leg-travel
git pull origin feat/006c-4b-second-leg-travel
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
# Long timeout — travel to sell town may take several minutes
.\ExportTbgEvidence.cmd
```

**Setup:** spread row where buy town ≠ sell town (`BlacksmithGuild_MarketIntel.json`).

---

## Output paths

| File | Purpose |
|------|---------|
| `BlacksmithGuild_AutonomousGuildLoop.json` | `TravelToSellTown`, `sellExecution` |
| `BlacksmithGuild_MapTradeCert.json` | `TravelToSellTarget`, `sellExecution` |
| `BlacksmithGuild_MarketIntel.json` | `spreadRows` |
| `BlacksmithGuild_Phase1.log` | `TBG GUILD LOOP MOVE` lines |
| `docs/evidence/latest/` | After ExportTbgEvidence |

---

## Known gaps

- **Live cert not run** — F7 gate pending Agent B USER verify
- Same-town spreads skip second leg (correct)
- Config `false` → 006C-4 honest `TryVanillaSell: Blocked` at buy town
- PR #6 merge blocked until Track B PASS and PR #5 merged (or USER waives)

---

## Rebase note (2026-06-22)

Rebased onto `main` @ `0c9f171` via `feat/006c-4-sell-loop`; no duplicate crash commit.
