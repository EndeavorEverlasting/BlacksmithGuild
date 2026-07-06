# Runtime stop policy preflight for Blacksmith Guild workflows.
$ErrorActionPreference = 'Stop'

param(
    [ValidateSet('git-inspect','source-patch-only','static-validation','summarize-only','build','install','launch','live-cert','full-workflow','route-visible-start')]
    [string]$Operation = 'static-validation',

    [switch]$WorkflowOwnsStop,

    [switch]$StopStepIncluded,

    [switch]$Json,

    [string]$OutputPath = $null
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$policyPath = Join-Path $repoRoot '.tbg\workflows\runtime-stop-policy.contract.json'
if (-not (Test-Path -LiteralPath $policyPath)) {
    throw "runtime stop policy missing: $policyPath"
}

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$operationPolicy = $policy.operations.$Operation
if (-not $operationPolicy) {
    throw "operation not found in runtime stop policy: $Operation"
}

$stopRequired = [bool]$operationPolicy.stopRequired
$compliant = (-not $stopRequired) -or [bool]$WorkflowOwnsStop -or [bool]$StopStepIncluded
$classification = if ($compliant) { 'runtime_stop_policy_satisfied' } else { [string]$policy.guardrailFailureClass }
$defaultStopCommand = @($policy.defaultStopCommand)

$result = [ordered]@{
    schema = 'tbg.runtimeStopPolicyResult.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    operation = $Operation
    stopRequired = $stopRequired
    reason = [string]$operationPolicy.reason
    workflowOwnsStop = [bool]$WorkflowOwnsStop
    stopStepIncluded = [bool]$StopStepIncluded
    compliant = [bool]$compliant
    classification = $classification
    defaultStopCommand = $defaultStopCommand
    requiredDeclaration = @($policy.requiredAgentDeclaration)
    policyPath = $policyPath
}

if (-not $OutputPath) {
    $latestDir = Join-Path $repoRoot 'artifacts\latest'
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
    $OutputPath = Join-Path $latestDir 'runtime-stop-policy.result.json'
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Host "Runtime/game stop needed: $stopRequired"
    Write-Host "Reason: $($result.reason)"
    Write-Host "Workflow owns stop internally: $([bool]$WorkflowOwnsStop)"
    Write-Host "Stop step included: $([bool]$StopStepIncluded)"
    if ($stopRequired -and -not $compliant) {
        Write-Host 'Stop command if needed:' -ForegroundColor Yellow
        foreach ($line in $defaultStopCommand) { Write-Host $line -ForegroundColor Yellow }
    }
    Write-Host "Classification: $classification"
    Write-Host "Result: $OutputPath"
}

if (-not $compliant) { exit 2 }
exit 0
