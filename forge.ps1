# One-click entry point from repo root.
#   .\forge.ps1                  build + install (+ auto save backup)
#   .\forge.ps1 -Launch          build + install + open launcher
#   .\forge.ps1 -Check           build + install + scan acceptance log
#   .\forge.ps1 -CollectDiagnostics  collect crash/log diagnostic bundle
#   .\forge.ps1 -BackupSaves     incremental save backup only
#   .\forge.ps1 -VerifySaves     read-only save safety check
#   .\forge.ps1 -SkipSaveBackup  opt out of automatic save backup

param(
    [switch]$Launch,
    [switch]$Check,
    [switch]$CollectDiagnostics,
    [switch]$BackupSaves,
    [switch]$VerifySaves,
    [switch]$SkipSaveBackup
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

Invoke-SaveBackupIfNeeded

$installParams = @{}
if ($Launch) { $installParams.Launch = $true }
if ($Check) { $installParams.CheckLog = $true }

& (Join-Path $PSScriptRoot 'scripts\install-mod.ps1') @installParams
