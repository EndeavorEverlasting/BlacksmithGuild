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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$events = [System.Collections.Generic.List[string]]::new()
function Log($m) { $ts = [DateTime]::UtcNow.ToString('HH:mm:ss'); $e = "[${ts}] $m"; Write-Host $e; $events.Add($e) }

function Get-NormalizedVersionPrefix {
    # Returns the leading dotted numeric version (e.g. "v1.4.7" -> "1.4.7"); $null if none.
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $m = [regex]::Match($Value, '(\d+\.\d+\.\d+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

Log "VERSION COMPATIBILITY CHECK"

# 1. Read the mod's expected version from registry (single supported baseline).
$compatPath = Join-Path $RepoRoot '.tbg\state\game-compatibility.registry.json'
$compat = if (Test-Path -LiteralPath $compatPath) { Get-Content -LiteralPath $compatPath -Raw | ConvertFrom-Json } else { $null }
$expectedVersion = if ($compat) { [string]$compat.repoSupportedBuild.gameVersionPrefix } else { $null }
$expectedBuild = if ($compat -and @($compat.repoSupportedBuild.certifiedSteamBuildIds).Count -gt 0) {
    [string]$compat.repoSupportedBuild.certifiedSteamBuildIds[0]
} else { $null }
Log "Mod expects: v$expectedVersion (build $expectedBuild)"

# 2. Detect installed version from Native/SubModule.xml <Version value="vX.Y.Z" />.
#    TaleWorlds.Library.dll FileVersion is always 1.0.0.0, so it is not a valid source.
$nativeSubModule = Join-Path $BannerlordRoot 'Modules\Native\SubModule.xml'
$installedVersion = $null
if (Test-Path -LiteralPath $nativeSubModule) {
    try {
        [xml]$nativeXml = Get-Content -LiteralPath $nativeSubModule -Raw -Encoding UTF8
        $rawVersion = [string]$nativeXml.Module.Version.value
        $installedVersion = Get-NormalizedVersionPrefix -Value $rawVersion
        if ($installedVersion) {
            Log "Installed (Native SubModule.xml): v$installedVersion"
        } else {
            Log "WARNING: Native SubModule.xml Version value not parseable: '$rawVersion'"
        }
    } catch {
        Log "WARNING: failed to read Native SubModule.xml: $($_.Exception.Message)"
    }
} else {
    Log "WARNING: Native SubModule.xml not found at $nativeSubModule"
}

# 3. Check Steam app manifest for build ID (secondary identity + fallback).
$appManifest = Join-Path (Split-Path $BannerlordRoot -Parent) 'appmanifest_261550.acf'
$installedBuild = $null
if (Test-Path -LiteralPath $appManifest) {
    $content = Get-Content -LiteralPath $appManifest -Raw -Encoding UTF8
    $match = [regex]::Match($content, '"buildid"\s+"(\d+)"')
    if ($match.Success) {
        $installedBuild = $match.Groups[1].Value
        Log "Steam build ID: $installedBuild"
    }
}

# 4. Compatibility verdict: only the single supported baseline is compatible.
$expectedPrefix = Get-NormalizedVersionPrefix -Value $expectedVersion
$isCompatible = $false
$reason = $null

if ($installedVersion -and $expectedPrefix) {
    if ($installedVersion -eq $expectedPrefix) {
        $isCompatible = $true
        $reason = "Version match: installed v$installedVersion == supported v$expectedPrefix"
    } else {
        $reason = "Version mismatch: installed v$installedVersion != supported v$expectedPrefix"
    }
} elseif ($installedBuild -and $expectedBuild) {
    if ($installedBuild -eq $expectedBuild) {
        $isCompatible = $true
        $reason = "Build match: installed $installedBuild == certified $expectedBuild"
    } else {
        $reason = "Build mismatch: installed $installedBuild != certified $expectedBuild"
    }
} else {
    $reason = "Cannot determine compatibility: missing installed version and build id"
}

Log "Verdict: $(if ($isCompatible) { 'COMPATIBLE' } else { 'INCOMPATIBLE' })"
Log "Reason: $reason"

# 5. Recommendation when incompatible: install the single supported baseline.
if (-not $isCompatible) {
    Log ""
    Log "=== RECOMMENDATION ==="
    Log "Install/select supported baseline: Bannerlord v$expectedPrefix (build $expectedBuild)."
    Log "How: Steam > Right-click Mount & Blade II Bannerlord > Properties > Game Versions & Betas > select the version that reports v$expectedPrefix."
}

# 6. Output
$result = [ordered]@{
    timestamp = [DateTime]::UtcNow.ToString('o')
    installedVersion = $installedVersion
    installedBuild = $installedBuild
    expectedVersion = $expectedPrefix
    expectedBuild = $expectedBuild
    compatible = $isCompatible
    reason = $reason
    supportedBaseline = "v$expectedPrefix (build $expectedBuild)"
    recommendation = if (-not $isCompatible) { "Install supported baseline v$expectedPrefix" } else { $null }
    events = $events.ToArray()
}

$outDir = Join-Path $RepoRoot 'artifacts\latest'
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$outPath = Join-Path $outDir 'version-compatibility.result.json'
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outPath -Encoding UTF8
Log "Output: $outPath"

if ($PassThru) { Write-Output $result }
