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
    'Food must be checked before route commitment.',
    'Horses and capacity must be checked before trade commitment.',
    'Trade should run only when the logistics circuit supports it.',
    'Route selection should optimize after the loop is reliable.',
    'manual_intervention_pending',
    'partyMovedDistance == 0',
    'Local harnesses should iterate and generate context'
)) {
    if ($docText.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$docPath missing doctrine phrase '$needle'") | Out-Null
    }
}

if ($manifest) {
    if ([int]$manifest.schemaVersion -lt 1) { $failures.Add('manifest schemaVersion must be >= 1') | Out-Null }
    if ([string]$manifest.circuitName -ne 'Travel Logistics Circuit') { $failures.Add('manifest circuitName must be Travel Logistics Circuit') | Out-Null }
    if ([string]$manifest.doctrinePath -ne 'docs/operator/travel-logistics-circuit.md') { $failures.Add('manifest doctrinePath must point to travel-logistics-circuit.md') | Out-Null }
    if ([string]$manifest.coreRule -notmatch 'Do not optimize trade before travel') { $failures.Add('manifest coreRule must keep trade downstream of travel') | Out-Null }

    $orders = @($manifest.developmentOrder | Sort-Object order | ForEach-Object { [string]$_.rule })
    $expectedOrder = @(
        'Travel must work.',
        'Travel must resume after manual intervention.',
        'Arrival must be detected.',
        'Town mechanics must run before leaving.',
        'Food must be checked before route commitment.',
        'Horses and capacity must be checked before trade commitment.',
        'Trade should run only when the logistics circuit supports it.',
        'Route selection should optimize after the loop is reliable.'
    )
    for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
        if ($orders.Count -le $i -or $orders[$i] -ne $expectedOrder[$i]) {
            $failures.Add("manifest developmentOrder[$i] expected '$($expectedOrder[$i])'") | Out-Null
        }
    }

    foreach ($currency in @('time','food','gold','cargoCapacity','horses','partySpeed','risk','inventoryPressure','townUtility','stamina','materials')) {
        Assert-ManifestArrayContains $manifest.currencies $currency 'currencies'
    }
    foreach ($branch in @('manual_intervention_pending','travel','arrival_detection','town_food','town_horses_capacity','town_trade_sell','town_trade_buy','town_smithing','town_rest','next_route_selection')) {
        Assert-ManifestArrayContains $manifest.branchOrder $branch 'branchOrder'
    }
    foreach ($signal in @('commandAcknowledged','campaignClockRunning','movementIntentSet','partyPositionDelta','distanceToTargetDelta','settlementDeparture','settlementArrival','routeTargetChange','movementCheckpointObserved','movementMetricDisagreement')) {
        Assert-ManifestArrayContains $manifest.travelProofSignals $signal 'travelProofSignals'
    }
    foreach ($utility in @('food_check','horse_capacity_check','sell_or_reduce_inventory_pressure','buy_trade_goods_when_supported','smith_refine_smelt_or_rest_when_legal','select_next_route_after_town_exhausted')) {
        Assert-ManifestArrayContains $manifest.townUtilityOrder $utility 'townUtilityOrder'
    }
    foreach ($field in @('reason','currentSurface','lastPlannedBranch','targetSettlement','userActionNeeded','resumeAllowedWhen','resumeCommand','evidencePath','nextOwner')) {
        Assert-ManifestArrayContains $manifest.manualInterventionPending.requiredFields $field 'manualInterventionPending.requiredFields'
    }
    foreach ($gap in @('manual_intervention_resume','arrival_to_town_mechanics_transition','movement_proof_breadth')) {
        Assert-ManifestKnownGap $manifest $gap
    }
}

# Code snippets that must stay aligned with the doctrine until the downstream implementations land.
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' "[ValidateSet('default', 'economic_loop')]" 'trade/town mechanics remain profile-gated, not accidental default behavior'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' '$isEconomicLoop = ($CertProfile -eq ''economic_loop'')' 'economic loop must be explicit until profile toggle is shared'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'ProbeVanillaTradeExecutionNow' 'trade driving surface must remain identifiable for downstream town mechanics work'
Assert-Contains 'scripts\run-autonomous-assist-session.ps1' 'Non-trade branch satisfied for economic-loop' 'economic loop must prove non-trade travel branch before trade counts'
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
