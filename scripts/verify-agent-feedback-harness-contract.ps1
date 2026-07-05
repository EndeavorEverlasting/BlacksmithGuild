# Offline contract verifier for agent feedback harness doctrine.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
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

function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

$harnessDoc = 'docs\handoff\agent-feedback-harness.md'
$schemaDoc = 'docs\handoff\agent-feedback-schema.md'
$manifest = 'docs\handoff\agent-feedback-harness.manifest.json'

Assert-TextContains -RelativePath $harnessDoc -Needle '# Agent Feedback Harness Doctrine' -Why 'main doctrine must exist'
Assert-TextContains -RelativePath $harnessDoc -Needle 'artifact evidence' -Why 'feedback pipeline must begin from artifacts'
Assert-TextContains -RelativePath $harnessDoc -Needle 'normalized interpretation' -Why 'harness must normalize raw logs for agents'
Assert-TextContains -RelativePath $harnessDoc -Needle 'BlacksmithGuild_AgentFeedback.json' -Why 'planned output surface must be named'
Assert-TextContains -RelativePath $harnessDoc -Needle 'allowedClaims' -Why 'agents need explicit allowed claims'
Assert-TextContains -RelativePath $harnessDoc -Needle 'forbiddenClaims' -Why 'agents need explicit forbidden claims'
Assert-TextContains -RelativePath $harnessDoc -Needle 'checkpoint_reached' -Why 'checkpoint classification must be defined'
Assert-TextContains -RelativePath $harnessDoc -Needle 'runtime_blocked' -Why 'runtime blocker classification must be defined'
Assert-TextContains -RelativePath $harnessDoc -Needle 'stale_evidence' -Why 'stale evidence must be a first-class state'
Assert-TextContains -RelativePath $harnessDoc -Needle 'bounded' -Why 'next sprint instructions must be bounded'
Assert-TextContains -RelativePath $harnessDoc -Needle 'branchable' -Why 'next sprint instructions must identify branch/worktree shape'
Assert-TextContains -RelativePath $harnessDoc -Needle 'CampaignOrchestrator = in-game engine handoff' -Why 'campaign and agent harnesses must remain distinct'
Assert-TextContains -RelativePath $harnessDoc -Needle 'AgentFeedbackHarness = repo feedback to next coding sprint' -Why 'agent harness purpose must be explicit'
Assert-TextContains -RelativePath $harnessDoc -Needle 'write-agent-feedback-summary.ps1' -Why 'future writer script must be named'
Assert-TextContains -RelativePath $harnessDoc -Needle 'must not silently merge PRs' -Why 'harness safety boundary must be explicit'

Assert-TextContains -RelativePath $schemaDoc -Needle '# Agent Feedback Schema' -Why 'schema doctrine must exist'
Assert-TextContains -RelativePath $schemaDoc -Needle 'TbgAgentFeedback.v1' -Why 'schema version must be named'
Assert-TextContains -RelativePath $schemaDoc -Needle 'repoState' -Why 'repo state is required for branch-aware feedback'
Assert-TextContains -RelativePath $schemaDoc -Needle 'runtimeState' -Why 'runtime state must be represented when known'
Assert-TextContains -RelativePath $schemaDoc -Needle 'classification' -Why 'classification object must exist'
Assert-TextContains -RelativePath $schemaDoc -Needle 'evidence' -Why 'evidence array must exist'
Assert-TextContains -RelativePath $schemaDoc -Needle 'nextSprint' -Why 'next sprint object must exist'
Assert-TextContains -RelativePath $schemaDoc -Needle 'validation' -Why 'validation commands must be surfaced'
Assert-TextContains -RelativePath $schemaDoc -Needle 'command_ack' -Why 'command ack artifacts must be recognized'
Assert-TextContains -RelativePath $schemaDoc -Needle 'git_diff_check' -Why 'git diff check artifacts must be recognized'
Assert-TextContains -RelativePath $schemaDoc -Needle 'proof_bundle' -Why 'proof bundles must be recognized'
Assert-TextContains -RelativePath $schemaDoc -Needle 'Freshness doctrine' -Why 'freshness rules must be documented'
Assert-TextContains -RelativePath $schemaDoc -Needle 'Do not emit validation that belongs to another PR' -Why 'validation must be branch-specific'

Assert-TextContains -RelativePath $manifest -Needle '"policyId": "agent-feedback-harness"' -Why 'manifest must name policy id'
Assert-TextContains -RelativePath $manifest -Needle '"plannedOutput": "BlacksmithGuild_AgentFeedback.json"' -Why 'manifest must name output file'
Assert-TextContains -RelativePath $manifest -Needle '"checkpoint_reached"' -Why 'manifest must list checkpoint state'
Assert-TextContains -RelativePath $manifest -Needle '"stale_evidence"' -Why 'manifest must list stale evidence state'
Assert-TextContains -RelativePath $manifest -Needle '"allowedClaims"' -Why 'manifest must require allowed claims'
Assert-TextContains -RelativePath $manifest -Needle '"forbiddenClaims"' -Why 'manifest must require forbidden claims'
Assert-TextContains -RelativePath $manifest -Needle '"futureVerifier": "scripts/verify-agent-feedback-harness-contract.ps1"' -Why 'manifest must point to this verifier'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: agent feedback harness contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: agent feedback harness contract verified.' -ForegroundColor Green
