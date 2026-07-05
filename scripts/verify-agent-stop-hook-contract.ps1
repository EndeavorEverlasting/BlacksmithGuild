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
