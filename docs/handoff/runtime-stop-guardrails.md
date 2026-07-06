# Runtime Stop Guardrails

## Purpose

Agents keep forgetting that Bannerlord is a live process with loaded DLLs, launcher state, pause/focus behavior, file handles, runtime JSON surfaces, and automation shells.

This document makes the stop decision part of the repo harness.

## Core rule

If a command block assumes Bannerlord should not be running, the command block must stop Bannerlord first.

Required default stop command from repo root:

```powershell
$env:FORGE_NO_PAUSE = '1'
.\ForgeStop.cmd soft
```

Use force only when the user explicitly requests it or when a prior soft stop is proven insufficient.

## Stop required

Stop before commands that do any of the following:

| Operation | Stop first? | Reason |
|---|---:|---|
| Build and install the mod DLL | yes | Avoid replacing files while the game has old code loaded. |
| Install/copy module files into Bannerlord runtime folders | yes | Avoid partial runtime state and stale DLL behavior. |
| Launch Bannerlord through ForgeReboot, launcher automation, or workflow runner | yes, unless the workflow itself stops first | Avoid attaching to stale or paused sessions. |
| Run a live cert | yes | Live certs claim runtime behavior and must start from a known process state. |
| Run route-visible-start full workflow | yes | The workflow must own launch, focus, and route action conditions. |
| Validate focus, launcher, Continue, attach, map-ready, movement, or route cert behavior | yes | These are live runtime claims. |
| Patch source only, no build/install/runtime run | no | Source edits alone do not require stopping the game. |
| Static docs or contract verifier only | no | No runtime assumption. |
| SummarizeOnly workflow | no | Reads existing compact artifacts and writes a summary result. |
| Git status, branch inspection, PR review | no | No runtime mutation or runtime proof. |

## Live cert definition

A live cert is any validation that claims something about Bannerlord runtime behavior, including:

```text
launcher selected Continue
Bannerlord process attached
campaignReady true
mapStateActive true
safeToExecuteTravel true
command inbox acknowledged
campaign clock resumed
route command issued
route started
movement observed
MapTradeRouteCert produced
```

If the next command produces or validates those claims, stop first unless the workflow itself declares and performs a stop phase.

## Correct command block shape

For build/install/live validation:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"

$env:FORGE_NO_PAUSE = '1'
.\ForgeStop.cmd soft

# build/install/live validation command follows
```

For a workflow that already owns stop internally:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"

.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz
```

The agent must state that the workflow owns the stop phase. If it cannot prove that, add the `ForgeStop.cmd soft` step before the workflow.

## Incorrect command block shape

Do not do this for live proof:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
.\ForgeReboot.cmd
```

unless a stop step immediately precedes it or the command itself routes through a verified stop phase.

Do not do this for live proof:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
dotnet build
.\scripts\install-mod.ps1
```

without stopping first.

## Stop decision preflight

Every agent command block should be preceded by this declaration:

```text
Runtime/game stop needed: yes/no
Reason:
Stop command if needed:
Workflow owns stop internally: yes/no
```

If the answer is `yes`, include the stop command in the command block.

## Repo harness script

Machine-readable stop policy lives in:

```text
.tbg/workflows/runtime-stop-policy.contract.json
```

Script preflight lives in:

```text
scripts/tbg/Assert-TbgRuntimeStopPolicy.ps1
```

Agents should run the script when uncertain instead of guessing.

## Failure classification

If an agent gives a build/install/live-cert command without a required stop step, classify the handoff as:

```text
runtime_stop_guardrail_missing
```

That is a harness failure, not user error.

## Relationship to worktrees

Worktree separation protects concurrent branches.

Runtime stop protects the live game process.

Both are required for live cert work.
