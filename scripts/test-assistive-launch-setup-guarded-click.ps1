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

$clickStart = $navText.IndexOf('public static string ClickButtonByNameInLauncher', [StringComparison]::Ordinal)
$clickEnd = $navText.IndexOf('private static bool NamesIndicateContinue', $clickStart, [StringComparison]::Ordinal)
if ($clickStart -lt 0 -or $clickEnd -le $clickStart) {
    throw 'launcher-auto-nav.ps1 ClickButtonByNameInLauncher body could not be isolated'
}
$clickBody = $navText.Substring($clickStart, $clickEnd - $clickStart)
$knownCustomIndex = $clickBody.IndexOf('var knownCustomCoordWindow', [StringComparison]::Ordinal)
$descendantScanIndex = $clickBody.IndexOf('FindClickableInScope(window, names, requireEnabled)', [StringComparison]::Ordinal)
if ($knownCustomIndex -lt 0 -or $descendantScanIndex -lt 0 -or $knownCustomIndex -gt $descendantScanIndex) {
    throw 'known custom-rendered launcher coordinate route must precede descendant UIA scanning'
}
if (($clickBody -notmatch 'known custom-rendered launcher bypasses descendant UIA') -or
    ($clickBody -notmatch 'known custom-rendered launcher waiting for stability')) {
    throw 'launcher-auto-nav.ps1 missing fail-closed custom-rendered launcher coordinate routing'
}

$cmdText = Get-Content -LiteralPath (Join-Path $repoRoot 'Run-LauncherNavNow.cmd') -Raw
if ($cmdText -notmatch '-LaunchSetup') {
    throw 'Run-LauncherNavNow.cmd must pass -LaunchSetup for explicit launch setup'
}

Write-Host 'PASS offline assistive launch setup guarded click regression'
