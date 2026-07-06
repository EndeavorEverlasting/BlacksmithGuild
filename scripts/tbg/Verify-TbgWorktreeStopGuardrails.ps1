# Offline verifier for worktree isolation, runtime stop guardrails, activity ledger doctrine, and orchestration map assets.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Need {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$RelativePath missing '$Needle'") | Out-Null
    }
}

$worktreeDoc = 'docs\architecture\local-worktree-sprint-contract.md'
$stopDoc = 'docs\handoff\runtime-stop-guardrails.md'
$workflowDoc = 'docs\architecture\agent-workflow-contracts.md'
$activityDoc = 'docs\architecture\campaign-activity-ledger.md'
$mapDoc = 'docs\architecture\agent-orchestration-map.md'
$mapGuardDoc = 'docs\handoff\orchestration-map-guardrails.md'
$mapMmd = 'docs\assets\agent-orchestration-map.mmd'
$mapMir = 'docs\assets\agent-orchestration-map.mir.json'
$mapSvg = 'docs\assets\agent-orchestration-map.svg'
$agents = 'AGENTS.md'
$worktreeJson = '.tbg\worktrees\local-sprint-worktrees.contract.json'
$stopJson = '.tbg\workflows\runtime-stop-policy.contract.json'
$activityJson = '.tbg\workflows\campaign-activity-ledger.contract.json'
$activityPlan = '.tbg\plans\campaign-activity-ledger-sprint\README.md'
$stopScript = 'scripts\tbg\Assert-TbgRuntimeStopPolicy.ps1'

Need $worktreeDoc 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild'
Need $worktreeDoc 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23'
Need $worktreeDoc 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence'
Need $worktreeDoc 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr27-duration-guard'
Need $worktreeDoc 'BlacksmithGuild-prNN-short-name'
Need $worktreeDoc 'Protected BlacksmithGuild checkout untouched'
Need $worktreeDoc 'Runtime/game stop needed'
Need $worktreeDoc 'docs/handoff/runtime-stop-guardrails.md'

Need $stopDoc 'ForgeStop.cmd soft'
Need $stopDoc 'Live certs claim runtime behavior and must start from a known process state.'
Need $stopDoc 'runtime_stop_guardrail_missing'
Need $stopDoc 'scripts/tbg/Assert-TbgRuntimeStopPolicy.ps1'
Need $stopDoc 'Workflow owns stop internally'
Need $stopDoc 'Use force only when the user explicitly requests it'

Need $workflowDoc 'docs/architecture/local-worktree-sprint-contract.md'
Need $workflowDoc 'docs/handoff/runtime-stop-guardrails.md'
Need $workflowDoc 'Required agent preflight declaration'
Need $workflowDoc 'Do not branch-switch the protected runtime checkout'
Need $workflowDoc 'Do not run build/install/live-cert validation without either a stop step or a verified workflow-owned stop phase.'

Need $agents 'Local worktree rule'
Need $agents 'Runtime stop rule'
Need $agents 'Campaign activity ledger rule'
Need $agents 'Assert-TbgRuntimeStopPolicy.ps1'
Need $agents 'BlacksmithGuild-pr25-launcher-evidence'
Need $agents 'docs/architecture/campaign-activity-ledger.md'

Need $worktreeJson 'tbg.localSprintWorktrees.v1'
Need $worktreeJson 'BlacksmithGuild-pr27-duration-guard'
Need $worktreeJson 'requiredAgentDeclaration'
Need $worktreeJson 'forbiddenShortcut'

Need $stopJson 'tbg.runtimeStopPolicy.v1'
Need $stopJson 'route-visible-start'
Need $stopJson 'live-cert'
Need $stopJson 'runtime_stop_guardrail_missing'
Need $stopJson 'ForgeStop.cmd soft'

Need $stopScript 'tbg.runtimeStopPolicyResult.v1'
Need $stopScript 'runtime_stop_policy_satisfied'
Need $stopScript 'runtime_stop_guardrail_missing'
Need $stopScript 'StopStepIncluded'
Need $stopScript 'WorkflowOwnsStop'

Need $activityDoc '# Campaign Activity Ledger'
Need $activityDoc 'Append meaningful events.'
Need $activityDoc 'Compare proposed plans against what the user does next.'
Need $activityDoc 'BlacksmithGuild_ActivityJournal.jsonl'
Need $activityDoc 'BlacksmithGuild_ActivityState.json'
Need $activityDoc 'BlacksmithGuild_RecentActivity.json'
Need $activityDoc 'BlacksmithGuild_PlanLedger.jsonl'
Need $activityDoc 'BlacksmithGuild_PlanComparisons.jsonl'
Need $activityDoc 'BlacksmithGuild_FeatureSignals.jsonl'
Need $activityDoc 'BlacksmithGuild_ActivityReport.md'
Need $activityDoc 'Do not log every campaign tick.'
Need $activityDoc 'Repeated rejection is a product signal.'
Need $activityDoc 'English-first reporting doctrine'
Need $activityDoc 'What did the user do instead, what does that teach the planner, and how do we make the next plan less annoying?'

Need $activityJson 'tbg.campaignActivityLedgerContract.v1'
Need $activityJson 'campaign-activity-ledger'
Need $activityJson 'appendOnly'
Need $activityJson 'boundedRuntimeRead'
Need $activityJson 'englishReport'
Need $activityJson 'repeatedDivergenceBecomesFeatureSignal'
Need $activityJson 'englishReportRequirements'
Need $activityJson 'runtimeReadsBoundedState'

Need $activityPlan 'Campaign Activity Ledger Sprint Plan'
Need $activityPlan 'The app suggested X.'
Need $activityPlan 'The user did Y instead.'
Need $activityPlan 'BlacksmithGuild_ActivityJournal.jsonl'
Need $activityPlan 'Do not scan full `ActivityJournal.jsonl` during normal planning.'
Need $activityPlan 'English report requirement'
Need $activityPlan 'artifacts/latest/campaign-activity-ledger.result.json'

Need $mapDoc '# Agent Orchestration Map'
Need $mapDoc 'docs/assets/agent-orchestration-map.mmd'
Need $mapDoc 'docs/assets/agent-orchestration-map.mir.json'
Need $mapDoc 'docs/assets/agent-orchestration-map.svg'
Need $mapDoc 'The Mermaid file is the canonical editable diagram.'
Need $mapDoc 'The repo owns the loop.'
Need $mapGuardDoc '# Orchestration Map Guardrails'
Need $mapGuardDoc 'The orchestration map is not a decorative screenshot.'
Need $mapGuardDoc 'Mermaid diagram: editable source of truth.'
Need $mapGuardDoc 'MIR JSON: machine-readable representation.'
Need $mapGuardDoc 'Do not update only the screenshot or SVG.'
Need $mapMmd 'flowchart LR'
Need $mapMmd 'Explore agent 1'
Need $mapMmd 'Plan - writes plan.md'
Need $mapMmd 'Implement - writes report.md'
Need $mapMmd 'Review agent 2 - correctness'
Need $mapMmd 'Done - Open PR'
Need $mapMir 'tbg.diagram.mir.v1'
Need $mapMir 'docs/assets/agent-orchestration-map.mmd'
Need $mapMir 'Review agent 3 - simplify'
Need $mapMir 'Done - Open PR'
Need $mapSvg '<title id="title">Orchestrating coding agent sessions</title>'
Need $mapSvg 'Explore agent 1'
Need $mapSvg 'Writes plan.md'
Need $mapSvg 'writes report.md'
Need $mapSvg 'agent 2 - correctness'
Need $mapSvg 'Open PR'

try {
    Get-Content -LiteralPath (Join-Path $repoRoot $worktreeJson) -Raw | ConvertFrom-Json | Out-Null
} catch {
    $failures.Add("$worktreeJson is not valid JSON: $($_.Exception.Message)") | Out-Null
}

try {
    $policy = Get-Content -LiteralPath (Join-Path $repoRoot $stopJson) -Raw | ConvertFrom-Json
    if (-not $policy.operations.'live-cert'.stopRequired) {
        $failures.Add('runtime stop policy must require stop for live-cert') | Out-Null
    }
    if (-not $policy.operations.'route-visible-start'.stopRequired) {
        $failures.Add('runtime stop policy must require stop for route-visible-start') | Out-Null
    }
    if ($policy.operations.'summarize-only'.stopRequired) {
        $failures.Add('runtime stop policy must not require stop for summarize-only') | Out-Null
    }
} catch {
    $failures.Add("$stopJson is not valid JSON: $($_.Exception.Message)") | Out-Null
}

try {
    $activity = Get-Content -LiteralPath (Join-Path $repoRoot $activityJson) -Raw | ConvertFrom-Json
    if (-not $activity.meaningfulEventsOnly) {
        $failures.Add('activity ledger contract must require meaningfulEventsOnly') | Out-Null
    }
    if (-not $activity.planFeedback.repeatedDivergenceBecomesFeatureSignal) {
        $failures.Add('activity ledger contract must turn repeated divergence into feature signal') | Out-Null
    }
    if (-not $activity.implementationAcceptance.englishReportWritten) {
        $failures.Add('activity ledger implementation acceptance must require English report') | Out-Null
    }
} catch {
    $failures.Add("$activityJson is not valid JSON: $($_.Exception.Message)") | Out-Null
}

try {
    Get-Content -LiteralPath (Join-Path $repoRoot $mapMir) -Raw | ConvertFrom-Json | Out-Null
} catch {
    $failures.Add("$mapMir is not valid JSON: $($_.Exception.Message)") | Out-Null
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: worktree/stop/activity/map guardrail contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: worktree, runtime stop, activity ledger, and orchestration map guardrails verified.' -ForegroundColor Green
exit 0
