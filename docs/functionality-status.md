# Functionality Status

**Last updated:** 2026-06-20  
**Mod version:** `v0.0.11`  
**Branch:** `main` (see latest commit)

Canonical snapshot of what works today, what is certified, and what is not built yet.

---

## Recent fixes (2026-06-20)

| Fix | Detail |
|-----|--------|
| **forge.ps1 allowlist drift** | `ProbeForgeRecipes`, `ProbeSmithingAudit`, `MarketSnapshotNow`, auto-build commands now in [`scripts/dev-command-names.ps1`](scripts/dev-command-names.ps1) |
| **Forge.cmd false FAIL** | After PLAY click, launcher waits up to 240s for `Bannerlord.exe`; polls Phase1 for `TBG READY` pre-handoff; WARN (not FAIL) if map ready at timeout |

## Certified (user PASS)

| Feature | How to use | Evidence |
|---------|------------|----------|
| **Zero-click bootstrap (Path A)** | `Forge.cmd` | Map + `TBG READY`; PLAY click `(811,764)` fractions `0.34×0.90` |
| **Dev harness hotkeys** | F7 status, F8 command list, F11 +100k gold | Feed ack lines on campaign map |
| **Market intel action plan** | **F12** (Ctrl+Alt+M fallback) | **USER PASS 2026-06-20** — Danustica: ACTION PLAN + BUY@NEAREST + TOP SPREADS |
| **Real forge rank** | Session 2 script / Ctrl+Alt+R | **USER PASS 2026-06-20** — `source=real`, templates=12, top=Javelin, `fallbackUsed=false` |
| **Smithing audit (Stage A)** | `ProbeSmithingAudit` | **USER PASS 2026-06-20** — `GetHeroCraftingStamina`/`SetHeroCraftingStamina` hints |
| **Path C quit loop** | Quit to main menu | Tag `006i-4-path-c-pass` |

### F12 cert evidence (2026-06-20, Danustica @ 4.1u)

Feed showed:

- `expanded scan (no routes in 30u)` — fallback to 60u/8 towns engaged
- **ACTION PLAN:** buy Felt @253 (stock 7) → ride Husn Fulq (52.9u) sell @1133 (+880)
- **BUY@NEAREST:** Felt, Planks, Oil ranked by spread
- **TOP SPREADS:** cross-town pairs including Velvet buy@Onira → sell@Danustica

JSON: `<Bannerlord>\BlacksmithGuild_MarketIntel.json` with `routeRows`, `actionPlan`, `towns`.

---

## Shipped but not user-certified

| Feature | How to use | PASS criteria | Blocker |
|---------|------------|---------------|---------|
| **Continue load (006I-5)** | `LaunchForgeContinue.cmd` | Map loads; Launch.log `clicked Module Mismatch Yes` if dialog shown | Not re-tested since 006I-5 ship |
| **Path B culture Back** | Second `Forge.cmd`; press Back on culture screen | Intro cutscene does **not** replay | Not re-certified |

---

## Available today (play loop)

Use on **disposable save** (`Forge.cmd`) or **Continue save** after cert:

```text
1. F12 on map     → action plan: buy @ nearest, ride to sell town
2. Enter town     → trade manually (no auto buy/sell)
3. Ctrl+Alt+R     → refresh forge recommendations (after real source set)
4. Enter smithy   → craft manually (game UI)
5. F12 at next town → next route
```

**Funding tests:** F11 (+100k gold) on disposable save only.

**Smithing setup:** Ctrl+Alt+S (rich progression) or inbox `RichSmithingProgressionTest`.

---

## Not built (do not promise)

| Area | Plan doc | Notes |
|------|----------|-------|
| Auto buy/sell | — | Read-only market intel; scope-locked |
| Stamina posse automation (Stages B–D) | [005e-smithing-posse-stamina-output.plan.md](plans/005e-smithing-posse-stamina-output.plan.md) | Blocked on real forge rank cert + API mapping |
| Forge ↔ market bridge | — | RankForgeCandidates ignores market prices for ore sourcing |
| Gauntlet trade UI panel | [005e-market-intelligence-shop-hotkey.plan.md](plans/005e-market-intelligence-shop-hotkey.plan.md) | BACKLOG |
| Travel cost / gold / carry weight in routes | — | Pure price spread ranking only |

---

## Hotkey reference

| Key | Action |
|-----|--------|
| F7 | Status summary |
| F8 | Command list |
| F9 | Advance one day |
| F10 | Toggle fast-forward |
| F11 | +100k gold (disposable cert) |
| F12 | Market intel action plan |
| Ctrl+Alt+M | Market intel fallback |
| Ctrl+Alt+R | Rank forge candidates |
| Ctrl+Alt+S | Rich smithing progression |

Full detail: [in-game-surfaces.md](in-game-surfaces.md)

---

## Output files (Bannerlord install folder)

| File | When written |
|------|--------------|
| `BlacksmithGuild_Phase1.log` | Always — full reports + trace |
| `BlacksmithGuild_MarketIntel.json` | F12 |
| `BlacksmithGuild_ForgeRecommendations.json` | Rank / daily tick |
| `BlacksmithGuild_RecipeProbe.json` | `ProbeForgeRecipes` |
| `BlacksmithGuild_SmithingAudit.json` | `ProbeSmithingAudit` |
| `BlacksmithGuild_Launch.log` | Forge.cmd / Continue automation |
| `BlacksmithGuild_Status.json` | F7 |

Collect: `CollectCertLogs.cmd`

---

## Next session

See [NEXT_STEPS.md](../NEXT_STEPS.md) — **Session 2: real forge rank**, then **LaunchForgeContinue** play loop.
