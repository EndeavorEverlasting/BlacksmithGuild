# F7 launch path contract — dot-sourced from run-f7-gate-continue.ps1 and offline regressions.

function Get-F7ArtifactFreshnessState {
    param(
        [string]$Path,
        [datetime]$CertStartedUtc
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return 'missing'
    }
    try {
        $mtime = (Get-Item -LiteralPath $Path).LastWriteTimeUtc
        if ($mtime -lt $CertStartedUtc.AddSeconds(-2)) {
            return 'stale'
        }
        return 'fresh'
    } catch {
        return 'missing'
    }
}

function Test-F7ContinueLaunchEligible {
    param(
        [string]$CertTarget,
        [string]$LaunchPath,
        [string]$LaunchSelectedBy,
        [bool]$AutomationContinueSuccess = $false
    )

    if ($CertTarget -eq 'any') { return $true }
    if ($CertTarget -ne 'continue') { return $true }

    if ($LaunchPath -eq 'play') { return $false }
    if ($LaunchSelectedBy -eq 'user') { return $false }
    if ($LaunchPath -eq 'continue' -and $LaunchSelectedBy -eq 'automation' -and $AutomationContinueSuccess) {
        return $true
    }
    if ($LaunchPath -eq 'continue' -and $LaunchSelectedBy -eq 'automation') {
        return $true
    }
    if ($LaunchPath -eq 'unknown') { return $false }
    return $false
}

function Test-TbgRealGameSpawnDetection {
    param($Detection)

    if (-not $Detection -or -not $Detection.gameProcessRunning) { return $false }

    $confidence = [string]$Detection.gameAliveConfidence
    if ($confidence -in @('launcher_hosted', 'process_detection_uncertain', 'none')) {
        return $false
    }

    return $confidence -in @('definite', 'phase1_active')
}

function Test-F7StrongPreIntentGameSignal {
    param(
        $Detection,
        [bool]$LoadingSurface = $false,
        [bool]$LauncherGone = $false
    )

    if ($LoadingSurface -and $LauncherGone) { return $true }
    if (-not $Detection) { return $false }

    foreach ($c in @($Detection.gameProcessCandidates)) {
        if ($c.method -in @('process_name_bannerlord', 'process_name_taleworlds')) { return $true }
        if ($c.method -eq 'launcher_child_executable') {
            if ((Get-Command Test-BannerlordGameExecutableLeaf -ErrorAction SilentlyContinue) `
                    -and (Test-BannerlordGameExecutableLeaf -Path $c.path)) {
                return $true
            }
            if (-not (Get-Command Test-BannerlordGameExecutableLeaf -ErrorAction SilentlyContinue)) {
                return $true
            }
        }
        if ($c.method -eq 'launcher_hosted_window' -and $c.isLauncherHosted) {
            if ((Get-Command Test-LauncherSingleplayerHostedTitle -ErrorAction SilentlyContinue) `
                    -and (Test-LauncherSingleplayerHostedTitle -Title $c.windowTitle)) {
                return $true
            }
        }
    }

    if ($Detection.gameProcessDetectionMethod -in @(
            'process_name_bannerlord', 'process_name_taleworlds', 'launcher_child_executable', 'executable_path'
        )) {
        return $true
    }

    if ($Detection.gameProcessDetectionMethod -eq 'launcher_hosted_window') {
        foreach ($c in @($Detection.gameProcessCandidates)) {
            if ($c.method -eq 'launcher_hosted_window' `
                    -and (Get-Command Test-LauncherSingleplayerHostedTitle -ErrorAction SilentlyContinue) `
                    -and (Test-LauncherSingleplayerHostedTitle -Title $c.windowTitle)) {
                return $true
            }
        }
    }

    return $false
}

function Get-F7PreIntentContaminationResult {
    param(
        [string]$Reason = 'game_running_before_automation_continue',
        [string]$SpawnAttribution = 'preautomation_spawn'
    )

    return [ordered]@{
        contaminated = $true
        failureReason = 'contaminated_launch_path'
        targetMismatch = $true
        targetMismatchReason = [string]$Reason
        gameSpawnAccepted = $false
        gameSpawnRejectedReason = 'pre_intent_game_spawn'
        readinessJudged = $false
        spawnAttribution = [string]$SpawnAttribution
    }
}

function Get-F7LaunchContaminationResult {
    param(
        [string]$CertTarget,
        [string]$LaunchPath,
        [string]$LaunchSelectedBy,
        [bool]$AutomationContinueSuccess = $false,
        [bool]$ContaminatedLaunchLogSeen = $false,
        [string]$ContaminatedLaunchLogReason = $null,
        [string]$SpawnAttribution = $null
    )

    $result = [ordered]@{
        contaminated = $false
        failureReason = $null
        targetMismatch = $false
        targetMismatchReason = $null
        gameSpawnAccepted = $false
        gameSpawnRejectedReason = $null
        readinessJudged = $true
        spawnAttribution = $null
    }

    if ($CertTarget -eq 'any') {
        $result.gameSpawnAccepted = ($LaunchPath -in @('continue', 'play'))
        return $result
    }

    if ($ContaminatedLaunchLogSeen) {
        $result.contaminated = $true
        $result.failureReason = 'contaminated_launch_path'
        $result.targetMismatch = $true
        $result.targetMismatchReason = if ($ContaminatedLaunchLogReason) {
            [string]$ContaminatedLaunchLogReason
        } else {
            'launcher logged contaminated_launch_path during continue cert'
        }
        $result.gameSpawnAccepted = $false
        if ($ContaminatedLaunchLogReason -eq 'game_running_before_automation_continue') {
            $result.gameSpawnRejectedReason = 'pre_intent_game_spawn'
        } else {
            $result.gameSpawnRejectedReason = 'contaminated_launch_path'
        }
        if ($SpawnAttribution) {
            $result.spawnAttribution = [string]$SpawnAttribution
        }
        $result.readinessJudged = $false
        return $result
    }

    if ($CertTarget -eq 'continue') {
        if (-not (Test-F7ContinueLaunchEligible -CertTarget $CertTarget -LaunchPath $LaunchPath `
                -LaunchSelectedBy $LaunchSelectedBy -AutomationContinueSuccess $AutomationContinueSuccess)) {
            $result.contaminated = $true
            $result.failureReason = 'contaminated_launch_path'
            $result.targetMismatch = $true
            if ($LaunchPath -eq 'play') {
                $result.targetMismatchReason = "certTarget=continue observed launchPath=play launchSelectedBy=$LaunchSelectedBy"
                $result.gameSpawnRejectedReason = 'user_or_observed_play_not_eligible_for_continue_cert'
            } elseif ($LaunchSelectedBy -eq 'user') {
                $result.targetMismatchReason = "certTarget=continue requires automation Continue; observed launchSelectedBy=user launchPath=$LaunchPath"
                $result.gameSpawnRejectedReason = 'user_handoff_not_eligible_for_continue_cert'
            } else {
                $result.targetMismatchReason = "certTarget=continue requires automation Continue; observed launchPath=$LaunchPath launchSelectedBy=$LaunchSelectedBy"
                $result.gameSpawnRejectedReason = 'launch_path_not_eligible_for_continue_cert'
            }
            $result.gameSpawnAccepted = $false
            $result.readinessJudged = $false
            return $result
        }

        $result.gameSpawnAccepted = $true
        return $result
    }

    if ($CertTarget -eq 'play') {
        if ($LaunchPath -eq 'continue' -or ($LaunchSelectedBy -eq 'user' -and $LaunchPath -ne 'play')) {
            $result.contaminated = $true
            $result.failureReason = 'contaminated_launch_path'
            $result.targetMismatch = $true
            $result.targetMismatchReason = "certTarget=play observed launchPath=$LaunchPath launchSelectedBy=$LaunchSelectedBy"
            $result.gameSpawnAccepted = $false
            $result.gameSpawnRejectedReason = 'launch_path_not_eligible_for_play_cert'
            $result.readinessJudged = $false
        } elseif ($LaunchPath -eq 'play' -and $LaunchSelectedBy -eq 'automation') {
            $result.gameSpawnAccepted = $true
        }
    }

    return $result
}

function Get-F7AssistiveAttachResult {
    param(
        [string]$LaunchPath = 'unknown',
        [string]$LaunchSelectedBy = 'unknown',
        [bool]$GameProcessRunning = $false,
        [bool]$ContaminatedLaunchLogSeen = $false
    )

    $manual = ($LaunchSelectedBy -in @('user', 'unknown'))
    $result = [ordered]@{
        assistiveAttach = $true
        manualLaunchObserved = [bool]$manual
        contaminated = $false
        targetMismatch = $false
        targetMismatchReason = $null
        failureReason = $null
        gameSpawnAccepted = [bool]$GameProcessRunning
        gameSpawnRejectedReason = $null
        readinessJudged = $true
        launchPath = [string]$LaunchPath
        launchSelectedBy = [string]$LaunchSelectedBy
    }

    if ($ContaminatedLaunchLogSeen) {
        $result.contaminated = $true
        $result.failureReason = 'assistive_attach_blocked_by_prior_contamination_log'
        $result.readinessJudged = $false
    }

    return [pscustomobject]$result
}
