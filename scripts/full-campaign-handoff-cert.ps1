# Full campaign handoff cert contract helpers (offline + runner).
# Movement is a checkpoint only. PASS requires arrival, town entry, governor handoff,
# ordinary trade, horse/pack buy, food buy, and manpower roster increase.

if (-not (Get-Command Test-TradeIterationProven -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'automation-boundary-contract.ps1')
}

$script:FullCampaignHandoffFailureClasses = @(
    'target_not_cert_capable',
    'route_not_started',
    'movement_not_observed',
    'arrival_not_observed',
    'town_entry_not_observed',
    'governor_handoff_missing',
    'governor_handoff_stalled',
    'ordinary_trade_delta_missing',
    'horse_delta_missing',
    'capacity_delta_missing',
    'provision_delta_missing',
    'manpower_delta_missing',
    'insufficient_gold',
    'party_capacity_full',
    'recruits_unavailable',
    'command_failure',
    'safe_idle_route_set_no_motion',
    'operator_interruption',
    'timeout',
    'movement_observed_terminal_forbidden',
    'reused_delta_counted_twice',
    'blocked_branch_counted_as_success',
    'stale_row_contamination',
    'orphan_command_started',
    'missing_terminal_finalized_pass',
    'fake_gameplay_delta',
    'direct_injection'
)

function Test-FullCampaignHandoffMovementTerminalForbidden {
    param([string]$StopReason, [string]$CertProfile)
    if ($CertProfile -ne 'full_campaign_handoff') { return $false }
    return ($StopReason -eq 'movement_observed')
}

function Get-TradeIterationClassification {
    param($Iteration)
    if (-not $Iteration) { return 'Unknown' }
    $c = $null
    if ($Iteration.PSObject.Properties.Name -contains 'itemClassification') {
        $c = [string]$Iteration.itemClassification
    }
    if ([string]::IsNullOrWhiteSpace($c)) { return 'Ordinary' }
    return $c
}

function Get-ProvenTradesByClassification {
    param(
        [object[]]$TradeIterations = @(),
        [nullable[datetime]]$SinceUtc = $null
    )
    $proven = @($TradeIterations | Where-Object { $_ -and (Test-TradeIterationProven -Iteration $_) })
    if ($null -ne $SinceUtc) {
        if (-not (Get-Command ConvertTo-Pr11Utc -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')
        }
        $since = ConvertTo-Pr11Utc -Value $SinceUtc
        $proven = @($proven | Where-Object {
            if (($_.PSObject.Properties.Name -contains 'atUtc') -and -not [string]::IsNullOrWhiteSpace([string]$_.atUtc)) {
                $rowUtc = ConvertTo-Pr11Utc -Value $_.atUtc
                return ($null -ne $rowUtc -and $null -ne $since -and $rowUtc -ge $since)
            }
            return $false
        })
    }
    return [pscustomobject][ordered]@{
        ordinary = @($proven | Where-Object { (Get-TradeIterationClassification -Iteration $_) -eq 'Ordinary' })
        horse = @($proven | Where-Object { (Get-TradeIterationClassification -Iteration $_) -in @('PackAnimal', 'Horse') })
        food = @($proven | Where-Object { (Get-TradeIterationClassification -Iteration $_) -eq 'Food' })
        all = $proven
    }
}

function Test-FullCampaignArrivalEvidence {
    param(
        [object]$Readiness = $null,
        [object]$ExecutionJson = $null,
        [string]$TargetSettlement = $null
    )
    $arrived = $false
    $townEntered = $false
    $currentTown = $null
    if ($ExecutionJson) {
        if ($ExecutionJson.PSObject.Properties.Name -contains 'arrived') { $arrived = [bool]$ExecutionJson.arrived }
        elseif ($ExecutionJson.PSObject.Properties.Name -contains 'Arrived') { $arrived = [bool]$ExecutionJson.Arrived }
        if ($ExecutionJson.certSummary -and ($ExecutionJson.certSummary.PSObject.Properties.Name -contains 'passCandidate')) {
            if ([bool]$ExecutionJson.certSummary.passCandidate) { $arrived = $true }
        }
    }
    if ($Readiness) {
        $surface = if ($Readiness.stateMachine.gameplaySurface) { [string]$Readiness.stateMachine.gameplaySurface } else { '' }
        $townEntered = [bool]$Readiness.townMenuReady -or ($surface -in @('settlement_menu', 'trading', 'town_management'))
        if ($Readiness.recursiveBranchState -and $Readiness.recursiveBranchState.currentTown) {
            $currentTown = [string]$Readiness.recursiveBranchState.currentTown
        }
        if (-not [string]::IsNullOrWhiteSpace($TargetSettlement) -and -not [string]::IsNullOrWhiteSpace($currentTown)) {
            if ($currentTown -eq $TargetSettlement -or $currentTown -like "*$TargetSettlement*" -or $TargetSettlement -like "*$currentTown*") {
                $arrived = $true
            }
        }
        if ($townEntered -and $arrived -eq $false -and -not [string]::IsNullOrWhiteSpace($TargetSettlement)) {
            # Town menu ready after an executed travel toward the target is arrival+entry evidence.
            $arrived = $true
        }
    }
    return [pscustomobject][ordered]@{
        arrivalObserved = [bool]$arrived
        townEntryObserved = [bool]$townEntered
        currentTown = $currentTown
        targetSettlement = $TargetSettlement
    }
}

function Test-FullCampaignGovernorHandoffEvidence {
    param([object]$GuildLoopJson = $null)
    if (-not $GuildLoopJson) {
        return [pscustomobject][ordered]@{ present = $false; stalled = $true; count = 0; handoffs = @() }
    }
    $handoffs = @()
    if ($GuildLoopJson.PSObject.Properties.Name -contains 'governorActivityHandoffs') {
        $handoffs = @($GuildLoopJson.governorActivityHandoffs)
    }
    $present = ($handoffs.Count -gt 0)
    $stalled = $false
    if ($present) {
        $openDictated = @($handoffs | Where-Object {
            ([string]$_.authorityMode -eq 'Dictated') -and
            ([string]$_.terminalOutcome -notin @('Completed', 'Blocked', 'Failed', 'Terminal'))
        })
        $stalled = ($openDictated.Count -gt 0)
    }
    return [pscustomobject][ordered]@{
        present = $present
        stalled = $stalled
        count = $handoffs.Count
        handoffs = $handoffs
    }
}

function Test-FullCampaignManpowerEvidence {
    param([object]$RecruitmentJson = $null)
    if (-not $RecruitmentJson) {
        return [pscustomobject][ordered]@{
            proven = $false
            acquisitionType = $null
            rosterBefore = $null
            rosterAfter = $null
            directInjection = $null
            goldDelta = $null
        }
    }
    $audit = $RecruitmentJson.mutationAudit
    $partyChanged = $false
    $directInjection = $false
    if ($audit) {
        if ($audit.PSObject.Properties.Name -contains 'partyChangedByVanillaRecruitment') {
            $partyChanged = [bool]$audit.partyChangedByVanillaRecruitment
        }
        if ($audit.PSObject.Properties.Name -contains 'directInjection') {
            $directInjection = [bool]$audit.directInjection
        }
    }
    $candidateInParty = $false
    if ($RecruitmentJson.PSObject.Properties.Name -contains 'candidateInParty') {
        $candidateInParty = [bool]$RecruitmentJson.candidateInParty
    }
    $after = $RecruitmentJson.after
    $before = $RecruitmentJson.before
    $rosterBefore = if ($before -and ($before.PSObject.Properties.Name -contains 'partyMemberCount')) { [int]$before.partyMemberCount } else { $null }
    $rosterAfter = if ($after -and ($after.PSObject.Properties.Name -contains 'partyMemberCount')) { [int]$after.partyMemberCount } else { $null }
    $rosterIncreased = ($null -ne $rosterBefore -and $null -ne $rosterAfter -and $rosterAfter -gt $rosterBefore)
    $proven = ($partyChanged -or $candidateInParty -or $rosterIncreased) -and (-not $directInjection)
    return [pscustomobject][ordered]@{
        proven = [bool]$proven
        acquisitionType = 'companion_recruitment'
        rosterBefore = $rosterBefore
        rosterAfter = $rosterAfter
        directInjection = $directInjection
        goldDelta = $(if ($after -and ($after.PSObject.Properties.Name -contains 'goldDelta')) { $after.goldDelta } else { $null })
    }
}

function Test-FullCampaignHandoffPassCriteria {
    param(
        [string]$CertProfile = 'full_campaign_handoff',
        [string]$StopReason = $null,
        [bool]$MovementObserved = $false,
        [bool]$ArrivalObserved = $false,
        [bool]$TownEntryObserved = $false,
        [bool]$GovernorHandoffPresent = $false,
        [bool]$GovernorHandoffStalled = $false,
        [object[]]$TradeIterations = @(),
        [nullable[datetime]]$TradeScopeSinceUtc = $null,
        [int]$TradeIterationTarget = 1,
        [int]$HorseAcquisitionTarget = 1,
        [int]$ProvisionAcquisitionTarget = 1,
        [int]$ManpowerAcquisitionTarget = 1,
        [object]$ManpowerEvidence = $null,
        [object[]]$RuntimeEvents = @(),
        [object[]]$CheckpointEvents = @(),
        [object[]]$BranchConsiderationLog = @(),
        [bool]$FakeGameplayDelta = $false,
        [bool]$DirectInjection = $false,
        [bool]$RequireTerminalEvent = $true
    )

    $failures = New-Object System.Collections.Generic.List[string]
    $classified = Get-ProvenTradesByClassification -TradeIterations $TradeIterations -SinceUtc $TradeScopeSinceUtc

    if (Test-FullCampaignHandoffMovementTerminalForbidden -StopReason $StopReason -CertProfile $CertProfile) {
        $failures.Add('movement_observed_terminal_forbidden') | Out-Null
    }
    if (-not $MovementObserved) { $failures.Add('movement_not_observed') | Out-Null }
    if (-not $ArrivalObserved) { $failures.Add('arrival_not_observed') | Out-Null }
    if (-not $TownEntryObserved) { $failures.Add('town_entry_not_observed') | Out-Null }
    if (-not $GovernorHandoffPresent) { $failures.Add('governor_handoff_missing') | Out-Null }
    if ($GovernorHandoffStalled) { $failures.Add('governor_handoff_stalled') | Out-Null }

    $ordinaryCount = @($classified.ordinary).Count
    $horseCount = @($classified.horse).Count
    $foodCount = @($classified.food).Count
    if ($ordinaryCount -lt $TradeIterationTarget) { $failures.Add('ordinary_trade_delta_missing') | Out-Null }
    if ($horseCount -lt $HorseAcquisitionTarget) { $failures.Add('horse_delta_missing') | Out-Null }
    if ($foodCount -lt $ProvisionAcquisitionTarget) { $failures.Add('provision_delta_missing') | Out-Null }

    $manpowerProven = $false
    if ($ManpowerEvidence -and $ManpowerEvidence.proven) { $manpowerProven = $true }
    if (-not $manpowerProven -and $ManpowerAcquisitionTarget -gt 0) {
        $failures.Add('manpower_delta_missing') | Out-Null
    }

    # Reject counting the same row under two required branches.
    $ids = @{}
    foreach ($row in @($classified.all)) {
        $key = "{0}|{1}|{2}|{3}" -f $row.iteration, $row.itemName, $row.goldBefore, $row.inventoryBefore
        if ($ids.ContainsKey($key)) { $failures.Add('reused_delta_counted_twice') | Out-Null; break }
        $ids[$key] = $true
    }

    $blockedAsSuccess = @($BranchConsiderationLog | Where-Object {
        ([string]$_.status -eq 'blocked') -and ($_.countedAsSuccess -eq $true)
    })
    if ($blockedAsSuccess.Count -gt 0) { $failures.Add('blocked_branch_counted_as_success') | Out-Null }

    if ($FakeGameplayDelta) { $failures.Add('fake_gameplay_delta') | Out-Null }
    if ($DirectInjection) { $failures.Add('direct_injection') | Out-Null }

    $orphans = Get-AutomationOrphanCommandStarts -RuntimeEvents $RuntimeEvents
    if ($orphans.orphanCount -gt 0) { $failures.Add('orphan_command_started') | Out-Null }

    if ($RequireTerminalEvent) {
        $finalizedPass = @($CheckpointEvents | Where-Object { $_.eventType -eq 'finalized_pass' -and $_.isTerminal -eq $true })
        $terminalEvents = @($CheckpointEvents | Where-Object { $_.isTerminal -eq $true })
        if (-not ($finalizedPass.Count -eq 1 -and $terminalEvents.Count -eq 1)) {
            $failures.Add('missing_terminal_finalized_pass') | Out-Null
        }
    }

    $unique = @($failures.ToArray() | Select-Object -Unique)
    return [pscustomobject][ordered]@{
        pass = ($unique.Count -eq 0)
        certProfile = $CertProfile
        stopReason = $StopReason
        movementObserved = [bool]$MovementObserved
        arrivalObserved = [bool]$ArrivalObserved
        townEntryObserved = [bool]$TownEntryObserved
        governorHandoffPresent = [bool]$GovernorHandoffPresent
        ordinaryTradeCount = $ordinaryCount
        horseAcquisitionCount = $horseCount
        provisionAcquisitionCount = $foodCount
        manpowerProven = [bool]$manpowerProven
        tradeIterationTarget = $TradeIterationTarget
        horseAcquisitionTarget = $HorseAcquisitionTarget
        provisionAcquisitionTarget = $ProvisionAcquisitionTarget
        manpowerAcquisitionTarget = $ManpowerAcquisitionTarget
        failureClasses = $unique
        exactFailureClass = $(if ($unique.Count -gt 0) { $unique[0] } else { $null })
    }
}

function Save-FullCampaignHandoffCertEvidence {
    param(
        [hashtable]$Evidence,
        [string]$BannerlordRoot,
        [hashtable]$Summary,
        [object]$Criteria
    )

    $dir = $Evidence.checkpointDir
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    foreach ($name in @(
            'BlacksmithGuild_TradeIterations.jsonl',
            'BlacksmithGuild_BoundaryEvents.jsonl',
            'BlacksmithGuild_AutonomousGuildLoop.json',
            'BlacksmithGuild_TavernHeroRecruitment.json',
            'BlacksmithGuild_AssistiveTravelExecution.json',
            'BlacksmithGuild_MovementProof.json',
            'BlacksmithGuild_FoodBuyProbe.json',
            'BlacksmithGuild_MapTradeProbe.json',
            'BlacksmithGuild_Status.json'
        )) {
        $src = Join-Path $BannerlordRoot $name
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $dir $name) -Force
        }
    }

    $summaryObj = [ordered]@{
        schema = 'tbg.full-campaign-handoff.summary.v1'
        runId = $Evidence.sessionId
        certProfile = 'full_campaign_handoff'
        startSha = $Summary.startSha
        endSha = $Summary.endSha
        loadedDllHash = $Summary.loadedDllHash
        builtDllHash = $Summary.builtDllHash
        installedDllHash = $Summary.installedDllHash
        disposableSave = $Summary.disposableSave
        targetSettlement = $Evidence.targetSettlement
        stopReason = $Summary.stopReason
        highestProofLevel = $Summary.highestProofLevel
        branches = [ordered]@{
            movement = [bool]$Summary.movementObserved
            arrival = [bool]$Summary.arrivalObserved
            townEntry = [bool]$Summary.townEntryObserved
            governorHandoff = [bool]$Summary.governorHandoffPresent
            ordinaryTrade = [int]$Criteria.ordinaryTradeCount
            horseAcquisition = [int]$Criteria.horseAcquisitionCount
            provisionAcquisition = [int]$Criteria.provisionAcquisitionCount
            manpowerAcquisition = [bool]$Criteria.manpowerProven
        }
        handoffChain = $Summary.handoffChain
        terminalState = $Summary.stopReason
        exactFailureClass = $Criteria.exactFailureClass
    }

    $certObj = [ordered]@{
        schema = 'tbg.full-campaign-handoff.cert.v1'
        pass = [bool]$Criteria.pass
        criteria = $Criteria
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    if (Get-Command Save-Pr11JsonArtifact -ErrorAction SilentlyContinue) {
        Save-Pr11JsonArtifact -Object $summaryObj -Path (Join-Path $dir 'full-campaign-handoff-summary.json') | Out-Null
        Save-Pr11JsonArtifact -Object $certObj -Path (Join-Path $dir 'full-campaign-handoff-cert.json') | Out-Null
    } else {
        $summaryObj | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $dir 'full-campaign-handoff-summary.json') -Encoding UTF8
        $certObj | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $dir 'full-campaign-handoff-cert.json') -Encoding UTF8
    }
    return $Criteria
}

function Get-FullCampaignHandoffNextCommand {
    # Deterministic phase driver after town entry. Returns command name or $null to observe.
    param(
        [bool]$MovementObserved,
        [bool]$ArrivalObserved,
        [bool]$TownEntryObserved,
        [bool]$OrdinaryTradeDone,
        [bool]$HorseDone,
        [bool]$ProvisionDone,
        [bool]$ManpowerDone,
        [string]$Surface
    )

    if (-not $MovementObserved -or -not $ArrivalObserved -or -not $TownEntryObserved) {
        return [pscustomobject][ordered]@{ phase = 'travel_arrival'; commandSent = $null; reason = 'await_arrival_or_town_entry' }
    }
    if ($Surface -notin @('trading', 'settlement_menu', 'town_management')) {
        return [pscustomobject][ordered]@{ phase = 'await_settlement_surface'; commandSent = $null; reason = 'town_surface_not_ready' }
    }
    if (-not $OrdinaryTradeDone) {
        return [pscustomobject][ordered]@{ phase = 'ordinary_trade'; commandSent = 'ProbeVanillaTradeExecutionNow'; reason = 'drive_ordinary_trade' }
    }
    if (-not $HorseDone) {
        return [pscustomobject][ordered]@{ phase = 'horse_acquisition'; commandSent = 'ProbePackAnimalBuyNow'; reason = 'drive_pack_animal_buy' }
    }
    if (-not $ProvisionDone) {
        return [pscustomobject][ordered]@{ phase = 'provision_acquisition'; commandSent = 'ProbeFoodBuyNow'; reason = 'drive_food_buy' }
    }
    if (-not $ManpowerDone) {
        return [pscustomobject][ordered]@{ phase = 'manpower_acquisition'; commandSent = 'RecruitTavernHeroVisibleNow'; reason = 'drive_companion_recruit' }
    }
    return [pscustomobject][ordered]@{ phase = 'complete'; commandSent = $null; reason = 'full_campaign_handoff_complete' }
}
