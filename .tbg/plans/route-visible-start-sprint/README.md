# Route Visible Start Sprint Closeout

## Plan directory

This directory is the sprint handoff home for the route workflow correction:

```text
.tbg/plans/route-visible-start-sprint/
```

The user-provided `xyz_plan_directory` marker is treated as a placeholder for this directory.

## Sprint objective

Stop using chat as the workflow engine.

Create a repo-owned workflow that can run the route-visible-start proof, summarize the runtime state, and emit one compact result file that any AI agent can use without asking for giant logs.

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
.tbg/workflows/route-visible-start.contract.json
.tbg/plans/route-visible-start-sprint/README.md
docs/architecture/agent-workflow-contracts.md
docs/handoff/route-visible-start-workflow.md
scripts/tbg/Invoke-TbgWorkflow.ps1
```

## Known gaps

### 1. Runtime route start is not patched in this PR

This PR is the workflow contract and runner layer. It does not yet patch `MapTradeAutonomousService.OnCampaignTick` to consume recursive branch travel state and start a route.

Expected next runtime patch target:

```text
src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs
```

Known seam:

```text
OnCampaignTick currently maintains an existing active route, but returns when _activeReport is null.
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

PR #36 is intentionally based on remote `main` and is additive. Merge or cherry-pick it into the local sprint branch before continuing runtime route work.

### 3. Full workflow requires native Windows runtime

Bannerlord, Steam paths, DLL installation, ForgeStop, and launch behavior are Windows-native.

Do not run full runtime proof from WSL unless the node delegates to native Windows PowerShell.

Use `-SummarizeOnly` for a safe no-launch smoke.

### 4. Existing PR stack is cluttered

Remote open PRs include a long stale/draft stack around agent feedback and guardrails. Do not delete them blindly. The clean path for this sprint is PR #36 plus the local route runtime branch.

Recommended cleanup after review:

```text
Keep PR #36 as current workflow-contract PR.
Close or supersede stale draft PRs only after confirming their contents are either merged into main or replaced by PR #36 and the next route runtime PR.
```

## Known risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| Workflow runner calls existing ForgeReboot | Existing ForgeReboot is still evidence-loop shaped | Runner emits compact result and does not treat ForgeReboot output as the product proof |
| Result artifact passes on legacy cert | `BlacksmithGuild_MapTradeCert.json` can imply route intent before new route cert exists | Prefer `BlacksmithGuild_MapTradeRouteCert.json`; legacy fallback is transitional only |
| Bannerlord focus pauses movement | Terminal focus can stop campaign clock or UI progression | Route command must be issued from in-mod campaign tick or map-ready lifecycle |
| Local branch diverges from remote main | Remote PR #36 cannot validate local route patch until merged locally | Merge PR #36 into `feat/route-owned-clock-resume`, then run the workflow locally |
| Stale PR stack creates merge confusion | Multiple draft PRs are stacked on old bases | Use PR #36 as the current clean workflow lane; do not stack new route runtime work on stale draft branches |
| Generated artifacts become git noise | Workflow creates `artifacts/latest` and runtime cert files | `.gitignore` now ignores `BlacksmithGuild_MapTradeRouteCert.json` and keeps `artifacts/` ignored |

## Product targets

### Current PR target

PR #36 target:

```text
Add workflow contracts and compact route-visible-start result runner.
```

This PR passes review if:

```text
- docs explain repo-owned workflow architecture
- route-visible-start contract exists
- workflow runner emits artifacts/latest/route-visible-start.result.json
- route cert output is ignored
- no runtime movement claim is made without cert fields
```

### Next PR target

Next PR target:

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

Runtime source files read by workflow:

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
docs/handoff/route-visible-start-workflow.md
.tbg/workflows/route-visible-start.contract.json
.archon/workflows/tbg-route-visible-start.yaml
scripts/tbg/Invoke-TbgWorkflow.ps1
```

## Local cleanup commands

These commands are for the user's local Windows repo.

No game stop is needed for pure git cleanup.

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"

git fetch origin
git status --short
```

Bring PR #36 into the local sprint branch:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"

git fetch origin pull/36/head:pr-36-agent-workflow-contracts
git switch feat/route-owned-clock-resume
git merge --no-ff pr-36-agent-workflow-contracts
```

Check for local noise:

```powershell
git status --short --ignored
```

If runtime artifacts appear as untracked files, they should be ignored, not committed.

Expected ignored local output includes:

```text
artifacts/
BlacksmithGuild_MapTradeRouteCert.json
BlacksmithGuild_MapTradeCert.json
BlacksmithGuild_Status.json
*.log
```

Push local sprint branch for another machine:

```powershell
git push -u origin feat/route-owned-clock-resume
```

## Workflow smoke commands

Safe summary only, no stop/build/launch:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz -SummarizeOnly
Get-Content ".\artifacts\latest\route-visible-start.result.json" -Raw
```

Full workflow. This stops the game internally:

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild"
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -TargetSettlement Quyaz
Get-Content ".\artifacts\latest\route-visible-start.result.json" -Raw
```

## Copy-paste agent handoff

Use this for the next AI agent:

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

You are not starting from scratch.

The previous agent added a repo-owned workflow contract layer inspired by Archon:
- docs/architecture/agent-workflow-contracts.md
- docs/handoff/route-visible-start-workflow.md
- .tbg/workflows/route-visible-start.contract.json
- .tbg/plans/route-visible-start-sprint/README.md
- .archon/workflows/tbg-route-visible-start.yaml
- scripts/tbg/Invoke-TbgWorkflow.ps1
- .gitignore now ignores BlacksmithGuild_MapTradeRouteCert.json

Core doctrine:
- The repo owns the repeated workflow.
- AI agents patch blockers and review diffs.
- Do not ask for giant collector logs first.
- Do not rely on terminal focus to prove movement.
- If commands assume Bannerlord should not be running, include ForgeStop first.
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

The movement blade already exists:
MapTradeVisibleMovementDriver.TryStartTravel calls CampaignMapMovementHelper.TryMoveToSettlement(MobileParty.MainParty, mission.TargetSettlement, out detail).

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

## Parallel sprint option

A separate agent can work in parallel on PR cleanup without touching runtime route code.

Parallel agent identity:

```text
Agent B: PR stack janitor
```

Agent B scope:

```text
- Review open PRs #2, #5, #6, #8, #9, #20, #24, #28 through #35.
- Identify which are obsolete, superseded, or still valuable.
- Do not close PRs without user approval.
- Produce a cleanup recommendation table.
- Do not touch feat/route-owned-clock-resume runtime work.
```

Primary route agent identity:

```text
Agent A: Route workflow/runtime owner
```

Agent A scope:

```text
- Merge PR #36 locally.
- Run route-visible-start workflow.
- Patch runtime route start only.
- Produce PASS or one exact blocker.
```
