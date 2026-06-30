# Read-only verifier for Food Provisioning doctrine and manifest.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-Text($RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { $failures.Add("missing file: $RelativePath") | Out-Null; return '' }
    return Get-Content -LiteralPath $path -Raw
}
function Assert-ManifestArrayContains($Array, [string]$Value, [string]$FieldName) {
    if (@($Array | ForEach-Object { [string]$_ }) -notcontains $Value) { $failures.Add("manifest $FieldName missing '$Value'") | Out-Null }
}
function Assert-OrderBefore($Array, [string]$Before, [string]$After, [string]$FieldName) {
    $values = @($Array | ForEach-Object { [string]$_ })
    $beforeIndex = [array]::IndexOf($values, $Before)
    $afterIndex = [array]::IndexOf($values, $After)
    if ($beforeIndex -lt 0 -or $afterIndex -lt 0 -or $beforeIndex -ge $afterIndex) {
        $failures.Add("$FieldName must place '$Before' before '$After'") | Out-Null
    }
}

$docPath = 'docs\operator\food-provisioning-doctrine.md'
$manifestPath = 'docs\handoff\food-provisioning.manifest.json'
$travelManifestPath = 'docs\handoff\travel-logistics-circuit.manifest.json'
$docText = Read-Text $docPath
$manifestRaw = Read-Text $manifestPath
$travelRaw = Read-Text $travelManifestPath
$manifest = $null
$travelManifest = $null
try { $manifest = $manifestRaw | ConvertFrom-Json } catch { $failures.Add("food manifest does not parse as JSON: $($_.Exception.Message)") | Out-Null }
try { $travelManifest = $travelRaw | ConvertFrom-Json } catch { $failures.Add("travel manifest does not parse as JSON: $($_.Exception.Message)") | Out-Null }

foreach ($needle in @(
    'Food provisioning is an actionable town branch',
    'Food provisioning runs after trade sell/buy and before horse/capacity checks.',
    'Food provisioning must either buy food and prove the result, or block departure with a useful reason.',
    'The advisor must output a decision, not just diagnostics.',
    'Trade profit should not prevent food safety.',
    'Route selection must consume food provisioning state.',
    'The next profit route is not valid if:',
    'After trade buy/sell, the system must reassess food using the post-trade inventory and gold state.',
    'Horses can improve route feasibility, but they do not replace food.'
)) { if ($docText.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) { $failures.Add("$docPath missing doctrine phrase '$needle'") | Out-Null } }

if ($manifest) {
    if ([string]$manifest.branchName -ne 'food_provisioning') { $failures.Add('manifest branchName must be food_provisioning') | Out-Null }
    if ([string]$manifest.coreRule -notmatch 'buy food and prove') { $failures.Add('manifest coreRule must require buy-and-prove or classified block') | Out-Null }
    foreach ($prior in @('town_trade_sell','town_trade_buy')) { Assert-ManifestArrayContains $manifest.positionInTownUtility.after $prior 'positionInTownUtility.after' }
    Assert-ManifestArrayContains $manifest.positionInTownUtility.before 'town_horses_capacity' 'positionInTownUtility.before'
    foreach ($decision in @(
        'hold_food_target_met',
        'buy_food',
        'emergency_buy_food',
        'block_departure_no_food',
        'block_departure_insufficient_gold',
        'block_departure_insufficient_capacity',
        'block_departure_market_unavailable',
        'manual_intervention_required'
    )) { Assert-ManifestArrayContains $manifest.decisionNames $decision 'decisionNames' }
    foreach ($outcome in @(
        'food_target_met',
        'food_bought_and_verified',
        'food_unavailable_in_market',
        'insufficient_gold_for_food',
        'insufficient_capacity_for_food',
        'market_read_failed',
        'execution_failed',
        'manual_intervention_required'
    )) { Assert-ManifestArrayContains $manifest.executionOutcomes $outcome 'executionOutcomes' }
    foreach ($file in @(
        'BlacksmithGuild_FoodProvisioningStatus.json',
        'BlacksmithGuild_FoodProvisioningDecision.json',
        'BlacksmithGuild_FoodProvisioningExecution.json'
    )) { Assert-ManifestArrayContains $manifest.evidenceFiles $file 'evidenceFiles' }
    foreach ($consumer in @('town_horses_capacity','next_profit_route_selection')) { Assert-ManifestArrayContains $manifest.downstreamConsumers $consumer 'downstreamConsumers' }
    if (-not $manifest.tradeIntegration.tradeProfitCannotOverrideFoodSafety) { $failures.Add('manifest tradeIntegration.tradeProfitCannotOverrideFoodSafety must be true') | Out-Null }
    if (-not $manifest.tradeIntegration.foodUsesPostTradeState) { $failures.Add('manifest tradeIntegration.foodUsesPostTradeState must be true') | Out-Null }
    foreach ($rule in @('useLegalMarketMechanics','verifyGoldDelta','verifyFoodInventoryDelta','doNotAllowDepartureWithoutVerifiedFoodStateOrClassifiedBlocker')) { Assert-ManifestArrayContains $manifest.integrityRules $rule 'integrityRules' }
}

if ($travelManifest) {
    foreach ($branch in @('town_trade_sell','town_trade_buy','town_food','town_horses_capacity')) { Assert-ManifestArrayContains $travelManifest.branchOrder $branch 'travel branchOrder' }
    Assert-OrderBefore $travelManifest.branchOrder 'town_trade_sell' 'town_trade_buy' 'travel branchOrder'
    Assert-OrderBefore $travelManifest.branchOrder 'town_trade_buy' 'town_food' 'travel branchOrder'
    Assert-OrderBefore $travelManifest.branchOrder 'town_food' 'town_horses_capacity' 'travel branchOrder'
    foreach ($utility in @('trade_sell','trade_buy','food_check','horse_capacity_check')) { Assert-ManifestArrayContains $travelManifest.townUtilityOrder $utility 'travel townUtilityOrder' }
    Assert-OrderBefore $travelManifest.townUtilityOrder 'trade_sell' 'trade_buy' 'travel townUtilityOrder'
    Assert-OrderBefore $travelManifest.townUtilityOrder 'trade_buy' 'food_check' 'travel townUtilityOrder'
    Assert-OrderBefore $travelManifest.townUtilityOrder 'food_check' 'horse_capacity_check' 'travel townUtilityOrder'
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: food provisioning contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}
Write-Host 'PASS: food provisioning contract verified.' -ForegroundColor Green
exit 0
