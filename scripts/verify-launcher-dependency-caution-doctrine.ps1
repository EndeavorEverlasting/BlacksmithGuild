# Verifies that Bannerlord dependency-mismatch CAUTION handling is a first-class launcher handoff state.

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
$installer = 'scripts\install-mod.ps1'
$workflow = '.tbg\workflows\continue-visible-trade-cycle.contract.json'

foreach ($needle in @(
    '# Launcher Dependency Caution Handoff Doctrine',
    'dependency_mismatch_caution_modal',
    'confirm_dependency_caution',
    'defaultAction=confirm',
    'dependencyMismatchHandled=true',
    'LAUNCH_STATE=launcher_setup_handoff_observed',
    'the PID comes from the fresh `TbgLauncherWindowContext.v1` context',
    'the candidate window belongs to that same PID',
    'the candidate is not the Safe Mode modal',
    'the candidate is not already a Singleplayer runtime window',
    'foreground was acquired before real input',
    'the PID/HWND is revalidated immediately before clicking Confirm',
    'Confirming the caution dialog proves only this',
    'Silent fallback is not allowed.'
)) {
    Assert-Contains $doc $needle 'dependency caution doctrine text'
}

foreach ($needle in @(
    'launcher-frozen-context-nav.ps1',
    'Get-TbgDependencyCautionCandidate',
    'Invoke-TbgDependencyCautionConfirm',
    'Wait-TbgModalGameHandoff',
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
    Assert-Contains $wrapper $needle 'wrapper must implement and log modal handling'
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

Write-Host 'PASS: launcher dependency caution doctrine verified.' -ForegroundColor Green
exit 0
