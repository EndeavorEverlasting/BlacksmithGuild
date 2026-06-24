# F7 Golden-Path Diff — Agent Handoff

**Last updated:** 2026-06-22  
**Branch:** `fix/f7-gate-stability` @ `376fb3c` — [PR #7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7)  
**Sprint:** Compare failed loads vs last known-good Continue boot; emulate tick order with new features deferred.

## Why golden-path diff (not just hook-mask bisect)

Failed F7 runs are comparable to a **documented PASS contract** in [`forge-zero-click-contract.md`](../forge-zero-click-contract.md). The gap is not launcher wiring — it is **what runs on the MapReady tick** and whether `TBG READY` / `[TBG MAPREADY]` appear before the process dies.

We **can and should** emulate the golden format. Blockers today are missing committed baseline tails and agent-shell focus stealing — not lack of methodology.

## Golden PASS sequence (Continue, 006I-5 USER PASS 2026-06-21)

From contract + `sprint-006i-live-results.md`:

```
Idle -> MainMenu
MainMenu -> MapTransition (GameLoadingState)
MapTransition -> MapReady (MapState)
bootstrap disarmed / setup complete
[TBG MAPREADY] StatusFlush ok          (post-orchestrator era)
[TBG MAPREADY] deferred scheduled…     (if heavy hooks enabled)
TBG READY: campaign map ready…         (InGameNotice via orchestrator)
Status.json: campaignReady=true, canPollFileInbox=true
```

**Not in golden path:** `[TBG HOTKEY TRACE] Campaign tick polling active` on the **same tick** as MapReady.

## Session comparison table

| Session | Commit | Mask | MapReady? | Hotkey @ MapReady? | [TBG MAPREADY]? | TBG READY? | Death |
|---------|--------|------|-----------|-------------------|-----------------|------------|-------|
| 006I-5 USER | pre-orchestrator | — | Yes | unknown | N/A | Yes | Quit clean |
| `002034` | early orchestrator | — | Yes (Quyaz) | Yes | partial | Yes lines | ~2s after |
| `013214` USER | `80ffa31` | default | Yes @ 01:33:23 | **Yes same tick** | No | No | ~2s |
| `014437` agent | `376fb3c` | `0x0F` | No (timeout) | during MapTransition | No | No | 5m timeout |
| **`015132` agent** | **`376fb3c`** | **`0x0F`** | **Yes @ 01:52:19** | **No** | **No** | **No** | interrupted |

**Interpretation:** `376fb3c` hotkey gate **worked** on `015132` (no hotkey trace after MapReady). Orchestrator still never logged — next fix targets **campaign tick reaching `CampaignMapReadyOrchestrator`** before process exit, not QuickStart/intro.

## Evidence paths

| Session | Path | Role |
|---------|------|------|
| Best USER repro (pre-gate) | `docs/evidence/live-cert/20260622-013214/` | MapReady + hotkey race |
| Post-gate agent | `docs/evidence/live-cert/20260622-015132/` | MapReady, no hotkey, no MAPREADY |
| Near-success crash | `docs/evidence/live-cert/20260622-002034/` | Full map-ready lines then ~2s death |
| Agent timeout | `docs/evidence/live-cert/20260622-014437/` | MapTransition only — ignore for bisect |

Live logs (always): `<Bannerlord>/BlacksmithGuild_Phase1.log`, `BlacksmithGuild_Launch.log`, `BlacksmithGuild_Status.json`

## Next sprint — USER terminal (required)

```powershell
git pull origin fix/f7-no-click-launch-runner
.\Run-F7GateContinue.cmd -HookMask 0x0F
```

Runner owns Safe Mode No, Continue click, refocus. Fail-fast exit 1 when hwnd/foreground theft blocks automation.

**PASS:** exit 0, manifest PASS, Phase1 shows `[TBG MAPREADY] StatusFlush ok` then `TBG READY`, stable 60s.

**If MapReady but no MAPREADY (like 015132):**
```powershell
.\Run-F7GateContinue.cmd -HookMask 0x00   # diagnostic: skip all hooks
.\Run-F7GateContinue.cmd -HookMask 0x01   # StatusFlush only
```

**Capture golden baseline after first USER PASS:**
```powershell
.\ExportTbgEvidence.cmd
# Commit docs/evidence/live-cert/<session>/ as golden-continue-pass
```

## Code targets (Agent B, if USER still fails)

| Target | File | Change |
|--------|------|--------|
| Orchestrator tick guarantee | `BlacksmithGuildCampaignBehavior.cs` | Log if MapReady but orchestrator skipped; ensure tick runs same frame as MapReady |
| Golden deferral | `CampaignMapReadyOrchestrator.cs` | All non-StatusFlush hooks deferred until tick+2 on Continue path |
| Status flush only first | mask default for Continue | `TBG_MAP_READY_HOOK_MASK=0x01` smoke |

## Parallel

| Agent | Task |
|-------|------|
| **USER** | F7 with mask `0x0F`, minimized Cursor |
| **Agent B** | Golden-path diff script: diff Phase1.tail vs contract checklist |
| **Blocked** | PR #5/#6, cert marathon until F7 USER PASS |

## Safe Mode rule

Safe Mode → No = prior hard-exit. Not launcher failure.
