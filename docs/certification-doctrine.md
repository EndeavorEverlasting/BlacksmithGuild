# Certification Doctrine

**Last updated:** 2026-06-21  
**Authority:** User-directed — live certs are reserved for mutation boundaries, not report surfaces.

Local repo state is canonical until pushed. **Launcher cert gate CLOSED** — see [pre-blacksmith-automation-handoff.md](checkpoints/pre-blacksmith-automation-handoff.md).

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
| Launcher / bootstrap (006I) | 2 | **CLOSED** — Path A, Continue, Path C PASS; Path B waived |
| Stage B smithing crew advisory | 1 | **USER PASS** 2026-06-21 |
| Stage C charcoal refine | **3** | **USER PASS 2026-06-20** |
| Track 2B FORGE MATERIALS | 1 | Code shipped — optional |
| 005E smithing posse automation | 2–3 | **UNBLOCKED** — next engineering |
| Party travel automation | **2** | **Shipped (Tier 2 smoke pending)** — see [007-auto-travel.plan.md](plans/007-auto-travel.plan.md) |

---

## Stage C cert (Tier 3) — **USER PASS recorded 2026-06-20**

**Status:** PASS on Continue save (Danustica area) @ 17:52:13 UTC. Charcoal 0→1, hardwood 5→3, `refineCount=1`, commit `951f480`.

**Re-cert only if** mutation code in `SmithingRefineApi`, `SmithingSafeActionService`, or refine guardrails changes.

**Stale JSON caveat:** `BlacksmithGuild_SmithingSafeAction.json` reflects the **latest** run. A successful mutation followed by a blocked run (e.g. hardwood=0) leaves JSON showing `executed: false` while Phase1 retains the PASS line. Cert helper (`run-stage-c-charcoal-cert.ps1`) falls back to Phase1 when JSON is stale.

**Goal:** Prove one headless hardwood→charcoal refine mutates inventory safely.

**Save:** Any disposable save (blacksmithing-labeled or explicitly named `disposable`). No precious-save preservation flow.

**Preconditions:**

- Charcoal low (below floor ~2)
- Hardwood present (≥1) — if missing, buy at town Trade first
- Campaign map ready — **no smithy UI needed** (headless from map)

**One-command helper** (game running on map):

```powershell
.\RunStageCCharcoalCert.cmd
```

Or manually:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\forge.ps1 -Command ProbeSmithingRefineApi -Wait
.\forge.ps1 -Command RunSmithingSafeActionNow -Wait
.\CollectCertLogs.cmd
```

### In-game setup

1. Load disposable save.
2. Reach campaign map.
3. If hardwood = 0: enter town → **Trade** → buy 1–5 **Hardwood** (do not buy charcoal).
4. Return to campaign map.
5. Run `RunStageCCharcoalCert.cmd` from PowerShell.

### Stale command replay (fixed)

If the feed shows `blocked: hardwood shortage` **immediately on Continue load** without you running the cert, that was a **stale inbox replay** from a prior session — not a failed cert. Rebuild/install, relaunch; the inbox is now cleared after consume and before launch.

If you intentionally run Stage C with hardwood = 0, the mod correctly blocks with `"blockedReason": "hardwood shortage"` — buy hardwood and rerun.

**Commands** (game must be running on map):

**PASS when:**

- `BlacksmithGuild_SmithingRefineProbe.json` — `doRefinementMapped: true`
- **Either** `BlacksmithGuild_SmithingSafeAction.json` — `"executed": true`, `charcoalAfter > charcoalBefore`, `"refineCount": 1`
- **Or** Phase1 — latest `[TBG FORGE] action=RefineCharcoal ... reserveAfter charcoal=N` where `charcoalAfter > charcoalBefore` (when JSON is stale from a later blocked run)
- Phase1 — `[TBG FORGE] action=RefineCharcoal ... refineCount=1 reserveBefore ... reserveAfter ...`

**FAIL — smallest fixes only:**

| Failure | Fix scope |
|---------|-----------|
| Probe cannot find API | `SmithingRefineApi.cs` reflection only |
| Wrong formula | Hardwood→charcoal formula selection only |
| Stamina fails | Pre-check + one action (already capped at 1) |
| Wrong game state | Clearer blocked JSON reason |

---

## Party travel cert (Tier 2) — smoke pending

**Status:** Code integrated on `integrate/pr-1-auto-travel`; **USER smoke not yet recorded**.

**Save:** Disposable or Continue save on campaign map (`campaignReady: true`).

```powershell
.\forge.ps1 -Command ShowAutoTravelChoices -Wait
.\forge.ps1 -Command AutoTravelChoice1 -Wait
```

**PASS when Phase1 contains:**

```text
[TBG TRAVEL] auto-travel started to <town>
```

Optional: visual party movement on map; hostile pause when a war party blocks the route.

Full plan: [007-auto-travel.plan.md](plans/007-auto-travel.plan.md)

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
- No Track 8 until user directs — Stage C gate **passed**
- No auto-buy/sell, Gauntlet clicks, inventory spawn on Continue
