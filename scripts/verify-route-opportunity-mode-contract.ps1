# Read-only verifier for route opportunity mode CMD/state contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-Text($RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { $failures.Add("missing file: $RelativePath") | Out-Null; return '' }
    return Get-Content -LiteralPath $path -Raw
}
function Assert-Contains($RelativePath, $Needle, $Why = '') {
    $text = Read-Text $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) { $failures.Add("$RelativePath missing '$Needle' $Why") | Out-Null }
}
function Assert-ManifestArrayContains($Array, [string]$Value, [string]$FieldName) {
    if (@($Array | ForEach-Object { [string]$_ }) -notcontains $Value) { $failures.Add("manifest $FieldName missing '$Value'") | Out-Null }
}
function Assert-ManifestKnownGap($Manifest, [string]$GapName) {
    $gapNames = @($Manifest.knownGaps | ForEach-Object { [string]$_.gap })
    if ($gapNames -notcontains $GapName) { $failures.Add("manifest knownGaps missing '$GapName'") | Out-Null }
}

$docPath = 'docs\operator\route-opportunity-mode-doctrine.md'
$manifestPath = 'docs\handoff\route-opportunity-mode.manifest.json'
$helper = 'scripts\route-opportunity-mode.ps1'
$cmd = 'ForgeRouteMode.cmd'
$manifestRaw = Read-Text $manifestPath
$manifest = $null
try { $manifest = $manifestRaw | ConvertFrom-Json } catch { $failures.Add("manifest does not parse as JSON: $($_.Exception.Message)") | Out-Null }

foreach ($needle in @(
    'Exploration is opt-in.',
    'The default mode is direct travel.',
    'The automation must not silently convert every route into an exploration sweep.',
    'In `direct` mode, the party should not detour for villages unless an emergency requires it.',
    'ForgeRouteMode.cmd status',
    'ForgeRouteMode.cmd direct',
    'ForgeRouteMode.cmd exploring',
    'ForgeRouteMode.cmd toggle',
    'BlacksmithGuild_RouteOpportunityMode.json'
)) { Assert-Contains $docPath $needle }

if ($manifest) {
    if ([string]$manifest.defaultMode -ne 'direct') { $failures.Add('manifest defaultMode must be direct') | Out-Null }
    foreach ($mode in @('direct', 'exploring')) { Assert-ManifestArrayContains $manifest.supportedModes $mode 'supportedModes' }
    foreach ($surface in @('ForgeRouteMode.cmd status', 'ForgeRouteMode.cmd direct', 'ForgeRouteMode.cmd exploring', 'ForgeRouteMode.cmd toggle')) { Assert-ManifestArrayContains $manifest.futureCmdSurface $surface 'futureCmdSurface' }
    foreach ($field in @('mode','requestedBy','reason','origin','destination','allowVillageStops','allowRecruitmentStops','allowHorseStops','allowGoodsStops','updatedAtUtc')) { Assert-ManifestArrayContains $manifest.modeFields $field 'modeFields' }
    foreach ($rule in @('routeModeMustBeExplicitForExploration','directModeMustRemainDestinationToDestination','exploringModeMustNotReplaceReliableTravel')) { Assert-ManifestArrayContains $manifest.integrityRules $rule 'integrityRules' }
    foreach ($gap in @('route_mode_cmd_not_built','shared_route_mode_state_not_built','recruitment_engine_not_built','village_horse_engine_not_built','village_goods_engine_not_built')) { Assert-ManifestKnownGap $manifest $gap }
}

foreach ($needle in @(
    'function Get-TbgRouteOpportunityModeJsonPath',
    'function Read-TbgRouteOpportunityMode',
    'function Write-TbgRouteOpportunityMode',
    'function Resolve-TbgRouteOpportunityMode',
    'BlacksmithGuild_RouteOpportunityMode.json',
    "@('direct', 'exploring')",
    'mode = $Mode',
    'allowVillageStops = [bool]$exploring',
    'allowRecruitmentStops = [bool]$exploring',
    'allowHorseStops = [bool]$exploring',
    'allowGoodsStops = [bool]$exploring',
    'source = ''explicit_route_mode''',
    'source = ''shared_json''',
    'source = ''safe_default''',
    'mode = ''direct'''
)) { Assert-Contains $helper $needle }

foreach ($needle in @(
    'ForgeRouteMode.cmd',
    'status',
    'direct',
    'exploring',
    'toggle',
    'FORGE_NO_PAUSE',
    'scripts\route-opportunity-mode.ps1',
    'Write-TbgRouteOpportunityMode',
    'Resolve-TbgRouteOpportunityMode'
)) { Assert-Contains $cmd $needle }

if ($failures.Count -gt 0) {
    Write-Host "FAIL: route opportunity mode contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}
Write-Host 'PASS: route opportunity mode contract verified.' -ForegroundColor Green
exit 0
