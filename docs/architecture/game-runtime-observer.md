# External Game Runtime Observer

[TBG | Sprint 4 | runtime observer | branch: sprint/game-runtime-observer]

## Scope

This Sprint 4 observer is an out-of-process, read-only producer of Sprint 2
`TbgRuntimeObserverEvent.v1` envelopes. It observes the canonical Bannerlord
process family, bounded Application Error/WER candidates, TaleWorlds report
metadata, log progress, and responsiveness. It never launches, clicks, kills,
stops, or otherwise mutates Bannerlord, saves, the launcher, or command files.

Owned files are `Start-TbgGameRuntimeObserver.ps1`, the three evidence
collectors, `Test-TbgGameRuntimeObserver.ps1`, `ForgeRuntimeObserver.cmd`, and
the Sprint 4 fixture. The shared schemas, incident assembly, launcher
automation, and `src/**` remain outside this sprint.

## Run and lease model

`Start-TbgGameRuntimeObserver.ps1` writes only under
`.local/tbg-runtime-observer/<runId>/`. The starter receives a random lease;
`stop` accepts that exact lease and disposes only observer state. It never
terminates a game process. Lifecycle observation uses a bounded CIM
reconciliation loop and records canonical name, PID, parent PID, session when
available, start/exit observation, and an exit-code value only when available.

```powershell
.\ForgeRuntimeObserver.cmd
.\ForgeRuntimeObserver.cmd status <runId>
.\ForgeRuntimeObserver.cmd stop <runId> <leaseId>
```

The test-only `-TestProcessId` option exists exclusively for the disposable
PowerShell child smoke; it does not broaden game observation or mutation.

## Evidence and classification boundaries

The Windows collector queries a bounded Application log window for Application
Error/WER candidates and stores sanitized excerpts plus hashes. The TaleWorlds
collector discovers reports from supplied local roots, tracks only filename,
metadata, hash, and redacted excerpt, and excludes dump files. No-data is a
successful observation result.

Heartbeat reports fresh progress, stalled progress, missing observer, absent
process, and wrong-run conditions separately. A stale log is never a crash.
`hang.suspected` needs an alive process with stalled activity; `hang.confirmed`
also needs an unresponsive process after the longer bounded threshold.

An `external_terminal_evidence` envelope is evidence to correlate, not a root
cause. A native-crash conclusion requires the later incident assembler to
correlate external evidence, process identity, and timestamp under the runtime
context contract.

## Validation and proof ceiling

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgGameRuntimeObserver.ps1
```

The test uses a disposable child process only. The observer's highest claim is
`harness`; it supplies no launcher, behavior, or live-runtime certification.
