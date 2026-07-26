[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
    if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }
}

$failures = [System.Collections.Generic.List[string]]::new()
function Fail([string]$Message) { $failures.Add($Message) | Out-Null }
function Read-Json([string]$RelativePath) {
    $path = Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "missing: $RelativePath"
        return $null
    }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { Fail "invalid JSON: $RelativePath :: $($_.Exception.Message)"; return $null }
}
function Read-Text([string]$RelativePath) {
    $path = Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "missing: $RelativePath"
        return ''
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}
function Write-ValidationResult([string]$Status) {
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { return }
    [ordered]@{
        schema = 'TbgDisposableSaveRegistryValidationResult.v1'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        status = $Status
        supportedGameVersionPrefix = if ($gameRegistry) { [string]$gameRegistry.repoSupportedBuild.gameVersionPrefix } else { $null }
        failureCount = $failures.Count
        failures = @($failures.ToArray())
        proofCeiling = 'static disposable-save registry, save-compatibility delegation, and runtime mutation-gate wiring'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputRoot 'validation-result.json') -Encoding UTF8
}

$registry = Read-Json '.tbg/state/disposable-save.registry.json'
$schema = Read-Json '.tbg/harness/schemas/disposable-save-registry.schema.json'
$policy = Read-Json '.tbg/harness/policies/disposable-save.policy.json'
$gameRegistry = Read-Json '.tbg/state/game-compatibility.registry.json'
$saveRegistry = Read-Json '.tbg/state/save-compatibility.registry.json'
$artifacts = Read-Json '.tbg/harness/disposable-save-artifacts.registry.json'
$profiles = Read-Json '.tbg/harness/e2e/profiles.json'
$catalog = Read-Json '.tbg/harness/test-catalog.d/core/disposable-save-registry.test.json'
$workflow = Read-Json '.tbg/workflows/disposable-save-live-cert.contract.json'

$updaterText = Read-Text 'scripts/tbg/Update-TbgDisposableSaveRegistry.ps1'
$liveCertText = Read-Text 'scripts/tbg/Invoke-TbgDisposableSaveLiveCert.ps1'
$classifierText = Read-Text 'src/BlacksmithGuild/SaveSafety/SaveSafetyClassifier.cs'
$tradeText = Read-Text 'src/BlacksmithGuild/MapTrade/MapTradeTradeActionReflection.cs'

if ($registry) {
    if ([string]$registry.schema -ne 'TbgDisposableSaveRegistry.v1') { Fail 'registry schema id mismatch' }
    if ([string]$registry.policy -ne '.tbg/harness/policies/disposable-save.policy.json') { Fail 'registry policy path mismatch' }
    if ([string]$registry.saveCompatibilityRegistry -ne '.tbg/state/save-compatibility.registry.json') { Fail 'registry must delegate version truth to save-compatibility.registry.json' }
    if ([string]$registry.saveCompatibilityEntrypoint -ne 'scripts/tbg/Invoke-TbgSaveCompatibility.ps1') { Fail 'registry save compatibility entrypoint mismatch' }
    if ([string]$registry.compatibility.gameCompatibilityRegistry -ne '.tbg/state/game-compatibility.registry.json') { Fail 'registry game compatibility source mismatch' }
    if ([string]$registry.compatibility.supportedVersionField -ne 'repoSupportedBuild.gameVersionPrefix') { Fail 'registry supported-version field mismatch' }
    if ($registry.compatibility.requireExactSaveVersion -ne $true) { Fail 'registry must require exact save version' }
    if ($registry.compatibility.requirePostCreateReclassification -ne $true) { Fail 'registry must require post-create reclassification' }
    if ($null -ne $registry.compatibility.PSObject.Properties['supportedGameVersionPrefix']) { Fail 'registry must not duplicate a hard-coded supportedGameVersionPrefix' }

    $registryPatterns = @($registry.namePatterns | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $policyPatterns = @($policy.namePatterns | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    if (($registryPatterns -join "`n") -ne ($policyPatterns -join "`n")) { Fail 'registry namePatterns drift from disposable-save.policy.json' }

    $cohortIds = @($registry.cohorts | ForEach-Object { [string]$_.id })
    if (($cohortIds | Sort-Object -Unique).Count -ne $cohortIds.Count) { Fail 'duplicate disposable-save cohort id' }
}

if ($schema -and [string]$schema.title -ne 'TbgDisposableSaveRegistry.v1') { Fail 'registry schema title mismatch' }
if ($gameRegistry -and [string]::IsNullOrWhiteSpace([string]$gameRegistry.repoSupportedBuild.gameVersionPrefix)) { Fail 'game compatibility registry lacks supported version prefix' }
if ($saveRegistry -and $saveRegistry.newSaveContract.requirePostCreateObservation.Count -eq 0) { Fail 'save compatibility new-save post-create observation contract missing' }

if ($artifacts) {
    if ([string]$artifacts.latestRoot -ne 'artifacts/latest/disposable-save') { Fail 'disposable-save artifact latestRoot mismatch' }
    $artifactIds = @($artifacts.artifacts | ForEach-Object { [string]$_.id })
    foreach ($requiredId in @('classification-result','classification-report','live-cert-result')) {
        if ($artifactIds -notcontains $requiredId) { Fail "artifact registry missing $requiredId" }
    }
}

foreach ($needle in @('Invoke-TbgSaveCompatibility.ps1','PASS_SAVE_VERSION_EXACT','post-create','Set-GovernorActiveDisposableSavePin')) {
    if ($updaterText -notmatch [regex]::Escape($needle)) { Fail "updater missing canonical gate marker: $needle" }
}
if ($updaterText -match 'supportedGameVersionPrefix\s*=\s*["'']1\.4\.7') { Fail 'updater hard-codes stale 1.4.7 support' }

foreach ($needle in @('Invoke-TbgSaveCompatibility.ps1','targetGateTerminalState','AllowDisposableSaveMutation')) {
    if ($liveCertText -notmatch [regex]::Escape($needle)) { Fail "live cert missing safety marker: $needle" }
}
if ($liveCertText -match 'ForgeStop\.cmd.*force') { Fail 'live cert must not force-stop an active/ambiguous runtime' }
if ($liveCertText -match 'PASS_priority_engine_live_on_exact_version_disposable_save') { Fail 'live cert must not advertise full behavior PASS before a same-run behavior observer exists' }

foreach ($needle in @('CampaignSetupStateTracker.DevSaveName','SaveSafetyClass.Disposable','prelaunch_exact_version_gate_required')) {
    if ($classifierText -notmatch [regex]::Escape($needle)) { Fail "runtime classifier missing marker: $needle" }
}
if ($classifierText -match 'SupportedGameVersionPrefix\s*=') { Fail 'runtime classifier must not duplicate the repository-supported version family' }
if ($tradeText -notmatch 'SaveSafetyClassifier\.IsMutationAllowed') { Fail 'MapTradeTradeActionReflection must gate the mutation chokepoint through SaveSafetyClassifier' }

if ($profiles) {
    $journey = @($profiles.journeys | Where-Object { $_.id -eq 'disposable-save-registry' })
    if ($journey.Count -ne 1) { Fail 'E2E profiles must register disposable-save-registry exactly once' }
    elseif ([string]$journey[0].script -ne 'scripts/tbg/Test-TbgDisposableSaveRegistry.ps1') { Fail 'E2E disposable-save-registry journey must use static validator' }

    $liveJourney = @($profiles.journeys | Where-Object { $_.id -eq 'disposable-save-live-cert' })
    if ($liveJourney.Count -ne 1) { Fail 'E2E profiles must register disposable-save-live-cert exactly once' }
    elseif ([string]$liveJourney[0].script -ne 'scripts/tbg/Invoke-TbgDisposableSaveLiveCert.ps1') { Fail 'live-cert journey entrypoint mismatch' }
}

if ($catalog) {
    if ([string]$catalog.sourcePath -ne 'scripts/tbg/Test-TbgDisposableSaveRegistry.ps1') { Fail 'one-click catalog sourcePath mismatch' }
    if (@($catalog.defaultProfileMembership) -notcontains 'default-static') { Fail 'disposable-save static validator must be in default-static' }
}

if ($workflow) {
    if ([string]$workflow.mutationAuthority.saveCompatibilityGate -ne 'scripts/tbg/Invoke-TbgSaveCompatibility.ps1') { Fail 'workflow must name canonical save compatibility gate' }
    if ($workflow.requiresForgeStopFirst -eq $true) { Fail 'workflow must not require automated ForgeStop; active runtime ownership is a separate launcher gate' }
    if ([string]$workflow.proofLevel -ne 'launcher') { Fail 'current live-cert workflow proof level must remain launcher until a behavior observer exists' }
}

if ($failures.Count -gt 0) {
    Write-ValidationResult -Status 'FAIL'
    Write-Host 'FAIL_disposable_save_registry_contract'
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}

Write-ValidationResult -Status 'PASS'
Write-Host 'PASS_disposable_save_registry_contract'
Write-Host "supportedVersion=$($gameRegistry.repoSupportedBuild.gameVersionPrefix)"
Write-Host "patterns=$(@($registry.namePatterns).Count) cohorts=$(@($registry.cohorts).Count)"
exit 0
