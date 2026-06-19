# Opens the Bannerlord launcher (shared by LaunchForge.cmd and ForgeAndLaunch.cmd).
param(
    [string]$BannerlordRoot
)

$ErrorActionPreference = 'Stop'

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

foreach ($procName in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher')) {
    if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
        throw "Bannerlord is already running ($procName). Close it before opening the launcher."
    }
}

Write-Host 'Opening Bannerlord launcher...' -ForegroundColor Cyan
Start-Process -FilePath $LauncherExe -WorkingDirectory (Split-Path -Parent $LauncherExe)
