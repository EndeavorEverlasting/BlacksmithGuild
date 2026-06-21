# Functionality Status

**Last updated:** 2026-06-21 (008C-Fix visible assistive launch separation; USER cert PENDING)  
**Mod version:** `v0.0.11`  
**Branch:** `main` — 008C-Fix **USER visible cert PENDING**

Canonical snapshot of what works today, what is certified, and what is not built yet.

**Next handoff:** [plans/008c-character-choice-catalog-build-variant-runner.plan.md](plans/008c-character-choice-catalog-build-variant-runner.plan.md)

**Cert doctrine:** [certification-doctrine.md](certification-doctrine.md) — Tier 0–3; Stage C **USER PASS** recorded; no further Stage C cert unless mutation code regresses.

---

## Recent fixes (2026-06-20)

| Fix | Detail |
|-----|--------|
| **Stage C charcoal refine** | `SmithingRefineApi` — headless hardwood→charcoal via inbox `RunSmithingSafeActionNow` — **USER PASS 2026-06-20 @ 17:52:13** (Continue save, Danustica area) |
| **Track 2B FORGE MATERIALS** | Ctrl+Alt+M report — party charcoal/hardwood shortfalls + nearest-town smithing stock/prices |
| **ProbeSmithingRefineApi** | inbox command — writes `BlacksmithGuild_SmithingRefineProbe.json` with method hints |
| **Stage B smithing crew advisory** | [`RunStageBSmithingCert.cmd`](RunStageBSmithingCert.cmd) or **Ctrl+Alt+R** / **Ctrl+Alt+G** | **USER PASS** 2026-06-21 — Danustica map, TBG READY |
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
| **Path C quit loop** | Quit to main menu (play + continue) | **USER PASS** 2026-06-21 — `session ended` / `forward launch already completed` |
| **Continue load (006I-5)** | [`LaunchForgeContinue.cmd`](LaunchForgeContinue.cmd) | **USER PASS** — load + quit (user 2026-06-21) |
| **Stage C charcoal refine** | inbox `RunSmithingSafeActionNow` | **USER PASS 2026-06-20 @ 17:52:13** — Continue (Danustica area); charcoal 0→1, hardwood 5→3, `refineCount=1`; commit `951f480` |

### Stage C cert evidence (2026-06-20, Continue save @ Danustica area)

Phase1 (17:52:13):

```text
[TBG FORGE] action=RefineCharcoal actor= refineCount=1 reserveBefore charcoal=0 hardwood=5 reserveAfter charcoal=1 hardwood=3
RunSmithingSafeActionNow succeeded
```

| Field | Value |
|-------|-------|
| Save | Continue (Danustica area) |
| Command | `RunSmithingSafeActionNow` via `forge.ps1` / cert helper |
| charcoalBefore / After | 0 → 1 |
| hardwoodBefore / After | 5 → 3 |
| refineCount | 1 |
| commit | `951f480` |
| Probe | PASS — `doRefinementMapped: true` (18:54:33 and earlier) |
| SafeAction JSON | **Stale on disk** — later blocked run (hardwood=0 @ 21:58 UTC) overwrote success JSON; Phase1 is canonical |
| Actor | Minor gap — blank in Phase1/JSON on success run (fix in progress) |

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

## Shipped — 008A (USER cert pending)

| Feature | How to use | Status |
|---------|------------|--------|
| **VanillaLegit Aserai culture default** | `Forge.cmd` Path A | Code shipped — USER cert pending |
| **Character build provenance JSON** | Map ready after bootstrap | `BlacksmithGuild_CharacterBuildProvenance.json` |
| **Character doctrine JSON + command** | `ShowCharacterDoctrine` / F7 | `BlacksmithGuild_CharacterDoctrine.json` |
| **Visible character creation pacing** | `CharacterCreationVisibleMode=true` (default) | 1 step/tick, 750ms pause |
| **Post-map injection off (VanillaLegit)** | Default bootstrap | `postMapProfileApply skipped: VanillaLegit` |
| **Blacksmith automation orchestrator** | `RunBlacksmithAutomationNow` | Wraps Stage C; USER cert pending |
| **Stage D rest plan (read-only)** | `RunSmithingRestPlanNow` | Shipped (pre-008A) |

DevOverride: set `LegitimacyMode=DevOverride` + `AutoApplyCharacterBuild=true` + `ApplyAutoCharacterBuild` for disposable profile testing only.

---

## Shipped — 008C (USER cert pending)

| Feature | How to use | Status |
|---------|------------|--------|
| **Live choice catalog** | `scripts/run-character-build-catalog.ps1` | Code shipped — needs live run |
| **Offline candidate matrix** | `GenerateCharacterBuildCandidatesNow` | Code shipped — after catalog |
| **Variant matrix runner** | `RunCharacterBuildVariantMatrix.cmd` | Code shipped — ≥3 runs or blocked evidence |
| **Mutation audit at map-ready** | Per variant run JSON | `mutationAudit.clean` required |
| **Best build selector** | `SelectCharacterBuildBestNow` | Code shipped — after matrix |
| **Visible replay checkpoint** | `RunCharacterBuildVisibleCert.cmd` | **USER cert PENDING** — required for TBGPersonalAserai001 |
| **Launch mode separation** | `write-character-build-launch-config.ps1` | Forge.cmd → UserVisible; catalog/matrix → AgentHeadless |
| **Per-choice in-game notices** | UserVisible character creation | Lower-left `TBG: stage → option` feed |
| **Legitimacy assert script** | `assert-character-legitimacy.ps1 -PersonalCert` | Read-only provenance + session-scoped Phase1 |

Test saves only: `BSG_ASR_TEST_*`. Never save personal baseline after catalog/matrix (AgentHeadless). Cert with `RunCharacterBuildVisibleCert.cmd` before `TBGPersonalAserai001`.

---

## Shipped — optional smoke before 005E automation

| Feature | How to use | PASS criteria | Status |
|---------|------------|---------------|--------|
| **Stage B smithing crew** | [`RunStageBSmithingCert.cmd`](RunStageBSmithingCert.cmd) | Advisory JSON + SMITHING CREW in Phase1 | **USER PASS** 2026-06-21 |
| **Track 2B forge materials** | **Ctrl+Alt+M** | `--- FORGE MATERIALS ---` | Tier 1 — optional |
| **Guild loop Ctrl+Alt+G** | **Ctrl+Alt+G** on map | Combined market + forge advisory JSON | Tier 1 — optional |

**Path B culture Back:** **WAIVED** — auto-skip loads past character creation; guard in code, no cert required.

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
| Stamina posse automation (005E) | [005e-smithing-posse-stamina-output.plan.md](plans/005e-smithing-posse-stamina-output.plan.md) | **UNBLOCKED** — Stage C proved headless mutation; crew rotation next |
| Party travel / map automation | — | **Future** — hero traverses map, enacts orders; proves party-level automation substrate (after 005E slice) |
| Forge ↔ market bridge (forge rank) | — | Per-material buy steps when Real + cached Ctrl+Alt+M — **code shipped**; Track 2B FORGE MATERIALS section **shipped** |
| Gauntlet trade UI panel | [005e-market-intelligence-shop-hotkey.plan.md](plans/005e-market-intelligence-shop-hotkey.plan.md) | BACKLOG |
| Travel cost / gold / carry weight in routes | — | Pure price spread ranking only |
| Headless safe **craft** mutation | 008A Track 7 | Automation blocks with `CraftManual` until API proven |
| Stage D rest/time mutation | — | Read-only rest plan only; no wait/rest mutation |
| Character creation menu ID discovery snapshot | 008A Track 4A | Run Path A once; capture narrative menu IDs to evidence |

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
| `BlacksmithGuild_GuildLoopReport.json` | **Ctrl+Alt+G** / inbox `RunGuildLoopNow` |
| `BlacksmithGuild_CommandSurface.json` | **F8** / map ready |
| `BlacksmithGuild_SmithingRestPlan.json` | inbox `RunSmithingRestPlanNow` (Stage D read-only) |
| `BlacksmithGuild_CharacterBuildProvenance.json` | Path A bootstrap / map ready |
| `BlacksmithGuild_CharacterDoctrine.json` | map ready / `ShowCharacterDoctrine` |
| `BlacksmithGuild_BlacksmithAutomation.json` | inbox `RunBlacksmithAutomationNow` |
| `BlacksmithGuild_Launch.log` | Forge.cmd / Continue automation |
| `BlacksmithGuild_Status.json` | F7 |

Collect: `CollectCertLogs.cmd` (uses `-LiteralPath`). Export to repo: `ExportTbgEvidence.cmd` → `docs/evidence/latest/`. Player guide: [player-command-guide.md](player-command-guide.md).

```powershell
Get-Content -LiteralPath "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json"
```

---

## Next session

**008A USER live cert** — Path A Aserai bootstrap + `RunBlacksmithAutomationNow` on Continue/disposable map. See [008a plan](plans/008a-vanilla-legit-aserai-tradesmith.plan.md). **Future:** Stage D rest/time mutation, headless craft API, party travel automation.
