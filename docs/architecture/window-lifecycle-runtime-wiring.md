# Window lifecycle runtime wiring

```text
[TBG | P19 | Window Lifecycle Runtime Wiring | architecture]
```

## Decision

P18 owns the pure reducer. P19 owns the runtime seam that turns ordered window-intelligence observations into canonical lifecycle artifacts.

The metadata watcher remains the only recognizer. The runtime adapter does not re-identify windows, click, focus, launch, sleep, OCR, or inspect pixels. It adapts already-decided observations into `TbgWindowLifecycleRuntimeEvent.v1`, rejects duplicate or out-of-order sequences, imports `Resolve-TbgWindowLifecycle.ps1`, and materializes the registered artifact set.

## Canonical run root

```text
.local/tbg-window-lifecycle/<run-id>/
  run-context.json
  artifact-registry.json
  events.jsonl
  state.json
  result.json
  operator-report.md
  handoff.md
```

Latest materialized view:

```text
artifacts/latest/window-lifecycle/
  window-lifecycle.run-context.json
  window-lifecycle.artifact-registry.json
  window-lifecycle.events.jsonl
  window-lifecycle.state.json
  window-lifecycle.result.json
  window-lifecycle.report.md
  window-lifecycle.handoff.md
```

## Contracts

| Contract | Schema |
|---|---|
| Run context | `TbgWindowLifecycleRunContext.v1` |
| Runtime event | `TbgWindowLifecycleRuntimeEvent.v1` |
| Materialized state | `TbgWindowLifecycleMaterializedState.v1` containing `TbgWindowLifecycleState.v1` windows |
| Transition | `TbgWindowLifecycleTransition.v1` from P18 |
| Artifact registry | `TbgWindowLifecycleArtifactRegistry.v1` |

Run context records run ID, correlation ID, source commit, branch, launcher-context path, target PID/HWND, launch intent, fixture/live mode, start time, proof ceiling, and output roots. It never stores credentials, user-profile paths, save paths, or mutable proof claims.

## Event mapping

| Window-intelligence observation | Runtime event |
|---|---|
| New tracked window | `window_observed` |
| Recognized identity | `identity_resolved` |
| Unknown window | `unknown_detected` |
| Exact action authority | `action_authorized` |
| Real UIA/keyboard dispatch | `action_dispatched` |
| Fixture would-dispatch only | authority only; never `action_dispatched` |
| Canonical Singleplayer host | `host_handoff_observed` |
| Previously tracked window absent on a later watch poll | `window_disappeared` |
| Rejected action authority | `action_rejected` |

Every event binds one stable `windowKey` (`pid:<pid>|hwnd:<hwnd>`), monotone sequence, run ID, and correlation ID.

## Operator surface

```powershell
.\ForgeWindowLifecycle.cmd validate
.\ForgeWindowLifecycle.cmd replay
.\ForgeWindowLifecycle.cmd status
```

The wrapper never launches Bannerlord. Status reports proof level and the fixed proof ceiling `launcher_lifecycle_harness`.

## Proof ceiling

Reached by P19:

```text
contract -> harness -> static fixture replay -> runtime-adapter execution -> launcher integration static proof
```

Not proven:

- modal acceptance by the application
- campaign readiness
- command ACK
- movement, arrival, buy, or sell
- live gameplay success
- operator acceptance

`window_disappeared` after `action_dispatched` retains `action_dispatch`. It does not create application acceptance.

## Deferred owners

| Owner | Responsibility |
|---|---|
| P20 | skills, capabilities, operations, artifact-engine triggers, router context injection |
| P21 | visible-trade coordinator consumption, live proof, PR #69/#43 disposition |

P20 and P21 must consume these output shapes and must not invent competing lifecycle artifacts.
