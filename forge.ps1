# One-click entry point from repo root.
#   .\forge.ps1                  build + install (+ auto save backup)
#   .\forge.ps1 -Launch          build + install + open launcher
#   .\forge.ps1 -Check           build + install + scan status JSON + log
#   .\forge.ps1 -Check -SkipInstall   scan only (game may stay open)
#   .\forge.ps1 -Command AdvanceOneDay -Wait
#   .\forge.ps1 -Certify -Wait     full Sprint 001 cert via file inbox
#   .\forge.ps1 -CertifyProgression -Wait   Sprint 002 progression cert
#   .\forge.ps1 -Watch                 auto rebuild on source changes (ForgeWatch.cmd)

param(
    [switch]$Launch,
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'play',
    [switch]$LaunchManual,
    [switch]$Watch,
    [switch]$Check,
    [switch]$CollectDiagnostics,
    [switch]$BackupSaves,
    [switch]$VerifySaves,
    [switch]$SkipSaveBackup,
    [switch]$SkipInstall,
    [switch]$Wait,
    [switch]$Certify,
    [switch]$CertifyProgression,
    [switch]$VerifyLogPatterns,
    [ValidateSet('AutoLoop', 'Manual')]
    [string]$IterationMode,
    [string]$Command,
    [int]$TimeoutSec = 60,
    [int]$WatchDebounceSec = 2
)

if ($VerifyLogPatterns) {
    & (Join-Path $PSScriptRoot 'scripts\verify-log-grep-patterns.ps1')
    return
}

function Invoke-SaveBackupIfNeeded {
    if ($SkipSaveBackup) {
        Write-Host 'Save backup skipped (-SkipSaveBackup).' -ForegroundColor DarkGray
        return
    }

    . (Join-Path $PSScriptRoot 'scripts\backup-saves.ps1')
    Invoke-SaveBackupWorkflow | Out-Null
}

if ($VerifySaves) {
    & (Join-Path $PSScriptRoot 'scripts\verify-saves.ps1')
    return
}

if ($BackupSaves) {
    & (Join-Path $PSScriptRoot 'scripts\backup-saves.ps1') -FinalizeRun
    return
}

if ($CollectDiagnostics) {
    Invoke-SaveBackupIfNeeded
    & (Join-Path $PSScriptRoot 'scripts\collect-diagnostics.ps1')
    return
}

. (Join-Path $PSScriptRoot 'scripts\forge-status.ps1')

if ($Watch) {
    & (Join-Path $PSScriptRoot 'scripts\forge-watch.ps1') -WatchDebounceSec $WatchDebounceSec
    return
}

if ($Command -or $Certify -or $CertifyProgression) {
    $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $PSScriptRoot
    if ($Certify) {
        Invoke-ForgeCertification -BannerlordRoot $bannerlordRoot -TimeoutSec $TimeoutSec
        return
    }
    if ($CertifyProgression) {
        Invoke-ForgeProgressionCertification -BannerlordRoot $bannerlordRoot -TimeoutSec $TimeoutSec
        return
    }
    try {
        Send-ForgeCommand -CommandName $Command -BannerlordRoot $bannerlordRoot -Wait:$Wait -TimeoutSec $TimeoutSec | Out-Null
        exit 0
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

Invoke-SaveBackupIfNeeded

if ($Launch) {
    . (Join-Path $PSScriptRoot 'scripts\forge-status.ps1')
    $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $PSScriptRoot
    Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null

    if ($LaunchIntent -eq 'play') {
        & (Join-Path $PSScriptRoot 'scripts\write-character-build-launch-config.ps1') `
            -Mode UserVisible `
            -BannerlordRoot $bannerlordRoot | Out-Null
    }

    if ($IterationMode) {
        & (Join-Path $PSScriptRoot 'scripts\write-agent-iteration-config.ps1') `
            -Mode $IterationMode `
            -BannerlordRoot $bannerlordRoot `
            -LaunchIntent $LaunchIntent | Out-Null
    }
}

$installParams = @{}
if ($Launch) { $installParams.Launch = $true }
if ($Check) { $installParams.CheckLog = $true }
if ($SkipInstall) { $installParams.SkipInstall = $true }
if ($Launch) { $installParams.LaunchIntent = $LaunchIntent }
if ($LaunchManual) { $installParams.LaunchManual = $true }

& (Join-Path $PSScriptRoot 'scripts\install-mod.ps1') @installParams
