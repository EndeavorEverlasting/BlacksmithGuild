# Collect Bannerlord + BlacksmithGuild diagnostic evidence into one bundle.
# Usage: .\scripts\collect-diagnostics.ps1

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'forge-status.ps1')

Start-ForgeStatusRun -Source 'collect-diagnostics' -Operation 'collect'

function Get-RepoRoot {
    $root = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path (Join-Path $root 'src\BlacksmithGuild\BlacksmithGuild.csproj'))) {
        throw "Cannot find repo root from $PSScriptRoot"
    }
    return $root
}

function Get-BannerlordRoot {
    param([string]$RepoRoot)

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }

    return $null
}

function Get-ModuleVersion {
    param([string]$SubModuleXmlPath)

    if (-not (Test-Path -LiteralPath $SubModuleXmlPath)) { return 'not found' }
    try {
        [xml]$xml = Get-Content -LiteralPath $SubModuleXmlPath
        return $xml.Module.Version.value
    } catch {
        return 'unreadable'
    }
}

function Copy-IfExists {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [ref]$Copied,
        [ref]$Missing
    )

    if (Test-Path -LiteralPath $SourcePath) {
        $destParent = Split-Path $DestPath -Parent
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        }

        if (Test-Path -LiteralPath $SourcePath -PathType Container) {
            Copy-Item -Recurse -Force -LiteralPath $SourcePath -Destination $DestPath
        } else {
            Copy-Item -Force -LiteralPath $SourcePath -Destination $DestPath
        }

        Write-Host "COPIED: $SourcePath" -ForegroundColor Green
        $Copied.Value += $SourcePath
        return $true
    }

    Write-Host "MISSING: $SourcePath" -ForegroundColor Yellow
    $Missing.Value += $SourcePath
    return $false
}

function Copy-GlobIfExists {
    param(
        [string]$Pattern,
        [string]$DestDir,
        [ref]$Copied,
        [ref]$Missing
    )

    $parent = Split-Path $Pattern -Parent
    $leaf = Split-Path $Pattern -Leaf
    if (-not (Test-Path -LiteralPath $parent)) {
        Write-Host "MISSING: $Pattern" -ForegroundColor Yellow
        $Missing.Value += $Pattern
        return
    }

    $items = Get-ChildItem -LiteralPath $parent -Filter $leaf -ErrorAction SilentlyContinue
    if (-not $items) {
        Write-Host "MISSING: $Pattern" -ForegroundColor Yellow
        $Missing.Value += $Pattern
        return
    }

    foreach ($item in $items) {
        $dest = Join-Path $DestDir $item.Name
        Copy-IfExists -SourcePath $item.FullName -DestPath $dest -Copied $Copied -Missing $Missing | Out-Null
    }
}

$RepoRoot = Get-RepoRoot
$BannerlordRoot = Get-BannerlordRoot -RepoRoot $RepoRoot
$DocsRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutRoot = Join-Path $DocsRoot "BlacksmithGuild_Diagnostics\$timestamp"
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

Write-Host '=== The Blacksmith Guild: collect-diagnostics ===' -ForegroundColor Cyan
Write-Host "Output: $OutRoot"
Write-Host ''

$transcriptPath = Join-Path $OutRoot 'collector-transcript.txt'
Start-Transcript -LiteralPath $transcriptPath -Force | Out-Null

$copied = [System.Collections.Generic.List[string]]::new()
$missing = [System.Collections.Generic.List[string]]::new()
$cRef = [ref]$copied
$mRef = [ref]$missing

# BlacksmithGuild mod log
$modLogSources = @(
    (Join-Path $DocsRoot 'BlacksmithGuild_Phase1.log')
)
if ($BannerlordRoot) {
    $modLogSources += Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
}
foreach ($log in $modLogSources) {
    if (Test-Path -LiteralPath $log) {
        Copy-IfExists -SourcePath $log -DestPath (Join-Path $OutRoot "logs\$(Split-Path $log -Leaf)") -Copied $cRef -Missing $mRef | Out-Null
    } else {
        Write-Host "MISSING: $log" -ForegroundColor Yellow
        $missing.Add($log)
    }
}

$statusPaths = Get-ForgeStatusPaths
foreach ($statusFile in @($statusPaths.StatusJson, $statusPaths.ForgeLog)) {
    if (Test-Path -LiteralPath $statusFile) {
        Copy-IfExists -SourcePath $statusFile -DestPath (Join-Path $OutRoot "status\$(Split-Path $statusFile -Leaf)") -Copied $cRef -Missing $mRef | Out-Null
    } else {
        Write-Host "MISSING: $statusFile" -ForegroundColor Yellow
        $missing.Add($statusFile)
    }
}

$backupManifest = Join-Path $DocsRoot 'BlacksmithGuild_SaveBackups\backup-manifest.json'
Copy-IfExists -SourcePath $backupManifest -DestPath (Join-Path $OutRoot 'status\backup-manifest.json') -Copied $cRef -Missing $mRef | Out-Null

Set-ForgeStep -Name 'collect_sources' -Status 'RUNNING'

# Bannerlord logs and crashes under Documents
if (Test-Path -LiteralPath $DocsRoot) {
    Copy-GlobIfExists -Pattern (Join-Path $DocsRoot 'logs\*') -DestDir (Join-Path $OutRoot 'bannerlord-logs') -Copied $cRef -Missing $mRef
    Copy-GlobIfExists -Pattern (Join-Path $DocsRoot 'crashes\*') -DestDir (Join-Path $OutRoot 'bannerlord-crashes') -Copied $cRef -Missing $mRef
    Copy-IfExists -SourcePath (Join-Path $DocsRoot 'Configs\LauncherData.xml') -DestPath (Join-Path $OutRoot 'config\LauncherData.xml') -Copied $cRef -Missing $mRef | Out-Null
}

# rgl_log from install root
if ($BannerlordRoot) {
    Copy-GlobIfExists -Pattern (Join-Path $BannerlordRoot 'rgl_log*.txt') -DestDir (Join-Path $OutRoot 'bannerlord-logs') -Copied $cRef -Missing $mRef
}

# Module manifests and DLLs
$repoSubModule = Join-Path $RepoRoot 'Module\BlacksmithGuild\SubModule.xml'
Copy-IfExists -SourcePath $repoSubModule -DestPath (Join-Path $OutRoot 'module-repo\SubModule.xml') -Copied $cRef -Missing $mRef | Out-Null

$installedModulePath = $null
if ($BannerlordRoot) {
    $installedModulePath = Join-Path $BannerlordRoot 'Modules\BlacksmithGuild'
    $installedSubModule = Join-Path $installedModulePath 'SubModule.xml'
    Copy-IfExists -SourcePath $installedSubModule -DestPath (Join-Path $OutRoot 'module-installed\SubModule.xml') -Copied $cRef -Missing $mRef | Out-Null

    foreach ($dllRel in @(
        'bin\Win64_Shipping_Client\BlacksmithGuild.dll',
        'bin\Win64_Shipping_wEditor\BlacksmithGuild.dll'
    )) {
        $srcDll = Join-Path $installedModulePath $dllRel
        $destDll = Join-Path $OutRoot "module-installed\$dllRel"
        Copy-IfExists -SourcePath $srcDll -DestPath $destDll -Copied $cRef -Missing $mRef | Out-Null
    }
} else {
    Write-Host 'MISSING: Bannerlord install root (set GameFolder in csproj)' -ForegroundColor Yellow
    $missing.Add('Bannerlord install root')
}

# DLL metadata
$dllMeta = New-Object System.Collections.Generic.List[string]
$dllMeta.Add('DLL metadata')
$dllMeta.Add("Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
if ($BannerlordRoot -and $installedModulePath) {
    foreach ($dllRel in @(
        'bin\Win64_Shipping_Client\BlacksmithGuild.dll',
        'bin\Win64_Shipping_wEditor\BlacksmithGuild.dll'
    )) {
        $dllPath = Join-Path $installedModulePath $dllRel
        if (Test-Path -LiteralPath $dllPath) {
            $item = Get-Item -LiteralPath $dllPath
            $hash = (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash
            $dllMeta.Add("$dllRel | Size=$($item.Length) | Modified=$($item.LastWriteTime) | SHA256=$hash")
        } else {
            $dllMeta.Add("$dllRel | not found")
        }
    }
}
$dllMeta | Set-Content -LiteralPath (Join-Path $OutRoot 'dll-metadata.txt') -Encoding UTF8
Write-Host 'WROTE: dll-metadata.txt' -ForegroundColor Green

# Save folder metadata only (no save copies)
$saveMeta = New-Object System.Collections.Generic.List[string]
$saveMeta.Add('Game Saves folder metadata (no files copied)')
$saveFolder = Join-Path $DocsRoot 'Game Saves'
if (Test-Path -LiteralPath $saveFolder) {
    $saves = Get-ChildItem -LiteralPath $saveFolder -Recurse -File -ErrorAction SilentlyContinue
    $saveMeta.Add("Path: $saveFolder")
    $saveMeta.Add("File count: $($saves.Count)")
    if ($saves.Count -gt 0) {
        $latest = $saves | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $saveMeta.Add("Latest save write: $($latest.LastWriteTime) ($($latest.FullName))")
    }
} else {
    $saveMeta.Add("Path not found: $saveFolder")
}
$saveMeta | Set-Content -LiteralPath (Join-Path $OutRoot 'save-folder-metadata.txt') -Encoding UTF8
Write-Host 'WROTE: save-folder-metadata.txt' -ForegroundColor Green

# dotnet info
try {
    dotnet --info | Set-Content -LiteralPath (Join-Path $OutRoot 'dotnet-info.txt') -Encoding UTF8
    Write-Host 'WROTE: dotnet-info.txt' -ForegroundColor Green
} catch {
    Write-Host "WARN: dotnet --info failed: $_" -ForegroundColor Yellow
}

# Known-error pattern scan
$patterns = @(
    'missing beard tag',
    'has missing beard tag',
    'Null object',
    'Null Object References',
    'Craftingpieces',
    'Perks',
    'Traits',
    'BuildingTypes',
    'Policies',
    'Object reference not set',
    'TaleWorlds.Core',
    'BasicCharacterObject',
    'BasicCharacterObject.cs',
    'Assertion Failed',
    'Module mismatch',
    'different modules',
    'ListName: Items'
)

$scanExtensions = @('.log', '.txt', '.xml')
$matchRecords = [System.Collections.Generic.List[string]]::new()
$lordIds = [System.Collections.Generic.HashSet[string]]::new()

Get-ChildItem -LiteralPath $OutRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $scanExtensions -contains $_.Extension } |
    ForEach-Object {
        $lines = Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        if (-not $lines) { return }
        $rel = $_.FullName.Substring($OutRoot.Length).TrimStart('\')
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            foreach ($pat in $patterns) {
                if ($line -match [regex]::Escape($pat)) {
                    $matchRecords.Add("$rel`:$($i + 1): $line")
                }
            }
            if ($line -match '(lord_\d+_\d+_\d+)\s+has missing beard tag') {
                [void]$lordIds.Add($Matches[1])
            }
        }
    }

$repoVersion = Get-ModuleVersion -SubModuleXmlPath $repoSubModule
$installedVersion = 'not found'
if ($BannerlordRoot) {
    $installedVersion = Get-ModuleVersion -SubModuleXmlPath (Join-Path $BannerlordRoot 'Modules\BlacksmithGuild\SubModule.xml')
}

$modLogFound = $false
$passFound = $false
foreach ($log in $modLogSources) {
    if (Test-Path -LiteralPath $log) {
        $modLogFound = $true
        if (Select-String -LiteralPath $log -Pattern '[TBG TEST] PASS' -SimpleMatch -Quiet) {
            $passFound = $true
        }
        break
    }
}

$classification = 'No known error patterns detected in collected text files.'
if ($matchRecords.Count -gt 0) {
    $joined = ($matchRecords | ForEach-Object { $_.ToLower() }) -join ' '
    if ($joined -match 'has missing beard tag|basiccharacterobject') {
        $classification = 'FAIL: character/body XML integrity (beard tag assertion on lord character data)'
    } elseif ($joined -match 'craftingpieces|perks|traits|buildingtypes|policies|null object|listname: items') {
        $classification = 'FAIL: base game/module XML/data load integrity'
    } elseif ($joined -match 'module mismatch|different modules') {
        $classification = 'FAIL: existing save/module list mismatch'
    } else {
        $classification = 'WARN: error-like patterns found; review matched lines below'
    }
}
if (-not $modLogFound) {
    $classification += ' | BlacksmithGuild may not have loaded before crash'
}

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('BlacksmithGuild Diagnostic Summary')
$summary.Add("Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$summary.Add("Repo: $RepoRoot")
$summary.Add("Bannerlord root: $(if ($BannerlordRoot) { $BannerlordRoot } else { 'not found' })")
$summary.Add("Installed module: $(if ($installedModulePath) { $installedModulePath } else { 'not found' })")
$summary.Add("BlacksmithGuild repo version: $repoVersion")
$summary.Add("BlacksmithGuild installed version: $installedVersion")
$summary.Add("BlacksmithGuild_Phase1.log found: $modLogFound")
$summary.Add("[TBG TEST] PASS found: $passFound")

$backupManifestPath = Join-Path $DocsRoot 'BlacksmithGuild_SaveBackups\backup-manifest.json'
$backedSaveCount = 0
if (Test-Path -LiteralPath $backupManifestPath) {
    try {
        $bm = Get-Content -LiteralPath $backupManifestPath -Raw | ConvertFrom-Json
        if ($bm.files) {
            $backedSaveCount = @($bm.files.PSObject.Properties).Count
        }
    } catch { }
}
$summary.Add("Save backups in manifest: $backedSaveCount (see BlacksmithGuild_SaveBackups)")
$summary.Add('Save safety: legacy saves load with mod disabled; backups are copy-only.')
$summary.Add('')
$summary.Add('Detected issues:')
if ($matchRecords.Count -eq 0) {
    $summary.Add('- (none)')
} else {
    $uniquePatterns = $matchRecords | ForEach-Object {
        if ($_ -match ':\s*(.+)$') { $Matches[1].Trim() }
    } | Sort-Object -Unique
    foreach ($u in $uniquePatterns) {
        $summary.Add("- $u")
    }
}
if ($lordIds.Count -gt 0) {
    $summary.Add('')
    $summary.Add('Lord IDs with missing beard tag:')
    foreach ($id in ($lordIds | Sort-Object)) {
        $summary.Add("- $id")
    }
}
$summary.Add('')
$summary.Add("Likely class: $classification")
$summary.Add('')
$summary.Add('Next step:')
$summary.Add('Do not certify Sprint 000A. Test on a new disposable campaign.')
$summary.Add('Verify Native, SandBoxCore, Sandbox, and StoryMode are enabled.')
$summary.Add('Verify game file integrity (Steam verify) if errors persist.')
$summary.Add('Share this file and the diagnostic zip if needed.')
$summary.Add('')
$summary.Add('Matched file lines:')
if ($matchRecords.Count -eq 0) {
    $summary.Add('- (none)')
} else {
    foreach ($rec in ($matchRecords | Select-Object -First 50)) {
        $summary.Add("- $rec")
    }
    if ($matchRecords.Count -gt 50) {
        $summary.Add("- ... and $($matchRecords.Count - 50) more matches")
    }
}

$summaryPath = Join-Path $OutRoot 'diagnostic-summary.txt'
$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host ''
Write-Host "WROTE: $summaryPath" -ForegroundColor Green

Stop-Transcript | Out-Null

$zipPath = Join-Path (Split-Path $OutRoot -Parent) "BlacksmithGuild_Diagnostics_$timestamp.zip"
try {
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -LiteralPath $OutRoot -DestinationPath $zipPath -Force
    Write-Host "ZIP: $zipPath" -ForegroundColor Green
} catch {
    Write-Host "WARN: Could not create zip: $_" -ForegroundColor Yellow
    $zipPath = '(zip failed)'
}

Write-Host ''
Write-Host 'Diagnostic collection complete.' -ForegroundColor Cyan
Write-Host "Folder: $OutRoot"
Write-Host "Summary: $summaryPath"
Write-Host "Zip: $zipPath"

Set-ForgeStep -Name 'collect_sources' -Status 'PASS' -Message $OutRoot
Set-ForgeStep -Name 'write_summary' -Status 'PASS' -Message $summaryPath
if ($matchRecords.Count -gt 0) {
    Add-ForgeError "Detected $($matchRecords.Count) error pattern matches. See diagnostic-summary.txt."
}
$overall = if ($matchRecords.Count -gt 0) { 'WARN' } else { 'PASS' }
$statusPath = Complete-ForgeStatusRun -Overall $overall
Write-ForgeStatusSummary -StatusJsonPath $statusPath
