# Runtime Incident Assembly

[TBG | Sprint 6 | runtime incident assembly | branch: sprint/runtime-incident-assembler]

## Purpose and scope

The assembler consumes a bounded, normalized runtime-observer run and creates a deterministic incident timeline and result. Its owned implementation is `scripts/tbg/Resolve-TbgRuntimeIncident.ps1`, its optional remote-review output is `scripts/tbg/New-TbgRuntimeIncidentCapsule.ps1`, and its static fixture validator is `scripts/tbg/Test-TbgRuntimeIncidentAssembler.ps1`.

It reads `run-context.json`, `artifact-registry.json`, `events.jsonl`, and `observer-status.json` from `.local/tbg-runtime-observer/<runId>/`. It does not launch, stop, inspect, or mutate a game process; write a command inbox; touch saves; change observers; alter shared schemas; or track raw logs and dumps.

## Deterministic evidence rules

The result preserves both source time ordering and ingestion order. Events are quarantined when run or correlation IDs differ, event IDs duplicate, timestamps are malformed or outside the bounded run window, the observer was undeclared, or the source is stale. A negative-evidence claim is invalid without an active observer-health signal.

The assembler correlates normalized window, process, WER, TaleWorlds, heartbeat, responsiveness, span, and observer-gap events. It emits only these classifications:

- `clean_exit`
- `managed_exception_confirmed`
- `native_crash_suspected`
- `native_crash_confirmed`
- `hang_suspected`
- `hang_confirmed`
- `log_stalled`
- `process_unobserved`
- `observer_failure`
- `unknown_failure`

`native_crash_confirmed` requires a correlated process-loss observation plus an external terminal evidence reference. A stale log, a vanished window, a process non-observation, or an open span cannot satisfy that gate.

An open span is recorded as an unresolved boundary. It is never a causal statement.

## Causality and capsule boundary

Each result separates direct observations, bounded inferences, hypotheses, `provenCause`, and `rootCauseEvidenceRefs`. `provenCause` remains null in this sprint: the assembler classifies incidents and reports evidence gaps but does not guess a root cause.

`New-TbgRuntimeIncidentCapsule.ps1` needs explicit `-RemoteReviewNeeded`. It emits the existing `TbgRuntimeContextCapsule.v1` shape only, keeps raw evidence local, redacts personal paths and sensitive data, and refuses a confirmed-native-crash capsule without external terminal evidence.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgRuntimeIncidentAssembler.ps1
```

The fixture replay is deterministic and static-test proof only. It does not establish live-runtime behavior or root-cause proof.
