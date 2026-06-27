# Offline regression: launcher UIA must capture a pre-launch PID baseline and prefer
# before/after process-set diff over coordinate/title window fallback for game-host detection.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'launcher-pid-baseline-policy.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')

$src = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -Raw
$openLauncherSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -Raw

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

foreach ($a in @(
    "Save-Pr11ProcessSnapshot -Snapshot `$s1Snapshot -OutputPath (Join-Path `$BannerlordRoot 'window-snapshot-S1-pre-launch.json')",
    ". (Join-Path `$PSScriptRoot 'pr11-process-window-classifier.ps1')",
    # Existing launcher (no game) is reused, not treated as a fatal blocker.
    "`$launcherRunning = [bool](Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher'",
    "if (`$launcherRunning -and -not `$gameRunning) {",
    'open-launcher: existing launcher detected; reusing',
    # A real game process still requires Forge Stop approval before opening the launcher.
    "`$gameRunning = [bool](Get-Process -Name 'Bannerlord'",
    "if (`$gameRunning -and -not `$AllowExistingProcess -and -not `$preflightOk) {",
    'Forge Stop approval'
)) {
    if ($openLauncherSrc -notmatch [regex]::Escape($a)) {
        throw "open-bannerlord-launcher.ps1 missing anchor: $a"
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
        [int]$ProcessId,
        [string]$Name,
        [string]$Title,
        [string]$Path,
        [int64]$Hwnd
    )

    return [pscustomobject][ordered]@{
        pid = $ProcessId
        processName = $Name
        parentPid = 1
        startTime = (Get-Date).ToUniversalTime().ToString('o')
        mainWindowHandle = $Hwnd
        mainWindowTitle = $Title
        executablePath = $Path
        commandLine = $null
        windowRectangle = $null
        visible = ($Hwnd -ne 0)
        uiaProcessId = $null
    }
}

$bannerlordRoot = 'C:\Steam\Mount & Blade II Bannerlord'
$s1 = [ordered]@{
    label = 'S1'
    processes = @(
        (New-LauncherFixtureProcess -ProcessId 44100 -Name 'TaleWorlds.MountAndBlade.Launcher' -Title 'M&B II: Bannerlord' -Path "$bannerlordRoot\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe" -Hwnd 101)
    )
}
$s2 = [ordered]@{
    label = 'S2'
    processes = @(
        (New-LauncherFixtureProcess -ProcessId 44100 -Name 'TaleWorlds.MountAndBlade.Launcher' -Title 'M&B II: Bannerlord' -Path "$bannerlordRoot\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe" -Hwnd 101),
        (New-LauncherFixtureProcess -ProcessId 55234 -Name 'TaleWorlds.MountAndBlade.Launcher' -Title 'M&B II: Bannerlord' -Path "$bannerlordRoot\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe" -Hwnd 202)
    )
}

$delta = Compare-Pr11ProcessSnapshots -BaselineSnapshot $s1 -AfterSnapshot $s2
$candidates = @(Get-Pr11WindowCandidates -Delta $delta -BannerlordRoot $bannerlordRoot)
$decision = Test-Pr11ClickAllowed -Candidates $candidates
if (-not $decision.allowed) {
    throw "expected window-delta winner to be allowed, got reason=$($decision.reason)"
}
if ([int]$decision.winner.pid -ne 55234) {
    throw "expected delta winner pid 55234 got $($decision.winner.pid)"
}
if ([int64]$decision.winner.hwnd -ne 202) {
    throw "expected delta winner hwnd 202 got $($decision.winner.hwnd)"
}
if (@($decision.winner.evidenceSignals) -notcontains 'new_pid_after_baseline') {
    throw 'window-delta winner must carry new_pid_after_baseline evidence'
}

Write-Host 'PASS offline launcher PID baseline diff anchors + behavioral policy'
