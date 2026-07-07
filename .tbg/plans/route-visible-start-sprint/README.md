# Route Visible Start Sprint Closeout

## PR context

```text
[TBG | PR #36 Stabilization | Route Workflow Contracts | branch: docs/agent-workflow-contracts]
```

PR #36 is the workflow contract and guardrail base for route automation. It is intentionally not the runtime route-start implementation. PR #37 stacks on this branch and should consume these contracts after PR #36 is clean.

## Plan directory

```text
.tbg/plans/route-visible-start-sprint/
```

The user-provided `xyz_plan_directory` marker is treated as a placeholder for this directory.

## Sprint objective

Stop using chat as the workflow engine.

Create a repo-owned workflow that can run the route-visible-start proof, summarize runtime state, and emit one compact result file that any AI agent can use without asking for giant logs.

## Executed work

Remote branch:

```text
docs/agent-workflow-contracts
```

Open PR:

```text
https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/36
```

Files added or updated:

```text
.gitignore
.archon/workflows/tbg-route-visible-start.yaml
.tbg/guardrails/runtime-state.guardrail.json
.tbg/plans/route-visible-start-sprint/README.md
.tbg/workflows/route-visible-start.contract.json
docs/architecture/agent-workflow-contracts.md
docs/architecture/local-worktree-lanes.md
docs/handoff/route-visible-start-workflow.md
scripts/tbg/Invoke-TbgWorkflow.ps1
scripts/tbg/Test-TbgRuntimeGuardrail.ps1
```

## What PR #36 owns

PR #36 owns:

```text
workflow contract
runtime-state guardrail
local worktree lane discipline
compact route-visible-start result shape
safe summarizer entrypoint
future-agent handoff docs
```

PR #36 does not own:

```text
MapTrade runtime route-start implementation
Bannerlord live movement proof
save mutation
command inbox route trigger
launcher behavior refactors
PR stack cleanup
```

## Guardrail contract

Machine-readable guardrail:

```text
.tbg/guardrails/runtime-state.guardrail.json
```

Checker:

```text
scripts/tbg/Test-TbgRuntimeGuardrail.ps1
```

Correct acknowledgement flag:

```powershell
.\scripts\tbg\Test-TbgRuntimeGuardrail.ps1 -Intent route-visible-start -StoppedGameConfirmed
```

Do not use `-StopPreflightAcknowledged`; that is not the parameter name in this PR.

Required stop preflight:

```powershell
$env:FORGE_NO_PAUSE = '1'
$env:FORGE_STOP_CHOICE = 'F'
$env:FORGE_STOP_DEFAULT = 'F'
$env:FORGE_STOP_TIMEOUT_SECONDS = '0'
cmd /c .\ForgeStop.cmd force
```

## Local lane discipline

Lane map:

```text
docs/architecture/local-worktree-lanes.md
```

Current known local lanes:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr27-duration-guard
```

If the primary worktree is dirty or conflicted, validate PR #36 in an isolated worktree:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord"

git -C ".\BlacksmithGuild" fetch origin
git -C ".\BlacksmithGuild" worktree add ".\BlacksmithGuild-pr36-agent-workflow-contracts" origin/docs/agent-workflow-contracts
Set-Location ".\BlacksmithGuild-pr36-agent-workflow-contracts"
git switch -c pr36-agent-workflow-contracts
```

If it already exists:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr36-agent-workflow-contracts"
git fetch origin
git status --short
git branch --show-current
git log --oneline -5
```

## Known gaps

### 1. Runtime route start is not patched in this PR

Expected next runtime patch target:

```text
src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs
```

Known seam from remote main:

```text
OnCampaignTick maintains an existing active route, but returns when _activeReport is null.
```

The runtime patch should make campaign tick auto-start route travel when:

```text
campaignReady = true
mapStateActive = true
safeToExecuteTravel = true
recursiveBranchState.nextPlannedBranch = travel
recursiveBranchState.targetSettlement is present
```

### 2. Remote main is behind the user's local sprint branch

The user's local branch is expected to contain newer route-owned-clock work:

```text
feat/route-owned-clock-resume
```

Merge PR #36 into that branch before continuing PR #37 runtime work.

### 3. Full workflow requires native Windows runtime

Bannerlord, Steam paths, DLL installation, ForgeStop, ForgeReboot, and launch behavior are Windows-native.

Use `-SummarizeOnly` for a safe no-launch smoke.

### 4. PR stack is cluttered

Do not delete old PRs blindly. PR cleanup is a separate coordinator lane.

## Known risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| Workflow runner calls existing ForgeReboot | Existing ForgeReboot is still evidence-loop shaped | Runner emits compact result and does not treat ForgeReboot output as product proof |
| Result artifact can read legacy cert | `BlacksmithGuild_MapTradeCert.json` can imply route intent before new route cert exists | Prefer `BlacksmithGuild_MapTradeRouteCert.json`; legacy fallback is transitional only |
| Bannerlord focus pauses movement | Terminal focus can stop campaign clock or UI progression | Route command must be issued from in-mod campaign tick or map-ready lifecycle |
| Local branch diverges from remote main | Remote PR #36 cannot validate local route patch until merged locally | Merge PR #36 into `feat/route-owned-clock-resume`, then run the workflow locally |
| Stale PR stack creates merge confusion | Multiple PRs are stacked on old bases | Use PR #36 as the current workflow base; do not stack new route runtime work on stale branches |
| Generated artifacts become git noise | Workflow creates `artifacts/latest` and runtime cert files | `.gitignore` ignores `BlacksmithGuild_MapTradeRouteCert.json` and keeps `artifacts/` ignored |

## Product targets

### Current PR target

PR #36 passes review if:

```text
- docs explain repo-owned workflow architecture
- local lane discipline exists and blocks cross-worktree confusion
- runtime-state guardrail exists and names exact ForgeStop preflight
- guardrail checker blocks route-visible-start until -StoppedGameConfirmed is used
- route-visible-start contract exists
- workflow runner emits artifacts/latest/route-visible-start.result.json
- route cert output is ignored
- no runtime movement claim is made without cert fields
```

### Next PR target

PR #37 target:

```text
feat(route): start branch-selected route from campaign tick
```

Patch targets:

```text
src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs
src/BlacksmithGuild/MapTrade/MapTradeEvidenceWriter.cs
src/BlacksmithGuild/MapTrade/MapTradeModels.cs
```

Acceptance result:

```json
{
  "workflow": "route-visible-start",
  "verdict": "PASS",
  "runtime": {
    "campaignReady": true,
    "mapStateActive": true,
    "safeToExecuteTravel": true,
    "nextPlannedBranch": "travel"
  },
  "route": {
    "certFound": true,
    "destinationSettlement": "Quyaz",
    "travelCommandIssued": true,
    "routeStarted": true
  }
}
```

## Output paths to analyze

Primary handoff file:

```text
artifacts/latest/route-visible-start.result.json
```

Runtime files read by workflow:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MapTradeRouteCert.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_MapTradeCert.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_CommandAck.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
```

Repo docs and contracts:

```text
docs/architecture/agent-workflow-contracts.md
docs/architecture/local-worktree-lanes.md
docs/handoff/route-visible-start-workflow.md
.tbg/guardrails/runtime-state.guardrail.json
.tbg/workflows/route-visible-start.contract.json
.archon/workflows/tbg-route-visible-start.yaml
scripts/tbg/Test-TbgRuntimeGuardrail.ps1
scripts/tbg/Invoke-TbgWorkflow.ps1
```

## PR #36 validation commands

Static hygiene:

```powershell
git diff --check
git status --short
```

JSON validation:

```powershell
Get-Content ".\.tbg\guardrails\runtime-state.guardrail.json" -Raw | ConvertFrom-Json | Out-Null
Get-Content ".\.tbg\workflows\route-visible-start.contract.json" -Raw | ConvertFrom-Json | Out-Null
```

Guardrail behavior:

```powershell
.\scripts\tbg\Test-TbgRuntimeGuardrail.ps1 -Intent route-visible-start
.\scripts\tbg\Test-TbgRuntimeGuardrail.ps1 -Intent route-visible-start -StoppedGameConfirmed
```

Safe summary only, no stop/build/launch:

```powershell
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz -SummarizeOnly
Get-Content ".\artifacts\latest\route-visible-start.result.json" -Raw
```

Full native workflow, only when explicitly validating runtime:

```powershell
$env:FORGE_NO_PAUSE = '1'
$env:FORGE_STOP_CHOICE = 'F'
$env:FORGE_STOP_DEFAULT = 'F'
$env:FORGE_STOP_TIMEOUT_SECONDS = '0'
cmd /c .\ForgeStop.cmd force

.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz
Get-Content ".\artifacts\latest\route-visible-start.result.json" -Raw
```

## Local merge commands

No game stop is needed for pure Git merge.

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"

git fetch origin pull/36/head:pr-36-agent-workflow-contracts
git switch feat/route-owned-clock-resume
git merge --no-ff pr-36-agent-workflow-contracts
git status --short --ignored
```

## Copy-paste agent handoff

```text
You are continuing The Blacksmith Guild Bannerlord mod sprint.

Repo:
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild

Current local sprint branch:
feat/route-owned-clock-resume

Current remote workflow PR:
PR #36 docs(agent): add route workflow contracts
Branch: docs/agent-workflow-contracts
URL: https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/36

PR #36 is the workflow contract and guardrail base. It is not PR #37 runtime route-start implementation.

Protocol files:
- docs/architecture/agent-workflow-contracts.md
- docs/architecture/local-worktree-lanes.md
- docs/handoff/route-visible-start-workflow.md
- .tbg/guardrails/runtime-state.guardrail.json
- .tbg/workflows/route-visible-start.contract.json
- .tbg/plans/route-visible-start-sprint/README.md
- .archon/workflows/tbg-route-visible-start.yaml
- scripts/tbg/Test-TbgRuntimeGuardrail.ps1
- scripts/tbg/Invoke-TbgWorkflow.ps1

Core doctrine:
- The repo owns the repeated workflow.
- AI agents patch blockers and review diffs.
- Do not ask for giant collector logs first.
- Do not rely on terminal focus to prove movement.
- If commands assume Bannerlord should not be running, include ForgeStop first.
- Use -StoppedGameConfirmed as the guardrail acknowledgement flag.
- The product objective is visible route start under mod control.

Primary artifact:
artifacts/latest/route-visible-start.result.json

First local step:
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
git fetch origin pull/36/head:pr-36-agent-workflow-contracts
git switch feat/route-owned-clock-resume
git merge --no-ff pr-36-agent-workflow-contracts

Then run:
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz -SummarizeOnly
Get-Content ".\artifacts\latest\route-visible-start.result.json" -Raw

The next runtime PR should patch:
src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs
src/BlacksmithGuild/MapTrade/MapTradeEvidenceWriter.cs
src/BlacksmithGuild/MapTrade/MapTradeModels.cs

Known route seam from remote main:
MapTradeAutonomousService.OnCampaignTick currently returns when _activeReport is null. It maintains an active route but does not auto-start one from recursive branch state.

Patch objective:
If campaign map is ready, safeToExecuteTravel is true, nextPlannedBranch is travel, and targetSettlement is resolved, issue the in-game route command from campaign tick and write BlacksmithGuild_MapTradeRouteCert.json.

Acceptance:
artifacts/latest/route-visible-start.result.json must show:
verdict = PASS
runtime.campaignReady = true
runtime.mapStateActive = true
runtime.safeToExecuteTravel = true
runtime.nextPlannedBranch = travel
route.certFound = true
route.travelCommandIssued = true
route.routeStarted = true
route.destinationSettlement = Quyaz

If verdict is BLOCKED, patch only the exact blocker in blockedReason or nextPatchHint.
Do not create another collector ritual.
```
