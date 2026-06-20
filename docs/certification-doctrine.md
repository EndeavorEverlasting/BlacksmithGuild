# Certification Doctrine

**Last updated:** 2026-06-20  
**Authority:** User-directed — live certs are reserved for mutation boundaries, not report surfaces.

Local repo state is canonical until pushed. Public GitHub may be stale relative to local `main`.

---

## Risk tiers

| Tier | Live cert? | Applies to |
|------|------------|------------|
| **0** | No — build + static review | Docs, markdown, command name lists, JSON field additions (non-mutation), report wording, refactors that do not touch game APIs |
| **1** | One lightweight smoke when convenient | Read-only advisory, market/forge report formatting, hotkey feed display, status surfaces |
| **2** | Required | Inventory/gold/stamina/save mutation, launcher/continue automation, reflection into Bannerlord internals |
| **3** | Disposable-first required | New mutation commands, headless smithing/refine/smelt/craft API calls |

### Tier 0 required checks

```powershell
git status --short
dotnet build -c Release
```

---

## Current cert priorities

| Item | Tier | Status |
|------|------|--------|
| Stage B smithing crew advisory | 1 | Code shipped — skip ceremony unless needed for context |
| Stage C charcoal refine | **3** | **Next USER cert** — disposable save, one refine per command |
| Track 2B FORGE MATERIALS | 1 | Code shipped — optional smoke |
| 006J Path B culture Back | 2 | Only when launcher/intro path touched |
| Track 8 caravan/army | — | Blocked until Stage C evaluated |

---

## Stage C cert (Tier 3)

**Goal:** Prove one headless hardwood→charcoal refine mutates inventory safely.

**Save:** Any disposable save (blacksmithing-labeled or explicitly named `disposable`). No precious-save preservation flow.

**Preconditions:**

- Charcoal low (below floor ~2)
- Hardwood present (≥1)
- Campaign map ready (town with smithy not required for headless API — map is enough)

**Commands** (game must be running on map):

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\forge.ps1 -Command ProbeSmithingRefineApi -Wait
.\forge.ps1 -Command RunSmithingSafeActionNow -Wait
.\CollectCertLogs.cmd
```

**PASS when:**

- `BlacksmithGuild_SmithingRefineProbe.json` — `doRefinementMapped: true`
- `BlacksmithGuild_SmithingSafeAction.json` — `"executed": true`, `charcoalAfter > charcoalBefore`, `"refineCount": 1`
- Phase1 — `[TBG FORGE] action=RefineCharcoal ... refineCount=1 reserveBefore ... reserveAfter ...`

**FAIL — smallest fixes only:**

| Failure | Fix scope |
|---------|-----------|
| Probe cannot find API | `SmithingRefineApi.cs` reflection only |
| Wrong formula | Hardwood→charcoal formula selection only |
| Stamina fails | Pre-check + one action (already capped at 1) |
| Wrong game state | Clearer blocked JSON reason |

---

## Save policy

- User does not preserve old saves for cert purposes.
- Saves labeled blacksmithing or `disposable` are fair game.
- Mutation certs run on disposable saves first; Continue only after disposable PASS if ever needed.

---

## Agent log response shape

When user pastes cert output:

```text
Verdict:
Stage C:
Probe:
SafeAction:
Inventory mutation:
Stamina / actor:
PASS/FAIL:
Smallest next fix:
Exact evidence lines:
```

---

## Scope lock

- No push unless user asks
- No Track 8 until Stage C gate evaluated
- No auto-buy/sell, Gauntlet clicks, inventory spawn on Continue
