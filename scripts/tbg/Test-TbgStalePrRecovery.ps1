[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-TbgTrue {
    param(
        [bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) { throw $Message }
}

function Assert-TbgPowerShellParses {
    param([Parameter(Mandatory = $true)][string]$Path)

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) {
        throw "$Path does not parse: $(@($errors | ForEach-Object { $_.Message }) -join '; ')"
    }
}

function Read-TbgResult {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-TbgTrue (Test-Path -LiteralPath $Path -PathType Leaf) "Expected result file is missing: $Path"
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Assert-TbgInstructionSet {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][string]$ReportPath,
        [Parameter(Mandatory = $true)][object[]]$RequiredStages
    )

    $instructions = @($Result.instructions)
    Assert-TbgTrue ($instructions.Count -ge 8) 'The result must contain at least one complete operating loop.'
    $stages = @($instructions | ForEach-Object { [string]$_.stage } | Select-Object -Unique)
    foreach ($stage in $RequiredStages) {
        Assert-TbgTrue ($stages -contains [string]$stage) "The result is missing the '$stage' operating-loop stage."
    }

    $reportText = Get-Content -LiteralPath $ReportPath -Raw
    Assert-TbgTrue ($reportText -notmatch '^\s*[\{\[]') 'The English report must not use raw JSON as its primary form.'
    Assert-TbgTrue ($reportText.Contains('The repository is')) 'The English report must name the repository in a complete sentence.'
    Assert-TbgTrue ($reportText.Contains('The next command is')) 'The English report must name the next command in a complete sentence.'

    $forbiddenCommands = @(
        'git reset --hard',
        'git clean -fd',
        'git branch -D',
        'git push --force',
        'git worktree remove --force',
        'gh pr close',
        'gh pr merge'
    )

    foreach ($instruction in $instructions) {
        foreach ($field in @('sequence', 'stage', 'subject', 'verb', 'object', 'condition', 'evidence', 'command', 'sentence')) {
            Assert-TbgTrue ($null -ne $instruction.PSObject.Properties[$field]) "Instruction $($instruction.sequence) is missing '$field'."
        }
        Assert-TbgTrue (-not [string]::IsNullOrWhiteSpace([string]$instruction.subject)) "Instruction $($instruction.sequence) has no subject."
        Assert-TbgTrue (-not [string]::IsNullOrWhiteSpace([string]$instruction.verb)) "Instruction $($instruction.sequence) has no action verb."
        Assert-TbgTrue (-not [string]::IsNullOrWhiteSpace([string]$instruction.object)) "Instruction $($instruction.sequence) has no object."
        Assert-TbgTrue ([string]$instruction.sentence -match '[.!?]$') "Instruction $($instruction.sequence) is not a complete sentence."
        Assert-TbgTrue ($reportText.Contains([string]$instruction.sentence)) "The English report omitted instruction $($instruction.sequence)."
        foreach ($forbidden in $forbiddenCommands) {
            Assert-TbgTrue (-not ([string]$instruction.command).Contains($forbidden)) "Instruction $($instruction.sequence) generated destructive command '$forbidden'."
        }
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$contractPath = Join-Path $repoRoot '.tbg/workflows/stale-pr-recovery-automation.contract.json'
$planPath = Join-Path $repoRoot '.tbg/plans/stale-pr-recovery-20260712/manifest.json'
$invokePath = Join-Path $repoRoot 'scripts/tbg/Invoke-TbgStalePrRecovery.ps1'
$wrapperPath = Join-Path $repoRoot 'ForgeStalePrRecovery.cmd'
$workflowPath = Join-Path $repoRoot '.github/workflows/harness-policy-reports.yml'

foreach ($path in @($contractPath, $planPath, $invokePath, $wrapperPath, $workflowPath)) {
    Assert-TbgTrue (Test-Path -LiteralPath $path -PathType Leaf) "Required stale PR recovery surface is missing: $path"
}

Assert-TbgPowerShellParses -Path $invokePath
Assert-TbgPowerShellParses -Path $PSCommandPath

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
$requiredStages = @('request', 'evidence', 'bounded_plan', 'action', 'artifacts', 'validation', 'report', 'next_decision')
Assert-TbgTrue ([string]$contract.id -eq 'stale-pr-recovery-automation') 'The workflow contract has the wrong id.'
Assert-TbgTrue (@($contract.operatingLoop).Count -eq $requiredStages.Count) 'The workflow contract must define the complete operating loop.'
foreach ($stage in $requiredStages) {
    Assert-TbgTrue (@($contract.operatingLoop) -contains $stage) "The workflow contract is missing operating-loop stage '$stage'."
}
Assert-TbgTrue (@($plan.waves).Count -ge 9) 'The recovery plan must retain every mapped wave.'
Assert-TbgTrue (@($plan.entries | Where-Object { [int]$_.pr -eq 2 }).Count -eq 1) 'The fixture source PR #2 is missing from the recovery plan.'

$workflowText = Get-Content -LiteralPath $workflowPath -Raw
Assert-TbgTrue ($workflowText.Contains("'.tbg/plans/**'")) 'Harness Policy Reports must run when recovery plans change.'
Assert-TbgTrue ($workflowText.Contains('Test-TbgStalePrRecovery.ps1')) 'Harness Policy Reports must execute the stale PR recovery validator.'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-stale-pr-recovery-{0}" -f [Guid]::NewGuid().ToString('N'))
try {
    $floorOutput = Join-Path $tempRoot 'floor'
    & $invokePath -Wave '0' -OutputDirectory $floorOutput | Out-Null
    $floorResultPath = Join-Path $floorOutput 'stale-pr-recovery.result.json'
    $floorReportPath = Join-Path $floorOutput 'stale-pr-recovery.report.md'
    $floorResult = Read-TbgResult -Path $floorResultPath
    Assert-TbgTrue ([string]$floorResult.verdict -eq 'READY') 'Wave 0 must be ready to collect local floor evidence.'
    Assert-TbgTrue ([string]$floorResult.terminalState -eq 'READY_local_floor_collection') 'Wave 0 produced the wrong terminal state.'
    Assert-TbgInstructionSet -Result $floorResult -ReportPath $floorReportPath -RequiredStages $requiredStages

    foreach ($name in @('stale-pr-recovery.result.json', 'stale-pr-recovery.report.md', 'stale-pr-recovery.events.jsonl', 'stale-pr-recovery.progress.log', 'stale-pr-recovery.handoff.md')) {
        Assert-TbgTrue (Test-Path -LiteralPath (Join-Path $floorOutput $name) -PathType Leaf) "Wave 0 did not write required artifact '$name'."
    }

    $blockedOutput = Join-Path $tempRoot 'blocked'
    & $invokePath -Wave 'B' -OutputDirectory $blockedOutput | Out-Null
    $blockedResult = Read-TbgResult -Path (Join-Path $blockedOutput 'stale-pr-recovery.result.json')
    Assert-TbgTrue ([string]$blockedResult.verdict -eq 'BLOCKED') 'Wave B must block when local floor proof is absent.'
    Assert-TbgTrue ([string]$blockedResult.terminalState -eq 'BLOCKED_local_floor_unverified') 'Wave B produced the wrong no-floor terminal state.'
    Assert-TbgTrue ([string]$blockedResult.nextCommand -eq '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked') 'The no-floor blocker must name the repo hygiene command.'

    $readyOutput = Join-Path $tempRoot 'ready'
    & $invokePath -PrNumber 2 -Wave 'B' -LocalFloorVerified -OutputDirectory $readyOutput | Out-Null
    $readyResultPath = Join-Path $readyOutput 'stale-pr-recovery.result.json'
    $readyReportPath = Join-Path $readyOutput 'stale-pr-recovery.report.md'
    $readyResult = Read-TbgResult -Path $readyResultPath
    Assert-TbgTrue ([string]$readyResult.verdict -eq 'READY') 'PR #2 must become ready when the local floor fixture is verified.'
    Assert-TbgTrue (@($readyResult.selectedTargets).Count -eq 1 -and [int]$readyResult.selectedTargets[0] -eq 2) 'The PR #2 fixture selected the wrong target.'
    Assert-TbgTrue ([string]$readyResult.nextCommand -match '^gh pr view 2 ') 'The PR #2 fixture must choose exact source inspection as the next command.'
    Assert-TbgInstructionSet -Result $readyResult -ReportPath $readyReportPath -RequiredStages $requiredStages

    $jsonCount = @($readyResult.instructions).Count
    $eventCount = @(Get-Content -LiteralPath (Join-Path $readyOutput 'stale-pr-recovery.events.jsonl') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    $progressCount = @(Get-Content -LiteralPath (Join-Path $readyOutput 'stale-pr-recovery.progress.log') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    Assert-TbgTrue ($jsonCount -eq $eventCount) 'The JSON result and JSONL event stream must contain the same instruction count.'
    Assert-TbgTrue ($jsonCount -eq $progressCount) 'The JSON result and progress log must contain the same instruction count.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Host 'PASS: stale PR recovery produced deterministic syntactic-English instructions, paired artifacts, fail-closed floor gating, and a bounded ready fixture.'
