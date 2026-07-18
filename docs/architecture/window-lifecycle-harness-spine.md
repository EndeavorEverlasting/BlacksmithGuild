# Window lifecycle harness spine

## Decision

Window identity and window lifecycle are separate contracts.

The metadata recognizer answers **what window is this?** The lifecycle reducer answers **what state transition is now legal for this exact window key?** Keeping those decisions separate prevents a high-confidence identity match from silently becoming action authority or application-success proof.

## Owned surfaces

```text
.tbg/harness/window-identities.registry.json
.tbg/harness/policies/window-intelligence.policy.json
.tbg/workflows/window-metadata-intelligence.contract.json
.tbg/harness/schemas/window-lifecycle-state.schema.json
.tbg/harness/schemas/window-lifecycle-transition.schema.json
.tbg/harness/fixtures/window-intelligence/window-lifecycle-sequences.fixture.json
scripts/tbg/Resolve-TbgWindowLifecycle.ps1
scripts/tbg/Test-TbgWindowLifecycle.ps1
```

## State model

Every exact `windowKey` begins at `unseen` and may enter only a declared state:

```text
unseen
observed
recognized
action_ready
action_dispatched
terminal_observation
unknown_quarantined
disappeared
blocked
```

The reducer accepts ordered events and returns a new materialized state plus an immutable transition record. It does not mutate the supplied state or event objects.

## Allowed progression

Known modal:

```text
unseen
  -> window_observed
observed
  -> identity_resolved
recognized
  -> action_authorized
action_ready
  -> action_dispatched
action_dispatched
  -> window_disappeared
disappeared
```

Singleplayer host:

```text
unseen
  -> window_observed
observed
  -> identity_resolved(bannerlord.singleplayer-host)
recognized
  -> host_handoff_observed
terminal_observation
```

Unknown window:

```text
unseen
  -> window_observed
observed
  -> unknown_detected
unknown_quarantined
```

`unknown_quarantined` rejects action authority. It may return to `recognized` only after an explicit tracked `identity_resolved` event.

## Pure reducer boundary

`scripts/tbg/Resolve-TbgWindowLifecycle.ps1` may:

- validate event ordering;
- resolve allowed transitions;
- retain canonical identity and action identifiers;
- preserve the highest proof level reached;
- record deterministic transition identifiers;
- return accepted and rejected transition objects.

It may not:

- launch or stop a process;
- click or focus a window;
- sleep or poll;
- invoke UI Automation;
- send keys or use coordinates;
- inspect images or OCR;
- read or write live runtime state;
- invent a timestamp;
- infer that Bannerlord accepted a dispatched action.

This makes the reducer reusable by fixtures, reports, runtime adapters, and later routing without importing runtime side effects.

## Proof ceiling

The lifecycle proof ladder is:

```text
none
observation
identity
action_authority
action_dispatch
terminal_observation
quarantine
```

`window_disappeared` after `action_dispatched` preserves `action_dispatch`. It does not create `acceptedByApplication`, campaign readiness, command acknowledgement, movement, arrival, trade, or live product success.

The terminal states are harness dispositions for one window key:

```text
terminal_observation
disappeared
blocked
```

They are not product-level completion claims.

## Fixture coverage

The committed fixture proves four paths:

1. dependency CAUTION progresses through exact action dispatch and disappearance while retaining the action-dispatch proof ceiling;
2. the canonical Singleplayer host reaches terminal observation without another launcher click;
3. an unknown window is quarantined, rejects action authority, and requires explicit identity resolution;
4. action dispatch from `unseen` is rejected without mutating the previous state.

## Validation

```powershell
.\scripts\tbg\Test-TbgWindowLifecycle.ps1
.\scripts\tbg\Test-TbgWindowIntelligence.ps1
```

The lifecycle validator parses both schemas, checks the reducer for forbidden runtime and pixel primitives, executes every fixture case, verifies deterministic transition IDs, confirms rejected-transition immutability, and enforces the action-dispatch proof boundary.

## Runtime integration

P18 established the pure harness spine. P19 wires runtime events through:

```text
scripts/tbg/Invoke-TbgWindowLifecycleRuntime.ps1
scripts/tbg/Test-TbgWindowLifecycleRuntime.ps1
.tbg/harness/schemas/window-lifecycle-run-context.schema.json
.tbg/harness/schemas/window-lifecycle-runtime-event.schema.json
.tbg/harness/fixtures/window-intelligence/window-lifecycle-runtime.fixture.json
ForgeWindowLifecycle.cmd
docs/architecture/window-lifecycle-runtime-wiring.md
```

The metadata watcher remains the recognizer. The runtime adapter imports this reducer, materializes run-context/state/result/report/handoff artifacts, and never clicks, focuses, launches, sleeps, OCRs, or inspects pixels.

Skill, trigger, and routing adoption belongs to P20. Live clicking, gameplay automation, image/OCR identity, and coordinate-learning identity remain outside the reducer and runtime adapter.
