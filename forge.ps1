# One-click entry point from repo root.
#   .\forge.ps1                  build + install (+ auto save backup)
#   .\forge.ps1 -Launch          build + install + open launcher
#   .\forge.ps1 -Check           build + install + scan status JSON + log
#   .\forge.ps1 -Check -SkipInstall   scan only (game may stay open)
#   .\forge.ps1 -Command AdvanceOneDay -Wait
#   .\forge.ps1 -Certify -Wait     full Sprint 001 cert via file inbox

param(
    [switch]$Launch,
    [switch]$Check,
    [switch]$CollectDiagnostics,
    [switch]$BackupSaves,
    [switch]$VerifySaves,
    [switch]$SkipSaveBackup,
    [switch]$SkipInstall,
    [switch]$Wait,
    [switch]$Certify,
    [string]$Command,
    [int]$TimeoutSec = 60
)

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

if ($Command -or $Certify) {
    $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $PSScriptRoot
    if ($Certify) {
        Invoke-ForgeCertification -BannerlordRoot $bannerlordRoot -TimeoutSec $TimeoutSec
        return
    }
    Send-ForgeCommand -CommandName $Command -BannerlordRoot $bannerlordRoot -Wait:$Wait -TimeoutSec $TimeoutSec
    return
}

Invoke-SaveBackupIfNeeded

$installParams = @{}
if ($Launch) { $installParams.Launch = $true }
if ($Check) { $installParams.CheckLog = $true }
if ($SkipInstall) { $installParams.SkipInstall = $true }

& (Join-Path $PSScriptRoot 'scripts\install-mod.ps1') @installParams
