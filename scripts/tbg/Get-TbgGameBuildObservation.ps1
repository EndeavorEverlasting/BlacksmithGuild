<#
.SYNOPSIS
    Detects local Bannerlord game build identity and compares with support registry.

.DESCRIPTION
    Reads the installed game directory, Steam app manifest, SubModule.xml, and DLL
    metadata to determine the locally installed game version. Persists observations
    through the canonical state spine and produces a compatibility result.

    This script does NOT launch Bannerlord, mutate saves, force Steam updates, or
    commit proprietary files.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$BannerlordRoot = '',
    [string]$OutputRoot = 'artifacts/latest/game-update',
    [switch]$DetectUpstream,
    [switch]$SkipAssessment
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $callerDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $RepoRoot = (Resolve-Path (Join-Path $callerDir '..\..')).Path
}

$compatDir = Join-Path $RepoRoot '.tbg\compatibility'
$supportPath = Join-Path $compatDir 'bannerlord-support.json'
$baselinePath = Join-Path $compatDir 'bannerlord-api-baseline.json'
$outDir = Join-Path $RepoRoot $OutputRoot
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

. (Join-Path $RepoRoot 'scripts\bannerlord-paths.ps1')

$nowUtc = (Get-Date).ToUniversalTime()
$observationId = "observation:game-build-$($nowUtc.ToString('yyyyMMddHHmmss'))"

$installedIdentity = $null
$detectionSource = 'install-directory'
$detectionSuccess = $false
$detectionError = ''

try {
    if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) {
        $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    }

    $friendlyVersion = ''
    $buildNumber = ''
    $moduleVersion = ''
    $dllProductVersion = ''
    $dllFileVersion = ''
    $dllSha256 = ''
    $installPath = $BannerlordRoot

    $dllPath = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.dll'
    if (Test-Path -LiteralPath $dllPath) {
        $versionInfo = Get-Item -LiteralPath $dllPath | Select-Object -ExpandProperty VersionInfo
        $dllProductVersion = [string]$versionInfo.ProductVersion
        $dllFileVersion = [string]$versionInfo.FileVersion
        $friendlyVersion = $dllProductVersion
        try {
            $hash = Get-FileHash -LiteralPath $dllPath -Algorithm SHA256
            $dllSha256 = "sha256:$($hash.Hash.ToLowerInvariant())"
        } catch { }
        $detectionSource = 'dll-metadata'
        $detectionSuccess = $true
    }

    $submodulePath = Join-Path $RepoRoot 'Module\BlacksmithGuild\SubModule.xml'
    if (Test-Path -LiteralPath $submodulePath) {
        $xml = [xml](Get-Content -LiteralPath $submodulePath -Raw)
        $moduleVersion = [string]$xml.Module.Version.value
        $nativeDep = $xml.Module.DependedModules.DependedModule | Where-Object { $_.Id -eq 'Native' } | Select-Object -First 1
        if ($nativeDep) {
            $moduleVersion = [string]$nativeDep.DependentVersion
        }
    }

    $appManifestPath = Join-Path (Split-Path $BannerlordRoot -Parent) 'appmanifest_261550.acf'
    if (Test-Path -LiteralPath $appManifestPath) {
        $acfContent = Get-Content -LiteralPath $appManifestPath -Raw
        if ($acfContent -match '"buildid"\s+"(\d+)"') {
            $buildNumber = $Matches[1]
        }
    }

    $installedIdentity = [ordered]@{
        friendlyVersion = $friendlyVersion
        buildNumber = $buildNumber
        moduleVersion = $moduleVersion
        dllProductVersion = $dllProductVersion
        dllFileVersion = $dllFileVersion
        dllSha256 = $dllSha256
        installPath = $installPath
    }
} catch {
    $detectionError = $_.Exception.Message
}

$observation = [ordered]@{
    schema = 'TbgGameBuildObservation.v1'
    observationId = $observationId
    observedUtc = $nowUtc.ToString('o')
    source = [ordered]@{
        kind = $detectionSource
        locator = if ($detectionSuccess) { $BannerlordRoot } else { 'detection_failed' }
    }
    identity = if ($installedIdentity) { $installedIdentity } else {
        [ordered]@{ friendlyVersion = ''; buildNumber = ''; installPath = '' }
    }
    steamAppId = 261550
    isInstalled = $detectionSuccess
    isUpstream = $false
    tags = @('local_install')
}

$observation | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outDir 'game-build-observation.json') -Encoding UTF8

$result = $null
$compatState = 'LOCAL_VERSION_UNKNOWN'

if ($detectionSuccess -and (Test-Path -LiteralPath $supportPath)) {
    $support = Get-Content -LiteralPath $supportPath -Raw | ConvertFrom-Json
    $supported = $support.supportedVersions | Where-Object { $_.minSupportedVersion -eq $true } | Select-Object -First 1

    if ($supported) {
        $verMatch = ($installedIdentity.friendlyVersion -eq $supported.friendlyVersion)
        $buildMatch = $false
        if ($supported.buildNumbers -and $supported.buildNumbers.Count -gt 0) {
            $buildMatch = $installedIdentity.buildNumber -in $supported.buildNumbers
        } else {
            $buildMatch = $verMatch
        }
        $fingerprintMatch = $false
        if ($supported.dllFingerprints -and $supported.dllFingerprints.Count -gt 0) {
            $fingerprintMatch = $installedIdentity.dllSha256 -in $supported.dllFingerprints
        } else {
            $fingerprintMatch = $verMatch
        }

        if ($verMatch -and $fingerprintMatch) {
            $compatState = 'SUPPORTED_BUILD_ONLY'
        } elseif ($verMatch -and -not $fingerprintMatch) {
            $compatState = 'COMPATIBILITY_FAILED'
        } else {
            $compatState = 'COMPATIBILITY_BLOCKED'
        }
    }
}

$resultId = "compat-result-$($nowUtc.ToString('yyyyMMddHHmmss'))"
$result = [ordered]@{
    schema = 'TbgGameCompatibilityResult.v1'
    resultId = $resultId
    assessedUtc = $nowUtc.ToString('o')
    upstreamIdentity = $null
    installedIdentity = $installedIdentity
    supportedIdentity = if ($detectionSuccess -and (Test-Path -LiteralPath $supportPath)) {
        $support = Get-Content -LiteralPath $supportPath -Raw | ConvertFrom-Json
        $support.supportedVersions | Where-Object { $_.minSupportedVersion -eq $true } | Select-Object -First 1
    } else { $null }
    repoSourceCommit = ''
    compatibilityState = $compatState
    versionMatch = $false
    buildMatch = $false
    fingerprintMatch = $false
    moduleXmlValid = $detectionSuccess
    buildTestPassed = $null
    apiDiffCompleted = $null
    launcherProofCompleted = $null
    runtimeProofCompleted = $null
    allowedActions = @('static_build', 'assessment')
    blockedClaims = @('launcher_compatibility', 'runtime_compatibility', 'behavior_compatibility')
    workItemId = $null
    eventIds = @($observationId)
    artifacts = [ordered]@{
        observation = Join-Path $OutputRoot 'game-build-observation.json'
        apiDiff = $null
        handoff = Join-Path $OutputRoot 'game-update.handoff.md'
        progressLog = Join-Path $OutputRoot 'game-update.progress.log'
    }
}

$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outDir 'game-compatibility-result.json') -Encoding UTF8

$progressLog = @(
    "[$($nowUtc.ToString('o'))] Local game build detection: $(if ($detectionSuccess) { 'SUCCESS' } else { "FAILED - $detectionError" })"
    "[$($nowUtc.ToString('o'))] Installed identity: $($installedIdentity.friendlyVersion) build $($installedIdentity.buildNumber)"
    "[$($nowUtc.ToString('o'))] Compatibility state: $compatState"
    "[$($nowUtc.ToString('o'))] Source: $detectionSource"
) -join "`n"
$progressLog | Set-Content -LiteralPath (Join-Path $outDir 'game-update.progress.log') -Encoding UTF8

$handoff = @"
# Game Compatibility Update

Assessed: $($nowUtc.ToString('o'))
Installed: $(if ($detectionSuccess) { "$($installedIdentity.friendlyVersion) build $($installedIdentity.buildNumber)" else { "DETECTION FAILED - $detectionError" })
State: $compatState
Allowed: $($result.allowedActions -join ', ')
Blocked: $($result.blockedClaims -join ', ')

## Artifacts

- Observation: ``artifacts/latest/game-update/game-build-observation.json``
- Result: ``artifacts/latest/game-update/game-compatibility-result.json``
- Progress: ``artifacts/latest/game-update/game-update.progress.log``

## Next command

``````powershell
.\ForgeGameUpdate.cmd status
``````
"@
$handoff | Set-Content -LiteralPath (Join-Path $outDir 'game-update.handoff.md') -Encoding UTF8

Write-Host "Game compatibility update: $compatState"
Write-Host "Installed: $($installedIdentity.friendlyVersion) build $($installedIdentity.buildNumber)"
Write-Host "Source: $detectionSource"
Write-Host "Artifacts: $outDir"
