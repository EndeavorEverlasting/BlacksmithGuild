# Offline verifier for worktree isolation and runtime stop guardrails.
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
$agents = 'AGENTS.md'
$worktreeJson = '.tbg\worktrees\local-sprint-worktrees.contract.json'
$stopJson = '.tbg\workflows\runtime-stop-policy.contract.json'
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
Need $agents 'Assert-TbgRuntimeStopPolicy.ps1'
Need $agents 'BlacksmithGuild-pr25-launcher-evidence'

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

if ($failures.Count -gt 0) {
    Write-Host "FAIL: worktree/stop guardrail contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: worktree and runtime stop guardrails verified.' -ForegroundColor Green
exit 0
