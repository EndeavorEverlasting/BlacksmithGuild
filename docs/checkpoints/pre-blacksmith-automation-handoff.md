# BlacksmithGuild — Master Agent Handoff (copy-paste entire file)

**Last updated:** 2026-06-21  
**HEAD after this sprint:** run `git log -1 --oneline` — expect Stage B cert helper + doc closeout  
**Authority:** User — launcher certs CLOSED; Path B WAIVED; 005E UNBLOCKED.

---

## 1. Repo

| Field | Value |
|-------|-------|
| Root | [`C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild`](C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild) |
| Remote | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch | `main` only — no stale feature branches |
| Open PRs | None |
| Push | **HOLD** until user explicitly requests (50+ commits ahead of origin) |
| Working tree | Must be clean before next feature branch |

```powershell
cd C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild
git status --short
dotnet build -c Release src/BlacksmithGuild/BlacksmithGuild.csproj
```

---

## 2. Named cert scenarios (NOT file paths)

| Name | Plain English | Entry command | PASS means |
|------|---------------|---------------|------------|
| **Path A** | Zero-click new campaign → map | [`Forge.cmd`](../../Forge.cmd) | `TBG READY` on map; no manual launcher/creation clicks |
| **Path B** | Culture Back does not replay intro | [`Forge.cmd`](../../Forge.cmd) → Back at culture | **WAIVED** — auto-skip past creation; no cert required |
| **Path C-play** | Quit to menu after play bootstrap | [`Forge.cmd`](../../Forge.cmd) → map → Pause → Quit once | Menu idle; log `decision=block reason=session ended` |
| **Path C-continue** | Quit to menu after Continue | [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) → map → Quit once | Menu idle; log `forward launch already completed`; no Continue re-click |
| **Continue load** | Launcher Continue → map | [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) | Map loads; Module Mismatch cleared if shown |
| **Stage C** | Headless charcoal refine (Tier 3 mutation) | [`RunStageCCharcoalCert.cmd`](../../RunStageCCharcoalCert.cmd) | Phase1 `RefineCharcoal` charcoal N→N+1 |
| **Stage B** | Smithing crew advisory (Tier 1 read-only) | [`RunStageBSmithingCert.cmd`](../../RunStageBSmithingCert.cmd) | **USER PASS** 2026-06-21 — Danustica map, TBG READY |

**Layer A** = PowerShell launcher automation (`Launch.log`). **Layer B** = in-game C# (`Phase1.log`).

---

## 3. Certification status (user-confirmed 2026-06-21)

### Launcher / bootstrap — **CLOSED**

| Item | Status |
|------|--------|
| Path A | **USER PASS** 2026-06-20 |
| Path B | **WAIVED** (obsolete) |
| Path C-play | **USER PASS** 2026-06-21 |
| Path C-continue | **USER PASS** 2026-06-21 |
| Continue load + quit | **USER PASS** (user 2026-06-21) |

Do **not** block smithing work on Path B or stale 006J partials.

### Smithing / forge — pre-005E queue

| # | Item | Tier | Status |
|---|------|------|--------|
| 1 | Stage C charcoal refine | 3 | **USER PASS** 2026-06-20 |
| 2 | Track 2A real forge rank (Ctrl+Alt+R) | 1 | **USER PASS** 2026-06-20 |
| 3 | Market intel (Ctrl+Alt+M) | 1 | **USER PASS** 2026-06-20 |
| 4 | Stage B smithing crew advisory | 1 | **USER PASS** (user 2026-06-21 — Danustica, map ready) |
| 5 | Track 2B FORGE MATERIALS | 1 | Optional |
| 6 | Guild loop (Ctrl+Alt+G) | 1 | Optional |

**Pre-005E smithing cert queue: COMPLETE.**

**Re-cert Stage C only** if `SmithingRefineApi` / `SmithingSafeActionService` changes.

---

## 4. Next engineering — 005E smithing posse automation

**Status:** **READY TO START** — pre-005E cert queue complete (2026-06-21).

**Plan:** [`docs/plans/005e-smithing-posse-stamina-output.plan.md`](../plans/005e-smithing-posse-stamina-output.plan.md)

**Already shipped:**

| Stage | What | Key files |
|-------|------|-----------|
| A | Read-only audit | `SmithingAuditService.cs` → `SmithingAudit.json` |
| B | Crew advisory | `SmithingAdvisoryService.cs`, `SmithingAdvisoryPlanner.cs` |
| C | Safe single refine | `SmithingSafeActionService.cs`, `SmithingRefineApi.cs` |
| D (read-only) | Rest plan | `SmithingRestPlanService.cs` → `SmithingRestPlan.json` |

**Next slice (005E):** multi-hero stamina rotation, role assignment beyond single charcoal refine, explained actions with reserve guards. Stage C proved headless map mutation works.

**Scope lock for 005E:** no Gauntlet UI clicks, no auto buy/sell, no launcher changes unless regression.

---

## 5. Future — party travel / map automation

**User goal (later):** Hero traverses campaign map and enacts orders — proves party-level automation (same substrate as inbox commands + campaign tick, extended to movement).

**Not started.** After 005E smithing slice is stable. No plan file yet.

Builds on: `GameSessionState.IsCampaignMapReady`, campaign tick hooks, `DevCommandBus`, evidence JSON pattern.

---

## 6. Runtime output paths (Bannerlord install dir)

Default Steam root: `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/`

| Artifact | Path |
|----------|------|
| Phase1 (primary evidence) | `.../BlacksmithGuild_Phase1.log` |
| Launch (Layer A) | `.../BlacksmithGuild_Launch.log` |
| Status | `.../BlacksmithGuild_Status.json` |
| Market intel | `.../BlacksmithGuild_MarketIntel.json` |
| Forge rank | `.../BlacksmithGuild_ForgeRecommendations.json` |
| Smithing advisory | `.../BlacksmithGuild_SmithingAdvisory.json` |
| Safe action (Stage C) | `.../BlacksmithGuild_SmithingSafeAction.json` |
| Refine probe | `.../BlacksmithGuild_SmithingRefineProbe.json` |
| Guild loop | `.../BlacksmithGuild_GuildLoopReport.json` |
| Rest plan (Stage D) | `.../BlacksmithGuild_SmithingRestPlan.json` |
| Command surface | `.../BlacksmithGuild_CommandSurface.json` |

Collect all: [`CollectCertLogs.cmd`](../../CollectCertLogs.cmd) from repo root.

Export to repo: [`ExportTbgEvidence.cmd`](../../ExportTbgEvidence.cmd) → [`docs/evidence/latest/`](../../docs/evidence/latest/)

---

## 7. Repo entrypoints (from repo root)

| Script | Purpose |
|--------|---------|
| [`Forge.cmd`](../../Forge.cmd) | Daily dev — play intent → map |
| [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) | Continue via launcher |
| [`ForgeStop.cmd`](../../ForgeStop.cmd) | Kill game + launcher + forge shell |
| [`CollectCertLogs.cmd`](../../CollectCertLogs.cmd) | Paste block for agent |
| [`RunStageCCharcoalCert.cmd`](../../RunStageCCharcoalCert.cmd) | Tier 3 Stage C cert |
| [`RunStageBSmithingCert.cmd`](../../RunStageBSmithingCert.cmd) | Tier 1 Stage B cert |
| [`ExportTbgEvidence.cmd`](../../ExportTbgEvidence.cmd) | Snapshot JSON to docs/evidence |

---

## 8. Key source files (005E / smithing)

| Path | Role |
|------|------|
| [`src/BlacksmithGuild/Forge/SmithingRefineApi.cs`](../../src/BlacksmithGuild/Forge/SmithingRefineApi.cs) | Headless DoRefinement |
| [`src/BlacksmithGuild/Forge/SmithingSafeActionService.cs`](../../src/BlacksmithGuild/Forge/SmithingSafeActionService.cs) | Stage C safe action cap |
| [`src/BlacksmithGuild/Forge/SmithingAdvisoryService.cs`](../../src/BlacksmithGuild/Forge/SmithingAdvisoryService.cs) | Stage B crew advisory |
| [`src/BlacksmithGuild/Forge/SmithingAdvisoryPlanner.cs`](../../src/BlacksmithGuild/Forge/SmithingAdvisoryPlanner.cs) | Reserve + crew doctrine |
| [`src/BlacksmithGuild/Forge/SmithingWorkerSelector.cs`](../../src/BlacksmithGuild/Forge/SmithingWorkerSelector.cs) | Party worker profiles |
| [`src/BlacksmithGuild/Forge/SmithingRestPlanService.cs`](../../src/BlacksmithGuild/Forge/SmithingRestPlanService.cs) | Stage D read-only rest |
| [`src/BlacksmithGuild/Forge/GuildLoopService.cs`](../../src/BlacksmithGuild/Forge/GuildLoopService.cs) | Ctrl+Alt+G combined loop |
| [`src/BlacksmithGuild/DevTools/DevCommandBus.cs`](../../src/BlacksmithGuild/DevTools/DevCommandBus.cs) | Inbox command dispatch |

Launcher (do not touch unless regression):

| Path | Role |
|------|------|
| [`src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs) | Path C fix — forward-launch latch |
| [`scripts/launcher-auto-nav.ps1`](../../scripts/launcher-auto-nav.ps1) | Layer A PLAY/CONTINUE |

---

## 9. Known gaps & risks

| Gap / risk | Detail |
|------------|--------|
| **Stage B user cert** | **DONE** 2026-06-21 — user confirmed PASS (Danustica map) |
| **53+ unpushed commits** | Push when user ready; branch from clean `main` |
| **Stale JSON vs Phase1** | Latest JSON may show blocked run after PASS — Phase1 is canonical for Stage C |
| **Build install blocked if game running** | Close Bannerlord or use Forge.cmd to install DLL |
| **005E stamina API unknowns** | Per-hero stamina read/assign may be advisory-only first |
| **Travel automation** | Future — not scoped until 005E stable |
| **Path B guard in code** | Remains; no cert required |

---

## 10. Agent mission templates

### A. ~~Run Stage B cert~~ **DONE** (USER PASS 2026-06-21)

Optional re-run:

```powershell
cd C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild
./RunStageBSmithingCert.cmd
```

### B. Start 005E implementation (agent)

1. Read [`005e-smithing-posse-stamina-output.plan.md`](../plans/005e-smithing-posse-stamina-output.plan.md)
2. Smallest slice: extend `SmithingSafeActionService` or worker rotation with logging `[TBG FORGE] worker=... action=... reason=...`
3. Tier 3 mutation → disposable save first
4. No launcher / Path C regressions
5. `dotnet build -c Release`; user cert on map

### C. If launcher regression

Inspect [`MainMenuAutoLauncher.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs) first; grep Phase1 for `decision=auto-select` after quit.

---

## 11. Related docs

| Doc | Purpose |
|-----|---------|
| [`docs/functionality-status.md`](../functionality-status.md) | What works today |
| [`docs/certification-doctrine.md`](../certification-doctrine.md) | Tier 0–3 model |
| [`docs/plans/006i-4-quit-to-menu-intro-loop.plan.md`](../plans/006i-4-quit-to-menu-intro-loop.plan.md) | Path C fix record |
| [`docs/plans/006j-full-live-cert-closeout.plan.md`](../plans/006j-full-live-cert-closeout.plan.md) | Launcher closeout (CLOSED) |
| [`docs/forge-zero-click-contract.md`](../forge-zero-click-contract.md) | Forge.cmd contract |

---

## 12. Scope lock

- No Path B cert unless user disables auto-skip
- No push unless user asks
- No travel automation until user directs post-005E
- No Gauntlet trade/smithy UI clicking
- No economics auto-buy/sell
