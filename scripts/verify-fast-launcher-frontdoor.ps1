# Static contract for the root Forge launcher front door.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Need {
    param([string]$Path, [string]$Needle)
    $text = Read-RepoText $Path
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$Path missing '$Needle'") | Out-Null
    }
}

function Forbid {
    param([string]$Path, [string]$Needle)
    $text = Read-RepoText $Path
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -ge 0) {
        $failures.Add("$Path contains forbidden '$Needle'") | Out-Null
    }
}

$frontdoor = 'scripts\launcher-fast-frontdoor.ps1'
foreach ($needle in @(
    'TbgLauncherFastFrontdoor.v1',
    'TotalBudgetSec = 30',
    'PhaseBudgetSec = 5',
    'MaxAttempts = 2',
    'SetProcessDPIAware',
    'GetWindowRect',
    'dpiAware=true',
    'artifacts\latest\launcher-frontdoor',
    'launcher-frontdoor.result.json',
    'Capture-LauncherWindow',
    'darkRatio',
    'LAUNCH_STATE=dependency_caution_modal_detected',
    'action=confirm',
    'cancelAction=forbidden',
    'launcher_menu_returned_after_confirm',
    'Stop-TbgLauncherFamily',
    'fast_retry_scheduled',
    'launcher_recovery_dead_end',
    'open-bannerlord-launcher.ps1',
    'launch-tail.log',
    'runtimeProofClaim = $false'
)) { Need $frontdoor $needle }

foreach ($needle in @(
    'TimeoutSec = 60',
    'Start-Sleep -Seconds 30',
    'defaultAction=cancel',
    'SendKeys(''%n'')'
)) { Forbid $frontdoor $needle }

foreach ($cmd in @('Forge.cmd', 'ForgeContinue.cmd')) {
    Need $cmd 'launcher-fast-frontdoor.ps1'
    Need $cmd '-LaunchManual'
    Need $cmd '-TotalBudgetSec 30'
    Need $cmd '-PhaseBudgetSec 5'
    Need $cmd '-MaxAttempts 2'
    Need $cmd 'artifacts\latest\launcher-frontdoor'
    Need $cmd 'if not defined TBG_NO_PAUSE pause'
    Need $cmd 'resolves RepoRoot from its own tracked location'
    Forbid $cmd 'launcher-frozen-context-nav.ps1'
    Forbid $cmd 'launcher-modal-aware-context-nav.ps1'
    Forbid $cmd '-RepoRoot "%~dp0"'
    Forbid $cmd '-RepoRoot ''%~dp0'''
}

$workhorseCmd = 'Run-LauncherValidationWorkhorse.cmd'
Need $workhorseCmd 'run-launcher-validation-workhorse.ps1'
Need $workhorseCmd 'if not defined TBG_NO_PAUSE pause'
Need $workhorseCmd 'resolves RepoRoot from its own tracked location'
Forbid $workhorseCmd '-RepoRoot "%~dp0"'
Forbid $workhorseCmd '-RepoRoot ''%~dp0'''

$frontdoorText = Read-RepoText $frontdoor
$confirmIndex = $frontdoorText.IndexOf("Click-LauncherFraction -Window `$window -XFraction 0.55 -YFraction 0.88 -Label 'dependency_caution_confirm'", [StringComparison]::Ordinal)
$retryIndex = $frontdoorText.IndexOf('LAUNCH_STATE=fast_retry_scheduled', [StringComparison]::Ordinal)
if ($confirmIndex -lt 0 -or $retryIndex -lt 0 -or $confirmIndex -ge $retryIndex) {
    $failures.Add('fast frontdoor must attempt dependency CAUTION Confirm before scheduling force-close retry') | Out-Null
}

$waitIndex = $frontdoorText.IndexOf('Wait-GameUntil -Deadline $attemptDeadline', [StringComparison]::Ordinal)
if ($waitIndex -lt 0 -or $waitIndex -ge $retryIndex) {
    $failures.Add('fast frontdoor must wait for the post-Confirm game handoff before force-close retry') | Out-Null
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: fast launcher frontdoor contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: fast launcher frontdoor timing, DPI, Confirm-first, bounded retry, internal root resolution, and local evidence contract verified.' -ForegroundColor Green
exit 0
