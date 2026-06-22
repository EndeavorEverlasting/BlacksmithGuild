# 006C-4 — Sell Driver + Multi-Cycle Guild Loop

**Branch:** `feat/006c-4-sell-loop`  
**Status:** CODE SHIPPED — USER live cert pending (map-ready gate)  
**Baseline fork:** `main` @ `8a00313` (2026-06-22)

---

## Shipped

| Deliverable | Path / command |
|-------------|----------------|
| Sell reflection (delta proof) | `MapTradeTradeActionReflection.TryExecuteSell` — PASS = `goldDelta > 0`, `inventoryDelta < 0` |
| Sell driver | `MapTradeVanillaTradeDriver.TryExecuteSell` |
| Sell probe | `ProbeVanillaSellExecutionNow` → `<Bannerlord>/BlacksmithGuild_MapTradeSellProbe.json` |
| Sell missions | `BuyProfitGoodAndSell`, `BuySmithingMaterialThenSellSurplus` in `MapTradeMissionSelector` |
| Guild loop sell step | `TryVanillaSell` + `capabilities.tradeSell` in `BlacksmithGuild_AutonomousGuildLoop.json` |
| Multi-cycle | `GuildLoopMaxCyclesPerCommand` wired; JSON fields `cycleIndex`, `cyclesCompleted`, `maxCycles` |

---

## PASS rubric (USER cert)

| Check | PASS when |
|-------|-----------|
| Build | `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release` — 0 errors |
| Sell probe | `BlacksmithGuild_MapTradeSellProbe.json`: `attemptSuccess: true`, `goldDelta > 0`, `quantitySold > 0` |
| Guild loop sell | `cycleSteps` contains `TryVanillaSell: Success` or honest `Blocked` |
| Multi-cycle | Set `GuildLoopMaxCyclesPerCommand = 2`, run `RunAutonomousGuildLoopNow` → `cyclesCompleted: 2`, no infinite loop |

---

## USER cert steps (after map-ready)

```powershell
.\ForgeContinue.cmd
# F7: campaignReady:true, canPollFileInbox:true
# At town with trade goods in inventory:
.\forge.ps1 -Command ProbeVanillaSellExecutionNow -Wait
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

Multi-cycle cert (optional):

```powershell
# Temporarily set GuildLoopMaxCyclesPerCommand = 2 in DevToolsConfig or agent config
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
# Expect cycleSteps with two CycleBoundary entries and cyclesCompleted: 2
```

---

## Output paths to analyze

| File | Purpose |
|------|---------|
| `<Bannerlord>/BlacksmithGuild_MapTradeSellProbe.json` | Sell probe verdict + delta proof |
| `<Bannerlord>/BlacksmithGuild_MapTradeProbe.json` | Buy probe (006C-1 baseline) |
| `<Bannerlord>/BlacksmithGuild_AutonomousGuildLoop.json` | Guild loop steps, sellExecution, cycle fields |
| `<Bannerlord>/BlacksmithGuild_MarketIntel.json` | Mission selection inputs (spreadRows, inventoryRows) |
| `docs/evidence/latest/` | Mirrored evidence after ExportTbgEvidence |

---

## Known gaps (honest)

- **USER live sell cert** — blocked until Continue/disposable map loads without crash (Agent B backlog)
- **Two-leg `BuyProfitGoodAndSell`** — buy at buy town works on first arrival; sell at sell town requires travel to `SellSettlement` (honest `TryVanillaSell: Blocked` until second leg or multi-cycle reaches sell town)
- **006D food/steward**, **006E hero churn**, **006C-3b interior smelt** — out of scope
- **PR merge** — wait for Agent B Continue cert verdicts on `main`, then `git rebase origin/main` before PR

---

## Do NOT touch (coordination)

- `docs/functionality-status.md` on `main` (Agent B owns)
- `docs/handoff/live-cert-marathon-agent-handoff.md`
- Launcher automation / disposable Forge.cmd crash fix
- 006C-3 smelt code (shipped on main)

---

## Risks

| Risk | Mitigation |
|------|------------|
| `SellItemsAction` overload drift | Signatures logged in probe JSON; same reflection loop as buy |
| Party role inversion | `TryInvokeSellItemsAction` uses player=seller, settlement=buyer |
| Multi-cycle infinite loop | Hard cap `GuildLoopMaxCyclesPerCommand`; re-enter only from `Complete` path |
| Sell before buy on spread mission | Buy runs first at buy town; sell blocked until at sell settlement |
