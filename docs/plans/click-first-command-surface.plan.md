# Click-First Command Surface Plan

Last updated: 2026-06-30

## Purpose

Make The Blacksmith Guild runnable and testable by a human through root-level `.cmd` files without requiring an AI agent to remember internal command names, hotkeys, or one-off PowerShell invocations.

The repository already has a working inbox-command substrate through `forge.ps1 -Command <Name> -Wait`. This plan turns that substrate into a stable click-first surface:

```text
Human clicks root CMD -> wrapper prints scope/risk/output -> forge.ps1 sends inbox command -> mod writes JSON/log evidence -> export wrapper collects evidence
```

The goal is not to hide the underlying command system. The goal is to make the human path obvious, repeatable, and hard for future agents to miss.

---

## Current facts on `main`

### Existing click-first foundation

- `docs/clickable-command-surface.md` is the current click-surface matrix and agent rulebook.
- `docs/launch-and-doc-index.md` links the click-surface doc and lists common wrappers.
- `scripts/verify-clickable-command-surface.ps1` verifies wrapper presence, docs references, and the direct Food advisory command surface.
- `.github/workflows/governor-contracts.yml` runs the click-surface verifier as a text/contract gate.

### Root wrappers already present or expected by the current contract

Read-only / advisory:

- `Run-MarketIntel.cmd` -> `MarketSnapshotNow` -> `BlacksmithGuild_MarketIntel.json`
- `Run-FoodAdvisory.cmd` -> `AnalyzeFood` -> `BlacksmithGuild_FoodAdvisory.json`
- `Run-FoodGovernorCheck.cmd` -> compatibility alias to `Run-FoodAdvisory.cmd`
- `Run-HorseMarketIntel.cmd` -> `AnalyzeHorseMarket` -> `BlacksmithGuild_HorseMarketIntel.json`
- `Run-GuildLoopAdvisory.cmd` -> `RunGuildLoopNow` -> `BlacksmithGuild_GuildLoopReport.json`
- `Run-CohesionAnalyze.cmd` -> `AnalyzeCohesionOpportunities` -> `BlacksmithGuild_CohesionOpportunities.json`
- `Run-AutoTravelChoices.cmd` -> `ShowAutoTravelChoices` -> Phase1/status output
- `Run-TickCostProfilerSmoke.cmd` -> `ShowForgeStatus`, then evidence export
- `Run-ExportEvidence.cmd` -> `ExportTbgEvidence.cmd`

Save-impacting / explicit warning required:

- `Run-AutonomousGuildLoop.cmd` -> `RunAutonomousGuildLoopNow`
- `Run-CohesionMove.cmd` -> `RunVisibleCohesionMoveNow`

Launch / recovery / evidence:

- `ForgeContinue.cmd`
- `Forge.cmd`
- `ForgeStop.cmd`
- `ExportTbgEvidence.cmd`
- `CollectCertLogs.cmd`
- `CollectDiagnostics.cmd`
- `BackupSaves.cmd`

---

## Doctrine

1. Human-facing repeat tests get a root `.cmd` wrapper.
2. Each wrapper must say whether it is read-only/advisory or save-impacting.
3. Each wrapper must name the underlying inbox command or path.
4. Each wrapper must name the expected JSON/log output.
5. Each wrapper must preserve `%ERRORLEVEL%`.
6. Read-only wrappers pause so a human can read the result.
7. Save-impacting wrappers must print a warning before invoking the command.
8. Compatibility aliases are acceptable, but docs must name the preferred wrapper.
9. No wrapper may imply feature certification. A wrapper is only a click surface unless a cert document says otherwise.
10. Do not add an action wrapper for unproven inventory, gold, time, recruitment, travel, or smithing mutation paths.

---

## Wrapper pattern

### Read-only / advisory wrapper

```bat
@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] <Feature> - read-only/advisory
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: <ExpectedOutput>.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command <CommandName> -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] <Feature> wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
```

### Save-impacting wrapper

```bat
@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] <Feature> - save-impacting command
echo WARNING: This can change campaign state. Use a disposable save unless accepted.
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: <ExpectedOutput>.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command <CommandName> -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] <Feature> wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
```

### Compatibility alias wrapper

```bat
@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] <OldName> is now a compatibility alias.
echo Prefer <PreferredWrapper>.cmd.
echo.
call "%~dp0<PreferredWrapper>.cmd"
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] <OldName> alias finished with exit code %TBG_EXIT%.
echo.
exit /b %TBG_EXIT%
```

---

## Phase 1 - Normalize the existing root surface

Status: mostly implemented, but future agents should verify locally.

Tasks:

1. Run `scripts/verify-clickable-command-surface.ps1`.
2. Confirm every wrapper preserves `%ERRORLEVEL%`.
3. Confirm every read-only wrapper pauses.
4. Confirm every save-impacting wrapper includes `WARNING:`.
5. Confirm docs prefer `Run-FoodAdvisory.cmd`, not the old governor-proxy path.
6. Confirm `Run-FoodGovernorCheck.cmd` remains only a compatibility alias.
7. Confirm `docs/launch-and-doc-index.md` lists the preferred wrappers.
8. Confirm `scripts/dev-command-names.ps1` contains every command used by wrappers.

Expected outputs:

- verifier PASS
- no code behavior changes
- no runtime evidence committed

---

## Phase 2 - Add missing everyday read-only wrappers

These features have command-bus support or near-existing cert wrappers but need cleaner everyday root click paths.

### Clan and noble intelligence

Create wrappers:

- `Run-ClanContext.cmd` -> `AnalyzeClanContext` -> `BlacksmithGuild_ClanContext.json`
- `Run-NobleNetwork.cmd` -> `AnalyzeNobleNetwork` -> `BlacksmithGuild_NobleNetwork.json`
- `Run-MarriageCandidates.cmd` -> `AnalyzeMarriageCandidates` -> relevant marriage candidate JSON
- `Run-ClanRoles.cmd` -> `AnalyzeClanRoles` -> relevant clan role JSON
- `Run-CourtshipPlan.cmd` -> `ShowCourtshipPlan` -> relevant courtship plan JSON

Rules:

- These should be read-only unless source proves otherwise.
- Do not add courtship action/mutation wrappers until a visible vanilla path is proven.

### Tavern hero everyday surface

Create wrappers:

- `Run-TavernHeroIntel.cmd` -> `AnalyzeTavernHeroes` -> `BlacksmithGuild_TavernHeroIntel.json`
- `Run-TavernHeroShowIntel.cmd` -> `ShowTavernHeroIntel` -> cached tavern intel
- `Run-TavernRecruitmentProbe.cmd` -> `ProbeTavernRecruitmentApi` -> probe JSON/log evidence

Rules:

- Keep `RunTavernHeroRecruitCert.cmd` as cert/disposable path.
- If adding an everyday recruit wrapper, it must be clearly save-impacting and disposable-save labeled.

### Smithing everyday surface

Create wrappers:

- `Run-SmithingAdvisory.cmd` -> `RunSmithingAdvisoryNow` -> `BlacksmithGuild_SmithingAdvisory.json`
- `Run-SmithingRestPlan.cmd` -> `RunSmithingRestPlanNow` -> `BlacksmithGuild_SmithingRestPlan.json`
- `Run-ForgeRank.cmd` -> `RankForgeCandidates` -> `BlacksmithGuild_ForgeRecommendations.json`
- `Run-SmithingAudit.cmd` -> `ProbeSmithingAudit` -> `BlacksmithGuild_SmithingAudit.json`
- `Run-SmithingRefineProbe.cmd` -> `ProbeSmithingRefineApi` -> `BlacksmithGuild_SmithingRefineProbe.json`

Rules:

- Safe-action/refine/smelt wrappers must be treated as save-impacting unless proven read-only.
- Existing `RunStageCCharcoalCert.cmd` should remain cert/disposable focused.

### Horse atlas / herd ledger surface

Create wrappers:

- `Run-HorseAtlasScan.cmd` -> `ScanHorseAtlas` -> `BlacksmithGuild_HorseAtlas.json`
- `Run-HorseAtlasShow.cmd` -> `ShowHorseAtlas` -> cached atlas display
- `Run-HorseDestinations.cmd` -> `RankHorseDestinations` -> horse destination ranking output
- `Run-HerdLedger.cmd` -> `AnalyzeHerdLedger` -> `BlacksmithGuild_HerdLedger.json`
- `Run-HerdLedgerShow.cmd` -> `ShowHerdLedger` -> cached herd ledger display

Rules:

- Keep these read-only/advisory.
- Do not add horse-buy wrappers until a proven vanilla action path exists.

---

## Phase 3 - Add save-impacting wrapper families with explicit guardrails

These wrappers should exist only when the underlying command already exists and the wrapper prints a warning.

### Auto-travel choice wrappers

Create:

- `Run-AutoTravelRecommended.cmd` -> `AutoTravelToRecommended`
- `Run-AutoTravelChoice1.cmd` -> `AutoTravelChoice1`
- `Run-AutoTravelChoice2.cmd` -> `AutoTravelChoice2`
- `Run-AutoTravelChoice3.cmd` -> `AutoTravelChoice3`
- `Run-AutoTravelChoice4.cmd` -> `AutoTravelChoice4`
- `Run-AutoTravelChoice5.cmd` -> `AutoTravelChoice5`

Required warning:

```text
WARNING: This moves the main party on the campaign map. Use a disposable save unless accepted.
```

### Movement/automation abort wrappers

Create:

- `Run-AbortAutomation.cmd` -> `AbortAutonomousGuildLoopNow`
- `Run-AbortCohesionMove.cmd` -> `AbortCohesionMoveNow`
- `Run-AbortMapTradeRoute.cmd` -> `AbortMapTradeRouteNow`

These are recovery wrappers; they may not be save-impacting in the same sense as movement, but they affect active automation state and should say so.

### Map trade route wrapper

Existing command:

- `RunAutonomousVisibleTradeRouteNow`

Potential wrapper:

- `Run-AutonomousVisibleTradeRoute.cmd`

Required warning:

```text
WARNING: This can move the party and can invoke supported vanilla trade probes/actions. Use a disposable save unless accepted.
```

Do not overstate trade buy/sell certification.

---

## Phase 4 - Add a top-level menu launcher

Add a root menu wrapper:

- `START-HERE-BlacksmithGuild.cmd`

It should present a numbered menu grouped by risk:

1. Launch / Continue / Stop
2. Read-only status and advisory
3. Evidence export
4. Save-impacting movement / automation
5. Cert/disposable tests
6. Docs / command list

Recommended implementation:

- Keep the menu in CMD or PowerShell, but expose the root file as `.cmd`.
- The menu should call existing wrappers instead of duplicating command logic.
- Every save-impacting selection must require a keypress confirmation.
- The menu should never call raw `forge.ps1` directly if a wrapper exists.

Potential file layout:

```text
START-HERE-BlacksmithGuild.cmd
scripts/show-click-command-menu.ps1
```

---

## Phase 5 - Add generated command surface index

Add a generated or manually maintained index:

- `docs/clickable-command-index.md`

It should include:

- wrapper filename
- underlying command
- save impact
- expected output
- required game surface
- cert status
- preferred/alias/deprecated marker

Optional generated JSON:

- `docs/clickable-command-index.json`

Future validator should compare:

- root `Run-*.cmd` files
- `docs/clickable-command-surface.md`
- `scripts/verify-clickable-command-surface.ps1`
- `scripts/dev-command-names.ps1`
- `DevCommandRegistry.cs`

---

## Phase 6 - Update verifier contracts

The verifier must grow with the wrapper surface.

Required checks:

1. Every required wrapper exists.
2. Every wrapper has `@echo off`.
3. Every wrapper preserves `%ERRORLEVEL%`.
4. Read-only wrappers contain `pause`.
5. Save-impacting wrappers contain `WARNING:`.
6. Every wrapper command exists in `scripts/dev-command-names.ps1`, unless it calls another wrapper or legacy script.
7. Every wrapper is documented in `docs/clickable-command-surface.md`.
8. Preferred wrappers are listed in `docs/launch-and-doc-index.md`.
9. Alias wrappers explicitly say they are aliases.
10. No runtime evidence files are required or committed.

Suggested future verifier name:

```text
scripts/verify-clickable-command-surface.ps1
```

Keep using the current verifier rather than creating duplicate partial verifiers.

---

## Explicit non-goals until proven

Do not add click wrappers that imply these are complete unless source/runtime proof exists:

- automated Food acquisition
- horse buying/selling
- unrestricted trade buy/sell
- rest/time mutation
- headless craft mutation
- companion recruitment outside visible vanilla path
- multi-cycle autonomous guild loop
- personal-save cert runs

These can have advisory/probe wrappers, but action wrappers need proof gates and visible warnings.

---

## Local validation sequence

From repo root on the Windows dev box:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-clickable-command-surface.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-campaign-governor-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-campaign-activity-dispatcher-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-campaign-activity-handoff-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-tick-cost-profiler-contract.ps1
```

Then build if source changed:

```powershell
dotnet build src\BlacksmithGuild\BlacksmithGuild.csproj -c Release
```

Runtime smoke after campaign map ready:

```powershell
.\Run-MarketIntel.cmd
.\Run-FoodAdvisory.cmd
.\Run-HorseMarketIntel.cmd
.\Run-GuildLoopAdvisory.cmd
.\Run-ExportEvidence.cmd
```

Save-impacting smoke only on disposable save or explicitly accepted save:

```powershell
.\Run-CohesionMove.cmd
.\Run-AutonomousGuildLoop.cmd
```

---

## Definition of done

This plan is complete when:

- every regularly used read-only/advisory inbox command has a root `.cmd` wrapper
- every save-impacting wrapper has a visible warning
- `START-HERE-BlacksmithGuild.cmd` provides a menu to discover wrappers
- docs and verifier cover the full wrapper set
- local verifier passes
- Bannerlord build passes if C# changed
- runtime smoke produces expected JSON/evidence
- no live evidence, saves, or generated runtime reports are committed
