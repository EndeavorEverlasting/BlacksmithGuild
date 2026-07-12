# Verifies that Bannerlord dependency-mismatch CAUTION handling is a first-class launcher handoff state
# with one bounded force-close retry, an explicit machine-readable dead end, child-state preservation,
# and diagnostic retention.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return
    }

    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

$doc = 'docs\handoff\launcher-dependency-caution-handoff-doctrine.md'
$wrapper = 'scripts\launcher-modal-aware-context-nav.ps1'
$recovery = 'scripts\launcher-recovery-policy.ps1'
$diagnostics = 'scripts\invoke-collect-diagnostics.ps1'
$installer = 'scripts\install-mod.ps1'
$workflow = '.tbg\workflows\continue-visible-trade-cycle.contract.json'

foreach ($needle in @(
    '# Launcher Dependency Caution Handoff Doctrine',
    'dependency_mismatch_caution_modal',
    'confirm_dependency_caution',
    'defaultAction=confirm',
    'dependencyMismatchHandled=true',
    'LAUNCH_STATE=modal_probe_started',
    'WINDOW_DELTA after=frozen_click_unverified_or_operator_action',
    'expectedWindowChange=game_spawned|dependency_caution_modal|safe_mode_modal|singleplayer_window',
    'LAUNCH_STATE=dependency_caution_modal_detected',
    'LAUNCH_STATE=launcher_setup_handoff_observed',
    'LAUNCH_STATE=launcher_recovery_retry_scheduled',
    'LAUNCH_STATE=launcher_recovery_force_close_complete',
    'LAUNCH_STATE=launcher_recovery_retry_started',
    'LAUNCH_STATE=launcher_recovery_recovered',
    'LAUNCH_STATE=launcher_recovery_dead_end',
    'BlacksmithGuild_LauncherRecovery.json',
    'TbgLauncherRecovery.v1',
    'one retry',
    'sameFailureAsPrevious',
    'parent launcher process reads and preserves the child attempt''s terminal recovery state',
    'status/BlacksmithGuild_LauncherRecovery.json',
    'the PID comes from the fresh `TbgLauncherWindowContext.v1` context',
    'the candidate window belongs to that same PID',
    'the candidate is not the Safe Mode modal',
    'the candidate is not already a Singleplayer runtime window',
    'foreground was acquired before real input',
    'the PID/HWND is revalidated immediately before clicking Confirm',
    'click_unverified_timeout',
    'operator_action_required',
    'processName',
    'originalHwnd',
    'currentHwnd',
    'foregroundHwnd',
    'expectedNextStates',
    'Confirming the caution dialog proves only this',
    'Silent fallback is not allowed.'
)) {
    Assert-Contains $doc $needle 'dependency caution doctrine text'
}

foreach ($needle in @(
    'launcher-frozen-context-nav.ps1',
    'launcher-recovery-policy.ps1',
    'Get-TbgLauncherWindowSnapshot',
    'Write-TbgLauncherWindowDelta',
    'Get-TbgDependencyCautionCandidate',
    'Invoke-TbgDependencyCautionConfirm',
    'Wait-TbgModalGameHandoff',
    'Invoke-TbgRecoveryForFailure',
    'RecoveryAttempt = 0',
    'MaxRecoveryRetries = 1',
    'PreviousFailureSignature',
    '$wasFrozenClickFailure',
    "`$tailText -match 'click_unverified_timeout'",
    "`$tailText -match 'operator_action_required'",
    'LAUNCH_STATE=modal_probe_started',
    'WINDOW_DELTA after={0} expectedPid={1} processExists={2} processName=',
    'expectedWindowChange=game_spawned|dependency_caution_modal|safe_mode_modal|singleplayer_window',
    'expectedNextStates = ''game_spawned|dependency_caution_modal|safe_mode_modal|singleplayer_window|operator_action_required''',
    'dependency_caution_modal_detected',
    'dependency_caution_detected',
    'dependency_mismatch_caution_modal',
    'confirm_dependency_caution_required',
    'CLICK_DEPENDENCY_CAUTION_RESULT result=confirm_dispatched',
    'defaultAction=confirm',
    'dependencyMismatchHandled=true',
    'runtimeProofClaim=false',
    'Test-TbgModalHwndPid -Hwnd $hwnd -ExpectedPid $ExpectedPid',
    'ForceForegroundWindow',
    'dependency_caution_focus_failed',
    'dependency_caution_focus_lost_before_confirm',
    'MOUSEEVENTF_LEFTDOWN',
    'LAUNCH_STATE=launcher_setup_handoff_observed classification=launcher_setup_handoff_observed source=dependency_caution_confirmed'
)) {
    Assert-Contains $wrapper $needle 'wrapper must implement modal handling and route failures through recovery'
}

foreach ($needle in @(
    'TbgLauncherRecovery.v1',
    'BlacksmithGuild_LauncherRecovery.json',
    'Read-TbgLauncherRecoveryState',
    'Get-TbgLauncherFailureSignature',
    'Stop-TbgLauncherProcessFamilyForRetry',
    'Invoke-TbgLauncherRecoveryRetry',
    "@('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')",
    'Stop-Process -Id $process.Id -Force',
    'MaxRecoveryRetries = 1',
    'LAUNCH_STATE=launcher_recovery_retry_scheduled',
    'LAUNCH_STATE=launcher_recovery_force_close_started',
    'LAUNCH_STATE=launcher_recovery_force_close_complete',
    'LAUNCH_STATE=launcher_recovery_retry_started',
    'LAUNCH_STATE=launcher_recovery_recovered',
    'LAUNCH_STATE=launcher_recovery_dead_end',
    'sameFailureAsPrevious',
    'retry_budget_exhausted',
    'launcher_recovery_restart_failed',
    'launcher_retry_child_failed_without_terminal_state',
    '$childState = Read-TbgLauncherRecoveryState',
    '$childState.sameFailureAsPrevious',
    '$childState.failureSignature',
    'runtimeProofClaim = $false',
    'RecoveryAttempt + 1',
    'RecoveryAttempt -ge $MaxRecoveryRetries',
    "Join-Path `$PSScriptRoot 'open-bannerlord-launcher.ps1'",
    '& powershell.exe @retryArgs'
)) {
    Assert-Contains $recovery $needle 'recovery policy must force-close, retry once, preserve child dead-end evidence, and record terminal evidence'
}

foreach ($needle in @(
    'BlacksmithGuild_LauncherRecovery.json',
    'BlacksmithGuild_Diagnostics',
    "Join-Path `$latestBundle.FullName 'status'",
    "Copy-Item -LiteralPath `$recoverySource -Destination `$destination -Force",
    'Added launcher recovery evidence'
)) {
    Assert-Contains $diagnostics $needle 'diagnostic compatibility entrypoint must retain launcher recovery evidence'
}

foreach ($needle in @(
    'launcher-modal-aware-context-nav.ps1',
    'dependencyMismatchHandled=true',
    'LAUNCH_STATE=dependency_caution_detected'
)) {
    Assert-Contains $installer $needle 'installer launch path must route through modal-aware wrapper and accept its logged handoff'
}

foreach ($needle in @(
    'dependencyMismatchCaution',
    'dependency_mismatch_caution_modal',
    'confirm',
    'dependencyMismatchHandled=true',
    'loadingHandoffIsNotRuntimeProof'
)) {
    Assert-Contains $workflow $needle 'visible-trade workflow must record dependency caution as launcher policy'
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher dependency caution doctrine has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher dependency caution doctrine, bounded recovery, child dead-end preservation, and diagnostic retention verified.' -ForegroundColor Green
exit 0
