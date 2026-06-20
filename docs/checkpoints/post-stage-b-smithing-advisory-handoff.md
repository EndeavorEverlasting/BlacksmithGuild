# Handoff — Track 2A PASS + Stage B Smithing Advisory (2026-06-20)

Copy-paste this entire document to the next AI agent.

---

## Mission state

| Item | Status |
|------|--------|
| **Track 2A map rank** | **USER PASS** 2026-06-20 @ 16:34 — screenshot: `[PASS] requested=Real resolved=real`, Javelin top, manual javelin craft on Continue save |
| **Stage B smithing advisory** | **CODE SHIPPED** — crew roles, charcoal/hardwood reserve, prep steps in ACTION PLAN, Ctrl+Alt+G guild loop |
| **Stage C auto-refine** | **FOUNDATION ONLY** — `RunSmithingSafeActionNow` inbox; RefineCharcoal API not mapped (returns blocked JSON) |
| **006J 1D Path B** | **USER PENDING** |
| **Branch** | `main`, working tree clean after commit, ahead of origin — push when user requests |

Prior commits: `cc739c1` (007C table spacing + Real-first), this sprint adds Stage B.

---

## What was shipped

| Feature | Trigger | Output |
|---------|---------|--------|
| **SMITHING CREW** on forge rank | **Ctrl+Alt+R** | `--- SMITHING CREW ---` — companion roles, stamina labels |
| **Charcoal prep steps** | Ctrl+Alt+R / Ctrl+Alt+G | ACTION PLAN: `{Companion}: refine hardwood→charcoal` when low charcoal + hardwood available |
| **Guild loop** | **Ctrl+Alt+G** | Market (cache/scan) + forge rank + smithing crew unified report |
| **Smithing advisory** | inbox `RunSmithingAdvisoryNow` | `BlacksmithGuild_SmithingAdvisory.json` |
| **Safe action stub** | inbox `RunSmithingSafeActionNow` | `BlacksmithGuild_SmithingSafeAction.json` — blocked until refine API mapped |

**Worker doctrine:** lowest Crafting skill companion for RefineCharcoal; highest skill for CraftRanked (main hero when best).

**No inventory spawn scripts** — Continue save scope-locked.

---

## Key files

| Path | Role |
|------|------|
| `src/BlacksmithGuild/Forge/SmithingAdvisoryPlanner.cs` | Reserve gaps, crew, prep steps, material enrichment |
| `src/BlacksmithGuild/Forge/SmithingWorkerSelector.cs` | Grunt vs craft hero selection |
| `src/BlacksmithGuild/Forge/SmithingStaminaReader.cs` | GetHeroCraftingStamina / SetActiveCraftingHero reflection |
| `src/BlacksmithGuild/Forge/SmithingAdvisoryService.cs` | Advisory command + JSON |
| `src/BlacksmithGuild/Forge/GuildLoopService.cs` | Ctrl+Alt+G orchestration |
| `src/BlacksmithGuild/Forge/SmithingSafeActionService.cs` | Stage C inbox (blocked refine) |
| `src/BlacksmithGuild/Forge/ForgeAdvisoryPlanner.cs` | ACTION PLAN merges prep steps |
| `src/BlacksmithGuild/DevTools/DevHotkeyHandler.cs` | Ctrl+Alt+G binding |

---

## Certified (USER PASS)

- Ctrl+Alt+M market intel (Continue + Danustica)
- 007B report UX + forge ACTION PLAN
- **Track 2A real forge on map** — screenshot 16:34: Real/Javelin/PASS; prior Session 2 disposable cert
- 006I-5 Continue, Path A/C, Smithing Stage A audit
- 007A Ctrl+Alt+M primary

---

## NOT certified (next live certs)

| Priority | Gate | PASS criteria |
|----------|------|---------------|
| **1** | **Stage B USER cert** | Short charcoal on map → Ctrl+Alt+R shows SMITHING CREW with companion RefineCharcoal + prep step in ACTION PLAN |
| **2** | **Stage C refine execution** | inbox `RunSmithingSafeActionNow` mutates inventory after API mapped |
| **3** | **006J 1D Path B** | Culture Back once — intro does not replay |

---

## USER smoke protocol

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\LaunchForgeContinue.cmd   # or Forge.cmd
# Low charcoal scenario on map:
Ctrl+Alt+M
Ctrl+Alt+R                  # or Ctrl+Alt+G for full guild loop
F7
.\CollectCertLogs.cmd
```

**Stage B PASS when feed shows:**

```text
--- SMITHING CREW ---
[1] {Companion} | RefineCharcoal | hardwood→charcoal x{N} | stamina … — low-skill grunt work
[2] {MainHero} | CraftRanked | Javelin | …

--- ACTION PLAN ---
1. {Companion}: refine hardwood→charcoal x{N} at smithy (…)
2. Enter smithy: craft …
```

**Track 2A re-check (optional):** `BlacksmithGuild_ForgeRecommendations.json` → `"source":"real"`, `"fallbackUsed":false`.

---

## Output paths to analyze

```
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_ForgeRecommendations.json
  BlacksmithGuild_SmithingAdvisory.json
  BlacksmithGuild_SmithingSafeAction.json
  BlacksmithGuild_MarketIntel.json
  BlacksmithGuild_Status.json          ← Get-Content -LiteralPath
  BlacksmithGuild_Phase1.log
```

---

## Known gaps

| Gap | Notes |
|-----|-------|
| Stage B USER cert | Code shipped; needs charcoal-short smoke on Continue |
| Stage C RefineCharcoal API | Headless refine not mapped — safe action returns blocked |
| Smelt automation | Advisory only |
| Track 2B FORGE MATERIALS market section | Partial via material gaps |
| 006J Path B + full tag | Pending |
| Push to origin | User requests when ready |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Stamina read fails on companions | Feed shows `stamina ?`; crew assignment still works by skill |
| Refine API never headless | Stage C stays advisory + SetActiveCraftingHero only |
| Main hero assigned grunt if solo party | Worker selector allows main when only hero |
| Safe action mistaken for working auto | JSON `executed:false` + WARN feed |

---

## Next agent tasks

1. User Stage B smoke on Continue with low charcoal — record PASS in functionality-status
2. Probe Bannerlord refine API for Stage C (disposable save first)
3. User 006J Path B when ready
4. Track 2B `--- FORGE MATERIALS ---` in market report
5. Push only when user requests

---

## Scope lock

No inventory spawn on Continue, no auto-buy/sell, no Gauntlet UI clicks, no Aserai autobuild, no Stage D rest optimizer.

---

## Hotkeys

| Key | Action |
|-----|--------|
| Ctrl+Alt+M | Market intel |
| Ctrl+Alt+R | Forge rank + smithing crew + ACTION PLAN |
| Ctrl+Alt+G | Guild loop (market + forge + crew) |
| F7 | Status |
| inbox | `RunSmithingAdvisoryNow`, `RunSmithingSafeActionNow` |

---

## Rollback

```powershell
git checkout cc739c1   # before Stage B
git checkout 006i-5-continue-pass
```
