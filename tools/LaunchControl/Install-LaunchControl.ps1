param(
    [switch]$NoDesktopShortcut,
    [switch]$NoStartMenuShortcut,
    [switch]$NoTaskbarHelper
)

$ErrorActionPreference = 'Stop'

function Get-InstallRepoRoot {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Write-JsonFile {
    param([string]$Path, $Payload)
    $Payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-LaunchControlConfigIfMissing {
    param([string]$RepoRoot)
    $configPath = Join-Path $PSScriptRoot 'Launch-Control.generated.local.json'
    if (Test-Path -LiteralPath $configPath) { return $configPath }
    $payload = [ordered]@{
        launchMode = 'New'
        bannerlordInstallPath = $null
        repoPath = $RepoRoot
        lastCommand = $null
        lastRunUtc = $null
        createDesktopShortcut = (-not $NoDesktopShortcut)
        createStartMenuShortcut = (-not $NoStartMenuShortcut)
        createTaskbarHelper = (-not $NoTaskbarHelper)
        showConsole = $true
        writeEvidence = $true
        defaultNewCommand = 'LaunchNew'
        defaultContinueCommand = 'LaunchContinue'
        oneClickLaunch = $false
        postLaunchCommand = $null
        notes = @('Generated locally by Install-LaunchControl.ps1. Machine-specific; do not commit.')
    }
    Write-JsonFile -Path $configPath -Payload $payload
    return $configPath
}

function New-WindowsShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$WorkingDirectory,
        [string]$Description
    )
    $parent = Split-Path -Parent $ShortcutPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $shortcut.Save()
}

$repoRoot = Get-InstallRepoRoot
$configPath = New-LaunchControlConfigIfMissing -RepoRoot $repoRoot
$cmdPath = Join-Path $PSScriptRoot 'Launch-Control.cmd'
$generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
$isWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT'

$desktop = [ordered]@{ requested = (-not $NoDesktopShortcut); created = $false; path = $null; reason = $null }
$startMenu = [ordered]@{ requested = (-not $NoStartMenuShortcut); created = $false; path = $null; reason = $null }
$taskbar = [ordered]@{
    requested = (-not $NoTaskbarHelper)
    automatedPinAttempted = $false
    createdHelper = $false
    manualPinInstructionsWritten = $true
    reason = 'Windows taskbar pinning may be blocked by OS policy. Right-click the Desktop shortcut or Start Menu entry and choose Pin to taskbar.'
}

if (-not (Test-Path -LiteralPath $cmdPath)) { throw "Missing Launch-Control.cmd at $cmdPath" }

if ($isWindows) {
    if ($desktop.requested) {
        $desktop.path = Join-Path ([Environment]::GetFolderPath('Desktop')) 'The Blacksmith Guild - Launch Control.lnk'
        New-WindowsShortcut -ShortcutPath $desktop.path -TargetPath $cmdPath -WorkingDirectory $repoRoot -Description 'Open TBG Launch Control menu'
        $desktop.created = $true
    }
    if ($startMenu.requested) {
        $programs = [Environment]::GetFolderPath('Programs')
        $startMenu.path = Join-Path (Join-Path $programs 'The Blacksmith Guild') 'The Blacksmith Guild - Launch Control.lnk'
        New-WindowsShortcut -ShortcutPath $startMenu.path -TargetPath $cmdPath -WorkingDirectory $repoRoot -Description 'Open TBG Launch Control menu'
        $startMenu.created = $true
    }
} else {
    $desktop.reason = 'Shortcut creation skipped because this installer is not running on Windows.'
    $startMenu.reason = 'Shortcut creation skipped because this installer is not running on Windows.'
}

$instructionsPath = Join-Path $PSScriptRoot 'TASKBAR-PINNING.txt'
@'
TBG Launch Control taskbar pinning

Windows taskbar pinning is not reliably scriptable on modern Windows.

Manual options:
1. Right-click the Desktop shortcut: The Blacksmith Guild - Launch Control
2. Choose Pin to taskbar

or:
1. Open Start Menu
2. Find The Blacksmith Guild - Launch Control
3. Right-click and choose Pin to taskbar
'@ | Set-Content -LiteralPath $instructionsPath -Encoding UTF8

$installEvidence = [ordered]@{
    generatedUtc = $generatedUtc
    source = 'Install-LaunchControl.ps1'
    repoPath = $repoRoot
    desktopShortcut = $desktop
    startMenuShortcut = $startMenu
    taskbar = $taskbar
    configPath = $configPath
    defaultLaunchMode = 'New'
    verdict = if ($isWindows) { 'Launch Control installed' } else { 'Launch Control config installed; Windows shortcuts skipped on non-Windows host' }
}

$rootEvidence = Join-Path $repoRoot 'BlacksmithGuild_LaunchControlInstall.json'
Write-JsonFile -Path $rootEvidence -Payload $installEvidence
$latest = Join-Path $repoRoot 'docs\evidence\latest'
if (Test-Path -LiteralPath $latest) {
    Write-JsonFile -Path (Join-Path $latest 'BlacksmithGuild_LaunchControlInstall.json') -Payload $installEvidence
}

& (Join-Path $PSScriptRoot 'Launch-Control.ps1') -ShowConfig | Out-Null

Write-Host 'TBG Launch Control install complete.' -ForegroundColor Green
Write-Host "Config: $configPath"
Write-Host "Desktop shortcut: $($desktop.path) created=$($desktop.created)"
Write-Host "Start Menu shortcut: $($startMenu.path) created=$($startMenu.created)"
Write-Host "Taskbar: manual pin instructions written to $instructionsPath"
Write-Host "Evidence: $rootEvidence"
