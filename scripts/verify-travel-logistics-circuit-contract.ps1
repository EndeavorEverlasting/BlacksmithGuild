# Read-only verifier for the Travel Logistics Circuit doctrine.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-Text($RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains($RelativePath, $Needle, $Why = '') {
    $text = Read-Text $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$RelativePath missing '$Needle' $Why") | Out-Null
    }
}

function Assert-ManifestArrayContains($Array, [string]$Value, [string]$FieldName) {
    if (@($Array | ForEach-Object { [string]$_ }) -notcontains $Value) {
        $failures.Add("manifest $FieldName missing '$Value'") | Out-Null
    }
}

function Assert-ManifestKnownGap($Manifest, [string]$GapName) {
    $gapNames = @($Manifest.knownGaps | ForEach-Object { [string]$_.gap })
    if ($gapNames -notcontains $GapName) {
        $failures.Add("manifest knownGaps missing '$GapName'") | Out-Null
    }
}

$docPath = 'docs\operator\travel-logistics-circuit.md'
$manifestPath = 'docs\handoff\travel-logistics-circuit.manifest.json'
$docText = Read-Text $docPath
$manifestRaw = Read-Text $manifestPath
$manifest = $null
try { $manifest = $manifestRaw | ConvertFrom-Json } catch { $failures.Add("manifest does not parse as JSON: $($_.Exception.Message)") | Out-Null }

foreach ($needle in @(
    'Travel must work.',
    'Travel must resume after manual intervention.',
    'Arrival must be detected.',
    'Town mechanics must run before leaving.',
    'Market trade must run before logistics checks.',
    'Food must be checked after the market pass and before departure.',
    'Horses and capacity must be checked after food and before route commitment.',
    'Tavern companion recruitment must run before smithing when useful, legal, and affordable.',
    'Smithing should use available companion stamina before the town is considered exhausted.',
    'Route selection should choose the next town that maximizes profit after town utility is exhausted.',
    'Town utility must run in this order:',
    '1. Trade sell',
    '2. Trade buy',
    '3. Food check',
    '4. Horse and capacity check',
    '5. Tavern visit',
    '6. Companion recruitment',
    '7. Smithing stamina refresh',
    '8. Use companion stamina for smithing',
    '9. Smith, refine, and smelt',
    '10. Select the next town that maximizes profit',
    'manual_intervention_pending',
    'partyMovedDistance == 0',
    'Local harnesses should iterate and generate context'
)) {
    if ($docText.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$docPath missing doctrine phrase '$needle'") | Out-Null
    }
}

if ($manifest) {
    if ([int]$manifest.schemaVersion -lt 2) { $failures.Add('manifest schemaVersion must be >= 2') | Out-Null }
    if ([string]$manifest.circuitName -ne 'Travel Logistics Circuit') { $failures.Add('manifest circuitName must be Travel Logistics Circuit') | Out-Null }
    if ([string]$manifest.doctrinePath -ne 'docs/operator/travel-logistics-circuit.md') { $failures.Add('manifest doctrinePath must point to travel-logistics-circuit.md') | Out-Null }
    if ([string]$manifest.coreRule -notmatch 'current town has been exhausted') { $failures.Add('manifest coreRule must keep next destination downstream of ordered town utility') | Out-Null }

    $orders = @($manifest.developmentOrder | Sort-Object order | ForEach-Object { [string]$_.rule })
    $expectedOrder = @(
        'Travel must work.',
        'Travel must resume after manual intervention.',
        'Arrival must be detected.',
        'Town mechanics must run before leaving.',
        'Market trade must run before logistics checks.',
        'Food must be checked after the market pass and before departure.',
        'Horses and capacity must be checked after food and before route commitment.',
        'Tavern companion recruitment must run before smithing when useful, legal, and affordable.',
        'Smithing should use available companion stamina before the town is considered exhausted.',
        'Route selection should choose the next town that maximizes profit after town utility is exhausted.'
    )
    for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
        if ($orders.Count -le $i -or $orders[$i] -ne $expectedOrder[$i]) {
            $failures.Add("manifest developmentOrder[$i] expected '$($expectedOrder[$i])'") | Out-Null
        }
    }

    foreach ($currency in @('time','food','gold','cargoCapacity','horses','partySpeed','risk','inventoryPressure','townUtility','companions','smithingStamina','materials')) {
        Assert-ManifestArrayContains $manifest.currencies $currency 'currencies'
    }
    foreach ($branch in @('manual_intervention_pending','travel','arrival_detection','town_trade_sell','town_trade_buy','town_food','town_horses_capacity','town_tavern_visit','town_companion_recruitment','town_smithing_stamina_refresh','town_smithing_use_companion_stamina','town_smith_refine_smelt','next_profit_route_selection')) {
        Assert-ManifestArrayContains $manifest.branchOrder $branch 'branchOrder'
    }
    foreach ($signal in @('commandAcknowledged','campaignClockRunning','movementIntentSet','partyPositionDelta','distanceToTargetDelta','settlementDeparture','settlementArrival','routeTargetChange','movementCheckpointObserved','movementMetricDisagreement')) {
        Assert-ManifestArrayContains $manifest.travelProofSignals $signal 'travelProofSignals'
    }
    foreach ($utility in @('trade_sell','trade_buy','food_check','horse_capacity_check','tavern_visit','companion_recruitment','smithing_stamina_refresh','use_companion_stamina_for_smithing','smith_refine_smelt','select_next_profit_route')) {
        Assert-ManifestArrayContains $manifest.townUtilityOrder $utility 'townUtilityOrder'
    }
    foreach ($field in @('reason','currentSurface','lastPlannedBranch','targetSettlement','userActionNeeded','resumeAllowedWhen','resumeCommand','evidencePath','nextOwner')) {
        Assert-ManifestArrayContains $manifest.manualInterventionPending.requiredFields $field 'manualInterventionPending.requiredFields'
    }
    foreach ($signal in @('tavernVisited','recruitableHeroDetected','recruitmentCostKnown','goldBefore','goldAfter','joinedPartyVerified','smithingStaminaRefreshed')) {
        Assert-ManifestArrayContains $manifest.companionRecruitment.requiredSignals $signal 'companionRecruitment.requiredSignals'
    }
    foreach ($gap in @('manual_intervention_resume','arrival_to_town_mechanics_transition','movement_proof_breadth','tavern_companion_recruitment_before_smithing','next_profit_route_selection')) {
        Assert-ManifestKnownGap $manifest $gap
    }
}

Assert-Contains 'scripts\run-autonomous-assist-session.ps1' "[ValidateSet('default', 'economic_loop', 'full_campaign_handoff')]" 'trade/town mechanics remain profile-gated, not accidental default behavior'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '$isEconomicLoop = ($CertProfile -eq ''economic_loop'')' 'economic loop must be explicit until profile toggle is shared'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '$isFullCampaignHandoff = ($CertProfile -eq ''full_campaign_handoff'')' 'full campaign handoff must be an explicit cert profile'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'continuing for arrival/town handoff' 'full campaign handoff must not terminal-stop on movement_observed'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'ProbeVanillaTradeExecutionNow' 'trade driving surface must remain identifiable for downstream town mechanics work'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Non-trade branch satisfied for economic-loop' 'economic loop must prove travel branch before trade counts'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Get-AutonomousAssistEngineTravelTarget' 'travel target handoff remains the spine before downstream logistics'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'movementProofClassification = $latestMovementUpdate.movementProofClassification' 'movement proof classification must remain visible to Reboot/handoff logic'
Assert-Contains 'scripts\autonomous-assist-session.ps1' 'function Test-AutonomousAssistDurableMovementObserved' 'movement proof must be durable and not one raw distance field'
Assert-Contains 'scripts\autonomous-assist-session.ps1' 'MovementMetricDisagreement' 'discrete/checkpoint movement uncertainty must remain representable'
Assert-Contains 'scripts\autonomous-assist-session.ps1' "-CheckpointName 'party_movement_observed'" 'visible movement proof must stay checkpointed'
Assert-Contains 'scripts\reboot-context-classifier.ps1' 'movementIntentSet' 'Reboot classifier must preserve movement intent'
Assert-Contains 'scripts\reboot-context-classifier.ps1' 'partyMovedDistanceBucket' 'distance is a bucketed signal, not sole truth'
Assert-Contains 'scripts\reboot-context-classifier.ps1' 'movementProofClassification' 'classifier must preserve richer movement proof labels'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: travel logistics circuit contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: travel logistics circuit contract verified.' -ForegroundColor Green
exit 0
