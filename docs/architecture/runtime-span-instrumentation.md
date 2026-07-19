# In-Process Runtime Span Instrumentation

`[TBG | Sprint 5 | runtime span instrumentation | branch: sprint/runtime-span-instrumentation]`

## Scope

This implementation adds best-effort, append-only diagnostic spans to the existing
`AutomationEvents.jsonl` stream. It does not alter campaign governor, mission-selection,
trade, route, launcher, command-inbox, or save behavior.

Each span start contains run/session/command/correlation identifiers, a unique span ID,
an optional parent span ID, operation name, expected signal, bounded pre-state, and module
assembly identity. Terminal events retain the same span ID and report `completed`, `blocked`,
`error`, or `abandoned`, with a bounded post-state and sanitized exception when applicable.
Writing diagnostics is lock-safe and failures are ignored after the existing emitter records
the local write failure; diagnostic failure never changes game control flow.

An unrelated terminal event cannot close a different span: terminal helpers accept and emit
only the context passed to them. Child spans receive their parent context explicitly.

## Instrumented operations

- `CampaignRuntimeGovernor.RunCycleNow`
- `MapTradeMissionSelector.SelectBestMission`
  - market scan, pack-animal evaluation, per-input lookup, settlement resolution, distance
    evaluation, candidate creation, fallback, and final ordering
- `MapTradeAutonomousService.StartRouteNow`
- `MapTradeAutonomousService.BeginTravel`

`RuntimeStateSnapshot` stores only surface/readiness booleans, party availability, optional
settlement/destination labels, cached-market status, candidate count, and an operation ID.
It does not read or serialize save contents, filesystem paths, or secrets.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeSpanInstrumentation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeEventObservation.ps1
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Debug
```

Proof ceiling: Debug build/static instrumentation validation. No install, launch, or runtime
behavior claim is made by this sprint.
