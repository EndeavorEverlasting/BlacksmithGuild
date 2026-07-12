param(
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [int]$TimeoutSec = 300,
    [switch]$SkipSaveBackup,
    [switch]$AllowFocusSteal
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
$focusHelper = Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1'

try {
    if ($AllowFocusSteal -and (Test-Path -LiteralPath $focusHelper)) {
        & $focusHelper | Out-Null
    }
} catch {
    Write-Host "Initial focus helper warning: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

$oldInteractive = $env:TBG_OPERATOR_INTERACTIVE_FOCUS
$oldTimeout = $env:TBG_OPERATOR_INTERACTIVE_FOCUS_TIMEOUT_SEC
try {
    $env:TBG_OPERATOR_INTERACTIVE_FOCUS = '1'
    $env:TBG_OPERATOR_INTERACTIVE_FOCUS_TIMEOUT_SEC = [string]$TimeoutSec
    $forgeParams = @{ Launch = $true; LaunchIntent = $LaunchIntent; LaunchManual = $true }
    if ($SkipSaveBackup) { $forgeParams.SkipSaveBackup = $true }
    if ($AllowFocusSteal) { $forgeParams.AllowFocusSteal = $true }
    & (Join-Path $RepoRoot 'forge.ps1') @forgeParams
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $frontdoor = Join-Path $PSScriptRoot 'launcher-fast-frontdoor.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $frontdoor `
        -LaunchIntent $LaunchIntent -TotalBudgetSec 30 -PhaseBudgetSec 5 -MaxAttempts 2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    $env:TBG_OPERATOR_INTERACTIVE_FOCUS = $oldInteractive
    $env:TBG_OPERATOR_INTERACTIVE_FOCUS_TIMEOUT_SEC = $oldTimeout
}
