# Offline regression: launcher UIA must capture a pre-launch PID baseline and prefer
# before/after process-set diff over coordinate/title window fallback for game-host detection.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'launcher-pid-baseline-policy.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')

$src = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -Raw -Encoding UTF8
$openLauncherSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -Raw -Encoding UTF8
$contextHelperSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-window-context.ps1') -Raw -Encoding UTF8

$anchors = @(
    'public static void CaptureBaselineProcessIds()',
    'private static HashSet<int> GetNewProcessIdsSinceBaseline()',
    'private static HashSet<int> _baselineProcessIds',
    '[UIAHelper]::CaptureBaselineProcessIds()',
    'foreach (var newId in GetNewProcessIdsSinceBaseline())',
    'window-snapshot-S1-pre-launch.json',
    'window-snapshot-S2-post-launch.json',
    'window-delta-candidates.json',
    'chosen-launch-window.json',
    'launch-selection.json',
    'Test-TbgLauncherDeltaMenuReady',
    "return ([string]`$Decision.winner.processName -match 'Bannerlord|TaleWorlds')",
    '[UIAHelper]::SetPreferredLauncherWindow',
    '. (Join-Path $PSScriptRoot ''pr11-process-window-classifier.ps1'')'
)

foreach ($a in $anchors) {
    if ($src -notmatch [regex]::Escape($a)) {
        throw "launcher-auto-nav.ps1 missing anchor: $a"
    }
}

# The wrapper no longer owns S1 snapshot internals. It delegates to the shared context helper
# and must pass explicit launch intent into the helper-owned path.
foreach ($a in @(
    ". (Join-Path `$PSScriptRoot 'launcher-window-context.ps1')",
    '[Parameter(Mandatory = $true)]',
    "[ValidateSet('play', 'continue')]",
    'Ensure-TbgLauncherWindowContext -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent',
    'open-launcher: existing launcher detected; reusing context',
    'open-launcher: fresh launcher context created',
    'Forge Stop approval'
)) {
    if ($openLauncherSrc -notmatch [regex]::Escape($a)) {
        throw "open-bannerlord-launcher.ps1 missing anchor: $a"
    }
}

# S1 baseline capture, existing-launcher reuse, game-process guard, and bounded process binding now
# live in launcher-window-context.ps1. Keep the regression anchored to the real owner.
foreach ($a in @(
    "Save-Pr11ProcessSnapshot -Snapshot `$baseline -OutputPath `$baselinePath",
    "`$baselinePath = Join-Path `$BannerlordRoot 'window-snapshot-S1-pre-launch.json'",
    "`$baselineLabel = if (`$existingLauncherReuse) { 'S1_existing_launcher_reuse' } else { 'S1_pre_launch' }",
    "`$launcher = Get-TbgLauncherProcessCandidate -PreferVisibleWindow",
    "`$existingLauncherReuse = [bool](`$launcher -and -not `$gameRunning)",
    "`$gameRunning = [bool](Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)",
    "if (`$gameRunning -and -not `$AllowExistingProcess -and -not `$preflightOk) {",
    'Forge Stop approval',
    'Resolve-TbgTestDurationBudget',
    'New-TbgTestDurationDeadline',
    'Test-TbgTestDurationExpired',
    'Start-Process -FilePath $launcherExe -WorkingDirectory (Split-Path -Parent $launcherExe) -PassThru',
    'Get-Process -Id $startedLauncher.Id -ErrorAction SilentlyContinue',
    'Launcher was started, but no launcher process could be bound for context.'
)) {
    if ($contextHelperSrc -notmatch [regex]::Escape($a)) {
        throw "launcher-window-context.ps1 missing anchor: $a"
    }
}

# Behavioral: new post-baseline PID must block weak title/coordinate fallback
$baseline = @(44100, 44112)
$afterLaunch = @(
    [pscustomobject]@{ Id = 44100; Name = 'TaleWorlds.MountAndBlade.Launcher' },
    [pscustomobject]@{ Id = 55234; Name = 'TaleWorlds.MountAndBlade.Launcher'; MainWindowTitle = 'Mount and Blade II Bannerlord - Singleplayer PID: 55234' }
)
$newPids = Get-TbgNewProcessIdsSinceBaseline -BaselineProcessIds $baseline -CurrentProcesses $afterLaunch
if (@($newPids).Count -ne 1 -or [int]$newPids[0] -ne 55234) {
    throw "expected one new pid 55234 got $(@($newPids) -join ',')"
}

$blocked = Test-TbgLauncherSelectionRespectsPidBaseline -BaselineProcessIds $baseline `
    -CurrentProcesses $afterLaunch -SelectionMethod 'coord_window_pick'
if ($blocked.allowed) {
    throw 'coord/title fallback must be blocked when new post-baseline PID exists'
}
if ($blocked.preferredMethod -ne 'pid_delta') {
    throw "expected pid_delta preference got $($blocked.preferredMethod)"
}

$allowed = Test-TbgLauncherSelectionRespectsPidBaseline -BaselineProcessIds $baseline `
    -CurrentProcesses $afterLaunch -SelectionMethod 'pid_delta'
if (-not $allowed.allowed -or $allowed.preferredMethod -ne 'pid_delta') {
    throw 'pid_delta selection must be allowed when new post-baseline PID exists'
}

# Behavioral: no new PID permits fallback
$unchanged = @(
    [pscustomobject]@{ Id = 44100; Name = 'TaleWorlds.MountAndBlade.Launcher' },
    [pscustomobject]@{ Id = 44112; Name = 'Bannerlord' }
)
$fallbackOk = Test-TbgLauncherSelectionRespectsPidBaseline -BaselineProcessIds $baseline `
    -CurrentProcesses $unchanged -SelectionMethod 'coordinate_fallback'
if (-not $fallbackOk.allowed) {
    throw 'fallback must remain allowed when no new post-baseline PID exists'
}

function New-LauncherFixtureProcess {
    param(
        [int]$Id,
        [string]$Name,
        [string]$MainWindowTitle = ''
    )
    [pscustomobject]@{
        Id = $Id
        ProcessName = $Name
        Name = $Name
        MainWindowTitle = $MainWindowTitle
    }
}

Write-Host 'PASS: launcher PID baseline diff policy verified.' -ForegroundColor Green
exit 0
