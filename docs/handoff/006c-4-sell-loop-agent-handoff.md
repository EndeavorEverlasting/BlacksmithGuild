# 006C-4 — Sell Driver + Multi-Cycle Guild Loop

**Branch:** `feat/006c-4-sell-loop` @ `518f4bd` (+ cert script commits)  
**Status:** CODE SHIPPED — USER live cert **BLOCKED** (Continue + disposable crash on `main`)  
**Baseline fork:** `main` @ `8a00313` (2026-06-22)

---

## Coordination (2026-06-22)

| Agent | Branch | Owns |
|-------|--------|------|
| **Agent B** | `main` | Crash triage, Continue certs, `functionality-status.md`, live-cert handoff |
| **Agent A (this sprint)** | `feat/006c-4-sell-loop` | 006C-4 sell + multi-cycle code, sell cert script, feature handoff |
| **Agent C** | TBD | Parallel sprint — avoid overlapping `main` doc commits with B |

**Merge gate:** Rebase `feat/006c-4-sell-loop` on `origin/main` before merge PR. Do **not** merge until map-ready + sell probe PASS or USER waives.

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

---

## PASS rubric (USER cert)

| Check | PASS when |
|-------|-----------|
| Build | `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release` — 0 errors |
| Sell probe | `BlacksmithGuild_MapTradeSellProbe.json`: `attemptSuccess: true`, `goldDelta > 0`, `quantitySold > 0` |
| Sell cert script | `Run-VanillaSellCert.cmd` exit 0 |
| Guild loop sell | `TryVanillaSell: Success` or honest `Blocked` in guild loop JSON |
| Multi-cycle | `GuildLoopMaxCyclesPerCommand = 2` → `cyclesCompleted: 2`, no infinite loop |

---

## USER cert steps (after map-ready / crash fix)

```powershell
git checkout feat/006c-4-sell-loop
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# F7 stable ≥60s: campaignReady:true, canPollFileInbox:true
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

- **USER live sell cert** — blocked: both Forge.cmd and ForgeContinue.cmd crash before stable F7 (Agent B triage on `main`)
- **Two-leg `BuyProfitGoodAndSell`** — sell at `SellSettlement` requires travel; honest `TryVanillaSell: Blocked` until second leg or multi-cycle reaches sell town
- **PR merge** — draft PR OK; merge after crash fix + cert or USER waives
- **006D food**, **006E hero churn**, **006C-3b interior smelt**, **006C-4b auto second-leg travel** — out of scope

---

## Do NOT touch

- `docs/functionality-status.md` on `main` (Agent B)
- `docs/handoff/live-cert-marathon-agent-handoff.md` (Agent B)
- Launcher UIA / disposable bootstrap crash fix (Agent B / Agent C per assignment)
- 006C-3 smelt code (shipped on main)

---

## Risks

| Risk | Mitigation |
|------|------------|
| `SellItemsAction` overload drift | Signatures in probe JSON |
| Party role inversion | Player = seller, settlement = buyer |
| Multi-cycle infinite loop | Hard cap `GuildLoopMaxCyclesPerCommand` |
| Merge conflict with B doc commits | Rebase feature branch before PR |
| Cert before map-ready | Run-VanillaSellCert exits 2 with honest BLOCKED |
