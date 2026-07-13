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

function Read-TbgJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-TbgTrue (Test-Path -LiteralPath $Path -PathType Leaf) "Expected JSON file is missing: $Path"
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planPath = Join-Path $repoRoot '.tbg/plans/stale-pr-recovery-20260712/manifest.json'
$ledgerPath = Join-Path $repoRoot '.tbg/plans/stale-pr-recovery-20260712/progress.json'
$dashboardPath = Join-Path $repoRoot 'docs/handoff/stale-pr-cherry-pick-progress.md'
$generatorPath = Join-Path $repoRoot 'scripts/tbg/Write-TbgStalePrRecoveryProgress.ps1'
$wrapperPath = Join-Path $repoRoot 'ForgeStalePrProgress.cmd'
$recoveryWrapperPath = Join-Path $repoRoot 'ForgeStalePrRecovery.cmd'
$contractPath = Join-Path $repoRoot '.tbg/workflows/stale-pr-recovery-automation.contract.json'
$workflowPath = Join-Path $repoRoot '.github/workflows/harness-policy-reports.yml'

foreach ($path in @($planPath, $ledgerPath, $dashboardPath, $generatorPath, $wrapperPath, $recoveryWrapperPath, $contractPath, $workflowPath)) {
    Assert-TbgTrue (Test-Path -LiteralPath $path -PathType Leaf) "Required stale PR progress surface is missing: $path"
}

Assert-TbgPowerShellParses -Path $generatorPath
Assert-TbgPowerShellParses -Path $PSCommandPath

$plan = Read-TbgJson -Path $planPath
$ledger = Read-TbgJson -Path $ledgerPath
$contract = Read-TbgJson -Path $contractPath
$planPrs = @($plan.entries | ForEach-Object { [int]$_.pr } | Sort-Object)
$ledgerPrs = @($ledger.entries | ForEach-Object { [int]$_.pr } | Sort-Object)

Assert-TbgTrue ($planPrs.Count -eq 16) 'The committed recovery plan must contain the 16 mapped stale pull requests.'
Assert-TbgTrue (($planPrs -join ',') -eq ($ledgerPrs -join ',')) 'The progress ledger must contain exactly the same pull requests as the recovery plan.'
Assert-TbgTrue (@($ledger.entries | Group-Object pr | Where-Object { $_.Count -ne 1 }).Count -eq 0) 'Every stale pull request must appear exactly once in the progress ledger.'
Assert-TbgTrue (@($ledger.terminalCompleteStatuses).Count -eq 4) 'The progress ledger must define four terminal completion statuses.'

$dashboardText = Get-Content -LiteralPath $dashboardPath -Raw
Assert-TbgTrue ($dashboardText.Contains('**Overall: INCOMPLETE**')) 'The tracked dashboard must display the current incomplete state.'
Assert-TbgTrue ($dashboardText.Contains('0 of 16 stale pull requests are complete')) 'The tracked dashboard must display the initial completion count.'
Assert-TbgTrue ($dashboardText.Contains('PR #65')) 'The tracked dashboard must show the active Wave A replacement pull request.'
Assert-TbgTrue ($dashboardText.Contains('An open replacement pull request is progress, not completion.')) 'The tracked dashboard must distinguish progress from completion.'

$wrapperText = Get-Content -LiteralPath $wrapperPath -Raw
$recoveryWrapperText = Get-Content -LiteralPath $recoveryWrapperPath -Raw
$workflowText = Get-Content -LiteralPath $workflowPath -Raw
Assert-TbgTrue ($wrapperText.Contains('Write-TbgStalePrRecoveryProgress.ps1')) 'The root progress wrapper must invoke the progress generator.'
Assert-TbgTrue ($recoveryWrapperText.Contains('ForgeStalePrProgress.cmd')) 'The stale PR recovery wrapper must refresh the progress dashboard before triggering the artifact engine.'
Assert-TbgTrue ($workflowText.Contains('Test-TbgStalePrRecoveryProgress.ps1')) 'Harness Policy Reports must execute the stale PR progress validator.'
Assert-TbgTrue (@($contract.requiredArtifacts) -contains 'artifacts/latest/stale-pr-recovery/stale-pr-recovery.progress.json') 'The workflow contract must register the machine-readable progress result.'
Assert-TbgTrue (@($contract.requiredArtifacts) -contains 'artifacts/latest/stale-pr-recovery/stale-pr-recovery.progress.md') 'The workflow contract must register the generated Markdown progress dashboard.'
Assert-TbgTrue (@($contract.requiredArtifacts) -contains 'docs/handoff/stale-pr-cherry-pick-progress.md') 'The workflow contract must register the tracked operator dashboard.'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-stale-pr-progress-{0}" -f [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $tempLedgerPath = Join-Path $tempRoot 'progress.json'
    $tempMarkdownPath = Join-Path $tempRoot 'progress.md'
    $tempOutputPath = Join-Path $tempRoot 'artifacts'
    Copy-Item -LiteralPath $ledgerPath -Destination $tempLedgerPath

    & $generatorPath status -PlanPath $planPath -LedgerPath $tempLedgerPath -MarkdownPath $tempMarkdownPath -OutputDirectory $tempOutputPath | Out-Null
    $initialResult = Read-TbgJson -Path (Join-Path $tempOutputPath 'stale-pr-recovery.progress.json')
    Assert-TbgTrue ([string]$initialResult.status -eq 'INCOMPLETE') 'The initial dashboard fixture must be incomplete.'
    Assert-TbgTrue (-not [bool]$initialResult.allComplete) 'The initial dashboard fixture must not claim completion.'
    Assert-TbgTrue ([int]$initialResult.total -eq 16) 'The initial dashboard fixture must account for 16 planned pull requests.'
    Assert-TbgTrue ([int]$initialResult.complete -eq 0) 'The initial dashboard fixture must begin with zero completed pull requests.'
    Assert-TbgTrue ([int]$initialResult.inProgress -eq 2) 'The initial dashboard fixture must identify the two Wave A entries as in progress.'
    Assert-TbgTrue ([int]$initialResult.blocked -eq 4) 'The initial dashboard fixture must identify four dependency-blocked entries.'
    Assert-TbgTrue ([int]$initialResult.notStarted -eq 10) 'The initial dashboard fixture must identify ten not-started entries.'
    Assert-TbgTrue ([int]$initialResult.nextPr -eq 9) 'The initial dashboard fixture must route the next decision through PR #9 and replacement PR #65.'
    Assert-TbgTrue ([string]$initialResult.nextCommand -match '^gh pr view 65 ') 'The initial dashboard fixture must name PR #65 inspection as the next command.'

    $terminalWithoutEvidenceFailed = $false
    try {
        & $generatorPath set -PlanPath $planPath -LedgerPath $tempLedgerPath -MarkdownPath $tempMarkdownPath -OutputDirectory $tempOutputPath -PrNumber 2 -Status rejected_recorded -Disposition 'Rejected.' | Out-Null
    }
    catch {
        $terminalWithoutEvidenceFailed = $true
    }
    Assert-TbgTrue $terminalWithoutEvidenceFailed 'A terminal disposition without evidence must fail closed.'

    & $generatorPath set -PlanPath $planPath -LedgerPath $tempLedgerPath -MarkdownPath $tempMarkdownPath -OutputDirectory $tempOutputPath -PrNumber 2 -Status rejected_recorded -Disposition 'Current main supersedes the stale identity wording change.' -Evidence 'replacement analysis; rejection record' -NextAction 'No further replay work remains for PR #2.' | Out-Null
    $updatedLedger = Read-TbgJson -Path $tempLedgerPath
    $updatedEntry = @($updatedLedger.entries | Where-Object { [int]$_.pr -eq 2 })[0]
    Assert-TbgTrue ([string]$updatedEntry.status -eq 'rejected_recorded') 'The set action must update the selected pull-request status.'
    Assert-TbgTrue (@($updatedEntry.evidence).Count -eq 2) 'The set action must split semicolon-delimited evidence into two retained records.'
    $updatedResult = Read-TbgJson -Path (Join-Path $tempOutputPath 'stale-pr-recovery.progress.json')
    Assert-TbgTrue ([int]$updatedResult.complete -eq 1) 'One terminal disposition must increase the complete count to one.'

    foreach ($entry in @($updatedLedger.entries)) {
        $entry.status = 'historical_retained'
        $entry.disposition = "PR #$([int]$entry.pr) has a recorded terminal fixture disposition."
        $entry.evidence = @('fixture terminal evidence')
        $entry.nextAction = "No further replay work remains for PR #$([int]$entry.pr)."
    }
    $updatedLedger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempLedgerPath -Encoding UTF8
    & $generatorPath status -PlanPath $planPath -LedgerPath $tempLedgerPath -MarkdownPath $tempMarkdownPath -OutputDirectory $tempOutputPath | Out-Null
    $completeResult = Read-TbgJson -Path (Join-Path $tempOutputPath 'stale-pr-recovery.progress.json')
    $completeMarkdown = Get-Content -LiteralPath $tempMarkdownPath -Raw
    Assert-TbgTrue ([string]$completeResult.status -eq 'COMPLETE') 'The all-terminal fixture must reach COMPLETE.'
    Assert-TbgTrue ([bool]$completeResult.allComplete) 'The all-terminal fixture must set allComplete to true.'
    Assert-TbgTrue ([int]$completeResult.complete -eq 16) 'The all-terminal fixture must report 16 completed pull requests.'
    Assert-TbgTrue ($completeMarkdown.Contains('**Overall: COMPLETE**')) 'The generated Markdown must show the complete terminal state.'
    Assert-TbgTrue ([string]$completeResult.nextCommand -eq 'git status --short') 'The complete terminal state must fall through to a clean Git-state inspection.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host 'PASS: stale PR recovery now has a canonical per-PR ledger, an enforced Markdown completion dashboard, evidence-required terminal dispositions, and an aggregate COMPLETE gate.'
