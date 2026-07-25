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

function Get-JsonFileContent {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Malformed JSON at ${Path}: $($_.Exception.Message)"
        return $null
    }
}

function Get-MemberProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Test-HasMember {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $false }
    return $null -ne $Object.PSObject.Properties[$Name]
}

# 1. Summary
$summaryPath = Join-Path $SessionDir 'governor-smoke-summary.json'
$summary = Get-JsonFileContent -Path $summaryPath

$testStartUtc = $null
$sessionId = ''

if ($summary) {
    $sessionId = [string](Get-MemberProperty $summary 'sessionId')
    $rawStart = Get-MemberProperty $summary 'testStartUtc'
    if ($rawStart) {
        try {
            $testStartUtc = [datetime]::Parse([string]$rawStart, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
        } catch { }
    }
}

$skipLaunch = $false
if ($summary -and (Test-HasMember $summary 'skipLaunch')) {
    $skipLaunch = [bool](Get-MemberProperty $summary 'skipLaunch')
}

$mode = 'live_fresh_launch'
if ($summary -and (Test-HasMember $summary 'mode')) {
    $modeStr = [string](Get-MemberProperty $summary 'mode')
    if (-not [string]::IsNullOrWhiteSpace($modeStr)) { $mode = $modeStr }
}

# 2. Launcher Context & Launch Action
$launcherCtxPath = Join-Path $SessionDir 'launcher-window-context.json'
$launcherCtx = Get-JsonFileContent -Path $launcherCtxPath

$launcherProcessObserved = $false
$launcherHwndObserved = $false
$launchActionDispatched = $false
$launcherPid = 0
$launcherHwnd = 0
$launcherSessionId = ''

if ($launcherCtx) {
    $parsedLauncherPid = Get-MemberProperty $launcherCtx 'processId'
    if ($parsedLauncherPid -and [int]$parsedLauncherPid -gt 0) {
        $launcherProcessObserved = $true
        $launcherPid = [int]$parsedLauncherPid
    }
    $hwnd = Get-MemberProperty $launcherCtx 'hwnd'
    if ($hwnd -and [int]$hwnd -gt 0) {
        $launcherHwndObserved = $true
        $launcherHwnd = [int]$hwnd
    }
    $launcherSessionId = [string](Get-MemberProperty $launcherCtx 'sessionId')

    $actDisp = Get-MemberProperty $launcherCtx 'launchActionDispatched'
    if ($null -eq $actDisp) { $actDisp = Get-MemberProperty $launcherCtx 'actionDispatched' }
    if ($actDisp -eq $true) {
        $actTimeRaw = Get-MemberProperty $launcherCtx 'actionDispatchedUtc'
        $actTime = $null
        if ($actTimeRaw) {
            try { $actTime = [datetime]::Parse([string]$actTimeRaw, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
        }
        if (-not $actTime -or ($testStartUtc -and $actTime -ge $testStartUtc.AddMinutes(-1))) {
            $launchActionDispatched = $true
        }
    }
}

if (-not $launchActionDispatched) {
    $launchLogPath = Join-Path $SessionDir 'launch-log.txt'
    if (Test-Path -LiteralPath $launchLogPath -PathType Leaf) {
        $logLines = Get-Content -LiteralPath $launchLogPath -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($line in $logLines) {
            if ($line -match 'CLICK "(launcher PLAY|launcher CONTINUE)"' -and $line -match 'dispatched') {
                $launchActionDispatched = $true
                break
            }
        }
    }
}

$launchRequested = -not $skipLaunch
$launchAttempted = $launchRequested -and ($launcherProcessObserved -or ($summary -and (Test-HasMember $summary 'bootstrapUsed') -and (Get-MemberProperty $summary 'bootstrapUsed')))

# 3. Game Process & Status
$statusPath = Join-Path $SessionDir 'BlacksmithGuild_Status.json'
$status = Get-JsonFileContent -Path $statusPath

$gameProcessObserved = $false
$campaignAttached = $false
$campaignReady = $false
$statusFresh = $false
$gamePid = 0
$statusSessionId = ''
$statusTime = $null

if ($status) {
    $statusSessionId = [string](Get-MemberProperty $status 'sessionId')

    $sm = Get-MemberProperty $status 'stateMachine'
    if ($sm) {
        $hbUtc = Get-MemberProperty $sm 'heartbeatUtc'
        if ($hbUtc) {
            try { $statusTime = [datetime]::Parse([string]$hbUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
        }
    }
    if (-not $statusTime) {
        $upUtc = Get-MemberProperty $status 'updatedAt'
        if ($upUtc) {
            try { $statusTime = [datetime]::Parse([string]$upUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
        }
    }

    if ($statusTime -and $testStartUtc -and $statusTime -ge $testStartUtc.AddMinutes(-1)) {
        $statusFresh = $true
    }

    $parsedGamePid = Get-MemberProperty $status 'processId'
    if ($parsedGamePid -and [int]$parsedGamePid -gt 0 -and $statusFresh) {
        $pName = [string](Get-MemberProperty $status 'processName')
        if ([string]::IsNullOrWhiteSpace($pName) -or $pName -like '*Bannerlord*') {
            $gameProcessObserved = $true
            $gamePid = [int]$parsedGamePid
        }
    }

    if ($gameProcessObserved -and $statusFresh) {
        $campaignAttached = $true
    }

    if ($gameProcessObserved -and $campaignAttached) {
        $cReady = [bool](Get-MemberProperty $status 'campaignReady')
        $sessObj = Get-MemberProperty $status 'session'
        $pollReady = $false
        if ($sessObj) {
            $pollReady = [bool](Get-MemberProperty $sessObj 'canPollFileInbox')
        }

        $readyUtc = $null
        $rawReadyUtc = Get-MemberProperty $status 'campaignReadyUtc'
        if ($rawReadyUtc) {
            try { $readyUtc = [datetime]::Parse([string]$rawReadyUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
        }
        $stableDurationSec = 0
        if ($readyUtc -and $statusTime) {
            $stableDurationSec = ($statusTime - $readyUtc).TotalSeconds
        } elseif ($testStartUtc -and $statusTime) {
            $stableDurationSec = ($statusTime - $testStartUtc).TotalSeconds
        }

        if ($cReady -and $pollReady -and $stableDurationSec -ge 60) {
            $campaignReady = $true
        }
    }
}

# 4. Command Request & ACK
$cmdReqPath = Join-Path $SessionDir 'command-request.json'
$cmdReq = Get-JsonFileContent -Path $cmdReqPath

$commandIssued = $false
$cmdReqId = ''
$cmdReqSessionId = ''

if ($cmdReq) {
    $cName = [string](Get-MemberProperty $cmdReq 'commandName')
    $cReqTimeRaw = Get-MemberProperty $cmdReq 'requestUtc'
    $cReqTime = $null
    if ($cReqTimeRaw) {
        try { $cReqTime = [datetime]::Parse([string]$cReqTimeRaw, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }
    if ($cName -eq 'RunCampaignGovernorCycleNow' -and ($cReqTime -and $testStartUtc -and $cReqTime -ge $testStartUtc)) {
        $commandIssued = $true
        $cmdReqId = [string](Get-MemberProperty $cmdReq 'commandId')
        $cmdReqSessionId = [string](Get-MemberProperty $cmdReq 'sessionId')
    }
}

$cmdAckPath = Join-Path $SessionDir 'command-ack.json'
$cmdAck = Get-JsonFileContent -Path $cmdAckPath

$commandAckObserved = $false
if ($commandIssued -and $cmdAck) {
    $ackName = [string](Get-MemberProperty $cmdAck 'commandName')
    $ackId = [string](Get-MemberProperty $cmdAck 'commandId')
    $ackSessionId = [string](Get-MemberProperty $cmdAck 'sessionId')
    $ackUtcRaw = Get-MemberProperty $cmdAck 'ackUtc'
    $ackUtc = $null
    if ($ackUtcRaw) {
        try { $ackUtc = [datetime]::Parse([string]$ackUtcRaw, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }

    if ($ackName -eq 'RunCampaignGovernorCycleNow' -and $ackId -eq $cmdReqId -and $ackUtc -and $testStartUtc -and $ackUtc -ge $testStartUtc) {
        $commandAckObserved = $true
    }
}

# 5. Governor Decision Behavior
$decisionPath = Join-Path $SessionDir 'BlacksmithGuild_CampaignGovernorDecision.json'
$decision = Get-JsonFileContent -Path $decisionPath

$behaviorObserved = $false
$decisionFresh = $false
$decisionSessionId = ''

if ($decision) {
    $decisionSessionId = [string](Get-MemberProperty $decision 'sessionId')
    $decisionTimeRaw = Get-MemberProperty $decision 'generatedUtc'
    $decisionTime = $null
    if ($decisionTimeRaw) {
        try { $decisionTime = [datetime]::Parse([string]$decisionTimeRaw, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }

    if ($decisionTime -and $testStartUtc -and $decisionTime -ge $testStartUtc) {
        $decisionFresh = $true
    }

    $cId = [string](Get-MemberProperty $decision 'cycleId')
    $sBranch = [string](Get-MemberProperty $decision 'selectedBranch')
    $sReason = [string](Get-MemberProperty $decision 'selectedReason')

    if ($decisionFresh -and -not [string]::IsNullOrWhiteSpace($cId) -and -not [string]::IsNullOrWhiteSpace($sBranch) -and -not [string]::IsNullOrWhiteSpace($sReason)) {
        $behaviorObserved = $true
    }
}

$runtimeArtifactCollected = $false
if ($behaviorObserved -and (Test-Path -LiteralPath $decisionPath -PathType Leaf)) {
    $runtimeArtifactCollected = $true
}

$evidenceFresh = $statusFresh -and $decisionFresh

# 6. End-to-End Correlation
$correlationContinuous = $false
if (-not [string]::IsNullOrWhiteSpace($sessionId)) {
    $mismatch = $false
    if ($launcherCtx -and $launcherSessionId -and $launcherSessionId -ne $sessionId) { $mismatch = $true }
    if ($status -and $statusSessionId -and $statusSessionId -ne $sessionId) { $mismatch = $true }
    if ($cmdReq -and $cmdReqSessionId -and $cmdReqSessionId -ne $sessionId) { $mismatch = $true }
    if ($cmdAck -and (Get-MemberProperty $cmdAck 'sessionId') -and [string](Get-MemberProperty $cmdAck 'sessionId') -ne $sessionId) { $mismatch = $true }
    if ($decision -and $decisionSessionId -and $decisionSessionId -ne $sessionId) { $mismatch = $true }

    if (-not $mismatch -and $behaviorObserved -and $evidenceFresh) {
        $correlationContinuous = $true
    }
}

$packet = [ordered]@{
    schema                   = 'TbgLiveRuntimeProofPacket.v1'
    sessionId                = $sessionId
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
