# Runtime Incident Operator Guide

[TBG | Sprint 6 | incident operator guide | branch: sprint/runtime-incident-assembler]

## Scope

Run this only against a completed local observer run. The assembler is read-only with respect to Bannerlord, windows, processes, command files, and saves. It owns local incident outputs under `.local/tbg-runtime-observer/<runId>/` and the latest static validation result under `artifacts/latest/runtime-incident/`.

```powershell
.\ForgeRuntimeIncident.cmd .local\tbg-runtime-observer\<runId>
.\ForgeRuntimeIncident.cmd capsule .local\tbg-runtime-observer\<runId> docs\evidence\runtime-context\<UTC-date>-<runId>.json
```

Use `capsule` only when another reviewer needs bounded remote diagnosis. Do not commit the local input run, raw logs, dumps, or any output containing private paths.

## Reading the report

The operator report divides claims into:

- **Known:** accepted event count, quarantine count, and the bounded classification.
- **Unknown:** `provenCause` remains null.
- **Suspected:** an inference that names its supporting observations.
- **Forbidden claims:** no root cause from the final event, an open span, stale silence, or a window transition.

For `native_crash_confirmed`, verify that the result includes correlated external terminal evidence. Without it, retain the narrower `native_crash_suspected` result.

Negative evidence is usable only when an expected signal was declared, its observer was active, the source was fresh, the window completed, and the signal was explicitly absent. Missing observer health and incomplete windows are evidence gaps, not absence.

## Validation and handoff

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgRuntimeIncidentAssembler.ps1
```

Validation is static-test proof. It does not prove a game action, launcher behavior, or live runtime state. Next command:

```powershell
.\ForgeRuntimeIncident.cmd test
```
