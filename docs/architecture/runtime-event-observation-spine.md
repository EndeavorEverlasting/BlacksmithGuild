# Runtime Event Observation Spine

[TBG | Sprint 2 | harness/runtime-observation | branch: sprint/runtime-event-spine]

## Scope

This spine is a canonical, read-only event boundary for later observer producers and the Sprint 6 incident assembler. It creates schemas, fixtures, validation, artifact roles, and static CI only. It does not implement observers, alter `src/**`, launch Bannerlord, write commands, mutate a save, or establish runtime proof.

The shared local run root is `.local/tbg-runtime-observer/<runId>/`. Its required artifacts are `run-context.json`, `artifact-registry.json`, `events.jsonl`, `observer-status.json`, `incident-timeline.json`, `incident-result.json`, and `operator-report.md`. The latest static validator result is `artifacts/latest/runtime-observer/runtime-event-observation.result.json`.

## Ownership

Sprint 2 owns the shared contracts, schemas, fixtures, registry wiring, validator, and this document. Sprint 3 produces window lifecycle events. Sprint 4 produces process, heartbeat, responsiveness, WER, and TaleWorlds evidence. Sprint 5 produces in-process span events. Sprint 6 consumes normalized events to assemble incidents and is the first owner permitted to promote bounded causality. Sprint 7 wires agent operations and triggers; Sprint 8 owns live certification.

Producers attach bounded observations with canonical run and correlation identity. Consumers may order, filter, and render those observations, but only the authorized assembler may separate observations, inferences, hypotheses, and a supported cause.

## Non-equivalences

- A window disappearance is not a process crash.
- A process disappearance is not native-crash confirmation.
- Stale or incomplete log silence is not valid negative evidence.
- A command dispatch or event presence is not application acceptance.
- An open or last span is an unresolved boundary, not the failing statement or root cause.
- A WER/TaleWorlds artifact is evidence to correlate, not a cause declaration by itself.
- A timeline orders evidence; it does not promote cause.

`native_crash_confirmed` requires correlated external terminal evidence, canonical process identity, and timestamp correlation. Raw dumps, secrets, tokens, and personal paths remain local and ignored.

## Validation

Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeEventObservation.ps1` for schema wiring and positive/negative doctrine fixtures. The proof ceiling is `static_test`; passing this validation does not prove observer behavior, a game outcome, or live runtime state.

## Next lane

Parallel Group Alpha may consume these stable schemas after this Sprint 2 PR is created with local validators passing. CI remains the pending remote gate.
