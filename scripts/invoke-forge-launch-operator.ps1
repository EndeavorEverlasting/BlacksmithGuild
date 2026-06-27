param(
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [int]$TimeoutSec = 300,
    [switch]$SkipSaveBackup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
$focusHelper = Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1'

try {
    if (Test-Path -LiteralPath $focusHelper) {
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
    if ($SkipSaveBackup) {
        & (Join-Path $RepoRoot 'forge.ps1') -Launch -LaunchIntent $LaunchIntent -SkipSaveBackup
    }
    else {
        & (Join-Path $RepoRoot 'forge.ps1') -Launch -LaunchIntent $LaunchIntent
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    $env:TBG_OPERATOR_INTERACTIVE_FOCUS = $oldInteractive
    $env:TBG_OPERATOR_INTERACTIVE_FOCUS_TIMEOUT_SEC = $oldTimeout
}