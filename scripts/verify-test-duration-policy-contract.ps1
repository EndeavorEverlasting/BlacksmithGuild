$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repoRoot 'scripts\test-duration-policy.ps1'
$docPath = Join-Path $repoRoot 'docs\operator\test-duration-doctrine.md'
$manifestPath = Join-Path $repoRoot 'docs\handoff\test-duration-policy.manifest.json'
$agentNotePath = Join-Path $repoRoot 'docs\handoff\test-duration-policy-agent-note.md'
$refactorPlanPath = Join-Path $repoRoot 'docs\handoff\test-duration-policy.refactor-plan.md'
$inventoryGuardPath = Join-Path $repoRoot 'scripts\verify-test-duration-inventory-guard.ps1'

$errors = New-Object System.Collections.Generic.List[string]

function Note-Error {
    param([string]$Message)
    $errors.Add($Message) | Out-Null
}

function Need-File {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) { Note-Error "$Label missing" }
}

function Need-Text {
    param([string]$Text, [string]$Needle, [string]$Label)
    if ($Text -notlike "*$Needle*") { Note-Error "$Label missing" }
}

Need-File -Path $helperPath -Label 'helper'
Need-File -Path $docPath -Label 'doctrine doc'
Need-File -Path $manifestPath -Label 'manifest'
Need-File -Path $agentNotePath -Label 'agent note'
Need-File -Path $refactorPlanPath -Label 'refactor plan'
Need-File -Path $inventoryGuardPath -Label 'inventory guard'

if ($errors.Count -eq 0) {
    $helper = Get-Content -LiteralPath $helperPath -Raw -Encoding UTF8
    $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
    $manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    $inventoryGuard = Get-Content -LiteralPath $inventoryGuardPath -Raw -Encoding UTF8
    $manifest = $manifestText | ConvertFrom-Json

    Need-Text -Text $helper -Needle 'function Resolve-TbgTestDurationBudget' -Label 'resolver'
    Need-Text -Text $helper -Needle 'Read-TbgTestDurationPolicyManifest' -Label 'manifest reader'
    Need-Text -Text $helper -Needle 'Test-TbgExplicitLongRunProfile' -Label 'extended profile gate'
    Need-Text -Text $helper -Needle 'New-TbgTestDurationDeadline' -Label 'deadline helper'
    Need-Text -Text $helper -Needle 'Test-TbgTestDurationExpired' -Label 'expiry helper'
    Need-Text -Text $helper -Needle 'Write-TbgTestDurationBudget' -Label 'logger'
    Need-Text -Text $doc -Needle 'Thirty seconds is the default test-duration budget' -Label 'core doctrine text'
    Need-Text -Text $manifestText -Needle '"defaultBudgetSec": 30' -Label 'manifest default'
    Need-Text -Text $inventoryGuard -Needle 'Start-Sleep' -Label 'inventory sleep scan'
    Need-Text -Text $inventoryGuard -Needle 'TimeoutSec' -Label 'inventory timeout scan'
    Need-Text -Text $inventoryGuard -Needle 'MaxRuntimeMinutes' -Label 'inventory minute scan'
    Need-Text -Text $inventoryGuard -Needle 'AllowLongRun' -Label 'inventory explicit allow marker'
    Need-Text -Text $inventoryGuard -Needle 'LongRunReason' -Label 'inventory reason allow marker'

    if ([int]$manifest.defaultBudgetSec -ne 30) { Note-Error 'manifest default is not 30' }

    . $helperPath

    $defaultBudget = Resolve-TbgTestDurationBudget -Caller 'contract-default' -PolicyPath $manifestPath
    if ([int]$defaultBudget.budgetSec -ne 30) { Note-Error 'default budget mismatch' }
    if ($defaultBudget.isLongRun) { Note-Error 'default classified as extended' }

    $shortBudget = Resolve-TbgTestDurationBudget -RequestedBudgetSec 15 -Caller 'contract-short' -PolicyPath $manifestPath
    if ([int]$shortBudget.budgetSec -ne 15) { Note-Error 'short budget mismatch' }

    $rejected = $false
    try {
        Resolve-TbgTestDurationBudget -RequestedBudgetSec 60 -Caller 'contract-reject' -PolicyPath $manifestPath | Out-Null
    } catch {
        $rejected = $true
    }
    if (-not $rejected) { Note-Error 'extended budget should require explicit approval' }

    $approved = Resolve-TbgTestDurationBudget -RequestedBudgetSec 60 -AllowLongRun -LongRunReason 'contract probe' -Caller 'contract-approve' -PolicyPath $manifestPath
    if (-not $approved.isLongRun) { Note-Error 'approved extended budget not classified' }
    if ([int]$approved.budgetSec -ne 60) { Note-Error 'approved budget mismatch' }

    $deadline = New-TbgTestDurationDeadline -Budget $defaultBudget
    if ($deadline -le (Get-Date)) { Note-Error 'deadline not in future' }
}

if ($errors.Count -gt 0) {
    Write-Host "FAIL: test duration policy contract has $($errors.Count) issue(s)." -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: test duration policy contract is wired.' -ForegroundColor Green
exit 0
