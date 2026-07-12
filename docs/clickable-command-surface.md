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
| `ForgeStop.cmd` | timed stop context | Unsaved progress risk | stop sentinel + launch log | Five-second Soft/Force/Cancel quit window; soft stop is the default |
| `Run-MarketIntel.cmd` | `MarketSnapshotNow` | No | `BlacksmithGuild_MarketIntel.json` | Read-only market action plan |
| `Run-FoodAdvisory.cmd` | `AnalyzeFood` | No | `BlacksmithGuild_FoodAdvisory.json` | Direct read-only Food runway/diversity/candidate advisory |
| `Run-FoodGovernorCheck.cmd` | compatibility alias to `Run-FoodAdvisory.cmd` | No | `BlacksmithGuild_FoodAdvisory.json` | Backward-compatible old Food wrapper name |
| `Run-HorseMarketIntel.cmd` | `AnalyzeHorseMarket` | No | `BlacksmithGuild_HorseMarketIntel.json` | Read-only pack/horse/capacity intel |
| `Run-GuildLoopAdvisory.cmd` | `RunGuildLoopNow` | No | `BlacksmithGuild_GuildLoopReport.json` | Advisory market + forge + crew plan |
| `Run-AutonomousGuildLoop.cmd` | immediate context controller -> `SetEngineToggleAutomation` -> `ResumeCampaignClock` -> `RunAutonomousGuildLoopNow` | Yes / movement, time, trade, forge actions | `BlacksmithGuild_AutonomousGuildLoop.json`, `artifacts/latest/autonomous-guild-loop-operator.json` | Immediate foreground/mode/clock setup, active focus/pause correction, crash-aware bounded cycle; optional 3/4/5-second startup grace |
| `Run-CohesionAnalyze.cmd` | `AnalyzeCohesionOpportunities` | No | `BlacksmithGuild_CohesionOpportunities.json` | Read-only cohesion/safety opportunity scan |
| `Run-CohesionMove.cmd` | `RunVisibleCohesionMoveNow` | Yes / movement | `BlacksmithGuild_CohesionMove.json` | Visible player-party cohesion move; disposable save unless accepted |
| `Run-AutoTravelChoices.cmd` | `ShowAutoTravelChoices` | No | Phase1 `[TBG TRAVEL]` lines / status | Read-only ranked travel choices |
| `Run-TickCostProfilerSmoke.cmd` | `ShowForgeStatus`, then `ExportTbgEvidence.cmd` | No | `BlacksmithGuild_TickCostProfiler.json` if slow ticks occurred | Confirms command polling and exports profiler/status evidence |
| `Run-ExportEvidence.cmd` | `ExportTbgEvidence.cmd` | No | `docs/evidence/latest/README.md` | Root alias for evidence export |
| `ExportTbgEvidence.cmd` | evidence export path | No | `docs/evidence/latest/` | Existing evidence snapshot command |
| `CollectCertLogs.cmd` | cert/log collection path | No | cert/log bundle | Raw cert and troubleshooting bundle |
| `CollectDiagnostics.cmd` | hash-compatible diagnostic wrapper | No | diagnostics bundle | Crash/log diagnostics even when Windows PowerShell cannot autoload `Get-FileHash` |
| `BackupSaves.cmd` | save backup path | No | backup copy | Save protection before risky runs |

---

## Context-aware Autonomous Guild Loop

`Run-AutonomousGuildLoop.cmd` is the normal play/operator surface, not a live certification harness. Clicking it with no argument declares **immediate Automation intent**.

The immediate controller performs this sequence:

1. Detect a live Bannerlord Singleplayer runtime.
2. Bring the bound Bannerlord window to the foreground.
3. Run `SetEngineToggleAutomation`.
4. Run `ResumeCampaignClock`.
5. Run `RunAutonomousGuildLoopNow`.
6. Keep watching the bounded cycle, reacquire Bannerlord focus when it is lost, and issue another `ResumeCampaignClock` when status reports a paused map.
7. Write `artifacts/latest/autonomous-guild-loop-operator.json` and `.md` with context transitions.

There is no default startup delay. Timed startup cancellation is optional:

```powershell
.\Run-AutonomousGuildLoop.cmd 3
.\Run-AutonomousGuildLoop.cmd 4
.\Run-AutonomousGuildLoop.cmd 5
```

Those explicit forms use the timed controller and allow **Q** or **Escape** during the requested window.

### In-game operator intent

`Ctrl+Alt+T` is also actionable. When the cycle reaches **Automation**, `OperatorAutomationContextController`:

- refreshes the current campaign context;
- runs `ResumeCampaignClock` when the campaign map is ready;
- starts `RunAutonomousGuildLoopNow`, or preserves it if already running;
- writes `BlacksmithGuild_OperatorAutomationContext.json`;
- shows a practical success or blocked notice instead of only displaying the mode label.

Cycling to Manual still invokes the existing manual holds/aborts. Hybrid enables direct commands without automatically starting the bounded loop.

### Quit behavior

- `ForgeStop.cmd` declares **Quit intent** and defaults to a soft stop after a five-second Soft/Force/Cancel window.
- A running external context controller watches the stop sentinel and exits when quit is requested.
- `Ctrl+Alt+B` remains the in-game movement abort.

Important terminal outcomes:

- `PASS_cycle_complete`: the bounded guild loop reached its terminal Complete report.
- `FAILED_game_disappeared_during_command`: Bannerlord vanished while setup or the loop was active.
- `BLOCKED_no_ack`: a context command was written but no matching ACK/status arrived.
- `BLOCKED_loop_not_terminal`: startup was acknowledged, but the guild-loop report did not become terminal before the bounded watch expired.
- `USER_QUIT_REQUESTED` / `USER_QUIT_HONORED`: an explicitly selected timed quit context won.

The controller may bring Bannerlord back to the foreground while its bounded cycle is active because Bannerlord pauses campaign movement after focus loss. Use `ForgeStop.cmd` to stop that behavior.

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

| Area | Current state | Next wrapper/doc action |
|---|---|---|
| Food provisioning | Direct Food advisory exists; automated food action is not built | No action wrapper until a real vanilla food action path exists |
| Auto-travel movement choices | `Run-AutoTravelChoices.cmd` is read-only, but movement choices still require inbox commands like `AutoTravelChoice1-5` | Add separate choice wrappers only after save-impact warning is explicit |
| Clan intel | Cert commands exist; everyday read-only wrappers are incomplete | Add root wrappers if the feature becomes user-facing |
| Tavern hero commands | Cert wrappers exist; everyday wrappers are incomplete | Keep recruit wrapper save-impact labeled |
| Stage D rest/time mutation | Read-only rest plan exists; no wait/rest mutation | Do not add mutation wrapper until a real action path exists |
| Multi-cycle guild loop | Immediate context-aware one-cycle play mode exists | Add deliberate multi-cycle/session policy after one-cycle runtime behavior is stable |

---

## Thin wrapper pattern

```bat
@echo off
setlocal
cd /d "%~dp0"
echo [TBG] <Feature Name>
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0<runner>.ps1"
set "TBG_EXIT=%ERRORLEVEL%"
pause
exit /b %TBG_EXIT%
```

---

## Agent checklist

- [ ] Is there a root-level `.cmd` wrapper?
- [ ] Does success return without unnecessarily blocking the game?
- [ ] Does failure remain visible long enough to read?
- [ ] Does the wrapper preserve the PowerShell exit code?
- [ ] Does a movement wrapper account for engine mode, focus, and campaign time?
- [ ] Is any startup grace optional unless the operation itself is Quit intent?
- [ ] Does an in-game operator intent produce practical follow-through and evidence?
- [ ] Is this file updated?
- [ ] Is `scripts/verify-clickable-command-surface.ps1` updated?
