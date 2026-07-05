# Offline contract verifier for the agent stop hook trigger layer.
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

$triggerDoc = 'docs\handoff\agent-stop-hook-trigger.md'
$outputSchema = 'docs\handoff\agent-stop-hook-output-schema.md'
$runbook = 'docs\handoff\agent-evidence-follow-through-runbook.md'
$checklist = 'docs\handoff\agent-stop-hook-implementation-checklist.md'
$manifest = 'docs\handoff\agent-trigger-map.manifest.json'
$expectedHook = 'scripts\invoke-agent-stop-hook.ps1'

Assert-TextContains -RelativePath $triggerDoc -Needle '# Agent Stop Hook Trigger Doctrine' -Why 'trigger doctrine must exist'
Assert-TextContains -RelativePath $triggerDoc -Needle 'scripts/invoke-agent-stop-hook.ps1' -Why 'primary hook script must be named'
Assert-TextContains -RelativePath $triggerDoc -Needle 'BlacksmithGuild_AgentFeedback.json' -Why 'feedback output must be named'
Assert-TextContains -RelativePath $triggerDoc -Needle 'BlacksmithGuild_AgentRemediationPlan.json' -Why 'remediation output must be named'
Assert-TextContains -RelativePath $triggerDoc -Needle 'artifacts/agent-stop-hook/<timestamp>/' -Why 'evidence archive location must be documented'
Assert-TextContains -RelativePath $triggerDoc -Needle 'Follow-through rule' -Why 'agents must have a follow-through rule'
Assert-TextContains -RelativePath $triggerDoc -Needle 'Agent report contract' -Why 'agent report contract must be documented'
Assert-TextContains -RelativePath $triggerDoc -Needle 'classification' -Why 'classification report must be required'
Assert-TextContains -RelativePath $triggerDoc -Needle 'allowed claims' -Why 'allowed claims report must be required'
Assert-TextContains -RelativePath $triggerDoc -Needle 'forbidden claims' -Why 'forbidden claims report must be required'
Assert-TextContains -RelativePath $triggerDoc -Needle 'blockers' -Why 'blocker report must be required'

Assert-TextContains -RelativePath $outputSchema -Needle '# Agent Stop Hook Output Schema' -Why 'output schema must exist'
Assert-TextContains -RelativePath $outputSchema -Needle 'TbgAgentStopHookSummary.v1' -Why 'summary schema version must be documented'
Assert-TextContains -RelativePath $outputSchema -Needle 'AgentStopHookSummary.json' -Why 'summary output file must be documented'
Assert-TextContains -RelativePath $outputSchema -Needle 'patchCandidateCount' -Why 'patch candidate count must be represented'
Assert-TextContains -RelativePath $outputSchema -Needle 'Blocking rule' -Why 'blocking rule must be documented'
Assert-TextContains -RelativePath $outputSchema -Needle 'Archive rule' -Why 'archive rule must be documented'
Assert-TextContains -RelativePath $outputSchema -Needle 'Report rule' -Why 'report rule must be documented'

Assert-TextContains -RelativePath $runbook -Needle '# Agent Evidence Follow-Through Runbook' -Why 'follow-through runbook must exist'
Assert-TextContains -RelativePath $runbook -Needle 'Required first read' -Why 'agent read order must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'If classification is checkpoint_reached' -Why 'checkpoint follow-through must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'If classification is runtime_blocked' -Why 'runtime-blocked follow-through must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'If classification is contract_fail' -Why 'contract-fail follow-through must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'If classification is stale_evidence' -Why 'stale evidence follow-through must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'If classification is unclassified' -Why 'unclassified follow-through must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'Remediation plan rule' -Why 'remediation plan priority must be documented'
Assert-TextContains -RelativePath $runbook -Needle 'Evidence discipline' -Why 'evidence discipline must be documented'

Assert-TextContains -RelativePath $checklist -Needle '# Agent Stop Hook Implementation Checklist' -Why 'implementation checklist must exist'
Assert-TextContains -RelativePath $checklist -Needle 'scripts/invoke-agent-stop-hook.ps1 exists' -Why 'completion rule must require executable hook'
Assert-TextContains -RelativePath $checklist -Needle 'AgentStopHookSummary.json' -Why 'completion rule must require summary output'
Assert-TextContains -RelativePath $checklist -Needle 'FailOnBlocking' -Why 'strict mode option must be listed'
Assert-TextContains -RelativePath $checklist -Needle 'SkipPlanner' -Why 'planner skip option must be listed'
Assert-TextContains -RelativePath $checklist -Needle 'NoPlannerScripts' -Why 'no generated planner scripts option must be listed'
Assert-TextContains -RelativePath $checklist -Needle 'ArtifactRoot override' -Why 'artifact root override must be listed'
Assert-TextContains -RelativePath $checklist -Needle 'Non-goals for first implementation' -Why 'implementation non-goals must be explicit'

Assert-TextContains -RelativePath $manifest -Needle '"policyId": "agent-stop-hook-trigger"' -Why 'manifest policy id must be present'
Assert-TextContains -RelativePath $manifest -Needle '"primaryTrigger": "scripts/invoke-agent-stop-hook.ps1"' -Why 'manifest must name primary trigger'
Assert-TextContains -RelativePath $manifest -Needle '"triggerMoment": "end_of_bounded_agent_task"' -Why 'manifest must name trigger moment'
Assert-TextContains -RelativePath $manifest -Needle '"generatedFeedback": "BlacksmithGuild_AgentFeedback.json"' -Why 'manifest must name feedback output'
Assert-TextContains -RelativePath $manifest -Needle '"generatedRemediationPlan": "BlacksmithGuild_AgentRemediationPlan.json"' -Why 'manifest must name remediation output'
Assert-TextContains -RelativePath $manifest -Needle '"run cheap guardrails"' -Why 'manifest must include guardrail duty'
Assert-TextContains -RelativePath $manifest -Needle '"capture evidence logs"' -Why 'manifest must include evidence capture duty'
Assert-TextContains -RelativePath $manifest -Needle '"write feedback JSON"' -Why 'manifest must include feedback duty'
Assert-TextContains -RelativePath $manifest -Needle '"write remediation plan JSON"' -Why 'manifest must include remediation duty'
Assert-TextContains -RelativePath $manifest -Needle '"runtime_blocked"' -Why 'manifest must include runtime blocked classification'
Assert-TextContains -RelativePath $manifest -Needle '"contractVerifier": "scripts/verify-agent-stop-hook-contract.ps1"' -Why 'manifest must point to this verifier'

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $expectedHook))) {
    $failures.Add("missing executable trigger: $expectedHook") | Out-Null
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: agent stop hook contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: agent stop hook contract verified.' -ForegroundColor Green
