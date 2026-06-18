# Read-only verification of live saves vs incremental backup manifest.
# Usage: .\scripts\verify-saves.ps1

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'backup-saves.ps1')

function Get-SaveVerificationResults {
    $paths = Get-SaveBackupPaths
    $manifest = Get-BackupManifest -ManifestPath $paths.ManifestPath
    $results = @()

    if (-not (Test-Path -LiteralPath $paths.GameSaves)) {
        return @{
            Results = @()
            Error   = "Game Saves folder not found: $($paths.GameSaves)"
        }
    }

    $savFiles = Get-ChildItem -LiteralPath $paths.GameSaves -Filter '*.sav' -File -ErrorAction SilentlyContinue
    foreach ($sav in $savFiles) {
        $hash = (Get-FileHash -LiteralPath $sav.FullName -Algorithm SHA256).Hash
        $entry = $manifest.files[$sav.Name]

        $status = 'UNBACKED'
        $message = 'No backup manifest entry yet'

        if ($entry) {
            if ($entry.sha256 -eq $hash) {
                $status = 'SAFE'
                $message = "Matches backup ($($entry.latestBackupPath))"
            } else {
                $status = 'CHANGED_SINCE_BACKUP'
                $message = 'Live file changed since last backup; run forge.ps1 to back up'
            }
        }

        $results += [pscustomobject]@{
            Name   = $sav.Name
            Status = $status
            SizeMB = [math]::Round($sav.Length / 1MB, 1)
            Modified = $sav.LastWriteTime
            Message = $message
        }
    }

    return @{ Results = $results; Error = $null }
}

Start-ForgeStatusRun -Source 'verify-saves' -Operation 'verify'
Set-ForgeStep -Name 'verify_saves' -Status 'RUNNING'

$verification = Get-SaveVerificationResults
if ($verification.Error) {
    Set-ForgeStep -Name 'verify_saves' -Status 'FAIL' -Message $verification.Error
    Add-ForgeError $verification.Error
    $statusPath = Complete-ForgeStatusRun -Overall 'FAIL'
    Write-ForgeStatusSummary -StatusJsonPath $statusPath
    exit 1
}

Write-Host ''
Write-Host '=== Save verification (read-only) ===' -ForegroundColor Cyan
Write-Host "Live saves: $((Get-SaveBackupPaths).GameSaves)"
Write-Host "Backup root: $((Get-SaveBackupPaths).BackupRoot)"
Write-Host ''
Write-Host 'Legacy campaigns: disable The Blacksmith Guild in the launcher before loading.'
Write-Host ''

$overall = 'PASS'
foreach ($row in $verification.Results) {
    $color = switch ($row.Status) {
        'SAFE' { 'Green' }
        'UNBACKED' { 'Yellow'; if ($overall -eq 'PASS') { $overall = 'WARN' } }
        'CHANGED_SINCE_BACKUP' { 'Yellow'; if ($overall -eq 'PASS') { $overall = 'WARN' } }
        default { 'Gray' }
    }

    Set-ForgeTest -Name $row.Name -Status $row.Status -Message $row.Message
    Write-Host "[$($row.Status)] $($row.Name) ($($row.SizeMB) MB, $($row.Modified))" -ForegroundColor $color
    if ($row.Message) {
        Write-Host "         $($row.Message)" -ForegroundColor DarkGray
    }
}

if ($verification.Results.Count -eq 0) {
    Write-Host 'No .sav files found.' -ForegroundColor Yellow
    $overall = 'WARN'
}

Set-ForgeStep -Name 'verify_saves' -Status $(if ($overall -eq 'PASS') { 'PASS' } else { 'WARN' })
$statusPath = Complete-ForgeStatusRun -Overall $overall
Write-ForgeStatusSummary -StatusJsonPath $statusPath
