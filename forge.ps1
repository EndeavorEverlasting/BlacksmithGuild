# One-click entry point from repo root.
#   .\forge.ps1                  build + install
#   .\forge.ps1 -Launch          build + install + open launcher
#   .\forge.ps1 -Check           build + install + scan acceptance log
#   .\forge.ps1 -CollectDiagnostics  collect crash/log diagnostic bundle

param(
    [switch]$Launch,
    [switch]$Check,
    [switch]$CollectDiagnostics
)

if ($CollectDiagnostics) {
    & (Join-Path $PSScriptRoot 'scripts\collect-diagnostics.ps1')
    return
}

$installParams = @{}
if ($Launch) { $installParams.Launch = $true }
if ($Check) { $installParams.CheckLog = $true }

& (Join-Path $PSScriptRoot 'scripts\install-mod.ps1') @installParams
