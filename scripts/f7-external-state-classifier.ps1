# External state classifier — cert + assistive attach foundation.
# Dot-sourced from run-f7-gate-continue.ps1, launcher-auto-nav.ps1, offline regressions.

$script:F7ExternalStateTimeline = $null
$script:F7ExternalStateTimelineEvents = New-Object System.Collections.Generic.List[object]
$script:F7ExternalStateLastClassifiedState = $null
$script:F7ExternalStateLastPollEmitUtc = [datetime]::MinValue

function Initialize-F7ExternalStateTimeline {
    param(
        [ValidateSet('cert', 'assistive', 'assistive_launch_setup')]
        [string]$Mode = 'cert',
        [string]$OutputPath,
        [string]$SessionId = $null,
        [string]$StartedAtUtc = $null
    )

    $script:F7ExternalStateTimelineEvents = New-Object System.Collections.Generic.List[object]
    $script:F7ExternalStateLastClassifiedState = $null
    $script:F7ExternalStateLastPollEmitUtc = [datetime]::MinValue

    $script:F7ExternalStateTimeline = [ordered]@{
        schemaVersion = 1
        mode          = [string]$Mode
        sessionId     = if ($SessionId) { [string]$SessionId } else { $null }
        startedAtUtc  = if ($StartedAtUtc) { [string]$StartedAtUtc } else { (Get-Date).ToUniversalTime().ToString('o') }
        outputPath    = if ($OutputPath) { [string]$OutputPath } else { $null }
        events        = @()
    }
}

function Get-F7ForegroundWindowInfo {
    $info = [ordered]@{
        hwnd = $null
        title = $null
        processName = $null
        processId = $null
        bounds = $null
    }

    try {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class F7ForegroundHelper {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@ -ErrorAction SilentlyContinue
        $hwnd = [F7ForegroundHelper]::GetForegroundWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            $info.hwnd = [int64]$hwnd
            $sb = New-Object System.Text.StringBuilder 512
            [void][F7ForegroundHelper]::GetWindowText($hwnd, $sb, 512)
            $info.title = [string]$sb.ToString()
            $pidOut = [uint32]0
            [void][F7ForegroundHelper]::GetWindowThreadProcessId($hwnd, [ref]$pidOut)
            if ($pidOut -gt 0) {
                $info.processId = [int]$pidOut
                $proc = Get-Process -Id $info.processId -ErrorAction SilentlyContinue
                if ($proc) { $info.processName = [string]$proc.ProcessName }
            }
        }
    } catch { }

    return [pscustomobject]$info
}

function Read-F7StatusJsonSafe {
    param([string]$StatusPath)

    if (-not $StatusPath -or -not (Test-Path -LiteralPath $StatusPath)) { return $null }
    try {
        return Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Resolve-F7ProcessClassifiedState {
    param(
        $Detection,
        [bool]$PreflightClean = $false,
        [bool]$Contaminated = $false,
        [string]$ContaminationReason = $null
    )

    if ($Contaminated) {
        if ($ContaminationReason -match 'pre_intent|game_running_before') {
            return 'ContaminatedPreIntentSpawn'
        }
        return 'ContaminatedWrongTarget'
    }

    if ($PreflightClean) { return 'ProcessClean' }
    if (-not $Detection) { return 'UnknownWindowState' }

    if (('UIAHelper' -as [type]) -and [UIAHelper]::HasSafeModeDialog()) {
        return 'SafeModeDialog'
    }

    if (-not $Detection.gameProcessRunning) {
        $launcher = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) {
            $title = [string]$launcher.MainWindowTitle
            if (('UIAHelper' -as [type]) -and [UIAHelper]::IsLauncherContinueVisible()) {
                return 'LauncherMenuContinueAvailable'
            }
            if (('UIAHelper' -as [type]) -and [UIAHelper]::IsLauncherPlayOnlyVisible()) {
                return 'LauncherMenuPlayOnly'
            }
            if ((Get-Command Test-LauncherMenuWindowTitle -ErrorAction SilentlyContinue) `
                    -and (Test-LauncherMenuWindowTitle -Title $title)) {
                return 'LauncherMenu'
            }
            return 'LauncherOpening'
        }
        return 'GameGone'
    }

    $method = [string]$Detection.gameProcessDetectionMethod
    if ($method -in @('process_name_bannerlord', 'process_name_taleworlds', 'executable_path', 'launcher_child_executable')) {
        return 'StandaloneGameProcess'
    }
    if ($method -eq 'launcher_hosted_window') {
        return 'HostedSingleplayerWindow'
    }
    if ($method -in @('phase1_log_fresh', 'status_json_fresh')) {
        return 'HostedSingleplayerWindow'
    }

    return 'UnknownWindowState'
}

function Resolve-F7GameSurfaceClassifiedState {
    param(
        $StatusJson,
        [string]$StatusArtifactState = 'missing'
    )

    if ($StatusArtifactState -ne 'fresh' -or -not $StatusJson) {
        return [pscustomobject]@{
            state = 'UnknownGameSurface'
            confidence = 'unknown'
            runtimeEvidenceStates = @()
            reason = "Status.json $StatusArtifactState; do not guess in-game surface"
        }
    }

    $surface = [string]$StatusJson.readinessSurface
    if (-not $surface -and $StatusJson.session) {
        $surface = [string]$StatusJson.session.readinessSurface
    }
    $runtime = New-Object System.Collections.Generic.List[string]
    if ($StatusJson.campaignReady -eq $true) { $runtime.Add('CampaignReady') | Out-Null }
    if ($StatusJson.session -and $StatusJson.session.canPollFileInbox -eq $true) {
        $runtime.Add('CanPollFileInbox') | Out-Null
    }
    if ($StatusJson.session -and $StatusJson.session.sessionReady -eq $true) {
        $runtime.Add('SessionReady') | Out-Null
    }

    $state = 'UnknownGameSurface'
    $confidence = 'medium'

    switch ($surface) {
        'loading' { $state = 'GameLoading' }
        'main_menu' { $state = 'MainMenu' }
        'settlement_menu' {
            $menuOpen = ($StatusJson.settlementMenuOpen -eq $true)
            if (-not $menuOpen -and $StatusJson.session) {
                $menuOpen = ($StatusJson.session.settlementMenuOpen -eq $true)
            }
            if ($menuOpen) {
                $state = 'SettlementTownMenu'
                $runtime.Add('ReadinessSurfaceSettlementMenu') | Out-Null
            }
        }
        'settlement_interior' {
            $state = 'SettlementInterior'
            $runtime.Add('ReadinessSurfaceSettlementInterior') | Out-Null
        }
        'map_surface' {
            $mapOpen = ($StatusJson.campaignMapSurfaceOpen -eq $true)
            if (-not $mapOpen -and $StatusJson.session) {
                $mapOpen = ($StatusJson.session.campaignMapSurfaceOpen -eq $true)
            }
            if ($mapOpen) {
                $state = 'CampaignMapSurface'
                $runtime.Add('ReadinessSurfaceMapSurface') | Out-Null
            }
        }
        default { $confidence = 'low' }
    }

    return [pscustomobject]@{
        state = $state
        confidence = $confidence
        runtimeEvidenceStates = @($runtime)
        reason = "readinessSurface=$surface from fresh Status.json"
    }
}

function Get-F7StatusSurfaceSignals {
    param(
        [string]$StatusPath,
        $CertStartedUtc = $null
    )

    $result = [ordered]@{
        readinessSurface = $null
        settlementMenuOpen = $false
        campaignMapSurfaceOpen = $false
        campaignReady = $false
        canPollFileInbox = $false
        inGameAssistReady = $false
        canAcceptAssistiveCommand = $false
        statusArtifactState = 'missing'
    }

    if (-not $StatusPath -or -not (Test-Path -LiteralPath $StatusPath)) {
        return [pscustomobject]$result
    }

    if ($CertStartedUtc -and (Get-Command Get-F7ArtifactFreshnessState -ErrorAction SilentlyContinue)) {
        $result.statusArtifactState = [string](Get-F7ArtifactFreshnessState -Path $StatusPath -CertStartedUtc $CertStartedUtc)
    } else {
        $result.statusArtifactState = 'unknown'
    }

    if ($CertStartedUtc -and $result.statusArtifactState -ne 'fresh') {
        return [pscustomobject]$result
    }

    $st = Read-F7StatusJsonSafe -StatusPath $StatusPath
    if (-not $st) { return [pscustomobject]$result }

    $result.readinessSurface = if ($st.readinessSurface) { [string]$st.readinessSurface }
                              elseif ($st.session -and $st.session.readinessSurface) { [string]$st.session.readinessSurface }
                              else { $null }
    $result.settlementMenuOpen = ($st.settlementMenuOpen -eq $true)
    if (-not $result.settlementMenuOpen -and $st.session) {
        $result.settlementMenuOpen = ($st.session.settlementMenuOpen -eq $true)
    }
    $result.campaignMapSurfaceOpen = ($st.campaignMapSurfaceOpen -eq $true)
    if (-not $result.campaignMapSurfaceOpen -and $st.session) {
        $result.campaignMapSurfaceOpen = ($st.session.campaignMapSurfaceOpen -eq $true)
    }
    $result.campaignReady = ($st.campaignReady -eq $true)
    if ($st.session) {
        $result.canPollFileInbox = ($st.session.canPollFileInbox -eq $true)
        if ($st.session.PSObject.Properties.Name -contains 'inGameAssistReady') {
            $result.inGameAssistReady = ($st.session.inGameAssistReady -eq $true)
        }
        if ($st.session.PSObject.Properties.Name -contains 'canAcceptAssistiveCommand') {
            $result.canAcceptAssistiveCommand = ($st.session.canAcceptAssistiveCommand -eq $true)
        }
    }
    return [pscustomobject]$result
}

function Get-F7AssistiveReadinessFromStatus {
    param([string]$StatusPath)

    $surface = Get-F7StatusSurfaceSignals -StatusPath $StatusPath -CertStartedUtc $null
    $result = [ordered]@{
        readinessSurface = $surface.readinessSurface
        settlementMenuOpen = [bool]$surface.settlementMenuOpen
        campaignMapSurfaceOpen = [bool]$surface.campaignMapSurfaceOpen
        campaignReady = [bool]$surface.campaignReady
        canPollFileInbox = [bool]$surface.canPollFileInbox
        inGameAssistReady = [bool]$surface.inGameAssistReady
        canAcceptAssistiveCommand = [bool]$surface.canAcceptAssistiveCommand
        townMenuReady = $false
        openMapReady = $false
        updatedAtUtc = $null
        statusPath = $StatusPath
        parseOk = $false
    }

    if (-not $StatusPath -or -not (Test-Path -LiteralPath $StatusPath)) {
        return [pscustomobject]$result
    }

    $st = Read-F7StatusJsonSafe -StatusPath $StatusPath
    if (-not $st) { return [pscustomobject]$result }

    $result.parseOk = $true
    if ($st.updatedAt) {
        try {
            $result.updatedAtUtc = [datetime]::Parse([string]$st.updatedAt, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
        } catch { }
    }
    if ($st.session) {
        if ($st.session.PSObject.Properties.Name -contains 'townMenuReady') {
            $result.townMenuReady = ($st.session.townMenuReady -eq $true)
        }
        if ($st.session.PSObject.Properties.Name -contains 'openMapReady') {
            $result.openMapReady = ($st.session.openMapReady -eq $true)
        }
    }
    return [pscustomobject]$result
}

function Test-F7AssistiveSurfaceAllowed {
    param([string]$ReadinessSurface)

    return [string]$ReadinessSurface -in @('settlement_menu', 'map_surface', 'settlement_interior')
}

function Test-F7AssistiveStatusFreshForAttach {
    param(
        [string]$StatusPath,
        [int]$MaxAgeSec = 300
    )

    $ready = Get-F7AssistiveReadinessFromStatus -StatusPath $StatusPath
    if (-not $ready.parseOk) { return $false }
    if ($ready.canPollFileInbox -and $ready.inGameAssistReady) { return $true }
    if ($ready.updatedAtUtc) {
        $ageSec = ((Get-Date).ToUniversalTime() - $ready.updatedAtUtc).TotalSeconds
        if ($ageSec -ge 0 -and $ageSec -le $MaxAgeSec) { return $true }
    }
    return $false
}

function Test-F7AssistiveSessionAttachable {
    param(
        [string]$BannerlordRoot,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [string]$CrashContextPath = $null,
        [int]$StatusFreshSec = 300
    )

    if (-not $StatusPath) {
        $StatusPath = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
    }
    if (-not $Phase1Path) {
        $Phase1Path = Get-Phase1LogPath -BannerlordRoot $BannerlordRoot
    }
    if (-not $CrashContextPath) {
        $CrashContextPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot
    }

    $det = Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot `
        -Phase1Path $Phase1Path -StatusPath $StatusPath -CrashContextPath $CrashContextPath

    $result = [ordered]@{
        attachable = $false
        reason = $null
        detection = $det
        readiness = $null
        routeAgent = 'Agent C - External State Classifier / F7 Runner'
    }

    if (-not $det.gameProcessRunning) {
        $result.reason = 'no_game_process'
        return [pscustomobject]$result
    }

    if (-not (Test-F7AssistiveStatusFreshForAttach -StatusPath $StatusPath -MaxAgeSec $StatusFreshSec)) {
        $result.reason = 'stale_status'
        $result.routeAgent = 'Human or Agent C investigation'
        return [pscustomobject]$result
    }

    $ready = Get-F7AssistiveReadinessFromStatus -StatusPath $StatusPath
    $result.readiness = $ready

    if (-not (Test-F7AssistiveSurfaceAllowed -ReadinessSurface $ready.readinessSurface)) {
        $result.reason = 'unsupported_surface'
        $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
        return [pscustomobject]$result
    }
    if (-not $ready.canPollFileInbox) {
        $result.reason = 'inbox_not_ready'
        $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
        return [pscustomobject]$result
    }
    if (-not $ready.inGameAssistReady) {
        $result.reason = 'assist_not_ready'
        $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
        return [pscustomobject]$result
    }
    if (-not $ready.canAcceptAssistiveCommand) {
        $result.reason = 'assist_command_blocked'
        $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
        return [pscustomobject]$result
    }

    $result.attachable = $true
    $result.reason = 'attach_ok'
    return [pscustomobject]$result
}

function Test-F7SettlementMenuReadyObserved {
    param(
        $StatusJson = $null,
        [string]$StatusArtifactState = 'missing'
    )

    if ($StatusArtifactState -ne 'fresh' -or -not $StatusJson) { return $false }
    $surface = [string]$StatusJson.readinessSurface
    if (-not $surface -and $StatusJson.session) {
        $surface = [string]$StatusJson.session.readinessSurface
    }
    $menuOpen = ($StatusJson.settlementMenuOpen -eq $true)
    if (-not $menuOpen -and $StatusJson.session) {
        $menuOpen = ($StatusJson.session.settlementMenuOpen -eq $true)
    }
    return ($surface -eq 'settlement_menu' -and $menuOpen)
}

function Test-F7OldGoldenPathSatisfied {
    param(
        $GoldenPathCheck = $null,
        $Signals = $null
    )

    if ($Signals) {
        if ($Signals.mapReadyStatus -eq 'PASS') { return $true }
        if ($Signals.phase1QuickStartMapReady -eq $true) { return $true }
    }
    if ($GoldenPathCheck -and $GoldenPathCheck.available) {
        if ($GoldenPathCheck.mapReadySeen -eq $true) { return $true }
    }
    return $false
}

function Get-F7SettlementMenuSemanticMismatchSec {
    return 15
}

function Get-F7StateActionPolicy {
    param(
        [string]$ClassifiedState,
        [ValidateSet('cert', 'assistive', 'assistive_launch_setup')]
        [string]$Mode = 'cert'
    )

    $observe = @('observe', 'poll_status')
    $forbiddenCert = @('claim_f7_pass', 'mutate_inventory')
    $forbiddenAssist = @('claim_f7_pass', 'mutate_inventory', 'click_launcher_continue', 'click_launcher_play')

    $routeC = 'Agent C - External State Classifier / F7 Runner'
    $routeB = 'Agent B - Runtime / Readiness / Gameplay safety'
    $routeHuman = 'Human or Agent C investigation'

    switch ($ClassifiedState) {
        'ProcessClean' {
            return [pscustomobject]@{
                legalActions = @($observe + 'start_launcher_automation')
                forbiddenActions = $forbiddenCert
                expectedTransitions = @('LauncherOpening', 'LauncherMenu')
                routeAgent = $routeC
            }
        }
        { $_ -in @('LauncherMenu', 'LauncherOpening', 'LauncherMenuContinueAvailable', 'LauncherMenuPlayOnly', 'SafeModeDialog') } {
            $legal = if ($Mode -in @('cert', 'assistive_launch_setup')) {
                @($observe + 'click_launcher_continue', 'click_launcher_play')
            } else {
                @($observe + 'surface_advisory')
            }
            return [pscustomobject]@{
                legalActions = $legal
                forbiddenActions = @('claim_f7_pass', 'mutate_inventory')
                expectedTransitions = @('HostedSingleplayerWindow', 'StandaloneGameProcess', 'SafeModeDialog')
                routeAgent = $routeC
            }
        }
        { $_ -in @('HostedSingleplayerWindow', 'StandaloneGameProcess', 'GameLoading', 'MainMenu',
                   'CampaignMapSurface', 'SettlementTownMenu', 'SettlementInterior') } {
            return [pscustomobject]@{
                legalActions = @($observe + 'surface_advisory')
                forbiddenActions = if ($Mode -eq 'cert') { @('click_launcher_continue', 'click_launcher_play') + $forbiddenCert }
                                 else { $forbiddenAssist }
                expectedTransitions = @('CampaignMapSurface', 'SettlementTownMenu', 'SmithyScreen', 'MarketTradeScreen')
                routeAgent = $routeB
            }
        }
        { $_ -in @('ContaminatedPreIntentSpawn', 'ContaminatedWrongTarget') } {
            return [pscustomobject]@{
                legalActions = @('observe')
                forbiddenActions = @('click_launcher_continue', 'click_launcher_play', 'claim_f7_pass', 'poll_status')
                expectedTransitions = @('ProcessClean')
                routeAgent = $routeC
            }
        }
        { $_ -in @('UnknownWindowState', 'UnknownGameSurface') } {
            return [pscustomobject]@{
                legalActions = @('observe')
                forbiddenActions = @('click_launcher_continue', 'click_launcher_play', 'claim_f7_pass', 'mutate_inventory')
                expectedTransitions = @()
                routeAgent = $routeHuman
            }
        }
        default {
            return [pscustomobject]@{
                legalActions = @($observe)
                forbiddenActions = @('click_launcher_continue', 'click_launcher_play', 'claim_f7_pass')
                expectedTransitions = @()
                routeAgent = $routeHuman
            }
        }
    }
}

function Get-F7ExternalStateSnapshot {
    param(
        [string]$BannerlordRoot,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [string]$CrashContextPath = $null,
        $CertStartedUtc = $null
    )

    $det = $null
    if (Get-Command Get-BannerlordProcessDetection -ErrorAction SilentlyContinue) {
        $det = Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot `
            -Phase1Path $Phase1Path -StatusPath $StatusPath -CrashContextPath $CrashContextPath
    }

    $phase1State = 'missing'
    $statusState = 'missing'
    if ($CertStartedUtc -and (Get-Command Get-F7ArtifactFreshnessState -ErrorAction SilentlyContinue)) {
        if ($Phase1Path) {
            $phase1State = [string](Get-F7ArtifactFreshnessState -Path $Phase1Path -CertStartedUtc $CertStartedUtc)
        }
        if ($StatusPath) {
            $statusState = [string](Get-F7ArtifactFreshnessState -Path $StatusPath -CertStartedUtc $CertStartedUtc)
        }
    }

    $statusJson = if ($statusState -eq 'fresh') { Read-F7StatusJsonSafe -StatusPath $StatusPath } else { $null }
    $fg = Get-F7ForegroundWindowInfo

    $evidence = New-Object System.Collections.Generic.List[string]
    $evidence.Add('process') | Out-Null
    if ($det -and $det.gameProcessCandidates -and $det.gameProcessCandidates.Count -gt 0) {
        $evidence.Add('window') | Out-Null
    }
    if ($phase1State -eq 'fresh') { $evidence.Add('Phase1.tail.txt') | Out-Null }
    if ($statusState -eq 'fresh') { $evidence.Add('BlacksmithGuild_Status.json') | Out-Null }

    return [pscustomobject]@{
        detection = $det
        phase1ArtifactState = $phase1State
        statusArtifactState = $statusState
        statusJson = $statusJson
        foreground = $fg
        evidenceSources = @($evidence)
    }
}

function Invoke-F7ExternalStateClassification {
    param(
        [string]$BannerlordRoot,
        [ValidateSet('cert', 'assistive', 'assistive_launch_setup')]
        [string]$Mode = 'cert',
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [string]$CrashContextPath = $null,
        $CertStartedUtc = $null,
        [bool]$PreflightClean = $false,
        [bool]$Contaminated = $false,
        [string]$ContaminationReason = $null,
        [string]$CertTarget = $null,
        [string]$LaunchPath = 'unknown',
        [string]$LaunchSelectedBy = 'unknown',
        [bool]$TargetMismatch = $false,
        [string]$LaunchState = $null,
        [string]$ReasonOverride = $null,
        $SettlementMenuReadyObserved = $null,
        $OldGoldenPathSatisfied = $null
    )

    $snap = Get-F7ExternalStateSnapshot -BannerlordRoot $BannerlordRoot `
        -Phase1Path $Phase1Path -StatusPath $StatusPath -CrashContextPath $CrashContextPath `
        -CertStartedUtc $CertStartedUtc

    $processState = Resolve-F7ProcessClassifiedState -Detection $snap.detection `
        -PreflightClean $PreflightClean -Contaminated $Contaminated -ContaminationReason $ContaminationReason
    $surface = Resolve-F7GameSurfaceClassifiedState -StatusJson $snap.statusJson `
        -StatusArtifactState $snap.statusArtifactState

    $classifiedState = $processState
    $confidence = 'low'
    if ($snap.detection) {
        switch ([string]$snap.detection.gameAliveConfidence) {
            'definite' { $confidence = 'high' }
            'launcher_hosted' { $confidence = 'medium' }
            'phase1_active' { $confidence = 'medium' }
            default { $confidence = 'low' }
        }
    }
    if ($PreflightClean) { $confidence = 'high' }
    if ($Contaminated) { $confidence = 'high' }

    $runtimeEvidence = @($surface.runtimeEvidenceStates)
    if ($snap.phase1ArtifactState -eq 'fresh') { $runtimeEvidence += 'Phase1Active' }
    if ($snap.statusArtifactState -eq 'fresh') { $runtimeEvidence += 'StatusFresh' }

    if ($surface.state -ne 'UnknownGameSurface' -and $snap.statusArtifactState -eq 'fresh') {
        $classifiedState = $surface.state
        if ([string]$surface.confidence -eq 'medium' -and $confidence -eq 'low') {
            $confidence = 'medium'
        }
    }

    $policy = Get-F7StateActionPolicy -ClassifiedState $classifiedState -Mode $Mode
    $manualLaunch = ($LaunchSelectedBy -in @('user', 'unknown')) -and ($LaunchPath -in @('continue', 'play'))
    $assistiveAttach = ($Mode -eq 'assistive')

    $procName = $null
    $procId = $null
    $hwnd = $null
    $windowTitle = $null
    if ($snap.detection -and $snap.detection.gameProcessPid) {
        $procId = [int]$snap.detection.gameProcessPid
        $procName = [string]$snap.detection.gameProcessName
        $windowTitle = ($snap.detection.gameProcessCandidates | Where-Object { $_.pid -eq $procId } | Select-Object -First 1).windowTitle
    }

    $fgMatch = $false
    if ($snap.foreground.hwnd -and $procId -and $snap.foreground.processId -eq $procId) {
        $fgMatch = $true
    }

    $reason = if ($ReasonOverride) { [string]$ReasonOverride }
              elseif ($Contaminated) { "Contamination: $ContaminationReason" }
              elseif ($PreflightClean) { 'Preflight clean; no residual Bannerlord processes.' }
              else { [string]$surface.reason }

    $windowBoundsReason = if ($snap.foreground.bounds) { $null } else { 'foreground_helper_no_rect' }

    $settlementObserved = $SettlementMenuReadyObserved
    if ($null -eq $settlementObserved) {
        $settlementObserved = Test-F7SettlementMenuReadyObserved -StatusJson $snap.statusJson `
            -StatusArtifactState $snap.statusArtifactState
    }

    return [pscustomobject]@{
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode = [string]$Mode
        classifiedState = [string]$classifiedState
        confidence = [string]$confidence
        processName = $procName
        processId = $procId
        hwnd = if ($snap.foreground.hwnd) { [int]$snap.foreground.hwnd } else { $null }
        windowTitle = if ($windowTitle) { [string]$windowTitle } elseif ($snap.foreground.title) { [string]$snap.foreground.title } else { $null }
        windowBounds = $snap.foreground.bounds
        windowBoundsReason = $windowBoundsReason
        foregroundWindowMatch = [bool]$fgMatch
        evidenceSources = @($snap.evidenceSources)
        runtimeEvidenceStates = @($runtimeEvidence | Select-Object -Unique)
        legalActions = @($policy.legalActions)
        forbiddenActions = @($policy.forbiddenActions)
        expectedTransitions = @($policy.expectedTransitions)
        routeAgent = [string]$policy.routeAgent
        reason = $reason
        manualLaunchObserved = [bool]$manualLaunch
        assistiveAttach = [bool]$assistiveAttach
        certTarget = if ($CertTarget) { [string]$CertTarget } else { $null }
        launchPath = [string]$LaunchPath
        targetMismatch = [bool]$TargetMismatch
        launchState = if ($LaunchState) { [string]$LaunchState } else { $null }
        settlement_menu_ready_observed = [bool]$settlementObserved
        oldGoldenPathSatisfied = if ($null -ne $OldGoldenPathSatisfied) { [bool]$OldGoldenPathSatisfied } else { $null }
    }
}

function Add-F7ExternalStateTimelineEvent {
    param(
        $Classification,
        [switch]$Force
    )

    if (-not $script:F7ExternalStateTimeline) { return $Classification }

    if (-not $Force) {
        if ($Classification.classifiedState -eq $script:F7ExternalStateLastClassifiedState) {
            return $Classification
        }
    }

    $script:F7ExternalStateLastClassifiedState = [string]$Classification.classifiedState
    $script:F7ExternalStateTimelineEvents.Add($Classification) | Out-Null
    return $Classification
}

function Add-F7ExternalStateTimelineEventThrottled {
    param(
        [string]$BannerlordRoot,
        [ValidateSet('cert', 'assistive', 'assistive_launch_setup')]
        [string]$Mode = 'cert',
        [string]$Phase1Path,
        [string]$StatusPath,
        [string]$CrashContextPath,
        $CertStartedUtc,
        [string]$CertTarget,
        [string]$LaunchPath,
        [string]$LaunchSelectedBy,
        [bool]$TargetMismatch,
        [string]$LaunchState,
        [string]$ReasonOverride,
        [int]$ThrottleSec = 15
    )

    $now = (Get-Date).ToUniversalTime()
    if (($now - $script:F7ExternalStateLastPollEmitUtc).TotalSeconds -lt $ThrottleSec) {
        return $null
    }
    $script:F7ExternalStateLastPollEmitUtc = $now

    $cls = Invoke-F7ExternalStateClassification -BannerlordRoot $BannerlordRoot -Mode $Mode `
        -Phase1Path $Phase1Path -StatusPath $StatusPath -CrashContextPath $CrashContextPath `
        -CertStartedUtc $CertStartedUtc -CertTarget $CertTarget -LaunchPath $LaunchPath `
        -LaunchSelectedBy $LaunchSelectedBy -TargetMismatch $TargetMismatch `
        -LaunchState $LaunchState -ReasonOverride $ReasonOverride
    return Add-F7ExternalStateTimelineEvent -Classification $cls
}

function Convert-F7ClassificationToTimelineEntry {
    param($Classification)

    $entry = [ordered]@{}
    foreach ($prop in $Classification.PSObject.Properties) {
        $val = $prop.Value
        if ($val -is [System.Collections.IDictionary]) {
            $nested = [ordered]@{}
            foreach ($k in $val.Keys) { $nested[[string]$k] = $val[$k] }
            $entry[$prop.Name] = $nested
        } elseif ($val -is [System.Array] -or ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string]))) {
            $entry[$prop.Name] = @($val)
        } else {
            $entry[$prop.Name] = $val
        }
    }

    foreach ($required in @(
        'timestampUtc', 'mode', 'classifiedState', 'confidence', 'processName', 'processId', 'hwnd',
        'windowTitle', 'windowBounds', 'windowBoundsReason', 'foregroundWindowMatch', 'evidenceSources',
        'legalActions', 'forbiddenActions', 'expectedTransitions', 'routeAgent', 'reason',
        'manualLaunchObserved', 'assistiveAttach', 'settlement_menu_ready_observed', 'oldGoldenPathSatisfied'
    )) {
        if (-not $entry.Contains($required)) {
            $entry[$required] = $null
        }
    }
    if (-not $entry.windowBoundsReason -and $null -eq $entry.windowBounds) {
        $entry.windowBoundsReason = 'not_recorded'
    }

    return $entry
}

function Save-F7ExternalStateTimeline {
    if (-not $script:F7ExternalStateTimeline) { return $null }

    $outPath = [string]$script:F7ExternalStateTimeline.outputPath
    $eventItems = New-Object System.Collections.Generic.List[object]
    foreach ($ev in $script:F7ExternalStateTimelineEvents) {
        $eventItems.Add((Convert-F7ClassificationToTimelineEntry -Classification $ev)) | Out-Null
    }

    $payload = [pscustomobject]@{
        schemaVersion = [int]$script:F7ExternalStateTimeline.schemaVersion
        mode          = [string]$script:F7ExternalStateTimeline.mode
        sessionId     = $script:F7ExternalStateTimeline.sessionId
        startedAtUtc  = [string]$script:F7ExternalStateTimeline.startedAtUtc
        events        = @($eventItems.ToArray())
    }

    if (-not $outPath) { return $payload }

    $dir = Split-Path -Parent $outPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $payload | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $outPath -Encoding UTF8
    return $outPath
}

function Test-F7GuardedActionAllowed {
    param(
        [ValidateSet('cert', 'assistive', 'assistive_launch_setup')]
        [string]$Mode = 'cert',
        [Parameter(Mandatory = $true)]
        [string]$Action,
        [string]$ClassifiedState = $null,
        $Classification = $null,
        [string]$BannerlordRoot = $null,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        $CertStartedUtc = $null
    )

    if (-not $Classification) {
        if ($ClassifiedState) {
            $policy = Get-F7StateActionPolicy -ClassifiedState $ClassifiedState -Mode $Mode
            $Classification = [pscustomobject]@{
                classifiedState = [string]$ClassifiedState
                legalActions = @($policy.legalActions)
                processId = $null
            }
        } elseif (-not $BannerlordRoot) {
            return $false
        } else {
            $Classification = Invoke-F7ExternalStateClassification -BannerlordRoot $BannerlordRoot `
                -Mode $Mode -Phase1Path $Phase1Path -StatusPath $StatusPath -CertStartedUtc $CertStartedUtc
        }
    }

    if ($ClassifiedState -and -not $Classification.classifiedState) {
        $Classification.classifiedState = [string]$ClassifiedState
    }

    if ($Classification.classifiedState -in @('UnknownWindowState', 'UnknownGameSurface')) {
        return $false
    }

    if (-not $Classification.processId -and $Action -match '^click_') {
        if ($Classification.classifiedState -notin @('LauncherMenu', 'LauncherOpening', 'LauncherMenuContinueAvailable', 'LauncherMenuPlayOnly')) {
            return $false
        }
    }

    if ($Classification.legalActions -contains $Action) {
        return $true
    }

    return $false
}

function Emit-F7ExternalStateTimelineCheckpoint {
    param(
        [string]$BannerlordRoot,
        [ValidateSet('cert', 'assistive', 'assistive_launch_setup')]
        [string]$Mode = 'cert',
        [string]$Phase1Path,
        [string]$StatusPath,
        [string]$CrashContextPath,
        $CertStartedUtc,
        [string]$CertTarget,
        [string]$LaunchPath = 'unknown',
        [string]$LaunchSelectedBy = 'unknown',
        [bool]$TargetMismatch = $false,
        [bool]$PreflightClean = $false,
        [bool]$Contaminated = $false,
        [string]$ContaminationReason = $null,
        [string]$LaunchState = $null,
        [string]$ReasonOverride = $null,
        $SettlementMenuReadyObserved = $null,
        $OldGoldenPathSatisfied = $null,
        [switch]$Force
    )

    if (-not $script:F7ExternalStateTimeline) { return $null }

    $cls = Invoke-F7ExternalStateClassification -BannerlordRoot $BannerlordRoot -Mode $Mode `
        -Phase1Path $Phase1Path -StatusPath $StatusPath -CrashContextPath $CrashContextPath `
        -CertStartedUtc $CertStartedUtc -PreflightClean $PreflightClean `
        -Contaminated $Contaminated -ContaminationReason $ContaminationReason `
        -CertTarget $CertTarget -LaunchPath $LaunchPath -LaunchSelectedBy $LaunchSelectedBy `
        -TargetMismatch $TargetMismatch -LaunchState $LaunchState -ReasonOverride $ReasonOverride `
        -SettlementMenuReadyObserved $SettlementMenuReadyObserved -OldGoldenPathSatisfied $OldGoldenPathSatisfied

    return Add-F7ExternalStateTimelineEvent -Classification $cls -Force:$Force.IsPresent
}
