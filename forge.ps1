# One-click entry point from repo root.
#   .\forge.ps1                  build + install (+ auto save backup)
#   .\forge.ps1 -Launch          build + install + open launcher
#   .\forge.ps1 -Command AdvanceOneDay   write command to in-game inbox
#   .\forge.ps1 -Check           build + install + scan status JSON + log

param(
    [switch]$Launch,
    [switch]$Check,
    [switch]$CollectDiagnostics,
    [switch]$BackupSaves,
    [switch]$VerifySaves,
    [switch]$SkipSaveBackup,
    [string]$Command
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

if ($Command) {
    . (Join-Path $PSScriptRoot 'scripts\forge-status.ps1')
    $bannerlordRoot = & {
        $csproj = Join-Path $PSScriptRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
        if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
            $fromCsproj = $Matches[1] -replace '&amp;', '&'
            if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
        }
        $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
        if (Test-Path -LiteralPath $default) { return $default }
        throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
    }
    Send-ForgeCommand -CommandName $Command -BannerlordRoot $bannerlordRoot
    return
}

Invoke-SaveBackupIfNeeded

$installParams = @{}
if ($Launch) { $installParams.Launch = $true }
if ($Check) { $installParams.CheckLog = $true }

& (Join-Path $PSScriptRoot 'scripts\install-mod.ps1') @installParams
