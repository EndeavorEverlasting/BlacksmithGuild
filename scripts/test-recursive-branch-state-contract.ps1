# Offline regression: recursive branch state must expose next-action truth without faking gameplay.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function New-BranchState {
    param(
        [string]$Surface = 'campaign_map',
        [bool]$SafeTravel = $false,
        [bool]$SafeTrade = $false,
        [bool]$SafeSmith = $false,
        [bool]$SafeWait = $true,
        [bool]$CampaignLoaded = $true,
        [string]$BlockReason = $null
    )

    $next = if ($SafeTravel) {
        'travel'
    } elseif ($SafeTrade -or $SafeSmith) {
        'observe_only'
    } elseif ($SafeWait) {
        'rest_wait'
    } else {
        'observe_only'
    }

    $defaultNextReason = if ([string]::IsNullOrWhiteSpace($BlockReason)) { 'branch_truth_requires_fresh_observation' } else { $BlockReason }
    $travelBlockedReason = if ([string]::IsNullOrWhiteSpace($BlockReason)) { 'travel_surface_blocked' } else { $BlockReason }

    return [pscustomobject]@{
        terminal = $false
        nextActionRequired = $true
        nextPlannedBranch = $next
        nextActionReason = if ($next -eq 'travel') { 'surface_allows_travel_recompute_destination_from_fresh_state' } elseif ($next -eq 'rest_wait') { 'productive_branch_blocked_wait_is_safe' } else { $defaultNextReason }
        branches = [pscustomobject]@{
            travel = [pscustomobject]@{ state = if ($SafeTravel) { 'available' } else { 'blocked' }; reason = if ($SafeTravel) { 'surface_allows_travel' } else { $travelBlockedReason }; evidenceSource = 'status'; boundaryName = 'map_traversal'; failureClass = $null }
            trade = [pscustomobject]@{ state = if ($SafeTrade) { 'unknown' } else { 'blocked' }; reason = if ($SafeTrade) { 'market_profitability_not_evaluated' } else { 'trade_surface_not_open' }; evidenceSource = 'map_trade'; boundaryName = 'execute_trade_iteration'; failureClass = $null }
            smith_refine = [pscustomobject]@{ state = if ($SafeSmith) { 'unknown' } else { 'blocked' }; reason = if ($SafeSmith) { 'smithing_stamina_materials_not_evaluated' } else { 'smithing_surface_not_open' }; evidenceSource = 'smithing'; boundaryName = 'smithing_or_prep'; failureClass = $null }
            rest_wait = [pscustomobject]@{ state = if ($SafeWait) { 'available' } else { 'blocked' }; reason = if ($SafeWait) { 'safe_wait_surface' } else { 'wait_not_safe_on_surface' }; evidenceSource = 'status'; boundaryName = 'rest_wait'; failureClass = $null }
            tavern_scan = [pscustomobject]@{ state = if ($Surface -in @('settlement_menu','settlement_city','settlement_interior')) { 'unknown' } else { 'blocked' }; reason = if ($Surface -in @('settlement_menu','settlement_city','settlement_interior')) { 'tavern_candidates_not_scanned' } else { 'not_at_settlement_surface' }; evidenceSource = 'status'; boundaryName = 'observe_runtime_state'; failureClass = $null }
            companion_roster = [pscustomobject]@{ state = if ($CampaignLoaded) { 'unknown' } else { 'blocked' }; reason = if ($CampaignLoaded) { 'companion_roster_not_scanned' } else { 'campaign_not_loaded' }; evidenceSource = 'status'; boundaryName = 'observe_runtime_state'; failureClass = $null }
            horse_acquisition = [pscustomobject]@{
                state = if ($Surface -in @('settlement_menu','settlement_city','settlement_interior')) { 'unknown' } else { 'blocked' }
                reason = if ($Surface -in @('settlement_menu','settlement_city','settlement_interior')) { 'horse_market_affordability_not_evaluated' } else { 'not_at_settlement_surface' }
                evidenceSource = if ($Surface -in @('settlement_menu','settlement_city','settlement_interior')) { 'horse_market' } else { 'none' }
                boundaryName = 'horse_acquisition'
                failureClass = $null
            }
            inventory_management = [pscustomobject]@{
                state = if ($CampaignLoaded) { 'unknown' } else { 'blocked' }
                reason = if ($CampaignLoaded) { 'inventory_pressure_not_evaluated' } else { 'campaign_not_loaded' }
                evidenceSource = if ($CampaignLoaded) { 'status' } else { 'none' }
                boundaryName = 'inventory_management'
                failureClass = $null
            }
            avoid_threat = [pscustomobject]@{ state = 'unknown'; reason = 'threat_state_unknown_until_posture_scan_consumed'; evidenceSource = 'threat_scan'; boundaryName = 'evaluate_threat_state'; failureClass = $null }
            observe_only = [pscustomobject]@{ state = 'available'; reason = 'always_safe_fallback'; evidenceSource = 'none'; boundaryName = 'observe_only'; failureClass = $null }
        }
    }
}

$travel = New-BranchState -Surface 'campaign_map' -SafeTravel $true -SafeWait $true
if ($travel.terminal) { throw 'recursiveBranchState must not be terminal' }
if (-not $travel.nextActionRequired) { throw 'recursiveBranchState must require a next action' }
if ($travel.nextPlannedBranch -ne 'travel') { throw 'travel-safe surface should plan travel branch' }
if ($travel.branches.trade.state -eq 'available') { throw 'trade must not be available without profitability evidence' }
if ($travel.branches.smith_refine.state -eq 'available') { throw 'smith/refine must not be available without stamina/material evidence' }
if ($travel.branches.companion_roster.state -eq 'available') { throw 'companion roster must not be available without roster/capacity evidence' }
if ($travel.branches.avoid_threat.state -eq 'available') { throw 'avoid threat must not be available without threat evidence' }
if ($travel.branches.horse_acquisition.state -eq 'available') { throw 'horse acquisition must not be available without affordability evidence' }
if ($travel.branches.inventory_management.state -eq 'available') { throw 'inventory management must not be available without inventory pressure evidence' }
foreach ($richBranch in @('travel','trade','horse_acquisition','inventory_management','smith_refine','rest_wait','avoid_threat','observe_only')) {
    $gate = $travel.branches.$richBranch
    foreach ($field in @('state','reason','evidenceSource','boundaryName')) {
        if (-not ($gate.PSObject.Properties.Name -contains $field)) {
            throw "branch '$richBranch' gate missing v2 field: $field"
        }
    }
}

$settlementHorse = New-BranchState -Surface 'settlement_menu' -SafeTravel $true
if ($settlementHorse.branches.horse_acquisition.state -ne 'unknown' -or $settlementHorse.branches.horse_acquisition.reason -ne 'horse_market_affordability_not_evaluated') {
    throw 'settlement surface should expose horse acquisition as unknown until affordability is evaluated'
}

$tradeSurface = New-BranchState -Surface 'trading' -SafeTrade $true -SafeWait $true
if ($tradeSurface.branches.trade.state -ne 'unknown' -or $tradeSurface.branches.trade.reason -ne 'market_profitability_not_evaluated') {
    throw 'trade surface should expose market truth as unknown until profitability is evaluated'
}
if ($tradeSurface.nextPlannedBranch -ne 'observe_only') {
    throw 'trade surface should observe first, not execute fake profitable trade'
}

$smithSurface = New-BranchState -Surface 'blacksmithing' -SafeSmith $true -SafeWait $true
if ($smithSurface.branches.smith_refine.state -ne 'unknown' -or $smithSurface.branches.smith_refine.reason -ne 'smithing_stamina_materials_not_evaluated') {
    throw 'smithing surface should expose smithing truth as unknown until stamina/materials are evaluated'
}

$settlement = New-BranchState -Surface 'settlement_menu' -SafeTravel $true
if ($settlement.branches.tavern_scan.state -ne 'unknown' -or $settlement.branches.tavern_scan.reason -ne 'tavern_candidates_not_scanned') {
    throw 'settlement surface should mark tavern scan as unknown until candidates are scanned'
}

$src = Get-Content -LiteralPath (Join-Path $repoRoot 'src\BlacksmithGuild\DevTools\RecursiveCampaignBranchState.cs') -Raw
foreach ($needle in @(
    'recursiveBranchState',
    'nextActionRequired',
    'nextPlannedBranch',
    'market_profitability_not_evaluated',
    'smithing_stamina_materials_not_evaluated',
    'companion_roster_not_scanned',
    'threat_state_unknown_until_posture_scan_consumed',
    'SchemaVersion = 2',
    'horse_acquisition',
    'inventory_management',
    'horse_market_affordability_not_evaluated',
    'inventory_pressure_not_evaluated',
    'evidenceSource',
    'boundaryName',
    'failureClass',
    'BuildSignature',
    'ResolveNearestSettlementFallback',
    'AssistiveLeaveTownTravelService.ResolveRecommendedTarget')) {
    if ($src -notmatch [regex]::Escape($needle)) {
        throw "RecursiveCampaignBranchState.cs missing contract needle: $needle"
    }
}

# Cold-session seed must be gated on travel safety so a non-travel surface never proposes a destination.
if ($src -notmatch 'snapshot\.SafeToExecuteTravel\)\s*\{\s*return ResolveNearestSettlementFallback') {
    throw 'RecursiveCampaignBranchState.cs must only seed nearest-settlement fallback on travel-safe surfaces'
}

$forgeStatus = Get-Content -LiteralPath (Join-Path $repoRoot 'src\BlacksmithGuild\ForgeStatus.cs') -Raw
if ($forgeStatus -notmatch [regex]::Escape('RecursiveCampaignBranchState.BuildJsonBlock')) {
    throw 'ForgeStatus.cs must append recursiveBranchState to Status.json'
}

Write-Host 'PASS recursive branch state contract'
