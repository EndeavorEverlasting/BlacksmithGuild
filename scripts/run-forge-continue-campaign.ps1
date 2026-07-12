param(
    [string]$ExpectedHead,
    [string]$SavePath,
    [int]$AttachTimeoutSec = 600,
    [int]$TradeTimeoutSec = 1200,
    [int]$CommandTimeoutSec = 90,
    [int]$EvidenceTimeoutSec = 90,
    [int]$PollIntervalMs = 500,
    [switch]$SkipPackAnimalAttempt,
    [switch]$SkipGuildLoop,
    [switch]$Diagnostic
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

if ([string]::IsNullOrWhiteSpace($ExpectedHead)) {
    $ExpectedHead = (& git rev-parse HEAD).Trim()
}

$startedAtUtc = (Get-Date).ToUniversalTime()
$runId = 'forge-continue-' + $startedAtUtc.ToString('yyyyMMdd-HHmmss-fff')
$latestRoot = Join-Path $repoRoot 'artifacts\latest'
$runRoot = Join-Path $latestRoot (Join-Path 'forge-continue-campaign' $runId)
$stepRoot = Join-Path $runRoot 'steps'
$progressPath = Join-Path $runRoot 'progress.log'
$eventsPath = Join-Path $runRoot 'events.jsonl'
$resultPath = Join-Path $runRoot 'result.json'
$reportPath = Join-Path $runRoot 'report.md'
$latestProgressPath = Join-Path $latestRoot 'forge-continue-campaign.progress.log'
$latestResultPath = Join-Path $latestRoot 'forge-continue-campaign.result.json'
$latestReportPath = Join-Path $latestRoot 'forge-continue-campaign.report.md'
New-Item -ItemType Directory -Force -Path $stepRoot | Out-Null

$sequence = 0
$stages = [System.Collections.Generic.List[object]]::new()
$failureDetail = $null
$terminalState = 'running'
$visibleTradeResult = $null
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$docsRoot = Get-BannerlordDocsRoot

function Write-AtomicJson {
    param([Parameter(Mandatory = $true)]$Value, [Parameter(Mandatory = $true)][string]$Path)
    $temp = "$Path.$PID.tmp"
    $json = $Value | ConvertTo-Json -Depth 30
    [IO.File]::WriteAllText($temp, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Write-AtomicText {
    param([Parameter(Mandatory = $true)][string]$Value, [Parameter(Mandatory = $true)][string]$Path)
    $temp = "$Path.$PID.tmp"
    [IO.File]::WriteAllText($temp, $Value, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Read-JsonSafe {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        if (Test-Path -LiteralPath $Path) {
            return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    } catch { }
    return $null
}

function Get-FileReference {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $item.FullName
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Write-CampaignEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][ValidateSet('started', 'passed', 'blocked', 'deferred', 'failed', 'info')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Sentence,
        [string]$Evidence = ''
    )
    $script:sequence++
    $timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $line = '[{0}] {1}: {2}' -f $timestamp, $Status.ToUpperInvariant(), $Sentence
    Add-Content -LiteralPath $progressPath -Value $line -Encoding UTF8
    Write-Host $line
    $event = [ordered]@{
        schemaVersion = 'TbgForgeContinueCampaignEvent.v1'
        runId = $runId
        sequence = $script:sequence
        timestampUtc = $timestamp
        stage = $Stage
        status = $Status
        sentence = $Sentence
        evidence = $Evidence
    }
    Add-Content -LiteralPath $eventsPath -Value ($event | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}

function Add-StageRecord {
    param(
        [string]$Name,
        [string]$Status,
        [string]$ProofLevel,
        [int]$ExitCode,
        [string]$Detail,
        [string]$LogPath,
        $Evidence,
        $Data
    )
    $stages.Add([pscustomobject][ordered]@{
        name = $Name
        status = $Status
        proofLevel = $ProofLevel
        exitCode = $ExitCode
        detail = $Detail
        logPath = $LogPath
        evidence = $Evidence
        data = $Data
    }) | Out-Null
}

function Wait-FreshJson {
    param(
        [Parameter(Mandatory = $true)][string[]]$Candidates,
        [Parameter(Mandatory = $true)][datetime]$NotBeforeUtc,
        [Parameter(Mandatory = $true)][int]$TimeoutSec
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        foreach ($candidate in $Candidates) {
            if (-not (Test-Path -LiteralPath $candidate)) { continue }
            $item = Get-Item -LiteralPath $candidate
            if ($item.LastWriteTimeUtc -lt $NotBeforeUtc) { continue }
            $value = Read-JsonSafe -Path $candidate
            if ($null -ne $value) {
                return [pscustomobject]@{ Path = $item.FullName; Value = $value }
            }
        }
        Start-Sleep -Milliseconds ([Math]::Max(250, $PollIntervalMs))
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Get-RuntimeCandidates {
    param([Parameter(Mandatory = $true)][string]$FileName)
    return @(
        (Join-Path $bannerlordRoot $FileName),
        (Join-Path $docsRoot $FileName)
    )
}

function Invoke-PowerShellStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogName
    )
    $logPath = Join-Path $stepRoot $LogName
    $global:LASTEXITCODE = 0
    $output = & powershell.exe @Arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    @($output) | Set-Content -LiteralPath $logPath -Encoding UTF8
    $output | ForEach-Object { Write-Host $_ }
    return [pscustomobject]@{ Name = $Name; ExitCode = $exitCode; LogPath = $logPath; Output = @($output) }
}

function Invoke-ForgeHandoffStage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Command,
        [string]$EvidenceFile,
        [switch]$AllowBlocked,
        [string]$ProofLevel = 'fresh_runtime_artifact'
    )
    $commandStartedUtc = (Get-Date).ToUniversalTime()
    Write-CampaignEvent -Stage $Name -Status started -Sentence ('The coordinator sent the bounded runtime command "{0}".' -f $Command)
    $step = Invoke-PowerShellStep -Name $Name -LogName ($Name + '.log') -Arguments @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $repoRoot 'forge.ps1'),
        '-Command', $Command, '-Wait', '-TimeoutSec', [string]$CommandTimeoutSec
    )
    $record = $null
    if (-not [string]::IsNullOrWhiteSpace($EvidenceFile)) {
        $record = Wait-FreshJson -Candidates (Get-RuntimeCandidates -FileName $EvidenceFile) `
            -NotBeforeUtc $commandStartedUtc -TimeoutSec $EvidenceTimeoutSec
    }

    if ($null -ne $record) {
        $reference = Get-FileReference -Path $record.Path
        $status = if ($step.ExitCode -eq 0) { 'passed' } else { 'blocked' }
        $detail = if ($step.ExitCode -eq 0) {
            'The runtime command completed and wrote fresh machine evidence.'
        } else {
            'The runtime command returned a blocked result and still wrote fresh machine evidence.'
        }
        Add-StageRecord -Name $Name -Status $status -ProofLevel $ProofLevel -ExitCode $step.ExitCode `
            -Detail $detail -LogPath $step.LogPath -Evidence $reference -Data $record.Value
        Write-CampaignEvent -Stage $Name -Status $status -Sentence $detail -Evidence $record.Path
        return $status -eq 'passed' -or $AllowBlocked
    }

    if ($step.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($EvidenceFile)) {
        $detail = 'The runtime accepted the handoff command; this is command-transport proof only.'
        Add-StageRecord -Name $Name -Status passed -ProofLevel command_ack -ExitCode 0 -Detail $detail `
            -LogPath $step.LogPath -Evidence $null -Data $null
        Write-CampaignEvent -Stage $Name -Status passed -Sentence $detail -Evidence $step.LogPath
        return $true
    }

    $failureStatus = if ($AllowBlocked) { 'deferred' } else { 'failed' }
    $failure = if ([string]::IsNullOrWhiteSpace($EvidenceFile)) {
        'The runtime did not acknowledge the handoff command.'
    } else {
        'The runtime did not produce fresh evidence for the handoff command.'
    }
    Add-StageRecord -Name $Name -Status $failureStatus -ProofLevel none -ExitCode $step.ExitCode `
        -Detail $failure -LogPath $step.LogPath -Evidence $null -Data $null
    Write-CampaignEvent -Stage $Name -Status $failureStatus -Sentence $failure -Evidence $step.LogPath
    return [bool]$AllowBlocked
}

function Write-FinalArtifacts {
    param([int]$ExitCode)
    $endedAtUtc = (Get-Date).ToUniversalTime()
    $requiredNames = @('visible-trade-cycle', 'horse-atlas', 'herd-ledger', 'horse-recommendation', 'governor-decision')
    $requiredPassed = $true
    foreach ($requiredName in $requiredNames) {
        $stage = @($stages | Where-Object { $_.name -eq $requiredName }) | Select-Object -Last 1
        if ($null -eq $stage -or $stage.status -ne 'passed') { $requiredPassed = $false }
    }

    $packStage = @($stages | Where-Object { $_.name -eq 'pack-animal-acquisition' }) | Select-Object -Last 1
    $governorStage = @($stages | Where-Object { $_.name -eq 'governor-decision' }) | Select-Object -Last 1
    $guildStage = @($stages | Where-Object { $_.name -eq 'guild-loop-handoff' }) | Select-Object -Last 1
    $packAcquired = $null -ne $packStage -and $null -ne $packStage.data -and $packStage.data.attemptSuccess -eq $true
    $pass = $ExitCode -eq 0 -and $requiredPassed
    $result = [ordered]@{
        schemaVersion = 'TbgForgeContinueCampaignResult.v1'
        runId = $runId
        correlationId = if ($visibleTradeResult) { [string]$visibleTradeResult.correlationId } else { $runId }
        startedAtUtc = $startedAtUtc.ToString('o')
        endedAtUtc = $endedAtUtc.ToString('o')
        repo = 'EndeavorEverlasting/BlacksmithGuild'
        branch = (& git branch --show-current).Trim()
        headSha = (& git rev-parse HEAD).Trim()
        expectedHead = $ExpectedHead
        passFail = if ($pass) { 'PASS' } else { 'FAIL' }
        terminalState = $terminalState
        failureDetail = $failureDetail
        visibleTrade = if ($visibleTradeResult) {
            [ordered]@{
                runId = $visibleTradeResult.runId
                terminalState = $visibleTradeResult.terminalState
                passFail = $visibleTradeResult.passFail
                result = Get-FileReference -Path (Join-Path $latestRoot 'visible-trade-cycle.result.json')
                report = Get-FileReference -Path (Join-Path $latestRoot 'visible-trade-cycle.report.md')
            }
        } else { $null }
        stages = @($stages.ToArray())
        handoffSummary = [ordered]@{
            forgeHandoffAcknowledged = @($stages | Where-Object { $_.name -eq 'forge-handoff' -and $_.status -eq 'passed' }).Count -gt 0
            horseAtlasFresh = @($stages | Where-Object { $_.name -eq 'horse-atlas' -and $_.status -eq 'passed' }).Count -gt 0
            herdLedgerFresh = @($stages | Where-Object { $_.name -eq 'herd-ledger' -and $_.status -eq 'passed' }).Count -gt 0
            horseRecommendationFresh = @($stages | Where-Object { $_.name -eq 'horse-recommendation' -and $_.status -eq 'passed' }).Count -gt 0
            packAnimalAttempted = $null -ne $packStage
            packAnimalAcquired = $packAcquired
            packAnimalDetail = if ($packStage -and $packStage.data) { [string]$packStage.data.attemptDetail } else { $null }
            governorDecisionFresh = $null -ne $governorStage -and $governorStage.status -eq 'passed'
            governorSelectedBranch = if ($governorStage -and $governorStage.data) { [string]$governorStage.data.selectedBranch } else { $null }
            governorNextAction = if ($governorStage -and $governorStage.data) { [string]$governorStage.data.nextAction } else { $null }
            governorTargetEngine = if ($governorStage -and $governorStage.data -and $governorStage.data.proposedActivity) { [string]$governorStage.data.proposedActivity.targetEngine } else { $null }
            guildLoopHandoff = if ($guildStage) { [string]$guildStage.status } else { 'skipped' }
        }
        allowedClaims = @(
            'A visible-trade claim is allowed only when the child visible-trade result passed.',
            'Horse acquisition is allowed only when the fresh pack-animal probe records attemptSuccess=true and its real trade delta.',
            'Governor and guild-loop handoffs are bounded next-engine transitions, not proof that their future objectives completed.'
        )
        forbiddenClaims = @(
            'Launcher handoff alone is not save, movement, arrival, trade, horse, or campaign-loop proof.',
            'A command acknowledgement alone is not downstream engine completion.',
            'A blocked pack-animal attempt must not be reported as an acquisition.'
        )
    }
    Write-AtomicJson -Value $result -Path $resultPath

    $stageLines = @($stages | ForEach-Object { '- **{0}:** `{1}` ({2}) — {3}' -f $_.name, $_.status, $_.proofLevel, $_.detail })
    $report = @"
# Forge Continue campaign pipeline

Run **$runId** ended as **$terminalState** at head **$ExpectedHead**.

The visible-trade child $(if ($visibleTradeResult) { 'ended as **' + $visibleTradeResult.terminalState + '**.' } else { 'did not return a readable result.' })

## Ordered stages

$($stageLines -join "`r`n")

## Horse and agent handoff

- Horse atlas fresh: **$(@($stages | Where-Object { $_.name -eq 'horse-atlas' -and $_.status -eq 'passed' }).Count -gt 0)**
- Herd ledger fresh: **$(@($stages | Where-Object { $_.name -eq 'herd-ledger' -and $_.status -eq 'passed' }).Count -gt 0)**
- Pack animal acquired: **$packAcquired**
- Governor branch: **$(if ($governorStage -and $governorStage.data) { $governorStage.data.selectedBranch } else { 'unavailable' })**
- Governor next action: **$(if ($governorStage -and $governorStage.data) { $governorStage.data.nextAction } else { 'unavailable' })**

The game is intentionally left open. The result distinguishes command acknowledgement, fresh engine evidence, real acquisition delta, and future asynchronous work.
"@
    Write-AtomicText -Value $report -Path $reportPath
    Copy-Item -LiteralPath $progressPath -Destination $latestProgressPath -Force
    Copy-Item -LiteralPath $resultPath -Destination $latestResultPath -Force
    Copy-Item -LiteralPath $reportPath -Destination $latestReportPath -Force
}

try {
    Write-CampaignEvent -Stage pipeline -Status started -Sentence 'Forge Continue started the exact-head launcher, save, visible-trade, and downstream engine pipeline.' -Evidence $runRoot
    if ($ExpectedHead -notmatch '^[0-9a-fA-F]{40}$') { throw 'FAILED_preflight:ExpectedHead must resolve to a full commit SHA.' }
    $actualHead = (& git rev-parse HEAD).Trim()
    if (-not [string]::Equals($ExpectedHead, $actualHead, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "FAILED_preflight:wrong_head expected=$ExpectedHead actual=$actualHead"
    }

    $visibleStartedUtc = (Get-Date).ToUniversalTime()
    Write-CampaignEvent -Stage visible-trade-cycle -Status started -Sentence 'The coordinator delegated build, install, native Continue, exact-save identity, travel, arrival, real buy, visible trade surface, and targeted Manual cleanup to the existing certifying runner.'
    $visibleArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'run-tbg-visible-trade-cycle.ps1'),
        '-ExpectedHead', $ExpectedHead,
        '-AttachTimeoutSec', [string]$AttachTimeoutSec,
        '-TradeTimeoutSec', [string]$TradeTimeoutSec,
        '-PollIntervalMs', [string]$PollIntervalMs
    )
    if (-not [string]::IsNullOrWhiteSpace($SavePath)) { $visibleArguments += @('-SavePath', $SavePath) }
    if ($Diagnostic) { $visibleArguments += '-Diagnostic' }
    $visibleStep = Invoke-PowerShellStep -Name visible-trade-cycle -LogName 'visible-trade-cycle.log' -Arguments $visibleArguments
    $visibleResultPath = Join-Path $latestRoot 'visible-trade-cycle.result.json'
    $visibleTradeResult = Read-JsonSafe -Path $visibleResultPath
    $visiblePass = $visibleStep.ExitCode -eq 0 -and $null -ne $visibleTradeResult -and $visibleTradeResult.passFail -eq 'PASS'
    Add-StageRecord -Name visible-trade-cycle -Status $(if ($visiblePass) { 'passed' } else { 'failed' }) `
        -ProofLevel terminal_runtime_evidence -ExitCode $visibleStep.ExitCode `
        -Detail $(if ($visiblePass) { 'The exact-head visible trade cycle passed.' } else { 'The visible trade child did not produce PASS.' }) `
        -LogPath $visibleStep.LogPath -Evidence (Get-FileReference -Path $visibleResultPath) -Data $visibleTradeResult
    if (-not $visiblePass) {
        $childState = if ($visibleTradeResult) { [string]$visibleTradeResult.terminalState } else { 'missing_result' }
        throw "FAILED_visible_trade_cycle:$childState"
    }
    Write-CampaignEvent -Stage visible-trade-cycle -Status passed -Sentence 'The child runner proved the exact save, movement, arrival, real buy, visible trade surface, and targeted MapTrade Manual cleanup.' -Evidence $visibleResultPath

    [void](Invoke-ForgeHandoffStage -Name forge-handoff -Command RunForgeHandoffAfterTradeNow -AllowBlocked -ProofLevel command_ack)
    if (-not (Invoke-ForgeHandoffStage -Name horse-atlas -Command ScanHorseAtlas -EvidenceFile BlacksmithGuild_HorseAtlas.json)) { throw 'FAILED_handoff:horse_atlas' }
    if (-not (Invoke-ForgeHandoffStage -Name herd-ledger -Command AnalyzeHerdLedger -EvidenceFile BlacksmithGuild_HerdLedger.json)) { throw 'FAILED_handoff:herd_ledger' }
    if (-not (Invoke-ForgeHandoffStage -Name horse-recommendation -Command AnalyzeHorseMarket -EvidenceFile BlacksmithGuild_HorseMarketIntel.json)) { throw 'FAILED_handoff:horse_recommendation' }

    if ($SkipPackAnimalAttempt) {
        Add-StageRecord -Name pack-animal-acquisition -Status deferred -ProofLevel none -ExitCode 0 `
            -Detail 'The operator explicitly skipped the bounded pack-animal acquisition attempt.' -LogPath '' -Evidence $null -Data $null
        Write-CampaignEvent -Stage pack-animal-acquisition -Status deferred -Sentence 'The operator explicitly skipped the bounded pack-animal acquisition attempt.'
    } else {
        [void](Invoke-ForgeHandoffStage -Name pack-animal-acquisition -Command ProbePackAnimalBuyNow `
            -EvidenceFile BlacksmithGuild_MapTradePackAnimalProbe.json -AllowBlocked -ProofLevel real_or_blocked_trade_delta)
    }

    [void](Invoke-ForgeHandoffStage -Name governor-resume -Command ResumeCampaignGovernorAutomation -AllowBlocked -ProofLevel command_ack)
    if (-not (Invoke-ForgeHandoffStage -Name governor-decision -Command RunCampaignGovernorCycleNow `
        -EvidenceFile BlacksmithGuild_CampaignGovernorDecision.json)) { throw 'FAILED_handoff:governor_decision' }

    if ($SkipGuildLoop) {
        Add-StageRecord -Name guild-loop-handoff -Status deferred -ProofLevel none -ExitCode 0 `
            -Detail 'The operator explicitly skipped the autonomous guild-loop handoff.' -LogPath '' -Evidence $null -Data $null
        Write-CampaignEvent -Stage guild-loop-handoff -Status deferred -Sentence 'The operator explicitly skipped the autonomous guild-loop handoff.'
    } else {
        [void](Invoke-ForgeHandoffStage -Name guild-loop-handoff -Command RunAutonomousGuildLoopNow `
            -EvidenceFile BlacksmithGuild_AutonomousGuildLoop.json -AllowBlocked -ProofLevel asynchronous_engine_handoff)
    }

    $terminalState = 'PASS_campaign_handoff'
    Write-CampaignEvent -Stage pipeline -Status passed -Sentence 'Forge Continue completed the visible trade proof and delivered fresh horse and governor handoffs; the game remains open for the user and asynchronous engines.' -Evidence $runRoot
    Write-FinalArtifacts -ExitCode 0
    exit 0
} catch {
    $failureDetail = $_.Exception.Message
    if ($terminalState -eq 'running') { $terminalState = ($failureDetail -split ':')[0] }
    Write-CampaignEvent -Stage pipeline -Status failed -Sentence ('Forge Continue stopped at a bounded stage: {0}' -f $failureDetail) -Evidence $runRoot
    Write-FinalArtifacts -ExitCode 2
    exit 2
}
