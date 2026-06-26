# Offline regression: launcher UIA must capture a pre-launch PID baseline and prefer
# before/after process-set diff over coordinate/title window fallback for game-host detection.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'launcher-pid-baseline-policy.ps1')

$src = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -Raw

$anchors = @(
    'public static void CaptureBaselineProcessIds()',
    'private static HashSet<int> GetNewProcessIdsSinceBaseline()',
    'private static HashSet<int> _baselineProcessIds',
    '[UIAHelper]::CaptureBaselineProcessIds()',
    'foreach (var newId in GetNewProcessIdsSinceBaseline())'
)

foreach ($a in $anchors) {
    if ($src -notmatch [regex]::Escape($a)) {
        throw "launcher-auto-nav.ps1 missing anchor: $a"
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

Write-Host 'PASS offline launcher PID baseline diff anchors + behavioral policy'
