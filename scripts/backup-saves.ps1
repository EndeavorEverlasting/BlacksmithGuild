# Incremental copy-only backup for Bannerlord Game Saves (.sav files).
# Usage: .\scripts\backup-saves.ps1 [-FinalizeRun]

param(
    [switch]$FinalizeRun
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'forge-status.ps1')

function Get-SaveBackupPaths {
    $docsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
    $gameSaves = Join-Path $docsRoot 'Game Saves'
    $backupRoot = Join-Path $docsRoot 'BlacksmithGuild_SaveBackups'
    $manifestPath = Join-Path $backupRoot 'backup-manifest.json'

    return @{
        DocsRoot     = $docsRoot
        GameSaves    = $gameSaves
        BackupRoot   = $backupRoot
        ManifestPath = $manifestPath
    }
}

function Get-BackupManifest {
    param([string]$ManifestPath)

    $empty = [ordered]@{
        updatedAt = (Get-Date).ToString('o')
        files     = @{}
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return $empty
    }

    try {
        $json = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        $files = @{}
        if ($json.files) {
            foreach ($prop in $json.files.PSObject.Properties) {
                $files[$prop.Name] = $prop.Value
            }
        }

        return [ordered]@{
            updatedAt = $json.updatedAt
            files     = $files
        }
    } catch {
        Write-ForgeLogLine 'WARN backup manifest unreadable; starting fresh'
        return $empty
    }
}

function Save-BackupManifest {
    param(
        [string]$ManifestPath,
        $Manifest
    )

    $parent = Split-Path $ManifestPath -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $payload = [ordered]@{
        updatedAt = (Get-Date).ToString('o')
        files     = $Manifest.files
    }

    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

function Invoke-IncrementalSaveBackup {
    $paths = Get-SaveBackupPaths
    $counts = @{ backedUp = 0; skipped = 0; failed = 0 }

    if (-not (Test-Path -LiteralPath $paths.GameSaves)) {
        Write-Host "MISSING: $($paths.GameSaves)" -ForegroundColor Yellow
        Add-ForgeError "Game Saves folder not found: $($paths.GameSaves)"
        return $counts
    }

    if (-not (Test-Path -LiteralPath $paths.BackupRoot)) {
        New-Item -ItemType Directory -Force -Path $paths.BackupRoot | Out-Null
    }

    $manifest = Get-BackupManifest -ManifestPath $paths.ManifestPath
    $savFiles = Get-ChildItem -LiteralPath $paths.GameSaves -Filter '*.sav' -File -ErrorAction SilentlyContinue
    if (-not $savFiles) {
        Write-Host 'No .sav files found in Game Saves.' -ForegroundColor Yellow
        return $counts
    }

    foreach ($sav in $savFiles) {
        try {
            $hash = (Get-FileHash -LiteralPath $sav.FullName -Algorithm SHA256).Hash
            $existing = $manifest.files[$sav.Name]

            if ($existing -and $existing.sha256 -eq $hash) {
                Write-Host "SKIP unchanged: $($sav.Name)" -ForegroundColor DarkGray
                $counts.skipped++
                continue
            }

            $destDir = Join-Path $paths.BackupRoot $sav.Name
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            }

            $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $destFile = Join-Path $destDir "$stamp.sav"
            Copy-Item -LiteralPath $sav.FullName -Destination $destFile -Force

            $backupCount = 1
            if ($existing -and $existing.backupCount) {
                $backupCount = [int]$existing.backupCount + 1
            }

            $manifest.files[$sav.Name] = [ordered]@{
                sha256           = $hash
                size             = $sav.Length
                sourceModified   = $sav.LastWriteTime.ToString('o')
                lastBackedUp     = (Get-Date).ToString('o')
                latestBackupPath = $destFile
                backupCount      = $backupCount
            }

            Write-Host "BACKED UP: $($sav.Name) -> $destFile" -ForegroundColor Green
            Write-ForgeLogLine "BACKUP $($sav.Name) -> $destFile"
            $counts.backedUp++
        } catch {
            Write-Host "FAIL: $($sav.Name) - $($_.Exception.Message)" -ForegroundColor Red
            Add-ForgeError "Backup failed for $($sav.Name): $($_.Exception.Message)"
            $counts.failed++
        }
    }

    Save-BackupManifest -ManifestPath $paths.ManifestPath -Manifest $manifest
    return $counts
}

function Invoke-SaveBackupWorkflow {
    param([switch]$FinalizeRun)

    if (-not $script:ForgeStatusState) {
        Start-ForgeStatusRun -Source 'backup-saves' -Operation 'backup'
    }

    Set-ForgeStep -Name 'backup_saves' -Status 'RUNNING'
    $results = Invoke-IncrementalSaveBackup
    $stepStatus = if ($results.failed -gt 0) { 'WARN' } else { 'PASS' }
    $message = "backedUp=$($results.backedUp) skipped=$($results.skipped) failed=$($results.failed)"
    Set-ForgeStep -Name 'backup_saves' -Status $stepStatus -Message $message

    $paths = Get-SaveBackupPaths
    Write-Host ''
    Write-Host 'Save backup root:' $paths.BackupRoot
    Write-Host 'Backup manifest:' $paths.ManifestPath

    if ($FinalizeRun) {
        $overall = if ($results.failed -gt 0) { 'WARN' } else { 'PASS' }
        $statusPath = Complete-ForgeStatusRun -Overall $overall
        Write-ForgeStatusSummary -StatusJsonPath $statusPath
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-SaveBackupWorkflow -FinalizeRun:$FinalizeRun.IsPresent
}
