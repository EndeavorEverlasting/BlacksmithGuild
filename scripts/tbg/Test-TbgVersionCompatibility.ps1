<#
.SYNOPSIS
Detects installed Bannerlord version, checks compatibility with the mod,
and tells the user exactly which Steam beta to use if incompatible.
#>
param(
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',
    [string]$RepoRoot,
    [switch]$PassThru
)

$ErrorActionPreference = 'SilentlyContinue'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$events = [System.Collections.Generic.List[string]]::new()
function Log($m) { $ts = [DateTime]::UtcNow.ToString('HH:mm:ss'); $e = "[${ts}] $m"; Write-Host $e; $events.Add($e) }

Log "VERSION COMPATIBILITY CHECK"

# 1. Read the mod's expected version from registry
$compatPath = Join-Path $RepoRoot '.tbg\state\game-compatibility.registry.json'
$compat = if (Test-Path $compatPath) { Get-Content $compatPath -Raw | ConvertFrom-Json } else { $null }
$expectedVersion = if ($compat) { $compat.repoSupportedBuild.gameVersionPrefix } else { $null }
$expectedBuild = if ($compat) { $compat.repoSupportedBuild.certifiedSteamBuildIds[0] } else { $null }
Log "Mod expects: v$expectedVersion (build $expectedBuild)"

# 2. Detect installed version
$versionDll = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.Library.dll'
$installedVersion = $null
if (Test-Path $versionDll) {
    $ver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($versionDll)
    $installedVersion = $ver.FileVersion
    Log "Installed: v$installedVersion"
} else {
    Log "WARNING: TaleWorlds.Library.dll not found"
}

# 3. Check Steam app manifest for build ID
$appManifest = Join-Path (Split-Path $BannerlordRoot -Parent) 'appmanifest_261550.acf'
$installedBuild = $null
if (Test-Path $appManifest) {
    $content = Get-Content $appManifest -Raw
    $match = [regex]::Match($content, '"buildid"\s+"(\d+)"')
    if ($match.Success) {
        $installedBuild = $match.Groups[1].Value
        Log "Steam build ID: $installedBuild"
    }
}

# 4. Check SubModule.xml for declared dependencies
$submodulePath = Join-Path $RepoRoot 'Module\BlacksmithGuild\SubModule.xml'
$declaredVersion = $null
if (Test-Path $submodulePath) {
    $submodule = Get-Content $submodulePath -Raw
    $depMatch = [regex]::Match($submodule, 'DependentVersion="(v[\d.]+)"')
    if ($depMatch.Success) {
        $declaredVersion = $depMatch.Groups[1].Value
        Log "SubModule.xml declares: $declaredVersion"
    }
}

# 5. Compatibility verdict
$isCompatible = $false
$reason = $null

if ($expectedBuild -and $installedBuild) {
    if ($installedBuild -eq $expectedBuild) {
        $isCompatible = $true
        $reason = "Build match: installed $installedBuild == expected $expectedBuild"
    } else {
        $reason = "Build mismatch: installed $installedBuild != expected $expectedBuild"
    }
} elseif ($expectedVersion -and $installedVersion) {
    if ($installedVersion -like "$expectedVersion*") {
        $isCompatible = $true
        $reason = "Version match: installed $installedVersion starts with $expectedVersion"
    } else {
        $reason = "Version mismatch: installed $installedVersion != expected $expectedVersion"
    }
} else {
    $reason = "Cannot determine compatibility: missing version data"
}

Log "Verdict: $(if ($isCompatible) { 'COMPATIBLE' } else { 'INCOMPATIBLE' })"
Log "Reason: $reason"

# 6. Known incompatible versions
$knownIncompatible = @(
    @{ version = '1.4.7'; reason = 'BuyItemsAction removed'; fix = 'Switch to beta v1.4.6' }
    @{ version = '1.4.8'; reason = 'BuyItemsAction removed'; fix = 'Switch to beta v1.4.6' }
)

foreach ($incomp in $knownIncompatible) {
    if ($installedVersion -like "$($incomp.version)*" -or $installedBuild -eq $incomp.buildId) {
        Log "KNOWN INCOMPATIBILITY: v$($incomp.version) — $($incomp.reason)"
        Log "FIX: $($incomp.fix)"
        $isCompatible = $false
        $reason = $incomp.reason
    }
}

# 7. Available Steam betas (from known list — Steam does not expose via API)
$availableBetas = @(
    @{ name = 'Default Public Version'; version = '1.4.7'; date = 'Jul 9, 2026'; compatible = $false; note = 'BuyItemsAction removed' }
    @{ name = 'beta'; version = '1.4.5'; date = 'May 18, 2026'; compatible = $true; note = 'Recommended — has BuyItemsAction' }
    @{ name = 'v1.4.6'; version = '1.4.6'; date = 'Jun 11, 2026'; compatible = $true; note = 'Recommended — has BuyItemsAction' }
    @{ name = 'v1.4.5'; version = '1.4.5'; date = 'Jun 2, 2026'; compatible = $true; note = 'Has BuyItemsAction' }
    @{ name = 'v1.3.15'; version = '1.3.15'; date = 'Mar 2, 2026'; compatible = $false; note = 'Too old — mod requires v1.4.x' }
)

Log ""
Log "=== AVAILABLE STEAM BETAS ==="
foreach ($beta in $availableBetas) {
    $marker = if ($beta.compatible) { "  [OK]" } else { "  [--]" }
    $current = if ($installedVersion -like "$($beta.version)*") { " (INSTALLED)" } else { "" }
    Log "$marker $($beta.name) v$($beta.version) ($($beta.date))$current — $($beta.note)"
}

# 8. Recommendation
if (-not $isCompatible) {
    $rec = $availableBetas | Where-Object { $_.compatible } | Sort-Object { $_.version } -Descending | Select-Object -First 1
    Log ""
    Log "=== RECOMMENDATION ==="
    Log "Switch to: $($rec.name) v$($rec.version)"
    Log "How: Steam > Right-click Mount & Blade II Bannerlord > Properties > Game Versions & Betas > Select '$($rec.name)'"
}

# 9. Output
$result = [ordered]@{
    timestamp = [DateTime]::UtcNow.ToString('o')
    installedVersion = $installedVersion
    installedBuild = $installedBuild
    expectedVersion = $expectedVersion
    expectedBuild = $expectedBuild
    compatible = $isCompatible
    reason = $reason
    availableBetas = $availableBetas
    recommendation = if (-not $isCompatible -and $rec) { "$($rec.name) v$($rec.version)" } else { $null }
    events = $events.ToArray()
}

$outPath = Join-Path $RepoRoot 'artifacts\latest\version-compatibility.result.json'
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outPath -Encoding UTF8
Log "Output: $outPath"

if ($PassThru) { Write-Output $result }
