# F7 Continue gate — no-click launch, passive stability poll, 60s stability checkpoint.
param(
    [string]$HookMask,
    [ValidateSet('continue', 'play', 'any')]
    [string]$CertTarget = 'continue',
    [int]$TimeoutSeconds = 300,
    [int]$StableSeconds = 60,
    [int]$LaunchTimeoutSec = 300,
    [int]$PostLaunchHwndWaitSec = 60
)

$ErrorActionPreference = 'Stop'
$PollTimeoutSec = $TimeoutSeconds
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1')

$focusHelperPath = Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1'
$compareGoldenPath = Join-Path $PSScriptRoot 'compare-phase1-golden-path.ps1'
$csproj = Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot

$statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
$phase1Path = Get-Phase1LogPath -BannerlordRoot $bannerlordRoot
$launchLogPath = Get-LaunchLogPath -BannerlordRoot $bannerlordRoot
$crashContextPath = Get-CrashContextJsonPath -BannerlordRoot $bannerlordRoot
$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate"
$startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')

$hookMaskWasSet = $false
$resolvedHookMask = $HookMask
if ($resolvedHookMask) {
    $env:TBG_MAP_READY_HOOK_MASK = $resolvedHookMask
    $hookMaskWasSet = $true
} else {
    Remove-Item -Path 'Env:TBG_MAP_READY_HOOK_MASK' -ErrorAction SilentlyContinue
}

$script:LaunchAutomation = [ordered]@{
    launchState = 'init'
    safeModeDetected = $false
    safeModeNoClicked = $false
    continueClick = [ordered]@{ attempted = $false; success = $false; method = 'unknown' }
    playClick = [ordered]@{ attempted = $false; success = $false; method = 'unknown' }
    lastFocusResult = $null
    launchError = $null
    handoffSeen = $false
    launchPath = 'unknown'
    launchSelectedBy = 'unknown'
    certTarget = $CertTarget
    targetMismatch = $false
    launchPathAdopted = $false
    continueEscalated = $false
    continueClickUtc = $null
    continueLatencySeconds = $null
}

$script:F7ProcessTimestamps = [ordered]@{
    gameStartUtc = $null
    gameEndUtc = $null
}

$script:LastProcessDetection = $null

$runnerCommandLine = "run-f7-gate-continue.ps1 -CertTarget $CertTarget" +
    $(if ($HookMask) { " -HookMask $HookMask" } else { '' }) +
    " -TimeoutSeconds $TimeoutSeconds -StableSeconds $StableSeconds"

function Write-F7LaunchState {
    param([string]$State)
    if ($script:LaunchAutomation.launchState -eq $State) { return }
    $script:LaunchAutomation.launchState = $State
    $line = "f7-gate: LAUNCH_STATE=$State"
    Write-Host $line -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $bannerlordRoot -Message $line
}

function Stop-BannerlordProcesses {
    $lockPath = Get-NavLockPath -BannerlordRoot $bannerlordRoot
    if (Test-Path -LiteralPath $lockPath) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared nav lock for F7 cert: $lockPath" -ForegroundColor DarkYellow
    }
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
        $script:LaunchAutomation.lastFocusResult = $false
        return $false
    }
    try {
        $focused = [bool](& $focusHelperPath)
        $script:LaunchAutomation.lastFocusResult = $focused
        return $focused
    } catch {
        $script:LaunchAutomation.lastFocusResult = $false
        return $false
    }
}

function Get-F7ProcessDetection {
    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot `
        -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath
    $script:LastProcessDetection = $det
    return $det
}

function Test-GameProcessRunning {
    return [bool](Get-F7ProcessDetection).gameProcessRunning
}

function Test-F7GameAliveUncertain {
    param($Detection)
    if (-not $Detection) { return $false }
    return [string]$Detection.gameAliveConfidence -in @(
        'launcher_hosted', 'phase1_active', 'process_detection_uncertain'
    )
}

function Get-F7GameGoneFailNotes {
    param(
        $Detection,
        [bool]$EverMapReady,
        [bool]$PriorSessionCrashLikely
    )

    if (Test-F7GameAliveUncertain -Detection $Detection) {
        $method = [string]$Detection.gameProcessDetectionMethod
        if ($EverMapReady) {
            return "F7 FAIL: process_detection_uncertain after map-ready (method=$method; Bannerlord.exe not matched)"
        }
        return "F7 FAIL: process_detection_uncertain; logs active but Bannerlord.exe not matched (method=$method)"
    }

    if ($EverMapReady) {
        return 'F7 FAIL: map-ready occurred then process died'
    }
    if ($PriorSessionCrashLikely) {
        return 'F7 FAIL: process died before map-ready; Safe Mode No on launch — prior session crash likely (mod/load chain)'
    }
    return 'F7 FAIL: process died before map-ready'
}

function Get-F7TimeoutFailNotes {
    param(
        $LastSignals,
        $Detection,
        [bool]$EverMapReady,
        $LaunchSignals
    )

    if (Test-F7GameAliveUncertain -Detection $Detection -or $LastSignals.gameRunning) {
        if (-not $EverMapReady) {
            $method = if ($Detection) { [string]$Detection.gameProcessDetectionMethod } else { 'unknown' }
            $conf = if ($Detection) { [string]$Detection.gameAliveConfidence } else { 'unknown' }
            if ($LaunchSignals.priorSessionCrashLikely) {
                return "F7 FAIL: timeout in MapTransition (game alive; detection=$conf method=$method); Safe Mode No on launch; prior session crash likely"
            }
            return "F7 FAIL: timeout in MapTransition (game alive; detection=$conf method=$method; no map-ready signal)"
        }
        if (-not (Test-F7GateCondition -Signals $LastSignals)) {
            return 'F7 FAIL: timeout — map-ready seen but gate conditions not stable 60s (status file stale/missing fields)'
        }
        return 'F7 FAIL: timeout before 60s stability window completed'
    }

    if (-not $LastSignals.gameRunning) {
        if ($EverMapReady) {
            return 'F7 FAIL: map-ready occurred then process died (timeout boundary)'
        }
        if ($LaunchSignals.priorSessionCrashLikely) {
            return 'F7 FAIL: process died before map-ready (timeout); Safe Mode No on launch — prior session crash likely'
        }
        return 'F7 FAIL: process died before map-ready (timeout boundary)'
    }

    if (-not $EverMapReady) {
        if ($LaunchSignals.priorSessionCrashLikely) {
            return 'F7 FAIL: timeout still in MapTransition; Safe Mode No on launch — prior session crash likely (mod/load chain)'
        }
        return 'F7 FAIL: timeout still in MapTransition (no map-ready signal)'
    }
    if (-not (Test-F7GateCondition -Signals $LastSignals)) {
        return 'F7 FAIL: timeout — map-ready seen but gate conditions not stable 60s (status file stale/missing fields)'
    }
    return 'F7 FAIL: timeout before 60s stability window completed'
}

function Test-LauncherProcessRunning {
    return $null -ne (Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue)
}

function Test-Phase1SessionActive {
    param([datetime]$SinceUtc)
    if (-not (Test-Path -LiteralPath $phase1Path)) { return $false }
    try {
        if ((Get-Item -LiteralPath $phase1Path).LastWriteTimeUtc -ge $SinceUtc.AddSeconds(-5)) {
            return $true
        }
    } catch { }
    return $false
}

function Test-Phase1TbgReady {
    if (-not (Test-Path -LiteralPath $phase1Path)) { return $false }
    $tail = Get-Content -LiteralPath $phase1Path -Tail 40 -ErrorAction SilentlyContinue
    if (-not $tail) { return $false }
    foreach ($line in $tail) {
        if (Test-Phase1ReadyLine -Line $line) { return $true }
    }
    return $false
}

function Test-Phase1QuickStartMapReady {
    param([datetime]$SinceLocal)
    if (-not (Test-Path -LiteralPath $phase1Path)) { return $false }
    try {
        $lines = Get-Content -LiteralPath $phase1Path -Tail 120 -ErrorAction Stop
    } catch { return $false }
    foreach ($line in $lines) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { continue }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }
        if ($line -match 'transition: MapTransition -> MapReady') { return $true }
    }
    return $false
}

function Test-Phase1MapTransition {
    param([datetime]$SinceLocal)
    if (-not (Test-Path -LiteralPath $phase1Path)) { return $false }
    try {
        $lines = Get-Content -LiteralPath $phase1Path -Tail 120 -ErrorAction Stop
    } catch { return $false }
    foreach ($line in $lines) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { continue }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }
        if ($line -match 'transition: MainMenu -> MapTransition') { return $true }
    }
    return $false
}

function Get-Phase1LastSignalLine {
    if (-not (Test-Path -LiteralPath $phase1Path)) { return $null }
    $tail = Get-Content -LiteralPath $phase1Path -Tail 1 -ErrorAction SilentlyContinue
    if ($tail) { return [string]$tail[-1] }
    return $null
}

function Get-LaunchAutomationSignals {
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
        $lines = Get-Content -LiteralPath $launchLogPath -Tail 500 -ErrorAction Stop
    } catch {
        return [pscustomobject]$signals
    }

    foreach ($line in $lines) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { continue }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }

        if ($line -match 'shut down unexpectedly|enable safe mode') {
            $signals.safeModePromptSeen = $true
            $signals.priorSessionCrashLikely = $true
            $script:LaunchAutomation.safeModeDetected = $true
            if ($line -match 'Game shut down unexpectedly[^"]*') {
                $signals.safeModePromptText = $Matches[0].Trim()
            }
        }
        if ($line -match 'clicked Safe Mode No|Safe Mode: No selected|LAUNCH_STATE=safe_mode_no_clicked') {
            $signals.safeModeDismissed = $true
            $signals.priorSessionCrashLikely = $true
            $script:LaunchAutomation.safeModeNoClicked = $true
        }
        if ($line -match 'clicked crash reporter No') {
            $signals.crashReporterDismissed = $true
            $signals.priorSessionCrashLikely = $true
        }
        if ($line -match 'LAUNCH_STATE=continue_escalate') {
            $script:LaunchAutomation.continueEscalated = $true
        }
        if ($line -match 'LAUNCH_STATE=continue_clicked|clicked CONTINUE') {
            $script:LaunchAutomation.continueClick.attempted = $true
            $script:LaunchAutomation.continueClick.success = $true
            if (-not $script:LaunchAutomation.continueClickUtc) {
                $script:LaunchAutomation.continueClickUtc = $lineTime
            }
            $script:LaunchAutomation.launchPath = 'continue'
            $script:LaunchAutomation.launchPathAdopted = $true
            if ($line -match 'selectedBy=user') {
                $script:LaunchAutomation.launchSelectedBy = 'user'
            } elseif ($line -match 'selectedBy=automation') {
                $script:LaunchAutomation.launchSelectedBy = 'automation'
            } elseif ($script:LaunchAutomation.launchSelectedBy -eq 'unknown') {
                $script:LaunchAutomation.launchSelectedBy = 'automation'
            }
            if ($line -match 'method=([^)\s]+)') {
                $script:LaunchAutomation.continueClick.method = $Matches[1]
            } elseif ($line -match 'coords') {
                $script:LaunchAutomation.continueClick.method = 'coordinate'
            } else {
                $script:LaunchAutomation.continueClick.method = 'uia-scoped'
            }
        }
        if ($line -match 'LAUNCH_STATE=play_clicked|clicked PLAY') {
            $script:LaunchAutomation.playClick.attempted = $true
            $script:LaunchAutomation.playClick.success = $true
            $script:LaunchAutomation.launchPath = 'play'
            $script:LaunchAutomation.launchPathAdopted = $true
            if ($line -match 'selectedBy=user') {
                $script:LaunchAutomation.launchSelectedBy = 'user'
            } elseif ($line -match 'selectedBy=automation') {
                $script:LaunchAutomation.launchSelectedBy = 'automation'
            } elseif ($CertTarget -eq 'continue') {
                $script:LaunchAutomation.launchSelectedBy = 'user'
            } else {
                $script:LaunchAutomation.launchSelectedBy = 'automation'
            }
        }
        if ($line -match 'LAUNCH_STATE=game_spawned|handoff:|LAUNCH_STATE=handoff') {
            if ($line -match 'handoff:|LAUNCH_STATE=handoff') {
                $script:LaunchAutomation.handoffSeen = $true
                if ($script:LaunchAutomation.launchSelectedBy -eq 'unknown' -and -not $script:LaunchAutomation.launchPathAdopted) {
                    $script:LaunchAutomation.launchSelectedBy = 'attach_existing'
                }
            }
            if ($script:LaunchAutomation.continueClickUtc -and -not $script:LaunchAutomation.continueLatencySeconds) {
                $script:LaunchAutomation.continueLatencySeconds = [int][Math]::Max(0, ($lineTime - $script:LaunchAutomation.continueClickUtc).TotalSeconds)
            }
        }
        if ($line -match 'LAUNCH_STATE=fail_foreground_theft|foreground theft') {
            $script:LaunchAutomation.launchError = 'launcher automation impossible: Cursor foreground >60s with no launcher/game hwnd'
        }
        if ($line -match 'LAUNCH_STATE=([^;\s]+)') {
            $script:LaunchAutomation.launchState = $Matches[1]
        }
        if ($line -match 'foreground="[^"]*Cursor[^"]*"' -and $line -match 'launcher=no game=no') {
            $script:LaunchAutomation.cursorForegroundNoHwnd = $true
        }
    }

    return [pscustomobject]$signals
}

function Get-F7GateSignals {
    $det = Get-F7ProcessDetection
    $result = [ordered]@{
        campaignReady = $false
        canPollFileInbox = $false
        mapReadyStatus = $null
        phase1TbgReady = $false
        phase1QuickStartMapReady = $false
        phase1LastSignal = $null
        gameRunning = [bool]$det.gameProcessRunning
        gameAliveConfidence = [string]$det.gameAliveConfidence
        gameProcessDetectionMethod = [string]$det.gameProcessDetectionMethod
        processDetection = $det
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

function Get-GoldenPathCheck {
    param([datetime]$SinceLocal)

    if (-not (Test-Path -LiteralPath $compareGoldenPath)) {
        return [ordered]@{
            available = $false
            reason = 'compare-phase1-golden-path.ps1 not present'
        }
    }

    try {
        $gp = & $compareGoldenPath -Phase1Path $phase1Path -SinceLocal $SinceLocal
        return [ordered]@{
            available = $true
            firstMissingStep = $gp.firstMissingStep
            mapReadySeen = [bool]$gp.mapReadySeen
            tbgReadySeen = [bool]$gp.tbgReadySeen
            hotkeyTraceAtMapReady = [bool]$gp.hotkeyTraceAtMapReady
            steps = $gp.steps
        }
    } catch {
        return [ordered]@{
            available = $false
            reason = $_.Exception.Message
        }
    }
}

function Test-F7GateCondition {
    param($Signals)
    $mapReadyPass = ($Signals.mapReadyStatus -eq 'PASS') -or $Signals.phase1TbgReady
    return ($Signals.campaignReady -and $Signals.canPollFileInbox -and $mapReadyPass)
}

function Resolve-F7LaunchPath {
    param([datetime]$SinceLocal)

    $null = Get-LaunchAutomationSignals -SinceLocal $SinceLocal

    if ($script:LaunchAutomation.launchPath -ne 'unknown') {
        if ($CertTarget -eq 'continue' -and $script:LaunchAutomation.launchPath -eq 'play') {
            $script:LaunchAutomation.targetMismatch = $true
        }
        return
    }

    if ($script:LaunchAutomation.handoffSeen -and $script:LaunchAutomation.launchSelectedBy -eq 'attach_existing') {
        $script:LaunchAutomation.launchPath = if ($CertTarget -eq 'play') { 'play' } else { 'continue' }
        return
    }

    if ($script:LaunchAutomation.continueClick.success) {
        $script:LaunchAutomation.launchPath = 'continue'
    } elseif ($script:LaunchAutomation.playClick.success) {
        $script:LaunchAutomation.launchPath = 'play'
        if ($CertTarget -eq 'continue') {
            $script:LaunchAutomation.targetMismatch = $true
        }
    }
}

function Test-F7CertTargetMismatch {
    if ($CertTarget -eq 'any') { return $false }
    if ($script:LaunchAutomation.launchPath -eq 'unknown') { return $false }
    return ($CertTarget -ne $script:LaunchAutomation.launchPath)
}

function Get-F7GamePhaseAtEnd {
    param($Signals, [datetime]$SinceLocal)

    if ($Signals.phase1TbgReady) { return 'TBG READY' }
    if ($Signals.phase1QuickStartMapReady) { return 'QuickStart MapReady' }
    if (Test-Phase1MapTransition -SinceLocal $SinceLocal) { return 'MapTransition' }
    if ($Signals.gameRunning) { return 'loading' }
    if ($Signals.phase1LastSignal) { return [string]$Signals.phase1LastSignal }
    return 'unknown'
}

function Update-F7ProcessTimestamps {
    $running = [bool](Get-F7ProcessDetection).gameProcessRunning
    $nowUtc = (Get-Date).ToUniversalTime().ToString('o')
    if ($running -and -not $script:F7ProcessTimestamps.gameStartUtc) {
        $script:F7ProcessTimestamps.gameStartUtc = $nowUtc
    }
    if (-not $running -and $script:F7ProcessTimestamps.gameStartUtc -and -not $script:F7ProcessTimestamps.gameEndUtc) {
        $script:F7ProcessTimestamps.gameEndUtc = $nowUtc
    }
}

function Write-FilteredTimestampTail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceLocal,
        [int]$MaxLines = 220
    )

    try {
        $raw = Get-Content -LiteralPath $InputPath -Tail 4000 -ErrorAction Stop
    } catch {
        return
    }

    $filtered = New-Object System.Collections.Generic.List[string]
    foreach ($line in $raw) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { continue }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }
        $filtered.Add($line)
    }

    if ($filtered.Count -gt $MaxLines) {
        $filtered = $filtered.GetRange($filtered.Count - $MaxLines, $MaxLines)
    }

    $filtered | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

function Get-F7LauncherAuditFields {
    param([datetime]$SinceLocal)

    $null = Get-LaunchAutomationSignals -SinceLocal $SinceLocal

    $launcherWarnings = New-Object System.Collections.Generic.List[string]
    if ($script:LaunchAutomation.launchError) {
        $launcherWarnings.Add([string]$script:LaunchAutomation.launchError) | Out-Null
    }
    if (($script:LaunchAutomation.continueEscalated -or $script:LaunchAutomation.launchState -match 'continue_escalate') `
            -and $script:LaunchAutomation.launchPath -eq 'continue' -and -not $script:LaunchAutomation.targetMismatch) {
        $launcherWarnings.Add('continue_escalate: hwnd-only Continue did not spawn game within 15s; foreground retry used (not cert failure cause)') | Out-Null
    }

    return [ordered]@{
        continueEscalated = [bool]($script:LaunchAutomation.continueEscalated -or ($script:LaunchAutomation.launchState -match 'continue_escalate'))
        continueClickMethod = [string]$script:LaunchAutomation.continueClick.method
        continueLatencySeconds = if ($null -ne $script:LaunchAutomation.continueLatencySeconds) { [int]$script:LaunchAutomation.continueLatencySeconds } else { $null }
        launcherTimeoutStage = [string]$script:LaunchAutomation.launchState
        launcherWarnings = @($launcherWarnings)
    }
}

function Save-CheckpointEvidence {
    param(
        [string]$PassFail,
        [int]$ExitCode,
        [int]$StableSec,
        $LastSignals,
        [string]$Notes,
        $LaunchSignals = $null,
        [datetime]$SinceLocal
    )

    New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null

    Resolve-F7LaunchPath -SinceLocal $SinceLocal
    if (Test-F7CertTargetMismatch) {
        $script:LaunchAutomation.targetMismatch = $true
        if ($PassFail -eq 'PASS') {
            $PassFail = 'FAIL'
            $ExitCode = 2
            $StableSec = 0
            $Notes = "target_mismatch: certTarget=$CertTarget launchPath=$($script:LaunchAutomation.launchPath) launchSelectedBy=$($script:LaunchAutomation.launchSelectedBy); $Notes"
        }
    }

    $gamePhaseAtEnd = Get-F7GamePhaseAtEnd -Signals $LastSignals -SinceLocal $SinceLocal
    $harvestFields = [ordered]@{}
    try {
        $startedDt = [datetime]::Parse($startedAtUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind)
        $harvestResult = Invoke-F7EvidenceHarvest `
            -CheckpointDir $checkpointDir `
            -BannerlordRoot $bannerlordRoot `
            -SinceLocal $SinceLocal `
            -StartedAtUtc $startedDt `
            -PassFail $PassFail `
            -Phase1Path $phase1Path `
            -LaunchLogPath $launchLogPath `
            -RunnerCommandLine $runnerCommandLine `
            -HookMask $(if ($resolvedHookMask) { $resolvedHookMask } else { 'default' }) `
            -ProcessTimestamps $script:F7ProcessTimestamps `
            -GamePhaseAtEnd $gamePhaseAtEnd
        foreach ($key in $harvestResult.Keys) {
            $harvestFields[$key] = $harvestResult[$key]
        }
    } catch {
        $harvestFields.harvestError = [string]$_.Exception.Message
        $harvestFields.harvestPartial = $false
        $harvestFields.harvestWarnings = @()
        $harvestFields.windowsCrashEventStatus = 'not_available'
        $harvestFields.windowsCrashEventCopied = $false
        $harvestFields.statusJsonCopied = $false
        $harvestFields.crashContextCopied = $false
        $harvestFields.missingArtifacts = @('harvest_enrichment_failed')
        $harvestFields.copiedArtifactCount = 0
        $harvestFields.artifactMeta = @()
        try {
            $tailPath = Join-Path $checkpointDir 'Phase1.tail.txt'
            if (Test-Path -LiteralPath $tailPath) {
                $m = Get-F7Phase1Markers -TailLines @(Get-Content -LiteralPath $tailPath -ErrorAction SilentlyContinue)
                $harvestFields.lastPhase1Marker = [string]$m.lastPhase1Marker
                $harvestFields.lastTraceMarker = if ($m.lastTraceMarker) { [string]$m.lastTraceMarker } else { $null }
                $harvestFields.lastMapReadyMarker = if ($m.lastMapReadyMarker) { [string]$m.lastMapReadyMarker } else { $null }
                $harvestFields.phase1TailLineCount = [int]@(Get-Content -LiteralPath $tailPath).Count
            }
            $launchTailPath = Join-Path $checkpointDir 'Launch.tail.txt'
            if (Test-Path -LiteralPath $launchTailPath) {
                $harvestFields.launchTailLineCount = [int]@(Get-Content -LiteralPath $launchTailPath).Count
            }
        } catch { }
        $harvestFields.evidenceCompleteness = [ordered]@{
            score = 'harvest_failed'
            harvestError = $true
            harvestFailed = $true
            harvestPartial = $false
        }
    }

    $launcherAudit = Get-F7LauncherAuditFields -SinceLocal $SinceLocal

    $manifest = [ordered]@{
        checkpoint = 'checkpoint-01-f7-gate'
        sessionId = $sessionId
        passFail = $PassFail
        exitCode = $ExitCode
        startedAtUtc = $startedAtUtc
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        stableSeconds = $StableSec
        hookMask = if ($resolvedHookMask) { $resolvedHookMask } else { 'default' }
        mapReadyHookMask = if ($resolvedHookMask) { $resolvedHookMask } else { 'default (All)' }
        launchState = $script:LaunchAutomation.launchState
        safeModeDetected = [bool]$script:LaunchAutomation.safeModeDetected
        safeModeNoClicked = [bool]$script:LaunchAutomation.safeModeNoClicked
        continueClick = $script:LaunchAutomation.continueClick
        playClick = $script:LaunchAutomation.playClick
        launchPath = $script:LaunchAutomation.launchPath
        launchSelectedBy = $script:LaunchAutomation.launchSelectedBy
        certTarget = $CertTarget
        targetMismatch = [bool]$script:LaunchAutomation.targetMismatch
        lastFocusResult = $script:LaunchAutomation.lastFocusResult
        launchAutomationError = $script:LaunchAutomation.launchError
        campaignReady = [bool]$LastSignals.campaignReady
        canPollFileInbox = [bool]$LastSignals.canPollFileInbox
        mapReadyStatus = $LastSignals.mapReadyStatus
        phase1TbgReady = [bool]$LastSignals.phase1TbgReady
        phase1QuickStartMapReady = [bool]$LastSignals.phase1QuickStartMapReady
        phase1LastSignal = $LastSignals.phase1LastSignal
        gameProcessRunning = [bool]$LastSignals.gameRunning
        gameAliveConfidence = if ($LastSignals.gameAliveConfidence) { [string]$LastSignals.gameAliveConfidence } else { $null }
        gameProcessDetectionMethod = if ($LastSignals.gameProcessDetectionMethod) { [string]$LastSignals.gameProcessDetectionMethod } else { $null }
        gameProcessPid = if ($script:LastProcessDetection) { $script:LastProcessDetection.gameProcessPid } else { $null }
        gameProcessName = if ($script:LastProcessDetection) { $script:LastProcessDetection.gameProcessName } else { $null }
        gameProcessPath = if ($script:LastProcessDetection) { $script:LastProcessDetection.gameProcessPath } else { $null }
        launcherProcessPid = if ($script:LastProcessDetection) { $script:LastProcessDetection.launcherProcessPid } else { $null }
        processDetectionWarnings = if ($script:LastProcessDetection) { @($script:LastProcessDetection.processDetectionWarnings) } else { @() }
        processDetectionLastSeenUtc = if ($script:LastProcessDetection) { $script:LastProcessDetection.processDetectionLastSeenUtc } else { $null }
        gameProcessCandidates = if ($script:LastProcessDetection) { @($script:LastProcessDetection.gameProcessCandidates) } else { @() }
        goldenPathCheck = (Get-GoldenPathCheck -SinceLocal $SinceLocal)
        launchSignals = if ($LaunchSignals) {
            [ordered]@{
                safeModeDismissed = [bool]$LaunchSignals.safeModeDismissed
                safeModePromptSeen = [bool]$LaunchSignals.safeModePromptSeen
                priorSessionCrashLikely = [bool]$LaunchSignals.priorSessionCrashLikely
                crashReporterDismissed = [bool]$LaunchSignals.crashReporterDismissed
                safeModePromptText = $LaunchSignals.safeModePromptText
            }
        } else { $null }
        notes = $Notes
        continueEscalated = [bool]$launcherAudit.continueEscalated
        continueClickMethod = $launcherAudit.continueClickMethod
        continueLatencySeconds = $launcherAudit.continueLatencySeconds
        launcherTimeoutStage = $launcherAudit.launcherTimeoutStage
        launcherWarnings = @($launcherAudit.launcherWarnings)
    }
    foreach ($key in $harvestFields.Keys) {
        $manifest[$key] = $harvestFields[$key]
    }
    $manifest | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $checkpointDir 'manifest.json') -Encoding UTF8

    $writtenPath = Join-Path $checkpointDir 'manifest.json'
    if (-not (Test-Path -LiteralPath $writtenPath)) {
        throw "manifest write failed: $writtenPath"
    }
    Confirm-F7GateManifestWritten -CheckpointDir $checkpointDir | Out-Null

    return $checkpointDir
}

function Exit-F7Gate {
    param(
        [int]$Code,
        [string]$CheckpointDir
    )

    if ($Code -eq 0) {
        if (-not $CheckpointDir) {
            Write-Host 'F7 FAIL-CLOSED: exit 0 rejected — no checkpoint directory.' -ForegroundColor Red
            exit 1
        }
        try {
            $manifestPath = Confirm-F7GateManifestWritten -CheckpointDir $CheckpointDir
        } catch {
            Write-Host "F7 FAIL-CLOSED: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
        if (-not (Test-F7GateManifestPass -ManifestPath $manifestPath -RequiredStableSeconds $StableSeconds)) {
            Write-Host "F7 FAIL-CLOSED: exit 0 rejected — manifest not PASS (stable >= ${StableSeconds}s required)." -ForegroundColor Red
            exit 1
        }
    } elseif ($CheckpointDir) {
        try {
            Confirm-F7GateManifestWritten -CheckpointDir $CheckpointDir | Out-Null
        } catch {
            Write-Host "F7 WARN: manifest missing for exit $Code — $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    exit $Code
}

function Invoke-F7NoClickLaunch {
    param(
        [int]$TimeoutSec,
        [datetime]$SinceLocal
    )

    Write-F7LaunchState 'polling'
    & (Join-Path $PSScriptRoot 'write-launch-intent.ps1') -LaunchIntent continue -BannerlordRoot $bannerlordRoot
    & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $bannerlordRoot
    Write-F7LaunchState 'launcher_spawned'

    $navScript = Join-Path $PSScriptRoot 'launcher-auto-nav.ps1'
    $navParams = @{
        LaunchIntent           = 'continue'
        BannerlordRoot         = $bannerlordRoot
        TimeoutSec             = $TimeoutSec
        PollMs                 = 180
        RespectUserForeground = $true
    }

    Write-Host 'Starting launcher-auto-nav inline (avoids & path / subprocess UIA issues)...' -ForegroundColor DarkGray
    $navExitCode = 0
    try {
        & $navScript @navParams
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { $navExitCode = $LASTEXITCODE }
    } catch {
        $navExitCode = 1
        if (-not $script:LaunchAutomation.launchError) {
            $script:LaunchAutomation.launchError = $_.Exception.Message
        }
        Write-Host "launcher-auto-nav error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $null = Get-LaunchAutomationSignals -SinceLocal $SinceLocal
    Resolve-F7LaunchPath -SinceLocal $SinceLocal

    if (Test-GameProcessRunning) {
        Write-F7LaunchState 'game_spawned'
        return $true
    }

    if ($script:LaunchAutomation.handoffSeen) {
        Write-F7LaunchState 'handoff'
        return $true
    }

    $skipNavRetry = $script:LaunchAutomation.launchPathAdopted `
        -or $script:LaunchAutomation.launchSelectedBy -eq 'user' `
        -or $script:LaunchAutomation.launchPath -eq 'play'

    if (-not $skipNavRetry -and -not $script:LaunchAutomation.continueClick.success -and (Test-LauncherProcessRunning)) {
        Write-Host 'Launcher still running without Continue — retrying launcher-auto-nav once...' -ForegroundColor Yellow
        try {
            & $navScript @navParams
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { $navExitCode = $LASTEXITCODE }
        } catch {
            $navExitCode = 1
            if (-not $script:LaunchAutomation.launchError) {
                $script:LaunchAutomation.launchError = $_.Exception.Message
            }
        }
        $null = Get-LaunchAutomationSignals -SinceLocal $SinceLocal
    }

    if (Test-GameProcessRunning -or $script:LaunchAutomation.handoffSeen) {
        if (Test-GameProcessRunning) { Write-F7LaunchState 'game_spawned' }
        return $true
    }

    if (-not $script:LaunchAutomation.launchError) {
        $script:LaunchAutomation.launchError = "launcher-auto-nav exit code $navExitCode"
    }

    if ($script:LaunchAutomation.continueClick.success -and `
            (Test-GameProcessRunning -or Test-Phase1SessionActive -SinceUtc $SinceLocal.ToUniversalTime())) {
        if (Test-GameProcessRunning) { Write-F7LaunchState 'game_spawned' }
        return $true
    }

    return $false
}

function Test-LaunchToolingFailure {
    param(
        [datetime]$SinceLocal,
        [bool]$LaunchNavSucceeded,
        [double]$ElapsedSinceLaunchEnd
    )

    $null = Get-LaunchAutomationSignals -SinceLocal $SinceLocal

    if ($script:LaunchAutomation.launchError -match 'fail_foreground_theft') {
        # Legacy log state from older runs — no longer a hard failure under RespectUserForeground policy.
        $script:LaunchAutomation.launchError = $null
    }

    if (-not $LaunchNavSucceeded) {
        $hasValidLaunch = $script:LaunchAutomation.continueClick.success `
            -or $script:LaunchAutomation.playClick.success `
            -or $script:LaunchAutomation.handoffSeen `
            -or $script:LaunchAutomation.launchPathAdopted `
            -or $script:LaunchAutomation.launchSelectedBy -eq 'user'
        if (-not $hasValidLaunch) {
            if (-not (Test-LauncherProcessRunning) -and -not (Test-GameProcessRunning)) {
                return 'launcher-auto-nav failed: Continue not clicked and no game/launcher process'
            }
        }
    }

    if ($ElapsedSinceLaunchEnd -ge $PostLaunchHwndWaitSec) {
        if (-not (Test-GameProcessRunning) -and -not (Test-LauncherProcessRunning)) {
            $hasValidLaunch = $script:LaunchAutomation.handoffSeen `
                -or $script:LaunchAutomation.continueClick.success `
                -or $script:LaunchAutomation.playClick.success `
                -or $script:LaunchAutomation.launchPathAdopted
            if (-not $hasValidLaunch) {
                return "no game or launcher hwnd after ${PostLaunchHwndWaitSec}s post-launch"
            }
        }
    }

    return $null
}

function Test-LaunchStillStarting {
    param(
        [bool]$GameRunning,
        [bool]$GameWasSeen,
        [double]$ElapsedSec,
        [datetime]$LaunchStartedLocal
    )
    if ($GameRunning) { return $false }
    if ($GameWasSeen) { return $false }

    $det = Get-F7ProcessDetection
    if (Test-F7GameAliveUncertain -Detection $det) { return $true }

    if (Test-Phase1SessionActive -SinceUtc $LaunchStartedLocal.ToUniversalTime()) { return $true }
    if ($det.phase1LogFresh) { return $true }
    if ($ElapsedSec -lt 90 -and (Test-LauncherProcessRunning)) { return $true }
    if ($ElapsedSec -lt 120 -and (Test-LauncherProcessRunning) -and -not $GameWasSeen) { return $true }
    if ($ElapsedSec -lt 45) { return $true }
    return $false
}

function Write-F7PollHeartbeat {
    param(
        [double]$ElapsedSec,
        $Signals,
        [bool]$EverMapReady,
        [string]$LaunchState
    )
    $gameTag = if ($Signals.gameRunning) {
        switch ([string]$Signals.gameAliveConfidence) {
            'definite' { 'running' }
            'launcher_hosted' { 'running(hosted)' }
            'phase1_active' { 'running(phase1)' }
            'process_detection_uncertain' { 'running(uncertain)' }
            default { 'running' }
        }
    } elseif ($EverMapReady) { 'gone-after-map-ready' }
    else { 'gone' }
    $state = "game=$gameTag"
    $phase = if ($Signals.phase1TbgReady) { 'TBG READY' }
        elseif ($Signals.phase1QuickStartMapReady) { 'QuickStart MapReady' }
        elseif (Test-Phase1MapTransition -SinceLocal $launchStartedLocal) { 'MapTransition' }
        else { 'loading' }
    $last = $Signals.phase1LastSignal
    if ($last -and $last.Length -gt 80) { $last = $last.Substring($last.Length - 80) }
    Write-Host ("  [{0:N0}s] LAUNCH_STATE={1} {2} phase1={3} focus={4} last={5}" -f `
        $ElapsedSec, $LaunchState, $state, $phase, $script:LaunchAutomation.lastFocusResult, $last) -ForegroundColor DarkGray
}

$launchStartedLocal = $null

try {
    Write-Host ''
    Write-Host '=== F7 Continue Gate (no-click) ===' -ForegroundColor Cyan
    Write-Host "Session: $sessionId"
    Write-Host "Bannerlord root: $bannerlordRoot"
    if ($resolvedHookMask) { Write-Host "HookMask: $resolvedHookMask" }
    Write-Host ''

    Stop-BannerlordProcesses

    Write-Host 'Building Release...' -ForegroundColor Cyan
    dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
    if ($LASTEXITCODE -ne 0) {
        $signals = Get-F7GateSignals
        $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 1 -StableSec 0 -LastSignals $signals `
            -Notes 'build failed' -SinceLocal (Get-Date)
        Write-Host "Build failed. Evidence: $dir" -ForegroundColor Red
        Exit-F7Gate -Code 1 -CheckpointDir $dir
    }

    $launchStarted = Get-Date
    $launchStartedLocal = $launchStarted

    Write-Host "Launching Continue (synchronous no-click, timeout ${LaunchTimeoutSec}s)..." -ForegroundColor Cyan
    $launchOk = Invoke-F7NoClickLaunch -TimeoutSec $LaunchTimeoutSec -SinceLocal $launchStartedLocal
    $null = Get-LaunchAutomationSignals -SinceLocal $launchStartedLocal

    $launchEnd = Get-Date
    $postLaunchSec = 0.0

    if (-not $launchOk) {
        $toolingFail = Test-LaunchToolingFailure -SinceLocal $launchStartedLocal -LaunchNavSucceeded $false -ElapsedSinceLaunchEnd 0
        if ($toolingFail) {
            Write-F7LaunchState 'fail_launch_automation'
            $signals = Get-F7GateSignals
            $launchSignals = Get-LaunchAutomationSignals -SinceLocal $launchStartedLocal
            $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 1 -StableSec 0 -LastSignals $signals `
                -Notes "LAUNCH FAIL: $toolingFail" -LaunchSignals $launchSignals -SinceLocal $launchStartedLocal
            Write-Host "Launch automation FAIL (exit 1): $toolingFail. Evidence: $dir" -ForegroundColor Red
            Exit-F7Gate -Code 1 -CheckpointDir $dir
        }
        Write-Host 'WARN: launcher-auto-nav returned error but handoff/continue may have occurred — continuing F7 poll' -ForegroundColor Yellow
    }

    if ($script:LaunchAutomation.handoffSeen -or (Test-GameProcessRunning)) {
        Write-F7LaunchState 'game_spawned'
    }

    $deadline = (Get-Date).AddSeconds($PollTimeoutSec)
    $stableSince = $null
    $lastSignals = $null
    $everMapReady = $false
    $gameEverSeen = $false
    $lastHeartbeatSec = -1

    Write-Host "Polling up to ${PollTimeoutSec}s (stable ${StableSeconds}s required, passive - no refocus)..." -ForegroundColor Cyan

    while ((Get-Date) -lt $deadline) {
        $lastSignals = Get-F7GateSignals
        Update-F7ProcessTimestamps
        $lastSignals.phase1QuickStartMapReady = Test-Phase1QuickStartMapReady -SinceLocal $launchStartedLocal
        if ($lastSignals.gameRunning) { $gameEverSeen = $true }

        if ($lastSignals.phase1TbgReady -or $lastSignals.mapReadyStatus -eq 'PASS' -or $lastSignals.phase1QuickStartMapReady) {
            $everMapReady = $true
            if ($lastSignals.phase1QuickStartMapReady) { Write-F7LaunchState 'map_ready' }
            if ($lastSignals.phase1TbgReady) { Write-F7LaunchState 'tbg_ready' }
        }

        $elapsedSec = ((Get-Date) - $launchStarted).TotalSeconds
        $postLaunchSec = ((Get-Date) - $launchEnd).TotalSeconds
        $heartbeatSec = [int][Math]::Floor($elapsedSec / 30)
        if ($heartbeatSec -ne $lastHeartbeatSec) {
            Write-F7PollHeartbeat -ElapsedSec $elapsedSec -Signals $lastSignals -EverMapReady $everMapReady `
                -LaunchState $script:LaunchAutomation.launchState
            $lastHeartbeatSec = $heartbeatSec
        }

        if (-not $lastSignals.gameRunning -and -not (Test-LaunchStillStarting -GameRunning $lastSignals.gameRunning `
                -GameWasSeen $gameEverSeen -ElapsedSec $elapsedSec -LaunchStartedLocal $launchStarted)) {
            $det = Get-F7ProcessDetection
            if (Test-F7GameAliveUncertain -Detection $det) {
                Write-F7LaunchState 'fail_process_detection_uncertain'
            } elseif ($everMapReady) {
                Write-F7LaunchState 'fail_game_gone_after_map_ready'
            }
            $launchSignals = Get-LaunchAutomationSignals -SinceLocal $launchStartedLocal
            $notes = Get-F7GameGoneFailNotes -Detection $det -EverMapReady $everMapReady `
                -PriorSessionCrashLikely $launchSignals.priorSessionCrashLikely
            $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 2 -StableSec 0 -LastSignals $lastSignals `
                -Notes $notes -LaunchSignals $launchSignals -SinceLocal $launchStartedLocal
            Write-Host "$notes. Evidence: $dir" -ForegroundColor Red
            Exit-F7Gate -Code 2 -CheckpointDir $dir
        }

        if (Test-F7GateCondition -Signals $lastSignals) {
            if (-not $stableSince) {
                $stableSince = Get-Date
                Write-F7LaunchState 'stable'
                Write-Host 'F7 gate conditions met — counting stable seconds...' -ForegroundColor Green
            } elseif (((Get-Date) - $stableSince).TotalSeconds -ge $StableSeconds) {
                $stableSec = [int][Math]::Floor(((Get-Date) - $stableSince).TotalSeconds)
                $launchSignals = Get-LaunchAutomationSignals -SinceLocal $launchStartedLocal
                Resolve-F7LaunchPath -SinceLocal $launchStartedLocal
                $passNotes = "F7 gate stable for >=${StableSeconds}s"
                $passFail = 'PASS'
                $exitCode = 0
                if (Test-F7CertTargetMismatch) {
                    $passFail = 'FAIL'
                    $exitCode = 2
                    $stableSec = 0
                    $passNotes = "target_mismatch: user_selected_play (certTarget=$CertTarget launchPath=$($script:LaunchAutomation.launchPath))"
                }
                $dir = Save-CheckpointEvidence -PassFail $passFail -ExitCode $exitCode -StableSec $stableSec -LastSignals $lastSignals `
                    -Notes $passNotes -LaunchSignals $launchSignals -SinceLocal $launchStartedLocal
                if ($passFail -eq 'PASS') {
                    Write-Host "F7 gate PASS ($stableSec s stable). Evidence: $dir" -ForegroundColor Green
                } else {
                    Write-Host "$passNotes. Evidence: $dir" -ForegroundColor Red
                }
                Exit-F7Gate -Code $exitCode -CheckpointDir $dir
            }
        } else {
            $stableSince = $null
        }

        Start-Sleep -Seconds 1
    }

    $lastSignals = Get-F7GateSignals
    $lastSignals.phase1QuickStartMapReady = Test-Phase1QuickStartMapReady -SinceLocal $launchStartedLocal
    $launchSignals = Get-LaunchAutomationSignals -SinceLocal $launchStartedLocal
    $det = Get-F7ProcessDetection
    $notes = Get-F7TimeoutFailNotes -LastSignals $lastSignals -Detection $det -EverMapReady $everMapReady `
        -LaunchSignals $launchSignals
    $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 2 -StableSec 0 -LastSignals $lastSignals `
        -Notes $notes -LaunchSignals $launchSignals -SinceLocal $launchStartedLocal
    Write-Host "$notes. Evidence: $dir" -ForegroundColor Red
    Exit-F7Gate -Code 2 -CheckpointDir $dir
}
catch {
    Write-Host "F7 gate tooling exception: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $signals = Get-F7GateSignals
        $sinceLocal = if ($launchStartedLocal) { $launchStartedLocal } else { Get-Date }
        $dir = Save-CheckpointEvidence -PassFail 'FAIL' -ExitCode 1 -StableSec 0 -LastSignals $signals `
            -Notes "F7 tooling exception: $($_.Exception.Message)" -SinceLocal $sinceLocal
        Exit-F7Gate -Code 1 -CheckpointDir $dir
    } catch {
        Write-Host "F7 FAIL-CLOSED: could not write manifest after exception: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
finally {
    if ($hookMaskWasSet) {
        Remove-Item -Path 'Env:TBG_MAP_READY_HOOK_MASK' -ErrorAction SilentlyContinue
    }
}
