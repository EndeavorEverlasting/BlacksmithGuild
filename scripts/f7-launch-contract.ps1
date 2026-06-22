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

function Get-F7LaunchContaminationResult {
    param(
        [string]$CertTarget,
        [string]$LaunchPath,
        [string]$LaunchSelectedBy,
        [bool]$AutomationContinueSuccess = $false,
        [bool]$ContaminatedLaunchLogSeen = $false,
        [string]$ContaminatedLaunchLogReason = $null
    )

    $result = [ordered]@{
        contaminated = $false
        failureReason = $null
        targetMismatch = $false
        targetMismatchReason = $null
        gameSpawnAccepted = $false
        gameSpawnRejectedReason = $null
        readinessJudged = $true
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
        $result.gameSpawnRejectedReason = 'contaminated_launch_path'
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
