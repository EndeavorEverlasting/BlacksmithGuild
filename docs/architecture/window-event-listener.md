# Windows window event listener

[TBG | Sprint 3 | window-event-listener | branch: sprint/window-event-listener]

## Scope

`scripts/tbg/Start-TbgWindowEventListener.ps1` is a read-only, event-first producer for the Sprint 2 runtime observation spine. It installs `SetWinEventHook` handlers for create, show, hide, destroy, title-change, and foreground/focus events. The callback only queues HWND, PID, native event code, and timestamp. The PowerShell loop drains that queue, resolves bounded metadata, deduplicates only hook/poll overlap, and appends `TbgRuntimeObserverEvent.v1` envelopes to `.local/tbg-runtime-observer/<runId>/events.jsonl`.

The listener filters to the exact PID/HWND supplied by run context when available. Without one, it accepts only Bannerlord or TaleWorlds identities. It does not click, focus, send keys, write command inbox files, launch the game, or mutate saves.

## Reconciliation

Polling is retained as reconciliation, not as the primary detector:

1. During the launch-sensitive interval it runs at 100 milliseconds.
2. After the bounded stable interval it slows to 500 milliseconds.
3. A polling-only discovery emits `observer.reconciled`.
4. A callback/listener failure emits `observer.gap`.
5. Cross-source duplicates within 350 milliseconds are suppressed; repeated events from one source remain observable.

Existing `Invoke-TbgWindowIntelligence.ps1` remains the owner of identity registry resolution, UI Automation inspection, exact-control action policy, unknown quarantine, and lifecycle reduction. `listen` is routed through that entrypoint but invokes only the read-only listener.

## Proof boundary

`window.destroyed` means a window disappeared. It does not prove an action was accepted, a process was lost, a crash occurred, campaign readiness, command acknowledgement, movement, trading, or live product success.

The bounded smoke command is:

```powershell
.\ForgeWindowIntel.cmd listen -Mode observe -DurationSeconds 10
```

It establishes only a Windows listener harness observation when it can register hooks. Fixture coverage remains the portable proof when a Windows desktop session cannot register or receive window events.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowEventListener.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowIntelligence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowLifecycle.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgWindowLifecycleRuntime.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeEventObservation.ps1
```

## Forbidden scope

This sprint does not change Sprint 2 shared schemas, lifecycle reducer/runtime adapter behavior, `src/**`, game observers, incident assembly, launcher expansion, OCR-first behavior, live-game certification, or unknown-window action policy.
