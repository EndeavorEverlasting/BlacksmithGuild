# Build/install/verify, then open Bannerlord launcher only on clean Forge PASS.
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host ''
Write-Host 'The Blacksmith Guild - Forge and Launch' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Step 1: Build, install, verify' -ForegroundColor Cyan

& (Join-Path $RepoRoot 'forge.ps1')
$forgeExit = $LASTEXITCODE

. (Join-Path $PSScriptRoot 'forge-status.ps1')
$statusPath = (Get-ForgeStatusPaths).StatusJson

Write-Host ''
Write-Host 'Step 2: Checking Forge status for launcher...' -ForegroundColor Cyan
. (Join-Path $PSScriptRoot 'forge-launch-on-pass.ps1')

if (Test-ForgeCleanPass -StatusJsonPath $statusPath) {
    Write-Host ''
    Write-Host 'Step 3: Opening Bannerlord launcher...' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1')
} else {
    Write-Host ''
    Write-Host 'Launcher will not be opened.' -ForegroundColor Yellow
}

exit $forgeExit
