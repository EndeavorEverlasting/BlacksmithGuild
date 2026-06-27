param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$AllowManualDevSaveSetup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'ensure-dev-save.ps1') -RepoRoot $RepoRoot -AllowManualDevSaveSetup:$AllowManualDevSaveSetup

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
$result = Invoke-EnsureDevSave -BannerlordRoot $bannerlordRoot -LaunchIfNeeded -AllowManualDevSaveSetup:$AllowManualDevSaveSetup
Write-Host ("Governor dev save ready: {0}" -f $result.devSavePath) -ForegroundColor Green