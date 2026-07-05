$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repoRoot 'scripts\test-duration-policy.ps1'
$docPath = Join-Path $repoRoot 'docs\operator\test-duration-doctrine.md'
$manifestPath = Join-Path $repoRoot 'docs\handoff\test-duration-policy.manifest.json'
$agentNotePath = Join-Path $repoRoot 'docs\handoff\test-duration-policy-agent-note.md'
$refactorPlanPath = Join-Path $repoRoot 'docs\handoff\test-duration-policy.refactor-plan.md'
$inventoryGuardPath = Join-Path $repoRoot 'scripts\verify-test-duration-inventory-guard.ps1'
$inventoryBaselinePath = Join-Path $repoRoot 'docs\handoff\test-duration-inventory-baseline.tsv'
$coalescencePath = Join-Path $repoRoot 'docs\handoff\pr23-pr25-pr27-coalescence.md'
$handoffDoctrinePath = Join-Path $repoRoot 'docs\handoff\unified-activity-handoff-doctrine.md'
$routeClockDoctrinePath = Join-Path $repoRoot 'docs\handoff\route-owned-clock-resume-doctrine.md'

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
Need-File -Path $inventoryBaselinePath -Label 'inventory baseline'
Need-File -Path $coalescencePath -Label 'PR coalescence note'
Need-File -Path $handoffDoctrinePath -Label 'unified handoff doctrine'
Need-File -Path $routeClockDoctrinePath -Label 'route-owned clock resume doctrine'

if ($errors.Count -eq 0) {
    $helper = Get-Content -LiteralPath $helperPath -Raw -Encoding UTF8
    $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
    $manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    $inventoryGuard = Get-Content -LiteralPath $inventoryGuardPath -Raw -Encoding UTF8
    $inventoryBaseline = Get-Content -LiteralPath $inventoryBaselinePath -Raw -Encoding UTF8
    $coalescence = Get-Content -LiteralPath $coalescencePath -Raw -Encoding UTF8
    $handoffDoctrine = Get-Content -LiteralPath $handoffDoctrinePath -Raw -Encoding UTF8
    $routeClockDoctrine = Get-Content -LiteralPath $routeClockDoctrinePath -Raw -Encoding UTF8
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
    Need-Text -Text $inventoryGuard -Needle 'test-duration-inventory-baseline.tsv' -Label 'inventory baseline wiring'
    Need-Text -Text $inventoryBaseline -Needle 'Baseline existing long-duration defaults' -Label 'inventory baseline purpose'
    Need-Text -Text $inventoryBaseline -Needle 'run-live-assistive-cert.ps1' -Label 'inventory baseline cert sample'
    Need-Text -Text $coalescence -Needle 'Merge order recommendation' -Label 'coalescence merge order'
    Need-Text -Text $coalescence -Needle 'PR #25 - launcher window context helper' -Label 'coalescence PR25 role'
    Need-Text -Text $coalescence -Needle 'PR #23 - engine toggle authority' -Label 'coalescence PR23 role'
    Need-Text -Text $coalescence -Needle 'PR #27 - duration inventory guard' -Label 'coalescence PR27 role'
    Need-Text -Text $coalescence -Needle 'The baseline is not a permission slip' -Label 'coalescence baseline debt rule'
    Need-Text -Text $handoffDoctrine -Needle 'A handoff is a controlled transfer of authority, state, evidence, and next responsibility' -Label 'handoff core rule'
    Need-Text -Text $handoffDoctrine -Needle 'BlacksmithGuild_HandoffEvents.jsonl' -Label 'handoff event stream target'
    Need-Text -Text $handoffDoctrine -Needle 'handoff.recorded' -Label 'handoff recorded event'
    Need-Text -Text $handoffDoctrine -Needle 'handoff.blocked' -Label 'handoff blocked event'
    Need-Text -Text $handoffDoctrine -Needle 'handoff.terminal' -Label 'handoff terminal event'
    Need-Text -Text $handoffDoctrine -Needle 'checkpoint != completion' -Label 'handoff checkpoint boundary'
    Need-Text -Text $handoffDoctrine -Needle 'baseline debt means approval for new debt' -Label 'handoff forbidden baseline claim'
    Need-Text -Text $routeClockDoctrine -Needle '# Route-Owned Clock Resume Doctrine' -Label 'route clock doctrine title'
    Need-Text -Text $routeClockDoctrine -Needle 'AutoTravelToRecommended can ACK Success and assign a route while campaign time remains stopped' -Label 'route clock ACK gap'
    Need-Text -Text $routeClockDoctrine -Needle 'route assigned is an intent checkpoint' -Label 'route assignment checkpoint rule'
    Need-Text -Text $routeClockDoctrine -Needle 'clock_resume_not_attempted' -Label 'route clock missing decision failure'
    Need-Text -Text $routeClockDoctrine -Needle 'Default route observation should stay inside the 30-second doctrine' -Label 'route duration rule'
    Need-Text -Text $routeClockDoctrine -Needle 'partyMovedDistance == 0 alone is not proof that movement did not occur' -Label 'movement observation correction'
    Need-Text -Text $routeClockDoctrine -Needle 'scripts/verify-route-owned-clock-resume-contract.ps1' -Label 'future route verifier target'

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