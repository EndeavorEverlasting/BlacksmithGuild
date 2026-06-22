# 006C-4 — Sell Driver + Multi-Cycle Guild Loop

<<<<<<< Updated upstream
**Branch:** `feat/006c-4-sell-loop` @ `027ac31` (rebased on `main` @ `2dfff05`)  
=======
**Branch:** `feat/006c-4-sell-loop` @ `8316b74` (rebased on `main` @ `5fe3a31`)  
>>>>>>> Stashed changes
**Status:** CODE SHIPPED — build PASS — **USER live cert PENDING** (F7 gate FAIL in agent shell; USER verify required)  
**PR:** #5 (draft) → `main`

---

## Coordination (2026-06-22)

| Agent | Branch | Owns |
|-------|--------|------|
| **Agent B** | `main` | F7 crash gate verify, Continue certs, `functionality-status.md`, live-cert marathon handoff |
| **Agent A** | `feat/006c-4-sell-loop` | 006C-4 sell + multi-cycle code, sell cert script, feature handoff, USER cert Track A |
| **Agent A/C** | `feat/006c-4b-second-leg-travel` | Second-leg travel (stacked); USER cert Track B |

**Merge gate:** Do **not** merge PR #5 until Track A sell probe PASS or USER waives. Rebase on `origin/main` before merge (done @ 2026-06-22).

---

## Shipped

| Deliverable | Path / command |
|-------------|----------------|
| Sell reflection | `MapTradeTradeActionReflection.TryExecuteSell` — PASS = `goldDelta > 0`, inventory down |
| Sell driver | `MapTradeVanillaTradeDriver.TryExecuteSell` |
| Sell probe | `ProbeVanillaSellExecutionNow` → `BlacksmithGuild_MapTradeSellProbe.json` |
| Sell cert script | `Run-VanillaSellCert.cmd` / `scripts/run-vanilla-sell-cert.ps1` |
| Sell missions | `BuyProfitGoodAndSell`, `BuySmithingMaterialThenSellSurplus` |
| Guild loop sell | `TryVanillaSell`, `capabilities.tradeSell`, `sellExecution` JSON |
| Multi-cycle | `GuildLoopMaxCyclesPerCommand`; `cycleIndex`, `cyclesCompleted`, `maxCycles` |
| Evidence export | `BlacksmithGuild_MapTradeSellProbe.json` in `export-tbg-evidence.ps1` |

---

## PASS rubric (USER cert — Track A)

| Check | PASS when |
|-------|-----------|
| Build | `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release` — 0 errors |
| F7 gate | `campaignReady: true`, `canPollFileInbox: true`, stable ≥60s on map |
| Sell probe | `BlacksmithGuild_MapTradeSellProbe.json`: `attemptSuccess: true`, `goldDelta > 0`, `quantitySold > 0` |
| Sell cert script | `Run-VanillaSellCert.cmd` exit 0 |
| Guild loop sell | `TryVanillaSell: Success` or honest `Blocked` in guild loop JSON |
| Multi-cycle | `GuildLoopMaxCyclesPerCommand = 2` → `cyclesCompleted: 2`, no infinite loop |

---

## USER cert steps (after F7 PASS)

```powershell
git checkout feat/006c-4-sell-loop
git pull origin feat/006c-4-sell-loop
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# F7 stable ≥60s: campaignReady:true, canPollFileInbox:true — keep Bannerlord focused
.\Run-VanillaSellCert.cmd
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

Multi-cycle cert (optional):

```powershell
# Set GuildLoopMaxCyclesPerCommand = 2 in DevToolsConfig (cert only)
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
```

---

## Output paths to analyze

| File | Purpose |
|------|---------|
| `<Bannerlord>/BlacksmithGuild_MapTradeSellProbe.json` | Sell probe verdict + delta proof |
| `<Bannerlord>/BlacksmithGuild_MapTradeProbe.json` | Buy probe (006C-1 baseline) |
| `<Bannerlord>/BlacksmithGuild_AutonomousGuildLoop.json` | Guild loop steps, sellExecution, cycle fields |
| `<Bannerlord>/BlacksmithGuild_MarketIntel.json` | Mission selection (spreadRows, inventoryRows) |
| `<Bannerlord>/BlacksmithGuild_Phase1.log` | `TBG MAP TRADE SELL PROBE` lines |
| `docs/evidence/latest/` | Mirrored after ExportTbgEvidence |

---

## Known gaps (honest)

- **USER live sell cert** — not run; F7 gate pending Agent B USER verify on Continue save
- **Two-leg sell at buy town** — fixed in 006C-4b (`feat/006c-4b-second-leg-travel`); without it, honest `TryVanillaSell: Blocked` at buy town
- **PR merge** — draft PR #5 OK; merge after Track A cert PASS or USER waives
- **006D food**, **006E hero churn**, **006C-3b interior smelt** — out of scope

---

## Do NOT touch

- `docs/functionality-status.md` on `main` (Agent B)
- `docs/handoff/live-cert-marathon-agent-handoff.md` (Agent B)
- Launcher UIA / disposable bootstrap crash fix (Agent B)
- 006C-3 smelt code (shipped on main)

---

## Risks

| Risk | Mitigation |
|------|------------|
| `SellItemsAction` overload drift | Signatures in probe JSON |
| Party role inversion | Player = seller, settlement = buyer |
| Multi-cycle infinite loop | Hard cap `GuildLoopMaxCyclesPerCommand` |
| Cert before map-ready | Run-VanillaSellCert exits 2 with honest BLOCKED |
| Focus theft during cert | Keep Bannerlord focused; not Cursor/Chrome |
