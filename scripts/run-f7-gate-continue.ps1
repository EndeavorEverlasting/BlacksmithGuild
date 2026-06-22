# F7 Continue gate — detached launch, sustained refocus, 60s stability checkpoint.
param(
    [int]$PollTimeoutSec = 300,
    [int]$StableSeconds = 60,
    [int]$RefocusIntervalSec = 2
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$focusHelperPath = Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1'
$csproj = Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
$bannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
if (Test-Path -LiteralPath $csproj) {
    $csprojText = Get-Content -LiteralPath $csproj -Raw
    if ($csprojText -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) {
            $bannerlordRoot = $fromCsproj
        }
    }
}

$statusPath = Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'
$launchLogPath = Join-Path $bannerlordRoot 'BlacksmithGuild_Launch.log'
$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate"
$startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')

function Stop-BannerlordProcesses {
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Stopping $name (PID $($_.Id))..." -ForegroundColor DarkYellow
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 3
}

function Invoke-BannerlordFocusHelper {
    if (-not (Test-Path -LiteralPath $focusHelperPath)) {
        return $false
    }
    try {
        return [bool](& $focusHelperPath)
    } catch {
        return $false
    }
}

function Test-GameProcessRunning {
    return $null -ne (Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)
}

function Test-Phase1SessionActive {
    param([datetime]$SinceUtc)
    if (-not (Test-Path -LiteralPath $phase1Path)) {
        return $false
    }
    try {
        if ((Get-Item -LiteralPath $phase1Path).LastWriteTimeUtc -ge $SinceUtc.AddSeconds(-5)) {
            return $true
        }
    } catch { }
    return $false
}
function Test-Phase1TbgReady {
    if (-not (Test-Path -LiteralPath $phase1Path)) {
        return $false
    }
    $tail = Get-Content -LiteralPath $phase1Path -Tail 40 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }
    foreach ($line in $tail) {
        if ($line -match 'TBG READY') {
            return $true
        }
    }
    return $false
}

function Test-Phase1QuickStartMapReady {
    param([datetime]$SinceLocal)

    if (-not (Test-Path -LiteralPath $phase1Path)) {
        return $false
    }
    try {
        $lines = Get-Content -LiteralPath $phase1Path -Tail 120 -ErrorAction Stop
    } catch {
        return $false
    }
    foreach ($line in $lines) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
            continue
        }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) {
            continue
        }
        if ($line -match 'transition: MapTransition -> MapReady') {
            return $true
        }
    }
    return $false
}

function Get-Phase1LastSignalLine {
    if (-not (Test-Path -LiteralPath $phase1Path)) {
        return $null
    }
    $tail = Get-Content -LiteralPath $phase1Path -Tail 1 -ErrorAction SilentlyContinue
    if ($tail) {
        return [string]$tail[-1]
    }
    return $null
}

function Get-LaunchCrashSignals {
    param([datetime]$SinceLocal)

    $signals = [ordered]@{
        safeModeDismissed = $false
        safeModePromptSeen = $false
        priorSessionCrashLikely = $false
        crashReporterDismissed = $false
        safeModePromptText = $null
    }

    if (-not (Test-Path -LiteralPath $launchLogPath)) {
        return [pscustomobject]$signals
    }

    try {
        $lines = Get-Content -LiteralPath $launchLogPath -Tail 400 -ErrorAction Stop
    } catch {
        return [pscustomobject]$signals
    }

    foreach ($line in $lines) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
            continue
        }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) {
            continue
        }

        if ($line -match 'shut down unexpectedly|enable safe mode') {
            $signals.safeModePromptSeen = $true
            $signals.priorSessionCrashLikely = $true
            if ($line -match 'Game shut down unexpectedly[^"]*') {
                $signals.safeModePromptText = $Matches[0].Trim()
            }
        }
        if ($line -match 'clicked Safe Mode No|Safe Mode: No selected') {
            $signals.safeModeDismissed = $true
            $signals.priorSessionCrashLikely = $true
        }
        if ($line -match 'clicked crash reporter No') {
            $signals.crashReporterDismissed = $true
            $signals.priorSessionCrashLikely = $true
        }
    }

    return [pscustomobject]$signals
}

function Get-F7GateSignals {
    $result = [ordered]@{
        campaignReady = $false
        canPollFileInbox = $false
        mapReadyStatus = $null
        phase1TbgReady = $false
        phase1QuickStartMapReady = $false
        phase1LastSignal = $null
        gameRunning = (Test-GameProcessRunning)
    }

    $result.phase1TbgReady = Test-Phase1TbgReady
    $result.phase1LastSignal = Get-Phase1LastSignalLine

    if (Test-Path -LiteralPath $statusPath) {
        try {
            $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
            $result.campaignReady = ($st.campaignReady -eq $true)
            if ($st.session) {
                $result.canPollFileInbox = ($st.session.canPollFileInbox -eq $true)
            }
            if ($st.tests -and $st.tests.map_ready) {
                $result.mapReadyStatus = [string]$st.tests.map_ready.status
            }
        } catch { }
    }

    return [pscustomobject]$result
}

function Test-F7GateCondition {
    param($Signals)
    $mapReadyPass = ($Signals.mapReadyStatus -eq 'PASS') -or $Signals.phase1TbgReady
    return ($Signals.campaignReady -and $Signals.canPollFileInbox -and $mapReadyPass)
}

function Save-CheckpointEvidence {
    param(
        [string]$PassFail,
        [int]$ExitCode,
        [int]$StableSec,
        $LastSignals,
        [string]$Notes,
        $LaunchSignals = $null
    )

    New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null

    if (Test-Path -LiteralPath $statusPath) {
        Copy-Item -LiteralPath $statusPath -Destination (Join-Path $checkpointDir 'BlacksmithGuild_Status.json') -Force
    }
    if (Test-Path -LiteralPath $phase1Path) {
        Get-Content -LiteralPath $phase1Path -Tail 220 |
            Set-Content -LiteralPath (Join-Path $checkpointDir 'Phase1.tail.txt') -Encoding UTF8
    }
    if (Test-Path -LiteralPath $launchLogPath) {
        Get-Content -LiteralPath $launchLogPath -Tail 220 |
            Set-Content -LiteralPath (Join-Path $checkpointDir 'Launch.tail.txt') -Encoding UTF8
    }

    $manifest = [ordered]@{
        checkpoint = 'checkpoint-01-f7-gate'
        sessionId = $sessionId
        passFail = $PassFail
        exitCode = $ExitCode
        startedAtUtc = $startedAtUtc
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        stableSeconds = $StableSec
        campaignReady = [bool]$LastSignals.campaignReady
        canPollFileInbox = [bool]$LastSignals.canPollFileInbox
        mapReadyStatus = $LastSignals.mapReadyStatus
        phase1TbgReady = [bool]$LastSignals.phase1TbgReady
        phase1QuickStartMapReady = [bool]$LastSignals.phase1QuickStartMapReady
        phase1LastSignal = $LastSignals.phase1LastSignal
        gameProcessRunning = [bool]$LastSignals.gameRunning
        launchSignals = if ($LaunchSignals) {
            [ordered]@{
                safeModeDismissed = [bool]$LaunchSignals.safeModeDismissed
                safeModePromptSeen = [bool]$LaunchSignals.safeModePromptSeen
                priorSessionCrashLikely = [bool]$LaunchSignals.priorSessionCrashLikely
                crashReporterDismissed = [bool]$LaunchSignals.crashReporterDismissed
                safeModePromptText = $LaunchSignals.safeModePromptText
            }
        } else { $null }
        mapReadyHookMask = $env:TBG_MAP_READY_HOOK_MASK
        notes = $Notes
    }
    $manifest | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $checkpointDir 'manifest.json') -Encoding UTF8

    return $checkpointDir
}

Write-Host ''
Write-Host '=== F7 Continue Gate ===' -ForegroundColor Cyan
Write-Host "Session: $sessionId"
Write-Host "Bannerlord root: $bannerlordRoot"
Write-Host ''

Stop-BannerlordProcesses

Write-Host 'Building Release...' -ForegroundColor Cyan
dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
if ($LASTEXITCODE -ne 0) {
    $signals = Get-F7GateSignals
    $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 1 -StableSec 0 -LastSignals $signals -Notes 'build failed'
    Write-Host "Build failed. Evidence: $dir" -ForegroundColor Red
    exit 1
}

$forgePs1 = Join-Path $repoRoot 'forge.ps1'
Write-Host 'Launching Continue (detached)...' -ForegroundColor Cyan
Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $forgePs1, '-Launch', '-LaunchIntent', 'continue'
) -WorkingDirectory $repoRoot | Out-Null

$deadline = (Get-Date).AddSeconds($PollTimeoutSec)
$launchStarted = Get-Date
$lastRefocusUtc = $null
$stableSince = $null
$lastSignals = $null
$everMapReady = $false
$gameEverSeen = $false
$lastHeartbeatSec = -1

function Write-F7PollHeartbeat {
    param(
        [double]$ElapsedSec,
        $Signals,
        [bool]$EverMapReady
    )
    $state = if ($Signals.gameRunning) { 'game=running' }
        elseif ($EverMapReady) { 'game=gone-after-map-ready' }
        else { 'game=gone' }
    $phase = if ($Signals.phase1TbgReady) { 'TBG READY' }
        elseif ($Signals.phase1QuickStartMapReady) { 'QuickStart MapReady' }
        else { 'loading' }
    $last = $Signals.phase1LastSignal
    if ($last -and $last.Length -gt 100) {
        $last = $last.Substring($last.Length - 100)
    }
    Write-Host ("  [{0:N0}s] {1} phase1={2} last={3}" -f $ElapsedSec, $state, $phase, $last) -ForegroundColor DarkGray
}

function Test-LauncherProcessRunning {
    return $null -ne (Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue)
}

function Test-LaunchStillStarting {
    param(
        [bool]$GameRunning,
        [bool]$GameWasSeen,
        [double]$ElapsedSec,
        [datetime]$LaunchStartedLocal
    )
    if ($GameRunning) {
        return $false
    }
    if ($GameWasSeen) {
        return $false
    }
    if (Test-Phase1SessionActive -SinceUtc $LaunchStartedLocal.ToUniversalTime()) {
        return $true
    }
    if ($ElapsedSec -lt 90 -and (Test-LauncherProcessRunning)) {
        return $true
    }
    if ($ElapsedSec -lt 45) {
        return $true
    }
    return $false
}

$launchStartedLocal = $launchStarted

Write-Host "Polling up to ${PollTimeoutSec}s (stable ${StableSeconds}s required)..." -ForegroundColor Cyan

while ((Get-Date) -lt $deadline) {
    $nowRefocusUtc = [DateTime]::UtcNow
    if (-not $lastRefocusUtc -or ($nowRefocusUtc - $lastRefocusUtc).TotalSeconds -ge $RefocusIntervalSec) {
        Invoke-BannerlordFocusHelper | Out-Null
        $lastRefocusUtc = $nowRefocusUtc
    }

    $lastSignals = Get-F7GateSignals
    $lastSignals.phase1QuickStartMapReady = Test-Phase1QuickStartMapReady -SinceLocal $launchStartedLocal
    if ($lastSignals.gameRunning) {
        $gameEverSeen = $true
    }

    if ($lastSignals.phase1TbgReady -or $lastSignals.mapReadyStatus -eq 'PASS' -or $lastSignals.phase1QuickStartMapReady) {
        $everMapReady = $true
    }

    $elapsedSec = ((Get-Date) - $launchStarted).TotalSeconds
    $heartbeatSec = [int][Math]::Floor($elapsedSec / 30)
    if ($heartbeatSec -ne $lastHeartbeatSec) {
        Write-F7PollHeartbeat -ElapsedSec $elapsedSec -Signals $lastSignals -EverMapReady $everMapReady
        $lastHeartbeatSec = $heartbeatSec
    }

    if (-not $lastSignals.gameRunning -and -not (Test-LaunchStillStarting -GameRunning $lastSignals.gameRunning -GameWasSeen $gameEverSeen -ElapsedSec $elapsedSec -LaunchStartedLocal $launchStarted)) {
        if ($everMapReady) {
            $notes = 'F7 FAIL: map-ready occurred then process died'
        } elseif ((Get-LaunchCrashSignals -SinceLocal $launchStartedLocal).priorSessionCrashLikely) {
            $notes = 'F7 FAIL: process died before map-ready; Safe Mode No on launch — prior session crash likely (mod/load chain)'
        } else {
            $notes = 'F7 FAIL: process died before map-ready'
        }
        $launchSignals = Get-LaunchCrashSignals -SinceLocal $launchStartedLocal
        $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 2 -StableSec 0 -LastSignals $lastSignals -Notes $notes -LaunchSignals $launchSignals
        Write-Host "$notes. Evidence: $dir" -ForegroundColor Red
        exit 2
    }

    if (Test-F7GateCondition -Signals $lastSignals) {
        if (-not $stableSince) {
            $stableSince = Get-Date
            Write-Host 'F7 gate conditions met — counting stable seconds...' -ForegroundColor Green
        } elseif (((Get-Date) - $stableSince).TotalSeconds -ge $StableSeconds) {
            $stableSec = [int][Math]::Floor(((Get-Date) - $stableSince).TotalSeconds)
            $launchSignals = Get-LaunchCrashSignals -SinceLocal $launchStartedLocal
            $dir = Save-CheckpointEvidence -PassFail 'PASS' -ExitCode 0 -StableSec $stableSec -LastSignals $lastSignals -Notes "F7 gate stable for >=${StableSeconds}s" -LaunchSignals $launchSignals
            Write-Host "F7 gate PASS (${stableSec}s stable). Evidence: $dir" -ForegroundColor Green
            exit 0
        }
    } else {
        $stableSince = $null
    }

    Start-Sleep -Seconds 1
}

$lastSignals = Get-F7GateSignals
$launchSignals = Get-LaunchCrashSignals -SinceLocal $launchStartedLocal
if (-not $lastSignals.gameRunning) {
    $notes = if ($everMapReady) { 'F7 FAIL: map-ready occurred then process died (timeout boundary)' }
        elseif ($launchSignals.priorSessionCrashLikely) { 'F7 FAIL: process died before map-ready (timeout); Safe Mode No on launch — prior session crash likely' }
        else { 'F7 FAIL: process died before map-ready (timeout boundary)' }
} elseif (-not $everMapReady) {
    $notes = if ($launchSignals.priorSessionCrashLikely) {
        'F7 FAIL: timeout still in MapTransition; Safe Mode No on launch — prior session crash likely (mod/load chain)'
    } else {
        'F7 FAIL: timeout still in MapTransition (no map-ready signal)'
    }
} elseif (-not (Test-F7GateCondition -Signals $lastSignals)) {
    $notes = 'F7 FAIL: timeout — map-ready seen but gate conditions not stable 60s (status file stale/missing fields)'
} else {
    $notes = 'F7 FAIL: timeout before 60s stability window completed'
}
$dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 2 -StableSec 0 -LastSignals $lastSignals -Notes $notes -LaunchSignals $launchSignals
Write-Host "$notes. Evidence: $dir" -ForegroundColor Red
exit 2
