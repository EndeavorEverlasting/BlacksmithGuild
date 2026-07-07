# BlacksmithGuild Agent Rules

## Context

This harness layer is for The Blacksmith Guild game-runtime repo.

It borrows workflow ideas from external harness references, but it does not vendor or copy those repositories into this app.

The rule is:

```text
Clone references elsewhere.
Extract patterns.
Commit only repo-local harness contracts that prove BlacksmithGuild behavior.
```

## Identity of this harness

BlacksmithGuild does not need a corporate harness cathedral.

It needs a lean runtime harness that can answer:

```text
Did the game behavior happen?
What artifact proves it?
What blocker remains?
What should the next agent patch?
```

## Non-negotiable rules

1. Do not claim runtime proof from a script merely completing.
2. Do not claim movement, travel, trade, smithing, or automation success without JSON/log evidence from the Bannerlord runtime.
3. Do not ask the user to manually translate raw logs when an English summary or compact result artifact can be produced.
4. Do not log every campaign tick.
5. Do not scan full history during campaign tick.
6. Do not rewrite giant JSON arrays during normal runtime.
7. Do not branch-switch the protected local runtime checkout for unrelated PR work.
8. Do not run build/install/launch/live-cert/full runtime validation without the runtime stop guardrail.

## Protected local runtime checkout

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

Use PR-specific sibling worktrees for concurrent work:

```text
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-prNN-short-name
```

## Runtime stop rule

Before commands that assume Bannerlord should not be running:

```powershell
$env:FORGE_NO_PAUSE = '1'
.\ForgeStop.cmd soft
```

Use force only when explicitly requested or after soft stop is proven insufficient.

## Harness entry points

Static guardrail verifier:

```powershell
.\scripts\tbg\Verify-TbgWorktreeStopGuardrails.ps1
```

Runtime stop policy checker:

```powershell
.\scripts\tbg\Assert-TbgRuntimeStopPolicy.ps1 -Operation live-cert
```

Orchestration map presenter:

```powershell
.\scripts\tbg\Show-TbgOrchestrationMap.ps1
```

Sprint plan pack presenter:

```powershell
.\scripts\tbg\Show-TbgSprintPlanPack.ps1
```

Runtime proof summary validator:

```powershell
.\scripts\tbg\Validate-TbgRuntimeProof.ps1
```

Workflow runner:

```powershell
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start
```

## Sprint plan pack

Use the sprint plan pack to launch bounded parallel TBG sprint chats without duplicating ownership or skipping dependency order.

Canonical file:

```text
docs/harness/TBG_SPRINT_PLAN_PACK.md
```

Presenter:

```powershell
.\scripts\tbg\Show-TbgSprintPlanPack.ps1
.\scripts\tbg\Show-TbgSprintPlanPack.ps1 -Format full
.\scripts\tbg\Show-TbgSprintPlanPack.ps1 -WriteResult
```

Result artifact:

```text
artifacts/latest/tbg-sprint-plan-pack.result.json
```

Default launch order is Chat 00 first, then Chat 01, Chat 02, and Chat 08 only after safe bases are confirmed.

## Orchestration map

The editable map is:

```text
docs/assets/agent-orchestration-map.mmd
```

Machine-readable representation:

```text
docs/assets/agent-orchestration-map.mir.json
```

Presentation rendering:

```text
docs/assets/agent-orchestration-map.svg
```

If the workflow model changes, update Mermaid, MIR, SVG, docs, and verifier together.

## Activity ledger rule

The activity ledger must listen to meaningful manual and automated actions without becoming a hot-path performance tax.

Allowed first-class outputs:

```text
BlacksmithGuild_ActivityJournal.jsonl
BlacksmithGuild_ActivityState.json
BlacksmithGuild_RecentActivity.json
BlacksmithGuild_PlanLedger.jsonl
BlacksmithGuild_PlanComparisons.jsonl
BlacksmithGuild_FeatureSignals.jsonl
BlacksmithGuild_ActivityReport.md
```

Runtime planning should read compact state and bounded recent activity only.

## Final handoff rule

Every sprint handoff must include:

```text
context label
repo / branch / head
owned scope
forbidden scope
files changed
artifacts generated
validation run
skipped checks
gaps
risks
important paths
git and PR state
next command
copy-paste next-agent prompt
```
