[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'set')]
    [string]$Action = 'status',
    [string]$PlanPath = '.tbg/plans/stale-pr-recovery-20260712/manifest.json',
    [string]$LedgerPath = '.tbg/plans/stale-pr-recovery-20260712/progress.json',
    [string]$MarkdownPath = 'docs/handoff/stale-pr-cherry-pick-progress.md',
    [string]$OutputDirectory = 'artifacts/latest/stale-pr-recovery',
    [ValidateRange(0, 999999)]
    [int]$PrNumber = 0,
    [ValidateSet(
        'not_started',
        'replacement_pr_open',
        'replay_in_progress',
        'validation_pending',
        'disposition_pending',
        'blocked_dependency',
        'blocked_runtime_proof',
        'replayed_and_merged',
        'superseded_recorded',
        'rejected_recorded',
        'historical_retained'
    )]
    [string]$Status = 'not_started',
    [ValidateRange(0, 999999)]
    [int]$ReplacementPr = 0,
    [string]$Disposition = '',
    [string]$Evidence = '',
    [string]$NextAction = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-TbgPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $RepoRoot $Path
}

function ConvertTo-TbgMarkdownCell {
    param([AllowNull()][object]$Value)

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return '—' }
    return (($text -replace '\|', '\|') -replace "`r?`n", '<br>')
}

function Get-TbgStatusClass {
    param([Parameter(Mandatory = $true)][string]$Status)

    if ($terminalCompleteStatuses -contains $Status) { return 'complete' }
    if ($Status -in @('replacement_pr_open', 'replay_in_progress', 'validation_pending', 'disposition_pending')) { return 'in_progress' }
    if ($Status -in @('blocked_dependency', 'blocked_runtime_proof')) { return 'blocked' }
    return 'not_started'
}

function Get-TbgStatusLabel {
    param([Parameter(Mandatory = $true)][string]$Status)

    $statusClass = Get-TbgStatusClass -Status $Status
    $prefix = switch ($statusClass) {
        'complete' { '✅' }
        'in_progress' { '🟡' }
        'blocked' { '⛔' }
        default { '⬜' }
    }
    return "$prefix $($Status -replace '_', ' ')"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$resolvedPlanPath = Resolve-TbgPath -RepoRoot $repoRoot -Path $PlanPath
$resolvedLedgerPath = Resolve-TbgPath -RepoRoot $repoRoot -Path $LedgerPath
$resolvedMarkdownPath = Resolve-TbgPath -RepoRoot $repoRoot -Path $MarkdownPath
$resolvedOutputDirectory = Resolve-TbgPath -RepoRoot $repoRoot -Path $OutputDirectory

foreach ($requiredPath in @($resolvedPlanPath, $resolvedLedgerPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required stale PR recovery progress input is missing: $requiredPath"
    }
}

$plan = Get-Content -LiteralPath $resolvedPlanPath -Raw | ConvertFrom-Json
$ledger = Get-Content -LiteralPath $resolvedLedgerPath -Raw | ConvertFrom-Json
$terminalCompleteStatuses = @($ledger.terminalCompleteStatuses | ForEach-Object { [string]$_ })
$allowedTerminalStatuses = @('replayed_and_merged', 'superseded_recorded', 'rejected_recorded', 'historical_retained')

if ($terminalCompleteStatuses.Count -ne $allowedTerminalStatuses.Count) {
    throw 'The progress ledger must define exactly four terminal completion statuses.'
}
foreach ($terminalStatus in $allowedTerminalStatuses) {
    if ($terminalCompleteStatuses -notcontains $terminalStatus) {
        throw "The progress ledger is missing terminal completion status '$terminalStatus'."
    }
}

$planEntries = @($plan.entries)
$ledgerEntries = @($ledger.entries)
$planPrNumbers = @($planEntries | ForEach-Object { [int]$_.pr } | Sort-Object)
$ledgerPrNumbers = @($ledgerEntries | ForEach-Object { [int]$_.pr } | Sort-Object)

if (($planPrNumbers -join ',') -ne ($ledgerPrNumbers -join ',')) {
    throw "The progress ledger PR set does not match the recovery plan. Plan: $($planPrNumbers -join ', '); ledger: $($ledgerPrNumbers -join ', ')."
}

if ($Action -eq 'set') {
    if ($PrNumber -le 0) { throw 'The set action requires -PrNumber.' }
    $target = @($ledgerEntries | Where-Object { [int]$_.pr -eq $PrNumber })
    if ($target.Count -ne 1) { throw "The progress ledger does not contain exactly one entry for PR #$PrNumber." }

    if ($terminalCompleteStatuses -contains $Status) {
        if ([string]::IsNullOrWhiteSpace($Disposition)) {
            throw "Terminal status '$Status' requires -Disposition."
        }
        if ([string]::IsNullOrWhiteSpace($Evidence)) {
            throw "Terminal status '$Status' requires -Evidence."
        }
    }
    if ($Status -eq 'replacement_pr_open' -and $ReplacementPr -le 0) {
        throw "Status 'replacement_pr_open' requires -ReplacementPr."
    }

    $entry = $target[0]
    $entry.status = $Status
    if ($ReplacementPr -gt 0) { $entry.replacementPr = $ReplacementPr }
    if (-not [string]::IsNullOrWhiteSpace($Disposition)) { $entry.disposition = $Disposition.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($Evidence)) {
        $entry.evidence = @($Evidence.Split(';') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if (-not [string]::IsNullOrWhiteSpace($NextAction)) { $entry.nextAction = $NextAction.Trim() }
    $ledger.updatedDate = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
    $ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedLedgerPath -Encoding UTF8
}

$waveOrder = @{}
for ($index = 0; $index -lt @($plan.waves).Count; $index++) {
    $waveOrder[[string]$plan.waves[$index].id] = $index
}
$orderedEntries = @($ledger.entries | Sort-Object @{ Expression = { $waveOrder[[string]$_.wave] } }, @{ Expression = { [int]$_.pr } })

$completeEntries = @($orderedEntries | Where-Object { (Get-TbgStatusClass -Status ([string]$_.status)) -eq 'complete' })
$inProgressEntries = @($orderedEntries | Where-Object { (Get-TbgStatusClass -Status ([string]$_.status)) -eq 'in_progress' })
$blockedEntries = @($orderedEntries | Where-Object { (Get-TbgStatusClass -Status ([string]$_.status)) -eq 'blocked' })
$notStartedEntries = @($orderedEntries | Where-Object { (Get-TbgStatusClass -Status ([string]$_.status)) -eq 'not_started' })
$totalCount = $orderedEntries.Count
$completeCount = $completeEntries.Count
$allComplete = $totalCount -gt 0 -and $completeCount -eq $totalCount
$completionPercent = if ($totalCount -eq 0) { 0 } else { [math]::Round(($completeCount * 100.0) / $totalCount, 1) }
$overallState = if ($allComplete) { 'COMPLETE' } else { 'INCOMPLETE' }
$terminalState = if ($allComplete) { 'COMPLETE_all_stale_pr_dispositions_recorded' } else { 'INCOMPLETE_stale_pr_recovery_work_remaining' }

$nextEntry = @($inProgressEntries | Select-Object -First 1)
if ($nextEntry.Count -eq 0) { $nextEntry = @($notStartedEntries | Select-Object -First 1) }
if ($nextEntry.Count -eq 0) { $nextEntry = @($blockedEntries | Select-Object -First 1) }

$nextCommand = 'git status --short'
$nextSentence = 'All stale pull-request entries have terminal dispositions recorded.'
if (-not $allComplete -and $nextEntry.Count -gt 0) {
    $candidate = $nextEntry[0]
    $nextSentence = "Wave $($candidate.wave), PR #$([int]$candidate.pr): $([string]$candidate.nextAction)"
    if ([int]$candidate.replacementPr -gt 0) {
        $nextCommand = "gh pr view $([int]$candidate.replacementPr) --json number,title,state,isDraft,mergeable,headRefOid,baseRefName,checks"
    }
    elseif (@($candidate.blockedBy).Count -gt 0) {
        $nextCommand = "gh pr view $([int]@($candidate.blockedBy)[0]) --json number,title,state,isDraft,mergeable,headRefOid,baseRefName"
    }
    else {
        $nextCommand = ".\ForgeStalePrRecovery.cmd -Wave $($candidate.wave) -PrNumber $([int]$candidate.pr) -LocalFloorVerified"
    }
}

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add('# Stale branch cherry-pick progress')
$markdown.Add('')
$markdown.Add("> **Overall: $overallState**")
$markdown.Add("> **$completeCount of $totalCount stale pull requests are complete ($completionPercent%).**")
$markdown.Add("> **Current distribution: $($inProgressEntries.Count) in progress, $($blockedEntries.Count) blocked, and $($notStartedEntries.Count) not started.**")
$markdown.Add("> **Next: $nextSentence**")
$markdown.Add('')
$markdown.Add("The authoritative machine-readable ledger is `$LedgerPath`. This Markdown file is generated from that ledger and the committed recovery plan.")
$markdown.Add('')
$markdown.Add('## Completion rule')
$markdown.Add('')
$markdown.Add('The stale-branch cherry-pick process is finished only when every planned source pull request has one terminal status: `replayed_and_merged`, `superseded_recorded`, `rejected_recorded`, or `historical_retained`. An open replacement pull request is progress, not completion.')
$markdown.Add('')
$markdown.Add('## Progress table')
$markdown.Add('')
$markdown.Add('| Wave | Source PR | Status | Replacement PR | Blocked by | Disposition or evidence | Next action |')
$markdown.Add('|---|---:|---|---:|---|---|---|')
foreach ($entry in $orderedEntries) {
    $replacementText = if ([int]$entry.replacementPr -gt 0) { "#$([int]$entry.replacementPr)" } else { '—' }
    $blockedText = if (@($entry.blockedBy).Count -gt 0) { (@($entry.blockedBy) | ForEach-Object { "#$_" }) -join ', ' } else { '—' }
    $evidenceText = @($entry.evidence) -join '; '
    $dispositionText = if (-not [string]::IsNullOrWhiteSpace([string]$entry.disposition)) { [string]$entry.disposition } elseif (-not [string]::IsNullOrWhiteSpace($evidenceText)) { $evidenceText } else { '—' }
    $markdown.Add("| $($entry.wave) | #$([int]$entry.pr) | $(ConvertTo-TbgMarkdownCell (Get-TbgStatusLabel -Status ([string]$entry.status))) | $replacementText | $blockedText | $(ConvertTo-TbgMarkdownCell $dispositionText) | $(ConvertTo-TbgMarkdownCell ([string]$entry.nextAction)) |")
}
$markdown.Add('')
$markdown.Add('## Active work excluded from stale recovery')
$markdown.Add('')
$markdown.Add('| PR | Status | Reason |')
$markdown.Add('|---:|---|---|')
foreach ($entry in @($ledger.activeExcluded)) {
    $markdown.Add("| #$([int]$entry.pr) | $([string]$entry.status) | $(ConvertTo-TbgMarkdownCell ([string]$entry.reason)) |")
}
$markdown.Add('')
$markdown.Add('## Operator commands')
$markdown.Add('')
$markdown.Add('Refresh and display the dashboard:')
$markdown.Add('')
$markdown.Add('```powershell')
$markdown.Add('.\ForgeStalePrProgress.cmd status')
$markdown.Add('```')
$markdown.Add('')
$markdown.Add('Record an in-progress replacement:')
$markdown.Add('')
$markdown.Add('```powershell')
$markdown.Add('.\ForgeStalePrProgress.cmd set -PrNumber 9 -Status replacement_pr_open -ReplacementPr 65 -Disposition "Historical value is in PR #65." -Evidence "PR #65"')
$markdown.Add('```')
$markdown.Add('')
$markdown.Add('Record a terminal disposition only after its gate is satisfied:')
$markdown.Add('')
$markdown.Add('```powershell')
$markdown.Add('.\ForgeStalePrProgress.cmd set -PrNumber 9 -Status historical_retained -Disposition "The maintained replacement merged and the source remains reachable as history." -Evidence "PR #65 merged; replacement commit <sha>" -NextAction "No further replay work remains for PR #9."')
$markdown.Add('```')
$markdown.Add('')
$markdown.Add('## Exact next command')
$markdown.Add('')
$markdown.Add('```powershell')
$markdown.Add($nextCommand)
$markdown.Add('```')
$markdown.Add('')
$markdown.Add('## Proof boundary')
$markdown.Add('')
$markdown.Add('This dashboard proves only that the committed plan and progress ledger were reconciled. A terminal status must cite the replacement, rejection, or retention evidence. The dashboard does not itself prove a cherry-pick, merge, build, launcher action, gameplay behavior, or runtime result.')

$markdownDirectory = Split-Path -Parent $resolvedMarkdownPath
New-Item -ItemType Directory -Force -Path $markdownDirectory | Out-Null
$markdown | Set-Content -LiteralPath $resolvedMarkdownPath -Encoding UTF8
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null
$artifactMarkdownPath = Join-Path $resolvedOutputDirectory 'stale-pr-recovery.progress.md'
$resultPath = Join-Path $resolvedOutputDirectory 'stale-pr-recovery.progress.json'
$markdown | Set-Content -LiteralPath $artifactMarkdownPath -Encoding UTF8

$result = [pscustomobject][ordered]@{
    schema = 'TbgStalePrRecoveryProgressResult.v1'
    repository = [string]$ledger.repository
    planPath = $PlanPath
    ledgerPath = $LedgerPath
    markdownPath = $MarkdownPath
    artifactMarkdownPath = $artifactMarkdownPath
    status = $overallState
    terminalState = $terminalState
    allComplete = [bool]$allComplete
    total = $totalCount
    complete = $completeCount
    inProgress = $inProgressEntries.Count
    blocked = $blockedEntries.Count
    notStarted = $notStartedEntries.Count
    completionPercent = $completionPercent
    nextPr = if ($nextEntry.Count -gt 0) { [int]$nextEntry[0].pr } else { $null }
    nextWave = if ($nextEntry.Count -gt 0) { [string]$nextEntry[0].wave } else { $null }
    nextCommand = $nextCommand
    entries = $orderedEntries
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host "Stale PR recovery: $overallState. $completeCount/$totalCount complete; $($inProgressEntries.Count) in progress; $($blockedEntries.Count) blocked; $($notStartedEntries.Count) not started."
Write-Host "Dashboard: $MarkdownPath"
Write-Host "Next command: $nextCommand"
Write-Output ($result | ConvertTo-Json -Depth 20)
