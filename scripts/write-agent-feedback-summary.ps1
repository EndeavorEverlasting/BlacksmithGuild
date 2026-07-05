# Generate BlacksmithGuild_AgentFeedback.json from repo and runtime artifacts.
# This script is read-only except for the AgentFeedback output file.

param(
    [string]$BannerlordRoot = $null,
    [string]$DocumentsRoot = $null,
    [string]$OutputPath = $null,
    [int]$FreshMinutes = 30,
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'BlacksmithGuild_AgentFeedback.json'
}

if (-not $BannerlordRoot) {
    $defaultBannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $defaultBannerlordRoot) {
        $BannerlordRoot = $defaultBannerlordRoot
    }
}

if (-not $DocumentsRoot -and $env:USERPROFILE) {
    $defaultDocumentsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
    if (Test-Path -LiteralPath $defaultDocumentsRoot) {
        $DocumentsRoot = $defaultDocumentsRoot
    }
}

$now = Get-Date
$freshWindow = [TimeSpan]::FromMinutes($FreshMinutes)

function Invoke-RepoGit {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    try {
        $output = & git -C $repoRoot @Args 2>&1
        return [pscustomobject][ordered]@{
            ok = ($LASTEXITCODE -eq 0)
            exitCode = $LASTEXITCODE
            text = (($output | ForEach-Object { [string]$_ }) -join "`n")
        }
    } catch {
        return [pscustomobject][ordered]@{
            ok = $false
            exitCode = -1
            text = $_.Exception.Message
        }
    }
}

function Test-FreshFile {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$Item)
    return (($now - $Item.LastWriteTime) -le $freshWindow)
}

function Read-JsonFileSafe {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function New-EvidenceItem {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][bool]$Fresh,
        [Parameter(Mandatory = $true)][string]$Summary,
        [string[]]$Supports = @(),
        [string[]]$DoesNotSupport = @()
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    [pscustomobject][ordered]@{
        path = $Path
        kind = $Kind
        fresh = $Fresh
        observedUtc = if ($item) { $item.LastWriteTimeUtc.ToString('o') } else { $null }
        summary = $Summary
        supports = $Supports
        doesNotSupport = $DoesNotSupport
    }
}

function Get-TailTextSafe {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$Tail = 80)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    try {
        return (Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop) -join "`n"
    } catch {
        return ''
    }
}

$branch = (Invoke-RepoGit -Args @('rev-parse', '--abbrev-ref', 'HEAD')).text.Trim()
$headSha = (Invoke-RepoGit -Args @('rev-parse', 'HEAD')).text.Trim()
$statusShort = (Invoke-RepoGit -Args @('status', '--short')).text.Trim()

$gitDiffCheck = Invoke-RepoGit -Args @('diff', '--check')

$evidence = New-Object System.Collections.Generic.List[object]
$allowedClaims = New-Object System.Collections.Generic.List[string]
$forbiddenClaims = New-Object System.Collections.Generic.List[string]
$blockers = New-Object System.Collections.Generic.List[object]
$notes = New-Object System.Collections.Generic.List[string]

$runtimeState = [ordered]@{
    known = $false
    campaignReady = $null
    hotkeysReady = $null
    commandBridgeReady = $null
}

$knownFiles = New-Object System.Collections.Generic.List[object]
function Add-KnownRuntimeFile {
    param([string]$Root, [string]$Name, [string]$Kind)
    if ([string]::IsNullOrWhiteSpace($Root)) { return }
    $path = Join-Path $Root $Name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        $knownFiles.Add([pscustomobject][ordered]@{ path = $path; kind = $Kind; item = $item }) | Out-Null
    }
}

foreach ($root in @($BannerlordRoot, $DocumentsRoot)) {
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_Launch.log' -Kind 'launch_log'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_Forge.log' -Kind 'forge_log'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_Phase1.log' -Kind 'phase1_log'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_Status.json' -Kind 'status_json'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_RuntimeLifecycle.json' -Kind 'runtime_lifecycle_json'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_CommandAck.json' -Kind 'command_ack'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_CommandInbox.json' -Kind 'command_inbox'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_MarketIntel.json' -Kind 'market_intel'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_MarketJournal.jsonl' -Kind 'market_journal'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_SmithingAudit.json' -Kind 'smithing_audit'
    Add-KnownRuntimeFile -Root $root -Name 'BlacksmithGuild_CampaignOutcome.json' -Kind 'campaign_outcome'
}

foreach ($known in $knownFiles) {
    $fresh = Test-FreshFile -Item $known.item
    $evidence.Add((New-EvidenceItem -Path $known.path -Kind $known.kind -Fresh $fresh -Summary ("Observed {0}; fresh={1}." -f $known.kind, $fresh))) | Out-Null
}

if (-not $gitDiffCheck.ok) {
    $blockers.Add([pscustomobject][ordered]@{
        kind = 'contract_fail'
        severity = 'blocking'
        summary = 'git diff --check reported whitespace or patch hygiene issues.'
        evidencePath = 'git diff --check'
        recommendedFix = 'Fix git diff --check findings before asking for review.'
    }) | Out-Null
}

$ack = $knownFiles | Where-Object { $_.kind -eq 'command_ack' } | Sort-Object { $_.item.LastWriteTimeUtc } -Descending | Select-Object -First 1
$audit = $knownFiles | Where-Object { $_.kind -eq 'smithing_audit' } | Sort-Object { $_.item.LastWriteTimeUtc } -Descending | Select-Object -First 1
$statusJson = $knownFiles | Where-Object { $_.kind -eq 'status_json' } | Sort-Object { $_.item.LastWriteTimeUtc } -Descending | Select-Object -First 1

$classificationState = 'unclassified'
$classificationConfidence = 'medium'
$classificationReason = 'No decisive fresh artifact pattern was found.'

if ($statusJson) {
    $status = Read-JsonFileSafe -Path $statusJson.path
    if ($status) {
        $runtimeState.known = $true
        if ($status.PSObject.Properties.Name -contains 'campaignReady') {
            $runtimeState.campaignReady = [bool]$status.campaignReady
        }
        if ($status.PSObject.Properties.Name -contains 'hotkeysReady') {
            $runtimeState.hotkeysReady = [bool]$status.hotkeysReady
        }
        if ($status.PSObject.Properties.Name -contains 'commandBridgeReady') {
            $runtimeState.commandBridgeReady = [bool]$status.commandBridgeReady
        }
    }
}

if ($ack) {
    $ackJson = Read-JsonFileSafe -Path $ack.path
    $ackFresh = Test-FreshFile -Item $ack.item
    if ($ackJson -and $ackJson.result -eq 'Success' -and $ackFresh) {
        $runtimeState.known = $true
        $runtimeState.commandBridgeReady = $true
        $classificationState = 'checkpoint_reached'
        $classificationConfidence = 'high'
        $classificationReason = ('Fresh command ACK observed: {0} result={1}.' -f $ackJson.command, $ackJson.result)
        $allowedClaims.Add(('Runtime command bridge accepted and completed {0}.' -f $ackJson.command)) | Out-Null
        $forbiddenClaims.Add('This does not prove autonomous campaign loop completion.') | Out-Null
        $forbiddenClaims.Add('This does not prove save mutation.') | Out-Null
        $forbiddenClaims.Add('This does not prove market, travel, companion, horse, or smithing automation.') | Out-Null

        if ($audit -and (Test-FreshFile -Item $audit.item)) {
            $auditJson = Read-JsonFileSafe -Path $audit.path
            if ($auditJson) {
                $runtimeState.campaignReady = if ($auditJson.PSObject.Properties.Name -contains 'campaignReady') { [bool]$auditJson.campaignReady } else { $runtimeState.campaignReady }
                $allowedClaims.Add('SmithingAudit refreshed after the command ACK.') | Out-Null
            }
        }

        $inbox = $knownFiles | Where-Object { $_.kind -eq 'command_inbox' } | Sort-Object { $_.item.LastWriteTimeUtc } -Descending | Select-Object -First 1
        if (-not $inbox) {
            $notes.Add('CommandInbox.json missing after a fresh ACK is not a blocker; consumed command inbox can be deleted by the runtime.') | Out-Null
        }
    } elseif ($ackJson -and -not $ackFresh) {
        $classificationState = 'stale_evidence'
        $classificationConfidence = 'medium'
        $classificationReason = 'CommandAck.json exists but is stale for this feedback run.'
        $forbiddenClaims.Add('Do not close the sprint from stale CommandAck evidence.') | Out-Null
    }
}

$launchLogs = $knownFiles | Where-Object { $_.kind -eq 'launch_log' } | Sort-Object { $_.item.LastWriteTimeUtc } -Descending
foreach ($log in $launchLogs) {
    $tail = Get-TailTextSafe -Path $log.path
    if ($tail -match 'safe_mode_detected' -and $tail -notmatch 'safe_mode_decline_dispatched|CLICK_SAFE_MODE_RESULT.*decline_dispatched|safe_mode_declined_then_game_spawned') {
        $classificationState = 'runtime_blocked'
        $classificationConfidence = 'high'
        $classificationReason = 'Safe Mode modal was detected without confirmed decline dispatch in the latest launch log tail.'
        $blockers.Add([pscustomobject][ordered]@{
            kind = 'runtime_blocked'
            severity = 'blocking'
            summary = 'Safe Mode modal detected without confirmed decline.'
            evidencePath = $log.path
            recommendedFix = 'Decline Safe Mode during frozen navigation, then watch for game_spawned or same-process Singleplayer handoff.'
        }) | Out-Null
        $forbiddenClaims.Add('Do not claim launcher handoff complete while Safe Mode remains unresolved.') | Out-Null
        break
    }
}

if ($blockers.Count -gt 0 -and $classificationState -eq 'unclassified') {
    $classificationState = 'checkpoint_blocked'
    $classificationConfidence = 'high'
    $classificationReason = $blockers[0].summary
}

if ($allowedClaims.Count -eq 0) {
    $allowedClaims.Add('Feedback file generated from available repo and runtime artifacts.') | Out-Null
}
if ($forbiddenClaims.Count -eq 0) {
    $forbiddenClaims.Add('Do not claim runtime proof, save mutation, or gameplay automation from this feedback file alone.') | Out-Null
}

$nextSprint = [ordered]@{
    title = 'Add agent stop hook runner'
    branchHint = 'agent-feedback-stop-hook'
    problem = 'The feedback writer exists, but agents still need a stop hook to run cheap guardrails and feed summary output back automatically.'
    scope = 'Run cheap verifiers, call write-agent-feedback-summary.ps1, print classification and next action, exit nonzero for blocking failures.'
    nonGoals = @('automatic merging', 'live cert execution by default', 'save mutation', 'gameplay automation')
    firstFiles = @('scripts/invoke-agent-stop-hook.ps1', 'scripts/verify-agent-feedback-stop-hook-contract.ps1')
}

if ($classificationState -eq 'runtime_blocked') {
    $nextSprint = [ordered]@{
        title = 'Repair runtime blocker before next automation work'
        branchHint = $branch
        problem = $classificationReason
        scope = 'Fix the blocking runtime condition using the evidencePath in blockers.'
        nonGoals = @('new gameplay automation', 'save mutation', 'broad refactor')
        firstFiles = @()
    }
} elseif ($classificationState -eq 'unclassified' -or $classificationState -eq 'stale_evidence') {
    $nextSprint = [ordered]@{
        title = 'Add more artifact interpretation rules'
        branchHint = 'agent-feedback-writer'
        problem = 'The writer could not classify the available evidence with high confidence.'
        scope = 'Add one or two concrete artifact rules. Do not build a giant review bot.'
        nonGoals = @('Semgrep integration', 'architectural test framework', 'live cert execution')
        firstFiles = @('scripts/write-agent-feedback-summary.ps1', 'scripts/verify-agent-feedback-writer-contract.ps1')
    }
}

$validation = @(
    'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-agent-feedback-writer-contract.ps1',
    'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-agent-feedback-harness-contract.ps1',
    'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1',
    'git diff --check',
    'git status --short'
)

$feedback = [pscustomobject][ordered]@{
    schema = 'TbgAgentFeedback.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    source = [ordered]@{
        kind = 'repo_artifact_analysis'
        tool = 'write-agent-feedback-summary.ps1'
    }
    repoState = [ordered]@{
        branch = $branch
        headSha = $headSha
        statusShort = $statusShort
        gitDiffCheckExitCode = $gitDiffCheck.exitCode
        untrackedPolicy = 'ignored_artifacts_allowed_when_artifacts_only'
    }
    runtimeState = $runtimeState
    classification = [ordered]@{
        state = $classificationState
        confidence = $classificationConfidence
        reason = $classificationReason
    }
    evidence = @($evidence)
    allowedClaims = @($allowedClaims)
    forbiddenClaims = @($forbiddenClaims)
    blockers = @($blockers)
    notes = @($notes)
    nextSprint = $nextSprint
    validation = $validation
}

$json = $feedback | ConvertTo-Json -Depth 12
if (-not $NoWrite) {
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
}

Write-Host ('AgentFeedback classification: {0} confidence={1}' -f $classificationState, $classificationConfidence) -ForegroundColor Cyan
Write-Host ('Reason: {0}' -f $classificationReason) -ForegroundColor Cyan
Write-Host ('Next sprint: {0}' -f $nextSprint.title) -ForegroundColor Cyan
if (-not $NoWrite) {
    Write-Host ('Wrote: {0}' -f $OutputPath) -ForegroundColor Green
}

if ($blockers.Count -gt 0) {
    foreach ($blocker in $blockers) {
        Write-Host ('BLOCKER: {0}' -f $blocker.summary) -ForegroundColor Yellow
    }
}
