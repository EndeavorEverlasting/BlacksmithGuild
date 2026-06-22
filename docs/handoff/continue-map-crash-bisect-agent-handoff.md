# Continue Map Crash Bisect — Agent Handoff

**Last updated:** 2026-06-22  
**Branch:** `fix/f7-gate-stability` (PR pending → `main`)  
**Status:** **F7 STABILITY FIX SHIPPED — F7 agent-shell still FAIL; USER verify required**

## Problem

Continue load dies during `MapTransition` before stable F7 in agent shell. Safe Mode on every relaunch confirms **prior run hard-exit** (mod/load chain, not launcher wiring).

## What shipped (this sprint)

| Area | Change |
|------|--------|
| **Scripts** | Post-handoff refocus in `launcher-auto-nav.ps1`; refocus in `run-live-assistive-cert.ps1` `Wait-MapReady`; new `Run-F7GateContinue.cmd` + `run-f7-gate-continue.ps1` |
| **Safe Mode trail** | Explicit launch log + F7 manifest `launchSignals.priorSessionCrashLikely` |
| **C# load gates** | `CanPollHelpHotkeys` map/settlement only; `SubModule` hotkey poll gated; `BlacksmithGuildCampaignBehavior` Refresh→MainHero→MapReady→orchestrator |

Prior on `main`: `CampaignMapReadyOrchestrator`, hook-mask bisect, `SyncForgeStatus`.

## F7 gate (agent shell, post-fix)

| Session | Verdict | Safe Mode | Phase1 last | Notes |
|---------|---------|-----------|-------------|-------|
| `20260622-011344` | FAIL | — | — | Premature exit (script grace bug; fixed) |
| `20260622-011418` | FAIL | **Yes → No** | `MapTransition` @ 01:15:02 | Safe Mode chain; no TBG READY; ~51s |

Evidence: `docs/evidence/live-cert/20260622-011418/checkpoint-01-f7-gate/`

**Interpretation:** Safe Mode No + MapTransition death = **prior crash + repeat load crash**. Not sell/smelt/clan. Hook-mask bisect **not applicable** (no map-ready line in same run after fix).

## Next step — USER terminal

```powershell
git checkout fix/f7-gate-stability   # or main after merge
git pull
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\Run-F7GateContinue.cmd
# PASS: exit 0, manifest passFail PASS, stableSeconds >= 60
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
```

Minimize Cursor during launch. If map-ready then crash: `$env:TBG_MAP_READY_HOOK_MASK = "0x0F"` etc.

## Parallel

- [PR #5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) `feat/006c-4-sell-loop` — merge after F7 USER PASS  
- [PR #6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) `feat/006c-4b-second-leg-travel` — stacked on #5  

Do **not** merge #5/#6 until F7 stable.
