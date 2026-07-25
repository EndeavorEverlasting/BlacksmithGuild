[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SessionDir,
    [string]$RepoRoot = '',
    [string]$BannerlordRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-JsonFileContent([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }
}

$summaryPath = Join-Path $SessionDir 'governor-smoke-summary.json'
$summary = Get-JsonFileContent $summaryPath

$testStartUtc = $null
if ($summary -and (Get-Member -InputObject $summary -Name 'testStartUtc') -and $summary.testStartUtc) {
    try {
        $testStartUtc = [datetime]::Parse([string]$summary.testStartUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    } catch { }
}

$skipLaunch = $false
if ($summary -and (Get-Member -InputObject $summary -Name 'skipLaunch')) {
    $skipLaunch = [bool]$summary.skipLaunch
}

$mode = 'live_fresh_launch'
if ($summary -and (Get-Member -InputObject $summary -Name 'mode') -and $summary.mode) {
    $mode = [string]$summary.mode
}

$launcherCtxPath = Join-Path $SessionDir 'launcher-window-context.json'
if (-not (Test-Path -LiteralPath $launcherCtxPath -PathType Leaf) -and -not [string]::IsNullOrWhiteSpace($BannerlordRoot)) {
    $launcherCtxPath = Join-Path $BannerlordRoot 'launcher-window-context.json'
}
$launcherCtx = Get-JsonFileContent $launcherCtxPath

$launcherProcessObserved = $false
$launcherHwndObserved = $false
$launchActionDispatched = $false

if ($launcherCtx) {
    if ((Get-Member -InputObject $launcherCtx -Name 'processId') -and $launcherCtx.processId -and [int]$launcherCtx.processId -gt 0) {
        $launcherProcessObserved = $true
    }
    if ((Get-Member -InputObject $launcherCtx -Name 'hwnd') -and $launcherCtx.hwnd -and [int]$launcherCtx.hwnd -gt 0) {
        $launcherHwndObserved = $true
    }
    if ($launcherProcessObserved -and $launcherHwndObserved) {
        $launchActionDispatched = $true
    }
}

$launchRequested = -not $skipLaunch
$launchAttempted = $launchRequested -and ($launcherProcessObserved -or ($summary -and (Get-Member -InputObject $summary -Name 'bootstrapUsed') -and $summary.bootstrapUsed))

$statusPath = Join-Path $SessionDir 'BlacksmithGuild_Status.json'
if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf) -and -not [string]::IsNullOrWhiteSpace($BannerlordRoot)) {
    $statusPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
}
$status = Get-JsonFileContent $statusPath

$gameProcessObserved = $false
$campaignAttached = $false
$campaignReady = $false
$statusFresh = $false

if ($status) {
    if ((Get-Member -InputObject $status -Name 'processId') -and $status.processId -and [int]$status.processId -gt 0) {
        $gameProcessObserved = $true
    } elseif (Get-Member -InputObject $status -Name 'stateMachine') {
        $gameProcessObserved = $true
    }

    $statusTime = $null
    if ((Get-Member -InputObject $status -Name 'stateMachine') -and $status.stateMachine -and (Get-Member -InputObject $status.stateMachine -Name 'heartbeatUtc') -and $status.stateMachine.heartbeatUtc) {
        try { $statusTime = [datetime]::Parse([string]$status.stateMachine.heartbeatUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    } elseif ((Get-Member -InputObject $status -Name 'updatedAt') -and $status.updatedAt) {
        try { $statusTime = [datetime]::Parse([string]$status.updatedAt, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }

    if ($statusTime -and $testStartUtc -and $statusTime -ge $testStartUtc.AddMinutes(-1)) {
        $statusFresh = $true
    }

    if ($gameProcessObserved -and $statusFresh) {
        $campaignAttached = $true
    }

    if ($campaignAttached) {
        $cReady = (Get-Member -InputObject $status -Name 'campaignReady') -and ($status.campaignReady -eq $true)
        $pollReady = (Get-Member -InputObject $status -Name 'session') -and $status.session -and (Get-Member -InputObject $status.session -Name 'canPollFileInbox') -and ($status.session.canPollFileInbox -eq $true)
        if ($cReady -or $pollReady) {
            $campaignReady = $true
        }
    }
}

$commandIssued = $campaignReady
$commandAckObserved = $false
if ($commandIssued -and $status -and ((Get-Member -InputObject $status -Name 'lastCommandAck') -or (Get-Member -InputObject $summary -Name 'cycleId'))) {
    $commandAckObserved = $true
}

$decisionPath = Join-Path $SessionDir 'BlacksmithGuild_CampaignGovernorDecision.json'
$decision = Get-JsonFileContent $decisionPath

$behaviorObserved = $false
$decisionFresh = $false

if ($decision) {
    $decisionTime = $null
    if ((Get-Member -InputObject $decision -Name 'generatedUtc') -and $decision.generatedUtc) {
        try { $decisionTime = [datetime]::Parse([string]$decision.generatedUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }

    if ($decisionTime -and $testStartUtc -and $decisionTime -ge $testStartUtc) {
        $decisionFresh = $true
    }

    if ($decisionFresh -and (Get-Member -InputObject $decision -Name 'cycleId') -and $decision.cycleId -and (Get-Member -InputObject $decision -Name 'selectedBranch') -and $decision.selectedBranch) {
        $behaviorObserved = $true
    }
}

$runtimeArtifactCollected = $false
if ($behaviorObserved -and (Test-Path -LiteralPath $decisionPath -PathType Leaf)) {
    $runtimeArtifactCollected = $true
}

$evidenceFresh = $statusFresh -and $decisionFresh

$correlationContinuous = $false
if ($summary -and (Get-Member -InputObject $summary -Name 'sessionId') -and $summary.sessionId) {
    if ($decision -and (Get-Member -InputObject $decision -Name 'cycleId') -and $decision.cycleId -and $evidenceFresh) {
        $correlationContinuous = $true
    }
}

$packet = [ordered]@{
    schema                   = 'TbgLiveRuntimeProofPacket.v1'
    sessionId                = if ($summary -and (Get-Member -InputObject $summary -Name 'sessionId')) { [string]$summary.sessionId } else { '' }
    generatedUtc             = [datetime]::UtcNow.ToString('o')
    mode                     = $mode
    skipLaunch               = $skipLaunch
    launchRequested          = $launchRequested
    launchAttempted          = $launchAttempted
    launcherProcessObserved  = $launcherProcessObserved
    launcherHwndObserved     = $launcherHwndObserved
    launchActionDispatched   = $launchActionDispatched
    gameProcessObserved      = $gameProcessObserved
    campaignAttached         = $campaignAttached
    campaignReady            = $campaignReady
    commandIssued            = $commandIssued
    commandAckObserved       = $commandAckObserved
    behaviorObserved         = $behaviorObserved
    runtimeArtifactCollected = $runtimeArtifactCollected
    evidenceFresh            = $evidenceFresh
    correlationContinuous    = $correlationContinuous
}

$outPath = Join-Path $SessionDir 'live-runtime-proof-packet.json'
$packet | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outPath -Encoding UTF8
return $outPath
