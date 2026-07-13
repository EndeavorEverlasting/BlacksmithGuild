[CmdletBinding()]
param(
    [ValidateSet('check','reconcile','offline','status')][string]$Command = 'check',
    [string]$RepoRoot,
    [string]$BannerlordRoot,
    [string]$AppManifestPath,
    [string]$RegistryPath = '.tbg/state/game-compatibility.registry.json',
    [string]$OutputDirectory = 'artifacts/latest/game-compatibility',
    [string]$StateObjectRoot = 'artifacts/state/objects',
    [string]$UpstreamFixturePath,
    [string]$BuiltDllPath,
    [string]$InstalledDllPath,
    [switch]$NoJournal,
    [switch]$NoEnvelope,
    [switch]$NoExit,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

function Resolve-TbgPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $RepoRoot ($Path -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Ensure-TbgDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Get-TbgPropertyValue {
    param($Object, [Parameter(Mandatory = $true)][string]$Name, $Default = $null)
    if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) {
        return $Object.PSObject.Properties[$Name].Value
    }
    return $Default
}

function Write-TbgJson {
    param($Value, [Parameter(Mandatory = $true)][string]$Path, [int]$Depth = 20)
    $parent = Split-Path -Parent $Path
    if ($parent) { Ensure-TbgDirectory -Path $parent }
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Normalize-TbgVersion {
    param([AllowNull()][string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    $value = $Version.Trim()
    if ($value.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) {
        $value = $value.Substring(1)
    }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($part in @($value -split '\.')) {
        if ($part -match '^([0-9]+)') { $parts.Add($Matches[1]) | Out-Null }
    }
    while ($parts.Count -lt 4) { $parts.Add('0') | Out-Null }
    return (@($parts.ToArray()) -join '.')
}

function Get-TbgFileFingerprint {
    param([AllowNull()][string]$Path)
    $record = [ordered]@{
        path = $Path
        exists = $false
        sha256 = $null
        length = $null
        lastWriteUtc = $null
        assemblyVersion = $null
        fileVersion = $null
    }
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]$record
    }
    $item = Get-Item -LiteralPath $Path
    $record.exists = $true
    $record.sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.length = [long]$item.Length
    $record.lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
    try { $record.assemblyVersion = [Reflection.AssemblyName]::GetAssemblyName($Path).Version.ToString() } catch { }
    try { $record.fileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion } catch { }
    return [pscustomobject]$record
}

function Get-TbgXmlModuleVersion {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ($null -ne $xml.Module.Version) { return [string]$xml.Module.Version.value }
    } catch { }
    return $null
}

function Get-TbgRepoDependencies {
    param([Parameter(Mandatory = $true)][string]$Path)
    $dependencies = @()
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $dependencies }
    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        foreach ($dependency in @($xml.Module.DependedModules.DependedModule)) {
            $dependencies += [pscustomobject][ordered]@{
                id = [string]$dependency.Id
                dependentVersion = [string]$dependency.DependentVersion
            }
        }
    } catch { }
    return $dependencies
}

function Read-TbgSteamManifest {
    param([AllowNull()][string]$Path)
    $record = [ordered]@{
        status = 'unavailable'
        path = $Path
        steamBuildId = $null
        lastUpdatedUnix = $null
        lastUpdatedUtc = $null
        installDir = $null
        stateFlags = $null
    }
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]$record
    }
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($mapping in @(
        @('buildid','steamBuildId'),
        @('LastUpdated','lastUpdatedUnix'),
        @('installdir','installDir'),
        @('StateFlags','stateFlags')
    )) {
        $pattern = '"' + [regex]::Escape($mapping[0]) + '"\s+"([^"]*)"'
        if ($text -match $pattern) { $record[$mapping[1]] = $Matches[1] }
    }
    if ($record.lastUpdatedUnix -match '^\d+$') {
        try { $record.lastUpdatedUtc = [DateTimeOffset]::FromUnixTimeSeconds([long]$record.lastUpdatedUnix).UtcDateTime.ToString('o') } catch { }
    }
    $record.status = if ($record.steamBuildId) { 'observed' } else { 'manifest_missing_build_id' }
    return [pscustomobject]$record
}

function Read-TbgUpstreamBuild {
    param(
        [Parameter(Mandatory = $true)]$Registry,
        [AllowNull()][string]$InstalledBuildId,
        [AllowNull()][string]$FixturePath,
        [switch]$OfflineMode
    )
    $record = [ordered]@{
        status = 'unavailable'
        source = $null
        queriedBuildId = $InstalledBuildId
        buildId = $null
        upToDate = $null
        versionIsListable = $null
        message = $null
        observedUtc = [DateTime]::UtcNow.ToString('o')
    }
    if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
        $fixture = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $response = Get-TbgPropertyValue -Object $fixture -Name 'response' -Default $fixture
        $record.source = 'fixture'
    }
    elseif ($OfflineMode) {
        $record.status = 'skipped_offline'
        $record.source = 'offline_mode'
        return [pscustomobject]$record
    }
    elseif ([string]::IsNullOrWhiteSpace($InstalledBuildId)) {
        $record.status = 'blocked_installed_build_unknown'
        $record.source = 'steam_web_api'
        return [pscustomobject]$record
    }
    else {
        $endpoint = [string]$Registry.upstream.endpointTemplate
        $uri = $endpoint -f [string]$Registry.steamAppId, $InstalledBuildId
        $record.source = $uri
        try {
            $api = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec ([int]$Registry.upstream.timeoutSeconds)
            $response = Get-TbgPropertyValue -Object $api -Name 'response' -Default $api
        }
        catch {
            $record.status = 'query_failed'
            $record.message = $_.Exception.Message
            return [pscustomobject]$record
        }
    }
    $success = [bool](Get-TbgPropertyValue -Object $response -Name 'success' -Default $false)
    if (-not $success) {
        $record.status = 'query_failed'
        $record.message = [string](Get-TbgPropertyValue -Object $response -Name 'message' -Default 'Steam returned success=false.')
        return [pscustomobject]$record
    }
    $record.upToDate = [bool](Get-TbgPropertyValue -Object $response -Name 'up_to_date' -Default $false)
    $record.versionIsListable = [bool](Get-TbgPropertyValue -Object $response -Name 'version_is_listable' -Default $false)
    $required = Get-TbgPropertyValue -Object $response -Name 'required_version' -Default $InstalledBuildId
    $record.buildId = if ($null -ne $required) { [string]$required } else { $InstalledBuildId }
    $record.message = [string](Get-TbgPropertyValue -Object $response -Name 'message' -Default '')
    $record.status = 'observed'
    return [pscustomobject]$record
}

$registryFullPath = Resolve-TbgPath -Path $RegistryPath
if (-not (Test-Path -LiteralPath $registryFullPath -PathType Leaf)) {
    throw "Game compatibility registry is missing: $registryFullPath"
}
$registry = Get-Content -LiteralPath $registryFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
$outputRoot = Resolve-TbgPath -Path $OutputDirectory
Ensure-TbgDirectory -Path $outputRoot
$latestResultPath = Join-Path $outputRoot 'game-compatibility.result.json'

if ($Command -eq 'status') {
    if (-not (Test-Path -LiteralPath $latestResultPath -PathType Leaf)) {
        Write-Host 'No compatibility result exists. Run ForgeGameUpdate.cmd first.' -ForegroundColor Yellow
        if (-not $NoExit) { exit 2 }
        return
    }
    $existing = Get-Content -LiteralPath $latestResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Game compatibility: $($existing.terminalState)"
    Write-Host "Installed build: $($existing.locallyInstalledBuild.steamBuildId)"
    Write-Host "Upstream build: $($existing.upstreamAvailableBuild.buildId)"
    Write-Host "Supported baseline: $($existing.repoSupportedBuild.id)"
    Write-Host "Report: $($existing.evidencePaths.report)"
    if ($PassThru) { return $existing }
    return
}

$offlineMode = $Command -eq 'offline'
$generatedUtc = [DateTime]::UtcNow.ToString('o')
$runId = 'game-compatibility-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0,6))
$runRoot = Join-Path $outputRoot (Join-Path 'runs' $runId)
Ensure-TbgDirectory -Path $runRoot
$progressPath = Join-Path $runRoot 'progress.log'
$eventsPath = Join-Path $runRoot 'events.jsonl'

function Add-TbgProgress {
    param([Parameter(Mandatory = $true)][string]$Sentence)
    $line = '[{0}] {1}' -f ([DateTime]::UtcNow.ToString('o')), $Sentence
    Add-Content -LiteralPath $progressPath -Value $line -Encoding UTF8
    Write-Host $Sentence
}

function Add-TbgEvent {
    param([Parameter(Mandatory = $true)][string]$EventType, [Parameter(Mandatory = $true)][string]$Sentence, $Data)
    $event = [ordered]@{
        schema = 'TbgGameCompatibilityEvent.v1'
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        eventType = $EventType
        sentence = $Sentence
        data = $Data
    }
    ($event | ConvertTo-Json -Depth 15 -Compress) | Add-Content -LiteralPath $eventsPath -Encoding UTF8
    Add-TbgProgress -Sentence $Sentence
}

Add-TbgEvent -EventType 'inspection.started' -Sentence 'The compatibility updater started a metadata-only inspection without launching or modifying Bannerlord.' -Data @{ command = $Command }

$sourceCommit = [string](& git -C $RepoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
$sourceBranch = [string](& git -C $RepoRoot branch --show-current 2>$null | Select-Object -First 1)
$sourceCommit = $sourceCommit.Trim()
$sourceBranch = $sourceBranch.Trim()
if ([string]::IsNullOrWhiteSpace($sourceBranch)) { $sourceBranch = 'detached' }
$sourceDirty = @(& git -C $RepoRoot status --porcelain 2>$null).Count -gt 0
$source = [pscustomobject][ordered]@{ commit = $sourceCommit; branch = $sourceBranch; dirty = $sourceDirty }
Add-TbgEvent -EventType 'source.observed' -Sentence "The updater recorded source commit $sourceCommit on branch $sourceBranch." -Data @{ commit = $sourceCommit; branch = $sourceBranch; dirty = $sourceDirty }

if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) {
    try {
        . (Join-Path $RepoRoot 'scripts/bannerlord-paths.ps1')
        $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    } catch { $BannerlordRoot = $null }
}
if ([string]::IsNullOrWhiteSpace($AppManifestPath) -and -not [string]::IsNullOrWhiteSpace($BannerlordRoot)) {
    $steamApps = Split-Path (Split-Path $BannerlordRoot -Parent) -Parent
    $candidate = Join-Path $steamApps ('appmanifest_{0}.acf' -f [string]$registry.steamAppId)
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $AppManifestPath = $candidate }
}

$manifest = Read-TbgSteamManifest -Path $AppManifestPath
$nativeVersionPath = if ($BannerlordRoot) { Join-Path $BannerlordRoot 'Modules/Native/SubModule.xml' } else { $null }
$gameExePath = if ($BannerlordRoot) { Join-Path $BannerlordRoot 'bin/Win64_Shipping_Client/Bannerlord.exe' } else { $null }
$nativeVersion = Get-TbgXmlModuleVersion -Path $nativeVersionPath
$gameExeFingerprint = Get-TbgFileFingerprint -Path $gameExePath
$locallyInstalled = [pscustomobject][ordered]@{
    status = if ($BannerlordRoot -and $manifest.status -eq 'observed') { 'observed' } else { 'incomplete' }
    bannerlordRoot = $BannerlordRoot
    appManifestPath = $AppManifestPath
    steamBuildId = $manifest.steamBuildId
    lastUpdatedUtc = $manifest.lastUpdatedUtc
    stateFlags = $manifest.stateFlags
    nativeModuleVersion = $nativeVersion
    gameExecutableVersion = $gameExeFingerprint.fileVersion
    gameExecutable = $gameExeFingerprint
}
Add-TbgEvent -EventType 'installed-build.observed' -Sentence "The updater recorded installed Steam build $($locallyInstalled.steamBuildId) and Native version $nativeVersion." -Data @{ steamBuildId = $locallyInstalled.steamBuildId; nativeModuleVersion = $nativeVersion }

$upstream = Read-TbgUpstreamBuild -Registry $registry -InstalledBuildId $manifest.steamBuildId -FixturePath $UpstreamFixturePath -OfflineMode:$offlineMode
Add-TbgEvent -EventType 'upstream-build.observed' -Sentence "The updater classified the upstream build source as $($upstream.status) with build $($upstream.buildId)." -Data @{ status = $upstream.status; buildId = $upstream.buildId; upToDate = $upstream.upToDate }

$supported = $registry.repoSupportedBuild
$repoSubModulePath = Join-Path $RepoRoot 'Module/BlacksmithGuild/SubModule.xml'
$repoDependencies = @(Get-TbgRepoDependencies -Path $repoSubModulePath)
$repoSupported = [pscustomobject][ordered]@{
    id = [string]$supported.id
    status = [string]$supported.status
    gameVersionPrefix = [string]$supported.gameVersionPrefix
    moduleDependencyVersion = [string]$supported.moduleDependencyVersion
    certifiedSteamBuildIds = @($supported.certifiedSteamBuildIds)
    certificationMode = [string]$supported.certificationMode
    source = [string]$supported.source
    repoModuleDependencies = $repoDependencies
}
$repoBaselineConsistent = $repoDependencies.Count -gt 0 -and @($repoDependencies | Where-Object {
    [string]$_.dependentVersion -ne [string]$supported.moduleDependencyVersion
}).Count -eq 0

if ([string]::IsNullOrWhiteSpace($BuiltDllPath)) { $BuiltDllPath = Resolve-TbgPath -Path ([string]$registry.mod.builtDllRelativePath) }
if ([string]::IsNullOrWhiteSpace($InstalledDllPath) -and $BannerlordRoot) {
    $InstalledDllPath = Join-Path $BannerlordRoot ([string]$registry.mod.installedDllRelativePath)
}
$builtDll = Get-TbgFileFingerprint -Path $BuiltDllPath
$installedDll = Get-TbgFileFingerprint -Path $InstalledDllPath
$normalizedInstalledVersion = Normalize-TbgVersion -Version $nativeVersion
$supportedPrefix = [string]$supported.gameVersionPrefix
$installedMatchesSupported = $false
if ($normalizedInstalledVersion -and $supportedPrefix) {
    $installedMatchesSupported = $normalizedInstalledVersion.StartsWith(($supportedPrefix.TrimEnd('.') + '.'), [StringComparison]::OrdinalIgnoreCase)
}
$certifiedIds = @($supported.certifiedSteamBuildIds | ForEach-Object { [string]$_ })
if ($certifiedIds.Count -gt 0) {
    $installedMatchesSupported = $installedMatchesSupported -and ($certifiedIds -contains [string]$manifest.steamBuildId)
}
$upstreamMatchesInstalled = $null
if ($upstream.status -eq 'observed' -and $manifest.steamBuildId) {
    $upstreamMatchesInstalled = [string]$upstream.buildId -eq [string]$manifest.steamBuildId
}
$builtMatchesInstalled = $builtDll.exists -and $installedDll.exists -and ([string]$builtDll.sha256 -eq [string]$installedDll.sha256)

$terminalState = 'PASS_compatibility_metadata_aligned'
$verdict = 'PASS'
$nextCommand = '.\ForgeGameUpdate.cmd status'
if ($locallyInstalled.status -ne 'observed') {
    $terminalState = 'ATTENTION_local_installation_metadata_incomplete'; $verdict = 'ATTENTION'; $nextCommand = 'Verify GameFolder and the Steam appmanifest path, then run .\ForgeGameUpdate.cmd again.'
}
elseif ($upstream.status -ne 'observed') {
    $terminalState = 'ATTENTION_upstream_build_unavailable'; $verdict = 'ATTENTION'; $nextCommand = '.\ForgeGameUpdate.cmd check'
}
elseif (-not [bool]$upstream.upToDate -or $upstreamMatchesInstalled -eq $false) {
    $terminalState = 'BLOCKED_game_update_available'; $verdict = 'BLOCKED'; $nextCommand = 'Update Bannerlord through Steam, then run .\ForgeGameUpdate.cmd again before runtime proof.'
}
elseif (-not $repoBaselineConsistent) {
    $terminalState = 'BLOCKED_repo_support_registry_drift'; $verdict = 'BLOCKED'; $nextCommand = 'Reconcile the compatibility registry with Module/BlacksmithGuild/SubModule.xml before building or launching.'
}
elseif (-not $installedMatchesSupported) {
    $terminalState = 'BLOCKED_repo_support_baseline_mismatch'; $verdict = 'BLOCKED'; $nextCommand = 'Review the installed Native version against .tbg/state/game-compatibility.registry.json before building or launching.'
}
elseif (-not $builtDll.exists) {
    $terminalState = 'ATTENTION_built_mod_dll_missing'; $verdict = 'ATTENTION'; $nextCommand = 'Run the stopped-game build workflow before launcher or runtime proof.'
}
elseif (-not $installedDll.exists) {
    $terminalState = 'ATTENTION_installed_mod_dll_missing'; $verdict = 'ATTENTION'; $nextCommand = 'Run the stopped-game install workflow before launcher or runtime proof.'
}
elseif (-not $builtMatchesInstalled) {
    $terminalState = 'BLOCKED_built_installed_dll_drift'; $verdict = 'BLOCKED'; $nextCommand = 'Use the stopped-game build/install workflow, then rerun .\ForgeGameUpdate.cmd.'
}

$comparisons = [pscustomobject][ordered]@{
    upstreamMatchesInstalled = $upstreamMatchesInstalled
    installedMatchesRepoSupported = $installedMatchesSupported
    repoBaselineMatchesModuleDependencies = $repoBaselineConsistent
    builtMatchesInstalled = $builtMatchesInstalled
}
$runResultPath = Join-Path $runRoot 'game-compatibility.result.json'
$runReportPath = Join-Path $runRoot 'game-compatibility.report.md'
$runHandoffPath = Join-Path $runRoot 'game-compatibility.handoff.md'
$evidencePaths = [pscustomobject][ordered]@{
    result = $runResultPath
    report = $runReportPath
    handoff = $runHandoffPath
    events = $eventsPath
    progress = $progressPath
}
$result = [pscustomobject][ordered]@{
    schema = 'TbgGameCompatibilityResult.v1'
    generatedUtc = $generatedUtc
    runId = $runId
    command = $Command
    sourceCommit = $source
    upstreamAvailableBuild = $upstream
    locallyInstalledBuild = $locallyInstalled
    repoSupportedBuild = $repoSupported
    builtModDll = $builtDll
    installedModDll = $installedDll
    comparisons = $comparisons
    verdict = $verdict
    terminalState = $terminalState
    proofLevel = 'harness'
    allowedClaims = @(
        'The updater observed the named metadata and file fingerprints at generatedUtc.',
        'The result distinguishes upstream, installed, repo-supported, source, built-DLL, and installed-DLL identities.'
    )
    forbiddenClaims = @(
        'Metadata alignment is not launcher, loaded-assembly, behavior, visible-trade, or live-runtime proof.',
        'The updater does not prove that Steam completed an update or that Bannerlord loaded the installed DLL.'
    )
    nextCommand = $nextCommand
    evidencePaths = $evidencePaths
}
Write-TbgJson -Value $result -Path $runResultPath

$report = @(
    '# Bannerlord Game Compatibility',
    '',
    "The metadata-only updater finished with **$terminalState**.",
    '',
    "- Source commit: $sourceCommit ($sourceBranch; dirty=$sourceDirty)",
    "- Upstream available build: $($upstream.buildId) ($($upstream.status))",
    "- Locally installed build: $($locallyInstalled.steamBuildId)",
    "- Installed Native version: $nativeVersion",
    "- Repo-supported baseline: $($repoSupported.id) / $($repoSupported.gameVersionPrefix)",
    "- Repo baseline matches module dependencies: $repoBaselineConsistent",
    "- Built mod DLL: exists=$($builtDll.exists), sha256=$($builtDll.sha256)",
    "- Installed mod DLL: exists=$($installedDll.exists), sha256=$($installedDll.sha256)",
    "- Built and installed DLL match: $builtMatchesInstalled",
    "- Next command: $nextCommand",
    '',
    'This report is harness evidence only. It does not establish launcher, loaded-assembly, behavior, visible-trade, or live-runtime proof.'
)
$report -join "`r`n" | Set-Content -LiteralPath $runReportPath -Encoding UTF8
@(
    '# Game Compatibility Handoff',
    '',
    "- Terminal state: $terminalState",
    "- Exact source head: $sourceCommit",
    "- Next command: $nextCommand",
    '- Runtime proof remains deferred until this metadata gate is current and compatible.'
) -join "`r`n" | Set-Content -LiteralPath $runHandoffPath -Encoding UTF8

$stateRoot = Resolve-TbgPath -Path $StateObjectRoot
$observationId = 'observation:game-compatibility-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ').ToLowerInvariant()), ([Guid]::NewGuid().ToString('N').Substring(0,6))
$observation = [pscustomobject][ordered]@{
    schema = 'TbgObservation.v1'
    id = $observationId
    subject = [pscustomobject][ordered]@{ kind = 'game'; id = 'steam-app-261550' }
    predicate = 'compatibility_metadata'
    value = [pscustomobject][ordered]@{
        sourceCommit = $sourceCommit
        upstreamBuildId = $upstream.buildId
        installedBuildId = $locallyInstalled.steamBuildId
        repoSupportedBuildId = $repoSupported.id
        builtDllSha256 = $builtDll.sha256
        installedDllSha256 = $installedDll.sha256
        terminalState = $terminalState
    }
    observedUtc = $generatedUtc
    source = [pscustomobject][ordered]@{ kind = 'script'; locator = 'scripts/tbg/Invoke-TbgGameCompatibility.ps1' }
    freshness = [pscustomobject][ordered]@{ class = 'time_bound'; expiresAfterSeconds = [int]$registry.freshnessSeconds }
    tags = @('bannerlord','game-build','compatibility','metadata-only')
}
$observationDirectory = Join-Path $stateRoot 'observations'
Ensure-TbgDirectory -Path $observationDirectory
Write-TbgJson -Value $observation -Path (Join-Path $observationDirectory (($observationId -replace '[:/\\]', '_') + '.json'))

$evidenceId = 'evidence:game-compatibility-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ').ToLowerInvariant()), ([Guid]::NewGuid().ToString('N').Substring(0,6))
$evidence = [pscustomobject][ordered]@{
    schema = 'TbgEvidenceRecord.v1'
    id = $evidenceId
    kind = 'local_validator'
    subject = 'Bannerlord game compatibility metadata'
    headSha = $sourceCommit
    result = if ($verdict -eq 'PASS') { 'success' } elseif ($verdict -eq 'BLOCKED') { 'failure' } else { 'inconclusive' }
    proofLevel = 'harness'
    producedUtc = $generatedUtc
    artifactRefs = @($runResultPath, $runReportPath, $eventsPath)
    allowedClaims = @($result.allowedClaims)
    forbiddenClaims = @($result.forbiddenClaims)
    tags = @('bannerlord','compatibility','exact-head')
}
$evidenceDirectory = Join-Path $stateRoot 'evidence'
Ensure-TbgDirectory -Path $evidenceDirectory
Write-TbgJson -Value $evidence -Path (Join-Path $evidenceDirectory (($evidenceId -replace '[:/\\]', '_') + '.json'))

if (-not $NoJournal) {
    $journalScript = Join-Path $RepoRoot 'scripts/tbg/Write-TbgJournalEvent.ps1'
    if (Test-Path -LiteralPath $journalScript -PathType Leaf) {
        & $journalScript -EventType 'game.compatibility.observed' -SourceKind 'script' -SourceId 'forge-game-update' -CorrelationId $runId -PayloadSchema 'TbgGameCompatibilityResult.v1' -Payload @{
            subject = 'steam-app-261550'
            predicate = 'compatibility_metadata'
            value = $terminalState
            resultPath = $runResultPath
            sourceCommit = $sourceCommit
            installedBuildId = [string]$locallyInstalled.steamBuildId
            upstreamBuildId = [string]$upstream.buildId
        } -IdempotencyKey ('game.compatibility|{0}|{1}|{2}|{3}' -f $sourceCommit, [string]$locallyInstalled.steamBuildId, [string]$upstream.buildId, [string]$installedDll.sha256) -RepoRoot $RepoRoot | Out-Null
    }
}
if (-not $NoEnvelope) {
    $envelopeScript = Join-Path $RepoRoot 'scripts/tbg/New-TbgStateEnvelope.ps1'
    if (Test-Path -LiteralPath $envelopeScript -PathType Leaf) { & $envelopeScript -RepoRoot $RepoRoot | Out-Null }
}

Add-TbgEvent -EventType 'inspection.completed' -Sentence "The updater completed with terminal state $terminalState and retained the exact metadata comparison." -Data @{ terminalState = $terminalState; resultPath = $runResultPath }
Copy-Item -LiteralPath $runResultPath -Destination $latestResultPath -Force
Copy-Item -LiteralPath $runReportPath -Destination (Join-Path $outputRoot 'game-compatibility.report.md') -Force
Copy-Item -LiteralPath $runHandoffPath -Destination (Join-Path $outputRoot 'game-compatibility.handoff.md') -Force
Copy-Item -LiteralPath $eventsPath -Destination (Join-Path $outputRoot 'game-compatibility.events.jsonl') -Force
Copy-Item -LiteralPath $progressPath -Destination (Join-Path $outputRoot 'game-compatibility.progress.log') -Force
Write-Host "Game compatibility: $terminalState" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } else { 'Yellow' })
Write-Host "Result: $latestResultPath"
Write-Host "Report: $(Join-Path $outputRoot 'game-compatibility.report.md')"
Write-Host "Next: $nextCommand"

if ($PassThru) { $result }
if (-not $NoExit) {
    if ($verdict -eq 'PASS') { exit 0 }
    exit 2
}
