# Agent Workflow Contracts

## Purpose

The Blacksmith Guild cannot rely on chat as the workflow engine.

The project needs repo-owned workflows that turn repeated development loops into deterministic, inspectable steps. AI agents should diagnose blockers and patch seams. They should not repeatedly rediscover how to stop the game, build the DLL, install the module, launch Bannerlord, wait for map readiness, and summarize the result.

This document defines the architecture for that shift.

## Problem this fixes

The current sprint has repeatedly fallen into this pattern:

1. User runs a long PowerShell block.
2. The assistant asks for logs, status files, or source excerpts.
3. A patch lands or partially lands.
4. A validator checks that the harness did something.
5. The larger app behavior is still not proven.
6. The user pays the token cost again.

That is not engineering. That is a slot machine with stack traces.

The workflow must be owned by the repo.

## Design rule

Every product proof workflow must answer one question:

> Did the app behavior happen, or what exact blocker prevented it?

For route automation, the question is:

> Did Bannerlord receive an in-game party travel order toward the selected settlement?

Not:

- Did a collector run?
- Did a log file exist?
- Did an inbox file get written?
- Did PowerShell sleep long enough?

Those are supporting details only.

## Inspiration from Archon

Archon is useful here as a pattern, not as magic.

The relevant pattern is:

- workflows live in the repo
- deterministic steps run through scripts
- AI steps are reserved for judgment-heavy work
- artifacts carry state across steps
- validation gates decide pass, blocked, or fail
- PRs carry the plan and acceptance criteria

Blacksmith Guild should copy that structure while keeping Windows and Bannerlord runtime constraints native.

## Local lane discipline

Concurrent work must be separated by local worktree lane.

The current lane map is documented here:

```text
docs/architecture/local-worktree-lanes.md
```

Agents must identify the lane root, branch, and objective before editing or validating.

Known local lanes:

| Local path | Lane role |
|---|---|
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` | Active integration lane for the current route sprint |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23` | Isolated PR #23 lane |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence` | Launcher evidence lane |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr27-duration-guard` | Duration guard lane |

Do not copy patches between lanes by memory. Use Git merge, cherry-pick, or a named diff.

## Runtime-state guardrail

The machine-readable guardrail lives here:

```text
.tbg/guardrails/runtime-state.guardrail.json
```

The checker lives here:

```text
scripts/tbg/Test-TbgRuntimeGuardrail.ps1
```

Before patching, building, installing, launching, or validating a live cert, an agent must satisfy the guardrail.

Example for route live-cert work:

```powershell
.\scripts\tbg\Test-TbgRuntimeGuardrail.ps1 -Intent route-visible-start
```

If it returns `BLOCKED`, the same result tells the agent the required preflight. After running the preflight, rerun with:

```powershell
.\scripts\tbg\Test-TbgRuntimeGuardrail.ps1 -Intent route-visible-start -StoppedGameConfirmed
```

A workflow such as `Invoke-TbgWorkflow.ps1 -Workflow route-visible-start` may perform its own stop/start lifecycle internally. In that case, the workflow itself is responsible for satisfying this guardrail.

## Hard constraints for this repo

### 1. Game stop is not optional

Any workflow that modifies source, builds, installs, launches, or assumes Bannerlord should not be running must stop the game first.

Required first step:

```powershell
$env:FORGE_NO_PAUSE = '1'
$env:FORGE_STOP_CHOICE = 'F'
$env:FORGE_STOP_DEFAULT = 'F'
$env:FORGE_STOP_TIMEOUT_SECONDS = '0'
cmd /c .\ForgeStop.cmd force
```

### 2. Runtime proof must not depend on terminal focus

Bannerlord can pause or stall when focus changes. A route proof that expects movement while the user is typing in PowerShell is invalid.

Runtime movement must be issued from inside the mod lifecycle, usually one of:

- campaign tick
- map-ready lifecycle
- in-game command driver that polls independently of focus

### 3. In-game certs beat collector packages

Collectors are allowed, but they are not the product result.

Product result files must be compact and stable:

```text
artifacts/latest/<workflow>.result.json
```

For route visible start:

```text
artifacts/latest/route-visible-start.result.json
```

### 4. One blocker only

When blocked, the result must name one exact blocker.

Bad:

```json
{
  "blockedReason": "route did not work, inspect logs"
}
```

Good:

```json
{
  "blockedReason": "safeToExecuteTravel is false",
  "nextPatchHint": "Find why GameSessionState or recursive branch state marks travel unsafe on map surface."
}
```

### 5. Product-shaped gates only

A workflow passes only when the product behavior is represented in the result contract.

For route visible start, minimum pass:

```json
{
  "verdict": "PASS",
  "route": {
    "travelCommandIssued": true,
    "routeStarted": true,
    "destinationSettlement": "Quyaz"
  }
}
```

A harness file existing is not enough.

## Separation of responsibilities

| Owner | Responsibility |
|---|---|
| PowerShell workflow | Stop, build, install, launch, wait, read files, emit compact JSON |
| Bannerlord mod runtime | Issue in-game commands, write certs, report blockers |
| AI agent | Patch exact code seams, review diffs, explain blockers |
| User | Choose product objective and approve visible behavior |

The assistant should consume compact workflow artifacts, not giant terminal transcripts.

## Standard workflow phases

Every workflow result should include a `phase` field using this vocabulary:

| Phase | Meaning |
|---|---|
| `stop` | Stop or kill existing game and automation shells |
| `build` | Compile source |
| `install` | Copy DLL/module to Bannerlord runtime path |
| `launch` | Start Bannerlord through the chosen launch path |
| `map-ready` | Campaign map is available |
| `runtime-action` | In-mod engine attempts the product behavior |
| `summarize` | Script reads runtime status and cert files |
| `done` | Final result written |

If the workflow blocks, `phase` should be the phase that blocked.

## Result contract requirements

Every result JSON should include:

```json
{
  "workflow": "route-visible-start",
  "commit": null,
  "branch": null,
  "startedAtUtc": null,
  "finishedAtUtc": null,
  "verdict": "PASS|BLOCKED|FAIL",
  "phase": null,
  "blockedReason": null,
  "nextPatchHint": null
}
```

Workflow-specific sections may extend this.

## PR review standard

A PR that adds or changes an automation workflow must answer:

1. What product behavior does this workflow prove?
2. What file is the compact result contract?
3. What exact fields define pass?
4. What exact fields define blocked?
5. Does the workflow stop the game before modifying/building/installing?
6. Does it avoid relying on foreground focus?
7. Does it avoid dumping giant logs by default?
8. Does it identify the correct local lane before patching or validation?
9. Does it satisfy `.tbg/guardrails/runtime-state.guardrail.json` for live cert work?

If any answer is vague, the PR is not ready.

## Near-term workflow targets

| Workflow | Product question |
|---|---|
| `route-visible-start` | Did the mod issue a real in-game travel command toward the target settlement? |
| `route-engine-patch` | Did the route code compile and produce the route-start cert schema? |
| `runtime-cert-smoke` | Did the installed DLL produce the expected compact cert files? |
| `config-path-audit` | Does the runtime load the same config file the harness writes? |

Start with `route-visible-start`. It is the pressure point.

## Anti-patterns

Do not create more generic proof folders unless they feed the compact result.

Do not make the user paste full logs when the workflow can summarize:

- status file
- route cert
