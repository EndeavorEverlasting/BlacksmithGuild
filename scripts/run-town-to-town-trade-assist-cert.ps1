# Assistive attach cert — town-to-town trade probe (attach-first; no F7 / no launcher by default).
param(
    [switch]$AttachOnly,
    [switch]$NoLaunch,
    [switch]$LaunchIfNeeded,
    [int]$MaxWallSec = 600,
    [int]$InboxWaitSec = 15,
    [int]$StatusFreshSec = 300,
    [int]$ProbeTimeoutSec = 30,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'dev-command-names.ps1')

if ($WhatIf) {
    $modeLabel = if ($LaunchIfNeeded) { 'attach then launch if needed' } else { 'attach-only' }
    Write-Host "WhatIf: $modeLabel; Send-ForgeCommand AssistiveTownToTownProbe; harvest assist evidence" -ForegroundColor Cyan
    exit 0
}

$allowLaunch = $LaunchIfNeeded.IsPresent
if ($AttachOnly -or $NoLaunch) { $allowLaunch = $false }

$runnerCommandLine = "run-town-to-town-trade-assist-cert.ps1" +
    $(if ($AttachOnly) { ' -AttachOnly' } elseif ($NoLaunch) { ' -NoLaunch' } else { '' }) +
    $(if ($LaunchIfNeeded) { ' -LaunchIfNeeded' } else { '' })

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$startedAtUtc = (Get-Date).ToUniversalTime()
$startedAtUtcStr = $startedAtUtc.ToString('o')
$sinceLocal = Get-Date
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-assistive-town-trade"
$statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
$phase1Path = Get-Phase1LogPath -BannerlordRoot $bannerlordRoot
$crashContextPath = Get-CrashContextJsonPath -BannerlordRoot $bannerlordRoot
$launchLogPath = Get-LaunchLogPath -BannerlordRoot $bannerlordRoot
$timelinePath = Join-Path $checkpointDir 'ExternalStateTimeline.json'
$manifestPath = Join-Path $checkpointDir 'manifest.json'
$probeCommand = 'AssistiveTownToTownProbe'
$wallDeadline = (Get-Date).AddSeconds($MaxWallSec)

$exitCode = 2
$passFail = 'FAIL'
$failureClass = $null
$routeAgent = 'Agent C - External State Classifier / Assistive Runner'
$notes = @()
$launchUsed = $false
$launchPath = 'existing_session'
$manualLaunchAccepted = $true
$probeAckOk = $false
$probeJson = $null
$harvestResult = $null

function Test-AssistWallExceeded {
    if ((Get-Date) -gt $wallDeadline) {
        $script:failureClass = 'wall_clock_exceeded'
        $script:notes += "Exceeded ${MaxWallSec}s wall without explicit authorization extension"
        return $true
    }
    return $false
}

function Write-AssistManifest {
    param([hashtable]$Extra = @{})

    if (-not (Test-Path -LiteralPath $checkpointDir)) {
        New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null
    }

    $ready = Get-F7AssistiveReadinessFromStatus -StatusPath $statusPath
    $manifest = [ordered]@{
        checkpoint = 'checkpoint-01-assistive-town-trade'
        sessionId = $sessionId
        passFail = $passFail
        exitCode = $exitCode
        startedAtUtc = $startedAtUtcStr
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode = 'assistive_attach'
        certTarget = $null
        probeCommand = $probeCommand
        launchUsed = [bool]$launchUsed
        launchPath = [string]$launchPath
        manualLaunchAccepted = [bool]$manualLaunchAccepted
        failureClass = $failureClass
        routeAgent = $routeAgent
        notes = ($notes -join '; ')
        readinessSurface = $ready.readinessSurface
        settlementMenuOpen = [bool]$ready.settlementMenuOpen
        campaignMapSurfaceOpen = [bool]$ready.campaignMapSurfaceOpen
        campaignReady = [bool]$ready.campaignReady
        canPollFileInbox = [bool]$ready.canPollFileInbox
        inGameAssistReady = [bool]$ready.inGameAssistReady
        canAcceptAssistiveCommand = [bool]$ready.canAcceptAssistiveCommand
        townMenuReady = [bool]$ready.townMenuReady
        openMapReady = [bool]$ready.openMapReady
        assistiveAttach = $true
        fakeGameplayDelta = $false
    }

    if ($probeJson) {
        if ($probeJson.currentSettlement) { $manifest.currentSettlement = [string]$probeJson.currentSettlement }
        if ($probeJson.recommendedNextTown) { $manifest.recommendedNextTown = [string]$probeJson.recommendedNextTown }
        if ($probeJson.tradeExecution) { $manifest.tradeExecution = [string]$probeJson.tradeExecution }
        if ($probeJson.travelReadiness -and $probeJson.travelReadiness.travelCommandMode) {
            $manifest.travelCommandMode = [string]$probeJson.travelReadiness.travelCommandMode
        } elseif ($probeJson.travelCommandMode) {
            $manifest.travelCommandMode = [string]$probeJson.travelCommandMode
        }
        if ($probeJson.PSObject.Properties.Name -contains 'fakeGameplayDelta') {
            $manifest.fakeGameplayDelta = [bool]$probeJson.fakeGameplayDelta
        }
    }

    if ($harvestResult -and $harvestResult.evidenceCompleteness) {
        $manifest.evidenceCompleteness = $harvestResult.evidenceCompleteness.score
        $manifest.harvestPartial = [bool]$harvestResult.harvestPartial
    }

    foreach ($key in $Extra.Keys) {
        $manifest[$key] = $Extra[$key]
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

function Complete-AssistCert {
    param([hashtable]$Extra = @{})

    $script:harvestResult = Invoke-F7AssistiveEvidenceHarvest `
        -CheckpointDir $checkpointDir `
        -BannerlordRoot $bannerlordRoot `
        -StartedAtUtc $startedAtUtc `
        -SinceLocal $sinceLocal `
        -PassFail $passFail `
        -LaunchUsed $launchUsed `
        -Phase1Path $phase1Path `
        -StatusPath $statusPath `
        -CrashContextPath $crashContextPath `
        -LaunchLogPath $launchLogPath `
        -RunnerCommandLine $runnerCommandLine

    $null = Emit-F7ExternalStateTimelineCheckpoint -BannerlordRoot $bannerlordRoot -Mode assistive `
        -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath `
        -LaunchPath $launchPath -LaunchSelectedBy 'user' `
        -ReasonOverride "Assistive town-trade cert ended passFail=$passFail launchUsed=$launchUsed" -Force
    Save-F7ExternalStateTimeline | Out-Null
    Write-AssistManifest $Extra
}

Initialize-F7ExternalStateTimeline -Mode assistive -OutputPath $timelinePath -SessionId $sessionId -StartedAtUtc $startedAtUtcStr

$allowed = Get-DevCommandNames
if ($allowed -notcontains $probeCommand) {
    $failureClass = 'assistive_command_not_supported'
    $routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
    $notes += "Runtime missing dev command $probeCommand"
    Complete-AssistCert @{ assistiveCommandSupported = $false }
    Write-Host "FAIL: $failureClass" -ForegroundColor Yellow
    exit $exitCode
}

$attachCheck = Test-F7AssistiveSessionAttachable -BannerlordRoot $bannerlordRoot `
    -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath `
    -StatusFreshSec $StatusFreshSec

if (-not $attachCheck.attachable) {
    if (-not $allowLaunch) {
        $failureClass = $attachCheck.reason
        $routeAgent = $attachCheck.routeAgent
        $notes += "Attach-only failed: $($attachCheck.reason)"
        Complete-AssistCert
        Write-Host "FAIL: $failureClass (attach-only)" -ForegroundColor Red
        exit $exitCode
    }

    $navScript = Join-Path $PSScriptRoot 'launcher-auto-nav.ps1'
    Write-Host "Attach not ready ($($attachCheck.reason)); launching with -LaunchSetup..." -ForegroundColor Yellow
    & powershell -NoProfile -ExecutionPolicy Bypass -File $navScript `
        -LaunchIntent continue -BannerlordRoot $bannerlordRoot -TimeoutSec 300 -LaunchSetup
    if ($LASTEXITCODE -ne 0) {
        $failureClass = 'launch_setup_failed'
        $notes += "launcher-auto-nav exited $LASTEXITCODE"
        Complete-AssistCert
        Write-Host "FAIL: $failureClass" -ForegroundColor Red
        exit $exitCode
    }
    $launchUsed = $true
    $launchPath = 'continue'
    $manualLaunchAccepted = $false
    Start-Sleep -Seconds 2
    $attachCheck = Test-F7AssistiveSessionAttachable -BannerlordRoot $bannerlordRoot `
        -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath `
        -StatusFreshSec $StatusFreshSec
    if (-not $attachCheck.attachable) {
        $failureClass = $attachCheck.reason
        $routeAgent = $attachCheck.routeAgent
        $notes += "Still not attachable after launch: $($attachCheck.reason)"
        Complete-AssistCert
        Write-Host "FAIL: $failureClass" -ForegroundColor Red
        exit $exitCode
    }
}

$attach = Get-F7AssistiveAttachResult -LaunchPath 'existing_session' -LaunchSelectedBy 'user' `
    -GameProcessRunning $true
if (-not $attach.assistiveAttach) {
    $failureClass = 'assistive_attach_rejected'
    $notes += 'Get-F7AssistiveAttachResult returned assistiveAttach=false'
    Complete-AssistCert
    Write-Host "FAIL: $failureClass" -ForegroundColor Red
    exit $exitCode
}

$null = Emit-F7ExternalStateTimelineCheckpoint -BannerlordRoot $bannerlordRoot -Mode assistive `
    -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath `
    -LaunchPath $launchPath -LaunchSelectedBy 'user' `
    -ReasonOverride 'Assistive attach to existing in-game session' -Force

$inboxDeadline = (Get-Date).AddSeconds($InboxWaitSec)
while ((Get-Date) -lt $inboxDeadline) {
    if (Test-AssistWallExceeded) { break }
    $readyNow = Get-F7AssistiveReadinessFromStatus -StatusPath $statusPath
    if ($readyNow.canPollFileInbox -and $readyNow.inGameAssistReady -and $readyNow.canAcceptAssistiveCommand) { break }
    Start-Sleep -Seconds 1
}

$ready = Get-F7AssistiveReadinessFromStatus -StatusPath $statusPath
if (-not $ready.canPollFileInbox) {
    $failureClass = 'inbox_not_ready'
    $routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
    $notes += "canPollFileInbox false after ${InboxWaitSec}s"
    Complete-AssistCert
    Write-Host "FAIL: $failureClass" -ForegroundColor Red
    exit $exitCode
}

if (Test-AssistWallExceeded) {
    Complete-AssistCert
    Write-Host "FAIL: $failureClass" -ForegroundColor Red
    exit $exitCode
}

try {
    Send-ForgeCommand -CommandName $probeCommand -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ProbeTimeoutSec | Out-Null
    $probeAckOk = $true
    $notes += "$probeCommand ack received"
} catch {
    $failureClass = 'assistive_probe_failed'
    $notes += $_.Exception.Message
}

$probePath = Get-TownToTownTradeProbeJsonPath -BannerlordRoot $bannerlordRoot
if (Test-Path -LiteralPath $probePath) {
    try {
        $probeJson = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
    } catch {
        $notes += "probe json parse failed: $($_.Exception.Message)"
    }
}

if (Test-F7AssistiveTownTradeCertPass -Readiness $ready -ProbeJson $probeJson -ProbeAckOk $probeAckOk) {
    $passFail = 'PASS'
    $exitCode = 0
    $failureClass = $null
} elseif (-not $failureClass) {
    $failureClass = if (-not $probeAckOk) { 'assistive_probe_failed' }
                  elseif (-not $probeJson) { 'probe_evidence_missing' }
                  elseif ($probeJson.fakeGameplayDelta -eq $true) { 'fake_gameplay_delta' }
                  else { 'assist_pass_criteria_unmet' }
    $routeAgent = if ($failureClass -match 'probe|fake') {
        'Agent B - Runtime / Readiness / Gameplay safety'
    } else {
        $routeAgent
    }
}

Complete-AssistCert @{ assistiveCommandSupported = $true; probeAck = $(if ($probeAckOk) { 'Success' } else { 'Failed' }) }
Write-Host "$passFail assistive town-trade cert (exit $exitCode) session=$sessionId" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })
Write-Host "Evidence: $checkpointDir" -ForegroundColor Cyan
exit $exitCode
