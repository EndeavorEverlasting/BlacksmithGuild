# Unified Launch Path and Surface Contract

## Operator outcome

Every supported Bannerlord launch entrypoint must enter the same observer-first harness before its first action:

- `ForgeContinue.cmd`;
- Auto Launch Nav;
- the new-game Play path;
- a Steam-mediated path;
- any future registered launch path.

The harness records every correlated top-level launch surface even when it does not interact with it:

- Play/Continue;
- calibration;
- Safe Mode;
- dependency Caution;
- other launcher windows;
- correlated Steam broker windows;
- Singleplayer handoff.

## Safety and action rules

- One run context, correlation identity, observer set, event stream, artifact registry, and proof boundary apply to every entrypoint.
- Observers start before actuation.
- Each surface receives an independently frozen process/window identity.
- Play/Continue intent comes only from launch context.
- Safe Mode uses the exact `No` control.
- Caution uses the exact `Confirm` control.
- Calibration remains observation-only until its semantic action and exact controls are registered and fixture-proven.
- Steam remains observation-only and must be correlated to the active launch; unrelated Steam windows are excluded.
- Unknown windows are quarantined.
- Background-safe, mouse-independent behavior is the default.
- Dispatch is not success; a fresh transition must be observed.

## Required event cascade

```text
launch.path.selected
  -> window.observed
  -> window.identity.resolved_or_quarantined
  -> action.authorized_or_blocked
  -> action.dispatched_or_skipped
  -> transition.verified_or_unverified
  -> launch.handoff_or_blocked
```

## Implementation sprint gate

Launcher implementation is complete only when path-parity fixtures and Windows smoke tests prove that all entrypoints produce the same event and artifact contract, including Steam visibility and calibration quarantine, without foreground or mouse dependence by default.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgUnifiedLaunchSurfaceDoctrine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgHarnessDoctrine.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowIntelligence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowEventListener.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeContextContinuity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-powershell-utf8-bom-contract.ps1
```

This document is an operator handoff and implementation gate. Canonical authority remains `docs/harness-doctrine.md`, `.tbg/harness/policies/harness-doctrine.policy.json`, and `.tbg/workflows/window-metadata-intelligence.contract.json`.
