# Handoff — 005E Market Action Plan (2026-06-20)

Copy-paste this entire document to the next AI agent.

---

## Mission state

Path A zero-click **USER PASS** (Forge.cmd → Danustica, `TBG READY`, PLAY coords `0.34×0.90` @ `(811,764)`).

**This sprint shipped:** F12 market intel **action plan** — tells player what to buy at nearest town and where to ride next. Profit-first ranking; smithing inputs tagged `[smith]` only.

**USER PASS (2026-06-20):** F12 @ Danustica — ACTION PLAN (Felt → Husn Fulq +880), BUY@NEAREST, expanded scan. See [functionality-status.md](../functionality-status.md).

**Next:** Session 2 real forge rank, then LaunchForgeContinue play loop.

---

## Immediate user action (blocking install)

Bannerlord was **running during build** — DLL compiled but **install blocked**.

```powershell
# 1. Quit Bannerlord completely (desktop, not pause)
# 2. From repo root:
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

**PASS:** F7 shows fresh `dllUtc`; F12 feed shows `--- ACTION PLAN ---` and `--- BUY@NEAREST ---`.

---

## What changed (engineering)

| File | Change |
|------|--------|
| `src/BlacksmithGuild/Market/MarketIntelligenceModels.cs` | `TradeRouteRow`, `ActionPlanStep`; report fields `RouteRows`, `ActionPlan`, `ExpandedScanUsed` |
| `src/BlacksmithGuild/Market/MarketIntelligenceService.cs` | `BuildNearestTownRoutes`, `BuildActionPlan`, expanded scan (60u/8 towns), feed + JSON |
| `.gitignore` | `BlacksmithGuild_SmithingAudit.json` |
| `docs/plans/005e-market-intelligence-shop-hotkey.plan.md` | Action plan cert rubric |
| `docs/in-game-surfaces.md` | F12 expected output |
| `NEXT_STEPS.md` | Step 1b updated |

### F12 feed format (target)

```
nearest=Danustica (41.0u) towns=5
--- ACTION PLAN ---
1. Enter Danustica: buy Iron Ore @ 45 (stock 12) [smith]
2. Ride to Poros (18.0u): sell @ 62 (+17)
--- BUY@NEAREST ---
Iron Ore: buy 45 -> Poros 62 (+17) [smith]
--- TOP SPREADS ---
...
```

Zero-spread inventory rows (e.g. `Grain (+0)`) **suppressed** from feed; still in Phase1.log/JSON.

---

## Cert sequence (user + agent)

### Session 1 — Market + dev surfaces

| Step | Action | PASS criteria |
|------|--------|---------------|
| 0 | Close game → `Forge.cmd` | `TBG READY` in Phase1.log |
| 1 | **F11** | `TBG F11: Gold test PASS, +100000.` |
| 2 | **F12** near Danustica | Feed: `ACTION PLAN` + `BUY@NEAREST` |
| 3 | Enter Danustica trade | Top plan item in stock at ~listed price |
| 4 | `CollectCertLogs.cmd` | JSON has `routeRows`, `actionPlan`, `towns` |

### Session 2 — Real forge rank

```powershell
.\scripts\run-session2-real-forge.ps1
```

Or manually: `ProbeForgeRecipes` → `SetForgeCandidateSourceReal` → **Ctrl+Alt+R** → doctrine toggle → re-rank → `ProbeSmithingAudit`.

**PASS:** F7 top candidate `source=real`; `BlacksmithGuild_ForgeRecommendations.json` changes with doctrine.

### Session 3 — Continue play loop

```powershell
# Close game fully first
.\LaunchForgeContinue.cmd
```

Use F12 action plan for town-to-town trading; Ctrl+Alt+R for forge refresh; manual smithy for crafting.

---

## Output paths to analyze

All under Bannerlord install folder unless noted:

| File | Purpose |
|------|---------|
| `BlacksmithGuild_Phase1.log` | Full `TBG REPORT: MARKET INTEL` tables, hotkey trace |
| `BlacksmithGuild_MarketIntel.json` | **`routeRows`**, **`actionPlan`**, **`towns[]`**, `spreadRows`, `inventoryRows`, `expandedScanUsed` |
| `BlacksmithGuild_ForgeRecommendations.json` | Real forge rank evidence (`source=real`) |
| `BlacksmithGuild_RecipeProbe.json` | Template count > 0 |
| `BlacksmithGuild_SmithingAudit.json` | Stage A stamina API probe |
| `BlacksmithGuild_Launch.log` | Forge.cmd / Continue automation |
| `BlacksmithGuild_Status.json` | F7 reload state |
| `CollectCertLogs.cmd` output | Aggregated cert paste block |

Repo logs after collect: `docs/sprint-006i-live-results.md` (update with cert lines).

---

## Known gaps (not fixed this sprint)

| Gap | Impact | Future work |
|-----|--------|-------------|
| No auto buy/sell | Player trades manually | Stage C+ if ever desired; scope-locked read-only |
| 5 towns / 30u horizon | May miss best global route | Expanded fallback to 60u/8; still not map-wide |
| Item universe = party + nearby stock | Won't suggest unstoked goods | Widen candidate sources or category scan |
| Spread rows ignore buy-side stock validation | Global spreads may cite unavailable buy town | Route rows require stock at nearest |
| No travel-time / gold / carry weight | Pure price spread ranking | Economics layer in 005E roadmap |
| Smithing `[smith]` tag is name heuristic | May miss mod items | ItemCategory API when mapped |
| No forge ↔ market bridge | RankForgeCandidates ignores prices for material sourcing | Post real-rank PASS |
| Stamina automation Stages B–D | Cannot auto-craft/rest party | `005e-smithing-posse-stamina-output.plan.md` |
| Gauntlet trade UI panel | Dev hotkey + log only | BACKLOG |
| Continue load re-cert | 006I-5 fix not re-tested | `LaunchForgeContinue.cmd` + Launch.log Module Mismatch |
| Path B culture Back | Not re-certified | Second `Forge.cmd` + Back on culture screen |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Bannerlord running blocks DLL install | Always close game before `Forge.cmd`; check F7 `reload=` |
| F12 swallowed by open panels | Close settlement/menus; Ctrl+Alt+M fallback |
| Empty `routeRows` in sparse region | Expanded scan; ride toward second town; cert documents limit |
| Real forge falls back to stub | Debug `ForgeRealCandidateMapper.cs`; do not start stamina automation |
| 20 commits ahead of origin | Push when user requests; no open PRs |
| UIA automation misfire | `ForgeStop.cmd`; check Launch.log `UIA: CLICK` |

---

## Repo state (post-sprint)

| Field | Value |
|-------|-------|
| Branch | `main` only (no feature branches) |
| Remote | `origin/main` — **ahead by 21 commits** after this commit (user must push) |
| Open PRs | None |
| Version | `v0.0.11` (no bump until user requests) |
| Rollback tag | `006i-4-path-c-pass` @ `57f6062` |
| Working tree | Should be clean after commit |

### Key docs

- [docs/in-game-surfaces.md](../in-game-surfaces.md)
- [docs/forge-zero-click-contract.md](../forge-zero-click-contract.md)
- [docs/plans/005e-market-intelligence-shop-hotkey.plan.md](../plans/005e-market-intelligence-shop-hotkey.plan.md)
- [docs/plans/005e-smithing-posse-stamina-output.plan.md](../plans/005e-smithing-posse-stamina-output.plan.md)
- [docs/plans/006j-full-live-cert-closeout.plan.md](../plans/006j-full-live-cert-closeout.plan.md)
- [NEXT_STEPS.md](../../NEXT_STEPS.md)

### Hotkeys reference

| Key | Command |
|-----|---------|
| F7 | Status |
| F8 | Command list |
| F11 | +100k gold |
| F12 | Market intel (action plan) |
| Ctrl+Alt+M | Market intel fallback |
| Ctrl+Alt+R | Rank forge candidates |
| Ctrl+Alt+S | Rich smithing progression |

---

## Copy-paste prompt for next agent

```text
BlacksmithGuild Bannerlord mod — continue 006J cert + 005E play loop.

DONE: Path A PASS (Danustica, TBG READY). Market intel action plan SHIPPED
(F12 shows ACTION PLAN + BUY@NEAREST; JSON routeRows/actionPlan/towns).

USER MUST: Close Bannerlord → Forge.cmd (install blocked while game running).

YOUR TASKS:
1. Walk user through F11/F12 cert at Danustica — verify ACTION PLAN in feed + JSON.
2. Run scripts\run-session2-real-forge.ps1 — verify source=real via F7 + ForgeRecommendations.json.
3. LaunchForgeContinue.cmd for persistent play loop.
4. Do NOT promise stamina automation (Stages B–D not built).

Evidence: CollectCertLogs.cmd, BlacksmithGuild_MarketIntel.json (routeRows),
BlacksmithGuild_ForgeRecommendations.json, BlacksmithGuild_SmithingAudit.json.

Read: docs/checkpoints/post-005e-market-action-plan-handoff.md, NEXT_STEPS.md,
docs/in-game-surfaces.md.
```

---

## What NOT to do

- Do not start stamina posse implementation before real forge rank PASS
- Do not use Alt+` console gold for cert (F11 canonical)
- Do not treat `click PLAY NOT verified` as failure if map loads
- Do not push to remote unless user asks
- Do not bump mod version unless user asks
