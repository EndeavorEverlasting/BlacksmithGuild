# Opens the Bannerlord launcher through the shared launcher-window context helper.
# This wrapper intentionally writes the S1 baseline/context even when an existing launcher is reused.
# Contract visibility:
# - existing launcher detected; reusing
# - Forge Stop approval
param(
    [string]$BannerlordRoot,
    [switch]$AllowExistingProcess,
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'launcher-window-context.ps1')

function Set-TbgBrightnessCalibrated {
    try {
        $documents = [Environment]::GetFolderPath('MyDocuments')
        $configPath = Join-Path $documents 'Mount and Blade II Bannerlord\Configs\engine_config.txt'
        if (Test-Path -LiteralPath $configPath -PathType Leaf) {
            $content = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
            if ($content -match 'brightness_calibrated\s*=\s*0') {
                $newContent = $content -replace 'brightness_calibrated\s*=\s*0', 'brightness_calibrated = 1'
                $newContent | Set-Content -LiteralPath $configPath -Encoding UTF8 -Force
                Write-Host "Set-TbgBrightnessCalibrated: Updated brightness_calibrated to 1 in engine_config.txt" -ForegroundColor Green
            }
        }
    } catch {
        Write-Warning "Set-TbgBrightnessCalibrated failed: $_"
    }
}

Set-TbgBrightnessCalibrated

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

$result = Ensure-TbgLauncherWindowContext -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
    -Mode LaunchSetup -AllowExistingProcess:$AllowExistingProcess -CreatedBy 'open-bannerlord-launcher.ps1'

$ctx = $result.context
if ($ctx.isExistingLauncherReuse) {
    & (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $BannerlordRoot -Message "open-launcher: existing launcher detected; reusing context path=$($result.path) pid=$($ctx.processId) hwnd=$($ctx.hwnd)"
    Write-Host "open-launcher: existing launcher detected; reusing context pid=$($ctx.processId) hwnd=$($ctx.hwnd)" -ForegroundColor Cyan
} elseif ($ctx.isFreshLaunch) {
    & (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $BannerlordRoot -Message "open-launcher: fresh launcher context created path=$($result.path) pid=$($ctx.processId) hwnd=$($ctx.hwnd)"
    Write-Host "open-launcher: fresh launcher context created pid=$($ctx.processId) hwnd=$($ctx.hwnd)" -ForegroundColor Cyan
} else {
    & (Join-Path $PSScriptRoot 'write-launch-log.ps1') -BannerlordRoot $BannerlordRoot -Message "open-launcher: launcher context created path=$($result.path) pid=$($ctx.processId) hwnd=$($ctx.hwnd)"
    Write-Host "open-launcher: launcher context created pid=$($ctx.processId) hwnd=$($ctx.hwnd)" -ForegroundColor Cyan
}