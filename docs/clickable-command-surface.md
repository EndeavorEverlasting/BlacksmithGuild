# Clickable Command Surface

This file exists so humans and AI agents do not miss the click-first requirement.

The rule is simple:

> If a feature is meant for a human/operator to test repeatedly, prefer a root-level `.cmd` wrapper over asking the user to type `forge.ps1 -Command ...`.

`forge.ps1` remains the implementation path. Root `.cmd` files are the human surface.

Implementation roadmap: [plans/click-first-command-surface.plan.md](plans/click-first-command-surface.plan.md)

---

## Required posture for future agents

Before telling a user to run a PowerShell inbox command directly:

1. Check whether a root `.cmd` wrapper already exists.
2. If a wrapper exists, tell the user to double-click or run that wrapper.
3. If a wrapper does not exist and the command is useful to humans, add a thin wrapper and document it here.
4. Label save-impacting behavior clearly: movement, recruitment, trading, time, inventory, and gold changes.
5. Do not claim a wrapper certifies a feature. A wrapper is only a click surface unless its cert status says otherwise.

---

## Root click wrappers available now

| Wrapper | Underlying command/path | Save impact | Primary output | Purpose |
|---|---|---:|---|---|
| `ForgeContinue.cmd` | launch Continue path | Loads game | `BlacksmithGuild_Launch.log`, status JSON | Daily dev/play launch path |
| `Forge.cmd` | launch New/Play path | Creates/loads test path | launch + character/build JSON | Fresh bootstrap / visible character creation |
| `ForgeStop.cmd` | stop game process | Unsaved progress risk | process state | Emergency/cleanup stop |
| `Run-MarketIntel.cmd` | `MarketSnapshotNow` | No | `BlacksmithGuild_MarketIntel.json` | Read-only market action plan |
| `Run-FoodAdvisory.cmd` | `AnalyzeFood` | No | `BlacksmithGuild_FoodAdvisory.json` | Direct read-only Food runway/diversity/candidate advisory |
| `Run-FoodGovernorCheck.cmd` | compatibility alias to `Run-FoodAdvisory.cmd` | No | `BlacksmithGuild_FoodAdvisory.json` | Backward-compatible old Food wrapper name |
| `Run-HorseMarketIntel.cmd` | `AnalyzeHorseMarket` | No | `BlacksmithGuild_HorseMarketIntel.json` | Read-only pack/horse/capacity intel |
| `Run-GuildLoopAdvisory.cmd` | `RunGuildLoopNow` | No | `BlacksmithGuild_GuildLoopReport.json` | Advisory market + forge + crew plan |
| `Run-AutonomousGuildLoop.cmd` | `scripts/run-autonomous-guild-loop-operator.ps1` -> `RunAutonomousGuildLoopNow` | Yes / possible movement and supported vanilla actions | `BlacksmithGuild_AutonomousGuildLoop.json`, `artifacts/latest/autonomous-guild-loop-operator.json` | Crash-aware one-cycle operator runner; records when Bannerlord disappears or no ACK/status arrives |
| `Run-CohesionAnalyze.cmd` | `AnalyzeCohesionOpportunities` | No | `BlacksmithGuild_CohesionOpportunities.json` | Read-only cohesion/safety opportunity scan |
| `Run-CohesionMove.cmd` | `RunVisibleCohesionMoveNow` | Yes / movement | `BlacksmithGuild_CohesionMove.json` | Visible player-party cohesion move; disposable save unless accepted |
| `Run-AutoTravelChoices.cmd` | `ShowAutoTravelChoices` | No | Phase1 `[TBG TRAVEL]` lines / status | Read-only ranked travel choices |
| `Run-TickCostProfilerSmoke.cmd` | `ShowForgeStatus`, then `ExportTbgEvidence.cmd` | No | `BlacksmithGuild_TickCostProfiler.json` if slow ticks occurred | Confirms command polling and exports profiler/status evidence |
| `Run-ExportEvidence.cmd` | `ExportTbgEvidence.cmd` | No | `docs/evidence/latest/README.md` | Root alias for evidence export |
| `ExportTbgEvidence.cmd` | evidence export path | No | `docs/evidence/latest/` | Existing evidence snapshot command |
| `CollectCertLogs.cmd` | cert/log collection path | No | cert/log bundle | Raw cert and troubleshooting bundle |
| `CollectDiagnostics.cmd` | diagnostics collection path | No | diagnostics bundle | Crash/log diagnostics |
| `BackupSaves.cmd` | save backup path | No | backup copy | Save protection before risky runs |

---

## Autonomous Guild Loop operator note

`Run-AutonomousGuildLoop.cmd` is an operator/play wrapper, not a live certification harness. It now writes `artifacts/latest/autonomous-guild-loop-operator.json` and `.md` for terminal outcomes.

Important outcomes:

- `FAILED_game_disappeared_during_command`: Bannerlord existed when the command was sent and vanished before matching ACK/status.
- `BLOCKED_no_ack`: the command inbox was written, but no matching ACK/status appeared before timeout.
- `PASS_ack_success` / `PASS_status_success`: the game acknowledged or reported the command as successful.

The wrapper tells the user that Bannerlord should stay foreground and unpaused for movement. It does not pretend alt-tab is safe for movement automation.

---

## Food-specific note

Food now has a direct read-only inbox command and root wrapper.

Use:

```powershell
.\Run-FoodAdvisory.cmd
.\Run-ExportEvidence.cmd
```

Underlying command:

```powershell
.\forge.ps1 -Command AnalyzeFood -Wait
```

Inspect:

- `BlacksmithGuild_FoodAdvisory.json`
- `verdict`
- `food.quantityStatus`
- `food.diversityStatus`
- `food.forecastStatus`
- `plan.procurementNeeded`
- `plan.foodShortfall`
- `plan.uniqueFoodTypeShortfall`
- `candidates.items[]`
- `marketStock.status`
- `marketMatches.status`
- `executionGate.status`
- `buyFoodSupported`

Current limit: Food can analyze runway, diversity, candidates, read-only market stock, matches, and proof gates. It still does not perform automated food acquisition. Do not promise food provisioning until a proven vanilla food action path exists.

`Run-FoodGovernorCheck.cmd` remains only as a compatibility alias. New work should prefer `Run-FoodAdvisory.cmd` and `AnalyzeFood`.

---

## Still not click-clean enough

These areas either need more wrappers or should be made clearer before normal users test them repeatedly.

| Area | Current state | Next wrapper/doc action |
|---|---|---|
| Food provisioning | Direct Food advisory exists; automated food action is not built | No action wrapper until a real vanilla food action path exists |
| Auto-travel movement choices | `Run-AutoTravelChoices.cmd` is read-only, but movement choices still require inbox commands like `AutoTravelChoice1-5` | Add separate `Run-AutoTravelChoice1.cmd` etc. only after save-impact warning is explicit |
| Clan intel | `Run-ClanIntelCert.cmd` exists for cert, but everyday read-only wrappers for each clan-intel command are not root-level | Add `Run-ClanContext.cmd`, `Run-NobleNetwork.cmd`, etc. if the feature becomes user-facing |
| Tavern hero commands | Cert wrappers exist; everyday wrappers are incomplete | Keep recruit wrapper disposable-save labeled; add read-only shortcuts if used often |
| Character build catalog/matrix | Cert/matrix wrappers exist, but these are agent/test-save surfaces | Do not present as normal personal-save click paths |
| Stage D rest/time mutation | Read-only rest plan exists; no wait/rest mutation | Do not add mutation wrapper until proof gate exists |
| Headless safe craft mutation | Blocks with `CraftManual` until API proven | No craft wrapper until safe craft mutation is proven |
| Multi-cycle guild loop | One cycle only; operator wrapper is crash-aware but still requires foreground/unpaused movement | Add a focus/pause-aware watch mode before presenting this as continuous background play |

---

## Thin wrapper pattern

For read-only inbox commands:

```bat
@echo off
setlocal
cd /d "%~dp0"
echo [TBG] <Feature Name> - read-only
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command <CommandName> -Wait
set "TBG_EXIT=%ERRORLEVEL%"
pause
exit /b %TBG_EXIT%
```

For save-impacting commands, add a visible warning before the PowerShell call:

```bat
echo WARNING: This can change campaign state. Use a disposable save unless accepted.
```

---

## Agent checklist

When adding a new user-facing feature:

- [ ] Is there a root-level `.cmd` wrapper?
- [ ] Does the wrapper pause so the user can read the result?
- [ ] Does the wrapper preserve the PowerShell exit code?
- [ ] Does the wrapper state save impact clearly?
- [ ] Is the output JSON named in the wrapper and docs?
- [ ] Is this file updated?
- [ ] Is `scripts/verify-clickable-command-surface.ps1` updated?
