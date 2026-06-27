# Opens the Bannerlord launcher (shared by LaunchForge.cmd and ForgeAndLaunch.cmd).
param(
    [string]$BannerlordRoot,
    [switch]$AllowExistingProcess
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')

function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot)
    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }
    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }
    throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
}

if (-not $BannerlordRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
}

$LauncherExe = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe'
$GameExe = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\Bannerlord.exe'

if (-not (Test-Path -LiteralPath $LauncherExe)) {
    throw "Launcher not found: $LauncherExe"
}

# Distinguish the actual game process (Bannerlord.exe) from the launcher
# (TaleWorlds.MountAndBlade.Launcher.exe). An already-running launcher is the target, not a blocker;
# only a running game process needs Forge Stop approval before we open the launcher.
$gameRunning = [bool](Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)
$launcherRunning = [bool](Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue)
$preflightOk = $false
if (Get-Command Test-TbgPreflightCompleted -ErrorAction SilentlyContinue) { $preflightOk = Test-TbgPreflightCompleted }

# Case 2: the actual game is running. Reuse is unsafe without Forge Stop approval.
# -AllowExistingProcess signals that approval (save/cancel) has already been granted upstream.
if ($gameRunning -and -not $AllowExistingProcess -and -not $preflightOk) {
    throw "Bannerlord game is already running (Bannerlord.exe). Forge Stop approval (save then stop, or stop without saving) is required before opening the launcher."
}

# Case 1: only the launcher is running (no game). Reuse the existing launcher instead of starting a
# second one; launcher-auto-nav.ps1 -LaunchSetup binds it via the baseline PID/window selection.
if ($launcherRunning -and -not $gameRunning) {
    & (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $BannerlordRoot -Message 'open-launcher: existing launcher detected; reusing'
    Write-Host 'open-launcher: existing launcher detected; reusing' -ForegroundColor Cyan
    $s1Snapshot = Get-Pr11ProcessSnapshot -Label 'S1_pre_launch' -BannerlordRoot $BannerlordRoot
    Save-Pr11ProcessSnapshot -Snapshot $s1Snapshot -OutputPath (Join-Path $BannerlordRoot 'window-snapshot-S1-pre-launch.json') | Out-Null
    return
}

Write-Host 'Opening Bannerlord launcher...' -ForegroundColor Cyan
$s1Snapshot = Get-Pr11ProcessSnapshot -Label 'S1_pre_launch' -BannerlordRoot $BannerlordRoot
Save-Pr11ProcessSnapshot -Snapshot $s1Snapshot -OutputPath (Join-Path $BannerlordRoot 'window-snapshot-S1-pre-launch.json') | Out-Null
& (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $BannerlordRoot -Message "open-launcher: Start-Process $LauncherExe"
Start-Process -FilePath $LauncherExe -WorkingDirectory (Split-Path -Parent $LauncherExe)
Start-Sleep -Seconds 2
& (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $BannerlordRoot -Message 'open-launcher: TaleWorlds.MountAndBlade.Launcher.exe started (2s post-start delay before UIA poll)'
