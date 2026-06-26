# Offline regression: assistive launch setup allows guarded launcher clicks; cert contamination unchanged.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')

if (-not (Test-F7GuardedActionAllowed -Mode 'assistive' -Action 'click_launcher_continue' -ClassifiedState 'LauncherOpening')) {
    Write-Host 'PASS: plain assistive denies launcher click on LauncherOpening'
} else {
    throw 'Plain assistive must deny click_launcher_continue on LauncherOpening'
}

if (-not (Test-F7GuardedActionAllowed -Mode 'assistive_launch_setup' -Action 'click_launcher_continue' -ClassifiedState 'LauncherOpening')) {
    throw 'assistive_launch_setup must allow click_launcher_continue on LauncherOpening'
}

if (-not (Test-F7GuardedActionAllowed -Mode 'cert' -Action 'click_launcher_continue' -ClassifiedState 'LauncherOpening')) {
    throw 'cert mode must still allow launcher continue click'
}

$cert = Get-F7LaunchContaminationResult -CertTarget 'continue' -LaunchPath 'continue' `
    -LaunchSelectedBy 'user' -AutomationContinueSuccess $false
if (-not $cert.contaminated) {
    throw 'Cert contamination rules must remain for user Continue'
}

$navText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -Raw
if ($navText -notmatch 'assistive_launch_setup' -or $navText -notmatch 'LaunchSetup') {
    throw 'launcher-auto-nav.ps1 missing LaunchSetup / assistive_launch_setup mode'
}

$cmdText = Get-Content -LiteralPath (Join-Path $repoRoot 'Run-LauncherNavNow.cmd') -Raw
if ($cmdText -notmatch '-LaunchSetup') {
    throw 'Run-LauncherNavNow.cmd must pass -LaunchSetup for explicit launch setup'
}

Write-Host 'PASS offline assistive launch setup guarded click regression'
