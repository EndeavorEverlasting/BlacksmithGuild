# PR38 Guardrails Closeout Handoff

## Context label

```text
PR #38 / docs-worktree-stop-guardrails
Context: guardrails, orchestration map, workflow-map presentation hook, activity-ledger doctrine
Base branch: docs/agent-workflow-contracts
Not context: route runtime implementation
Runtime/game stop needed: no
```

## Placeholder note

`xyz_plan_directory` was treated as a placeholder request name. A repository search found no existing path or file content matching that term.

The relevant committed plan files are:

```text
.tbg/plans/campaign-activity-ledger-sprint/README.md
.tbg/plans/route-visible-start-sprint/README.md
```

## What this sprint committed

PR38 makes these concepts repo-owned instead of chat-only:

```text
local sibling-worktree policy
runtime stop-before-live-cert policy
campaign activity ledger doctrine
agent orchestration map doctrine
editable Mermaid diagram
machine-readable MIR diagram
presentation SVG diagram
orchestration-map presenter script
workflow-runner hook for map presentation
static guardrail verifier coverage
```

## Primary files to inspect

```text
docs/architecture/local-worktree-sprint-contract.md
docs/handoff/runtime-stop-guardrails.md
docs/architecture/campaign-activity-ledger.md
docs/architecture/agent-orchestration-map.md
docs/handoff/orchestration-map-guardrails.md
docs/assets/agent-orchestration-map.mmd
docs/assets/agent-orchestration-map.mir.json
docs/assets/agent-orchestration-map.svg
.tbg/worktrees/local-sprint-worktrees.contract.json
.tbg/workflows/runtime-stop-policy.contract.json
.tbg/workflows/campaign-activity-ledger.contract.json
.tbg/plans/campaign-activity-ledger-sprint/README.md
scripts/tbg/Assert-TbgRuntimeStopPolicy.ps1
scripts/tbg/Show-TbgOrchestrationMap.ps1
scripts/tbg/Invoke-TbgWorkflow.ps1
scripts/tbg/Verify-TbgWorktreeStopGuardrails.ps1
```

## Natural orchestration-map surfaces

```powershell
.\scripts\tbg\Show-TbgOrchestrationMap.ps1
.\scripts\tbg\Show-TbgOrchestrationMap.ps1 -Format mermaid
.\scripts\tbg\Show-TbgOrchestrationMap.ps1 -Format mir
.\scripts\tbg\Show-TbgOrchestrationMap.ps1 -Format svg
.\scripts\tbg\Show-TbgOrchestrationMap.ps1 -WriteResult
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow agent-orchestration-map
.\scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow route-visible-start -SummarizeOnly -ShowOrchestrationMap
```

The presenter writes:

```text
artifacts/latest/agent-orchestration-map.result.json
```

## Output paths to analyze

```text
artifacts/latest/agent-orchestration-map.result.json
artifacts/latest/route-visible-start.result.json
<Bannerlord root>\BlacksmithGuild_Status.json
<Bannerlord root>\BlacksmithGuild_MapTradeRouteCert.json
<Bannerlord root>\BlacksmithGuild_MapTradeCert.json
<Bannerlord root>\BlacksmithGuild_CommandAck.json
<Bannerlord root>\BlacksmithGuild_Phase1.log
```

Future activity-ledger outputs:

```text
BlacksmithGuild_ActivityJournal.jsonl
BlacksmithGuild_ActivityState.json
BlacksmithGuild_RecentActivity.json
BlacksmithGuild_PlanLedger.jsonl
BlacksmithGuild_PlanComparisons.jsonl
BlacksmithGuild_FeatureSignals.jsonl
BlacksmithGuild_ActivityReport.md
```

## Known gaps

1. PR38 is not locally validated yet.
2. GitHub currently reports PR38 as not mergeable.
3. PR38 is stacked on PR36, so merge order matters.
4. The broad launch/doc index did not receive the attempted orchestration-map index update because the connector blocked that full-file replacement.
5. The exact original screenshot PNG is not committed. Mermaid, MIR JSON, and SVG are committed.
6. The campaign activity ledger is doctrine and contract only; no C# listener/writer implementation exists yet.
7. No gameplay event seams are wired yet for manual actions, automated actions, or governance-tree node escalation/de-escalation.
8. The diagram verifier checks marker presence and MIR JSON parsing, not full semantic graph equivalence.
9. PR38 does not claim runtime proof, route movement proof, live cert, activity-ledger runtime behavior, or in-game automation success.

## Known risks

```text
stacked PR confusion
mergeability false
false product confidence from docs-only work
diagram drift across Mermaid/MIR/SVG
activity-ledger performance regression if it logs every tick
activity-ledger scope creep
protected checkout contamination
runtime stop omission
old open PR stack confusion
```

## Local validation target

Run from a PR-specific sibling worktree. This is static docs/script validation only and does not require stopping Bannerlord.

```powershell
Set-Location "C:\Users\Cheex\Desktop\dev\Mods\Bannerlord"
git -C ".\BlacksmithGuild" fetch origin

if (-not (Test-Path -LiteralPath ".\BlacksmithGuild-pr38-worktree-stop-guardrails")) {
    git -C ".\BlacksmithGuild" worktree add ".\BlacksmithGuild-pr38-worktree-stop-guardrails" origin/docs-worktree-stop-guardrails
}

Set-Location ".\BlacksmithGuild-pr38-worktree-stop-guardrails"
git switch docs-worktree-stop-guardrails

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Verify-TbgWorktreeStopGuardrails.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Assert-TbgRuntimeStopPolicy.ps1 -Operation live-cert -StopStepIncluded
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Show-TbgOrchestrationMap.ps1 -Format mermaid -WriteResult
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Invoke-TbgWorkflow.ps1 -Workflow agent-orchestration-map -OrchestrationMapFormat mir
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1

git diff --check
git status --short --ignored
```

## PR stack snapshot

```text
PR #36: docs(agent): add route workflow contracts; base main; mergeable true.
PR #37: feat(route): start branch-selected travel from campaign tick; stacked on PR36; mergeable true.
PR #38: docs(guardrails): codify worktree/runtime stop/activity/orchestration; stacked on PR36; mergeable false.
PR #39: feat(harness): add local agent harness foundation; base main; mergeable true.
Legacy/draft PRs: #28-#35 plus older #2/#5/#6/#8/#9/#20/#24 need separate review.
```

Recommended order:

```text
Validate PR36 first or keep it as the explicit stack base.
Repair PR38 mergeability against PR36.
Validate PR38 locally.
Treat PR37 as runtime route-start proof work, not docs/guardrails.
Treat PR39 as a parallel harness foundation that must be reconciled with PR38 before merging overlapping guardrails.
Do not close or merge legacy PRs without explicit review.
```

## Next sprint target

Recommended branch:

```text
feat/activity-ledger-writers
```

Recommended PR title:

```text
feat(activity): add campaign activity ledger writers
```

First implementation slice:

```text
CampaignActivityEvent model
CampaignActivityLedger writer service
append-only JSONL writer
bounded RecentActivity writer
compact ActivityState writer
PlanLedger writer
PlanComparison writer
FeatureSignal writer
English ActivityReport writer
runtime read-boundary verifier
```

Performance invariants:

```text
No per-tick full-history reads.
No giant JSON array rewrites.
No full journal scan inside campaign tick.
Only meaningful events are appended.
Runtime planning reads ActivityState plus RecentActivity only.
Long history is summarized outside the hot path.
```

Gameplay/action domains to listen for later:

```text
manual travel
automated travel
market buy/sell
companion inspection/hire/skip
recruit inspection/hire/skip
smithing/refining/crafting/stamina changes
inventory/gold deltas
settlement entry/exit
plan proposal
plan acceptance/rejection
manual override
governance-tree node escalation/de-escalation
feature signal emission
```

## Parallel model

```text
Agent A / PR38 validator:
Validate PR38 locally, repair mergeability, run BOM/diff/status checks, and keep branch clean.

Agent B / Activity ledger implementer:
After PR38 validation, implement the first activity-ledger writer slice on a new branch. No live cert required for the first writer slice unless explicitly requested.

Agent C / PR stack janitor:
Review open PRs #36, #37, #38, #39 and legacy #28-#35/#24/#20/#9/#8/#6/#5/#2. Do not close or merge anything without explicit approval. Produce stack order and stale-PR disposition plan.
```

## Boundary

This closeout does not claim local validation, runtime proof, clean local working tree, or merge readiness.
