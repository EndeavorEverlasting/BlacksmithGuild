# Functionality Status

**Last updated:** 2026-06-20 (Stage C refine API mapped + Track 2B forge materials)  
**Mod version:** `v0.0.11`  
**Branch:** `main` — Track 2A **USER PASS**; Stage B **code shipped**; Stage C **API mapped, USER cert PENDING**

Canonical snapshot of what works today, what is certified, and what is not built yet.

**Cert doctrine:** [certification-doctrine.md](certification-doctrine.md) — Tier 0–3; Stage C is the only required USER cert now.

---

## Recent fixes (2026-06-20)

| Fix | Detail |
|-----|--------|
| **Stage C refine API mapped** | `SmithingRefineApi` — `DoRefinement` + `GetRefiningFormulas`; inbox `RunSmithingSafeActionNow` invokes headless hardwood→charcoal — **USER cert PENDING** (disposable save first) |
| **Track 2B FORGE MATERIALS** | Ctrl+Alt+M report — party charcoal/hardwood shortfalls + nearest-town smithing stock/prices |
| **ProbeSmithingRefineApi** | inbox command — writes `BlacksmithGuild_SmithingRefineProbe.json` with method hints |
| **Stage B smithing crew advisory** | **Ctrl+Alt+R**, **Ctrl+Alt+G**, inbox `RunSmithingAdvisoryNow` | **CODE SHIPPED** — SMITHING CREW, charcoal refine prep, companion role assignment — **USER cert PENDING** |
| **007C market table spacing** | Ctrl+Alt+M file report | Wider columns, ellipsis — visual check optional |
| **Module Mismatch verify-dismiss** | `52c2114` — retry until `IsAnyInquiryActive` false; `confirmed (inquiry cleared)` log line |
| **forge.ps1 allowlist drift** | `ProbeForgeRecipes`, `ProbeSmithingAudit`, `MarketSnapshotNow`, auto-build commands now in [`scripts/dev-command-names.ps1`](scripts/dev-command-names.ps1) |
| **Forge.cmd false FAIL** | After PLAY click, launcher waits up to 240s for `Bannerlord.exe`; polls Phase1 for `TBG READY` pre-handoff; WARN (not FAIL) if map ready at timeout |

## Certified (user PASS)

| Feature | How to use | Evidence |
|---------|------------|----------|
| **Zero-click bootstrap (Path A)** | `Forge.cmd` | Map + `TBG READY`; PLAY click `(811,764)` fractions `0.34×0.90` |
| **Dev harness hotkeys** | F7 status, F8 command list, F11 +100k gold | Feed ack lines on campaign map |
| **Market intel action plan** | **Ctrl+Alt+M** | **USER PASS 2026-06-20** — Continue (Poros) + Danustica smoke: `MarketSnapshotNow`, ACTION PLAN, BUY@NEAREST, TOP SPREADS, Hardwood `[smith]`. **Blacksmith Guild** headers + colored sections. |
| **007B report UX + forge ACTION PLAN** | **Ctrl+Alt+R**, **F7** | **USER PASS 2026-06-20** — Danustica smoke: branding, ACTION PLAN, honest stub JSON |
| **Track 2A real forge on map** | **Ctrl+Alt+R** on campaign map | **USER PASS 2026-06-20 @ 16:34** — screenshot: `requested=Real resolved=real`, Javelin top, `[PASS]`; manual javelin craft on Continue save |
| **Real forge rank (Session 2 disposable cert)** | Session 2 script with `SetForgeCandidateSourceReal` | **USER PASS 2026-06-20** — disposable cert: `source=real`, templates=12, top=Javelin, `fallbackUsed=false` |
| **Smithing audit (Stage A)** | `ProbeSmithingAudit` | **USER PASS 2026-06-20** — `GetHeroCraftingStamina`/`SetHeroCraftingStamina` hints |
| **Path C quit loop** | Quit to main menu | Tag `006i-4-path-c-pass` |
| **Continue load (006I-5)** | `LaunchForgeContinue.cmd` | **USER PASS 2026-06-20** — Tevea map; Phase1 `confirmed (inquiry cleared)`; tag `006i-5-continue-pass` @ `52c2114` |

### Continue cert evidence (2026-06-20, cared-about save @ Tevea)

Phase1 (15:18:49):

- `Module Mismatch inquiry queued (event)`
- `Module Mismatch auto-Yes attempt=1 inquiryActive=false`
- `Module Mismatch auto-Yes confirmed (inquiry cleared) source=deferred`
- `TBG READY: campaign map ready`

Fix history: `687cb1b` deferred invoke logged success but dialog persisted; `52c2114` verify-dismiss resolved.

**Market intel smoke test:** USER PASS with hotkey collision. F12 produced useful market action output, but F12 conflicts with Steam screenshots. Primary hotkey changed to **Ctrl+Alt+M**.

**Forge recommendation status:** Ctrl+Alt+R on map produces Real rank with SOURCE HONESTY / SMITHING CREW / MATERIAL GAPS / ACTION PLAN. **Track 2A USER PASS** @ 16:34 (Real, Javelin, `[PASS]`). Stage B adds companion charcoal refine prep when reserves low.

**Status.json collection:** use `Get-Content -LiteralPath` (path contains `&`) or `CollectCertLogs.cmd` — not a mod failure if bare `Get-Content` errors.

---

## Shipped but not user-certified

| Feature | How to use | PASS criteria | Blocker |
|---------|------------|---------------|---------|
| **Stage B smithing crew** | **Ctrl+Alt+R** or **Ctrl+Alt+G** when charcoal low | SMITHING CREW + prep step | **Tier 1 — cert optional** |
| **Stage C auto-refine** | inbox `RunSmithingSafeActionNow` on disposable save | `executed=true`, `charcoalAfter > charcoalBefore`, `refineCount=1` | **Tier 3 — USER cert next** |
| **Track 2B forge materials** | **Ctrl+Alt+M** | `--- FORGE MATERIALS ---` party reserves + nearest buy | **CODE SHIPPED** — visual check optional |
| **Path B culture Back** | Second `Forge.cmd`; press Back on culture screen | Intro cutscene does **not** replay | Not re-certified |

### Market intel cert evidence (2026-06-20, Continue save near Tevea/Zestica)

Feed showed:

- `source: MarketSnapshotNow`
- nearest Poros; towns=3
- **ACTION PLAN**, **BUY@NEAREST**, **TOP SPREADS** with nonzero prices/spreads
- (Prior Danustica cert: expanded scan fallback 60u/8 towns; Felt → Husn Fulq +880)

JSON: `<Bannerlord>\BlacksmithGuild_MarketIntel.json` with `routeRows`, `actionPlan`, `towns`.

---

## Available today (play loop)

Use on **disposable save** (`Forge.cmd`) or **Continue save** after cert:

```text
1. Ctrl+Alt+M on map → action plan: buy @ nearest, ride to sell town
2. Enter town       → trade manually (no auto buy/sell)
3. Ctrl+Alt+R       → forge rank + smithing crew + ACTION PLAN (or Ctrl+Alt+G guild loop)
4. Enter smithy     → craft manually (game UI)
5. Ctrl+Alt+M at next town → next route
```

**Funding tests:** F11 (+100k gold) on disposable save only.

**Smithing setup:** Ctrl+Alt+S (rich progression) or inbox `RichSmithingProgressionTest`.

---

## Not built (do not promise)

| Area | Plan doc | Notes |
|------|----------|-------|
| Auto buy/sell | — | Read-only market intel; scope-locked |
| Stamina posse automation (Stage C–D) | [005e-smithing-posse-stamina-output.plan.md](plans/005e-smithing-posse-stamina-output.plan.md) | Stage B advisory shipped; Stage C API mapped — USER cert on disposable save |
| Forge ↔ market bridge (forge rank) | — | Per-material buy steps when Real + cached Ctrl+Alt+M — **code shipped**; Track 2B FORGE MATERIALS section **shipped** |
| Gauntlet trade UI panel | [005e-market-intelligence-shop-hotkey.plan.md](plans/005e-market-intelligence-shop-hotkey.plan.md) | BACKLOG |
| Travel cost / gold / carry weight in routes | — | Pure price spread ranking only |
| Character doctrine (Aserai Trade-Smith) | [007a-guild-loop-advisory-automation.plan.md](plans/007a-guild-loop-advisory-automation.plan.md) | Planned. Default target is Aserai Trade-Smith with Khuzait mounted fallback. Config/logging only after live-cert gate. |

---

## Hotkey reference

| Key | Action |
|-----|--------|
| F7 | Status summary |
| F8 | Command list |
| F9 | Advance one day |
| F10 | Toggle fast-forward |
| F11 | +100k gold (disposable cert) |
| Ctrl+Alt+M | Market intel action plan (primary) |
| Ctrl+Alt+R | Rank forge candidates + smithing crew |
| Ctrl+Alt+G | Guild loop (market + forge + crew) |
| Ctrl+Alt+S | Rich smithing progression |
| F12 | Market intel (legacy only; `LegacyF12MarketHotkey=true`; conflicts with Steam) |

Full detail: [in-game-surfaces.md](in-game-surfaces.md)

---

## Output files (Bannerlord install folder)

| File | When written |
|------|--------------|
| `BlacksmithGuild_Phase1.log` | Always — full reports + trace |
| `BlacksmithGuild_MarketIntel.json` | Ctrl+Alt+M |
| `BlacksmithGuild_ForgeRecommendations.json` | Rank / daily tick |
| `BlacksmithGuild_RecipeProbe.json` | `ProbeForgeRecipes` |
| `BlacksmithGuild_SmithingAudit.json` | `ProbeSmithingAudit` |
| `BlacksmithGuild_SmithingAdvisory.json` | Ctrl+Alt+R / Ctrl+Alt+G / `RunSmithingAdvisoryNow` |
| `BlacksmithGuild_SmithingSafeAction.json` | inbox `RunSmithingSafeActionNow` |
| `BlacksmithGuild_SmithingRefineProbe.json` | inbox `ProbeSmithingRefineApi` |
| `BlacksmithGuild_Launch.log` | Forge.cmd / Continue automation |
| `BlacksmithGuild_Status.json` | F7 |

Collect: `CollectCertLogs.cmd` (uses `-LiteralPath`). Manual:

```powershell
Get-Content -LiteralPath "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json"
```

---

## Next session

See [007a-guild-loop-advisory-automation.plan.md](plans/007a-guild-loop-advisory-automation.plan.md) — **Track 2A USER PASS**; **Stage B USER cert PENDING**; **Stage C USER cert PENDING** (disposable save); **006J** Path B Back pending.
