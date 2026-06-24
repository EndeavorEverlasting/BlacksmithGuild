# Offline regression: pre-intent game spawn before automation Continue (session 20260622-175909).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')

$sessionId = '20260622-175909'
$launchTailPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\Launch.tail.txt"
if (-not (Test-Path -LiteralPath $launchTailPath)) {
    throw "Missing Launch.tail: $launchTailPath"
}

$launchLines = Get-Content -LiteralPath $launchTailPath
$gameSpawnLine = [string]($launchLines | Where-Object { $_ -match 'LAUNCH_STATE=game_spawned' } | Select-Object -First 1)
$continueLine = [string]($launchLines | Where-Object { $_ -match 'LAUNCH_STATE=continue_clicked selectedBy=automation' } | Select-Object -First 1)
if (-not $gameSpawnLine) {
    throw 'Launch.tail missing LAUNCH_STATE=game_spawned (175909 root cause evidence)'
}
if (-not $continueLine) {
    throw 'Launch.tail missing continue_clicked selectedBy=automation'
}

$gameSpawnTs = if ($gameSpawnLine -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { $Matches[1] } else { $null }
$continueTs = if ($continueLine -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { $Matches[1] } else { $null }
if (-not $gameSpawnTs -or -not $continueTs) {
    throw 'Could not parse timestamps from Launch.tail contamination timeline'
}
$gameSpawnDt = [datetime]::ParseExact($gameSpawnTs, 'yyyy-MM-dd HH:mm:ss', $null)
$continueDt = [datetime]::ParseExact($continueTs, 'yyyy-MM-dd HH:mm:ss', $null)
if ($gameSpawnDt -ge $continueDt) {
    throw "Expected game_spawned before continue_clicked in 175909 evidence; game=$gameSpawnTs continue=$continueTs"
}

$contaminated = Get-F7LaunchContaminationResult `
    -CertTarget 'continue' `
    -LaunchPath 'continue' `
    -LaunchSelectedBy 'automation' `
    -AutomationContinueSuccess $true `
    -ContaminatedLaunchLogSeen $true `
    -ContaminatedLaunchLogReason 'game_running_before_automation_continue' `
    -SpawnAttribution 'preautomation_spawn'

if (-not $contaminated.contaminated) {
    throw 'Expected contaminated=true for game_running_before_automation_continue'
}
if ($contaminated.failureReason -ne 'contaminated_launch_path') {
    throw "Expected failureReason=contaminated_launch_path got $($contaminated.failureReason)"
}
if ($contaminated.targetMismatchReason -ne 'game_running_before_automation_continue') {
    throw "Expected targetMismatchReason=game_running_before_automation_continue got $($contaminated.targetMismatchReason)"
}
if ($contaminated.gameSpawnRejectedReason -ne 'pre_intent_game_spawn') {
    throw "Expected gameSpawnRejectedReason=pre_intent_game_spawn got $($contaminated.gameSpawnRejectedReason)"
}
if ($contaminated.gameSpawnAccepted) {
    throw 'Expected gameSpawnAccepted=false'
}
if ($contaminated.readinessJudged) {
    throw 'Expected readinessJudged=false'
}

$preIntent = Get-F7PreIntentContaminationResult -Reason 'game_running_before_automation_continue' -SpawnAttribution 'preautomation_spawn'
if ($preIntent.gameSpawnRejectedReason -ne 'pre_intent_game_spawn') {
    throw 'Get-F7PreIntentContaminationResult must set pre_intent_game_spawn'
}

$contamLine = [string]($launchLines | Where-Object { $_ -match 'LAUNCH_STATE=contaminated_launch_path' } | Select-Object -First 1)
if ($contamLine -match 'selectedBy=user') {
    Write-Host "NOTE: committed 175909 evidence still shows selectedBy=user (pre-fix); post-fix logs use spawnAttribution="
}

$menuTitle = 'M&B II: Bannerlord'
if (Test-LauncherHostedWindowTitle -Title $menuTitle) {
    throw "Menu title must not classify as launcher-hosted: $menuTitle"
}
if (-not (Test-LauncherMenuWindowTitle -Title $menuTitle)) {
    throw "Menu title must classify as launcher menu: $menuTitle"
}

$mockDet = [ordered]@{
    gameProcessRunning = $true
    gameProcessCandidates = @(
        [PSCustomObject]@{
            method = 'launcher_hosted_window'
            isLauncherHosted = $true
            windowTitle = $menuTitle
            path = $null
        }
    )
    gameProcessDetectionMethod = 'launcher_hosted_window'
}
if (Test-F7StrongPreIntentGameSignal -Detection $mockDet) {
    throw 'Menu title alone must not be a strong pre-intent game signal'
}

$hostedTitle = 'Mount and Blade II Bannerlord - Singleplayer PID: 139112'
$hostedDet = [ordered]@{
    gameProcessRunning = $true
    gameProcessCandidates = @(
        [PSCustomObject]@{
            method = 'launcher_hosted_window'
            isLauncherHosted = $true
            windowTitle = $hostedTitle
            path = $null
        }
    )
    gameProcessDetectionMethod = 'launcher_hosted_window'
}
if (-not (Test-F7StrongPreIntentGameSignal -Detection $hostedDet)) {
    throw "Singleplayer PID title must be strong pre-intent signal: $hostedTitle"
}

Write-Host "PASS offline pre-intent contaminated launch regression $sessionId"
Write-Host "gameSpawnLine=$gameSpawnLine"
Write-Host "continueLine=$continueLine"
