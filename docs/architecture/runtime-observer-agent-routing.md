# Runtime Observer Agent Routing

[TBG | Sprint 7 | harness/agent-routing | branch: sprint/runtime-observer-agent-harness]

## Scope

Sprint 7 factors completed runtime observation into skills, capabilities, and read-only trigger routes. It does not modify observer or assembler implementations, C#, shared schemas, launcher/process/window/save/command behavior, or proof levels.

## Skill and capability decisions

- `launcher-lifecycle` owns observer start, status, and owned-lease stop entrypoints. Stopping an observer never stops Bannerlord.
- `window-lifecycle-runtime` owns window lifecycle status and unknown/error quarantine.
- `runtime-incident-triage` owns completed-run crash, process-loss, hang, WER, TaleWorlds, open-span, heartbeat, and observer-gap reconstruction.
- `runtime-evidence-certification` owns freshness and proof classification, including the bounded `incident_ready` result.
- `local-artifact-engine` owns read-only parsing and declared trigger routing.

The registered capabilities expose the merged observer and incident entrypoints. Their outputs remain bounded local observer artifacts and static validation packets. No capability grants restart, kill, click, focus, command-inbox, save, cleanup, root-cause, or live-certification authority.

## Deterministic triggers

| Trigger | Primary skill | Boundary |
|---|---|---|
| `process_lost` | `runtime-incident-triage` | Observation is not a confirmed crash. |
| `external_terminal_evidence` | `runtime-incident-triage` | Correlate before classification. |
| `window_error_or_unknown_quarantine` | `window-lifecycle-runtime` | Quarantine never authorizes a click. |
| `open_span_at_process_loss` | `runtime-incident-triage` | Open span is a boundary, not cause. |
| `heartbeat_stalled_with_live_process` | `runtime-incident-triage` | Diagnostic only; no kill or restart. |
| `observer_gap` | `runtime-incident-triage` | Unknown, never negative-evidence confidence. |
| `incident_ready` | `runtime-evidence-certification` | Not live certification. |

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgArtifactEngine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgArtifactWatcher.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeIncidentAssembler.ps1
```

## Risks and next command

The router verifies static declarations and fixture routing only. It does not establish observer runtime health or Bannerlord behavior. Next command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Invoke-TbgEndToEndValidation.ps1 -Profile default-static
```
