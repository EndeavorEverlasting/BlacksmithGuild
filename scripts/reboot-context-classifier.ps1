# Shared local reboot context normalization and stable-gap handoff helpers.

function Read-RebootJsonFile {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json
    } catch { return $null }
}

function Read-RebootJsonlFile {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return @() }
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($line in @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $items.Add(($line | ConvertFrom-Json)) | Out-Null } catch { }
    }
    return @($items.ToArray())
}

function Get-RebootLastItem {
    param([object[]]$Items)
    if (-not $Items -or $Items.Count -eq 0) { return $null }
    return $Items[$Items.Count - 1]
}

function Get-RebootFirstValue {
    param([object[]]$Values)
    foreach ($value in @($Values)) {
        if ($null -eq $value) { continue }
        $text = [string]$value
        if (-not [string]::IsNullOrWhiteSpace($text)) { return $text }
    }
    return $null
}

function ConvertTo-RebootBool {
    param($Value)
    if ($Value -eq $true) { return $true }
    if ($Value -eq $false) { return $false }
    if ($null -eq $Value) { return $false }
    return ([string]$Value -match '^(true|1|yes)$')
}

function Get-RebootMovementBucket {
    param($Distance)
    $value = 0.0
    if ($null -ne $Distance) { [double]::TryParse([string]$Distance, [ref]$value) | Out-Null }
    if ($value -le 0) { return 'zero' }
    if ($value -lt 1) { return 'positive_lt_1' }
    if ($value -lt 10) { return 'positive_1_10' }
    return 'positive_10_plus'
}

function Get-RebootMovementProofClassification {
    param(
        [object]$Execution,
        [object]$MovementProof
    )
    foreach ($candidate in @(
        $MovementProof.classification,
        $Execution.movementProofClassification,
        $Execution.movementProof.classification,
        $Execution.movementProof.result
    )) {
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { return [string]$candidate }
    }
    return $null
}

function Test-RebootDurableMovementObserved {
    param(
        [object]$Execution,
        [object]$MovementProof
    )
    $distance = 0.0
    foreach ($candidate in @($Execution.partyMovedDistance, $MovementProof.partyMovedDistance)) {
        if ($null -eq $candidate) { continue }
        if ([double]::TryParse([string]$candidate, [ref]$distance)) { break }
    }
    $classification = Get-RebootMovementProofClassification -Execution $Execution -MovementProof $MovementProof
    return [bool](
        ($distance -gt 0) -or
        ($Execution.movementCheckpointObserved -eq $true) -or
        ($Execution.movementMetricDisagreement -eq $true) -or
        ($classification -in @(
            'MovementDistanceObserved',
            'MovementCheckpointObserved',
            'MovementMetricDisagreement',
            'movement_distance_observed',
            'movement_checkpoint_observed',
            'movement_metric_disagreement'
        ))
    )
}

function Get-RebootMovementObservationClass {
    param(
        [string]$MovementProofClassification,
        [bool]$DurableMovementObserved,
        [double]$PartyMovedDistance,
        [bool]$CommandAcknowledged,
        [bool]$MovementIntentSet,
        [bool]$TravelClockRunning,
        [bool]$OperatorInterruptionObserved,
        [bool]$ForegroundLoss,
        [bool]$FairWindowElapsed,
        [bool]$MovementProofPresent
    )

    if ($DurableMovementObserved -and $PartyMovedDistance -le 0) { return 'movement_metric_disagreement' }
    if ($DurableMovementObserved) {
        switch -Regex ([string]$MovementProofClassification) {
            'MetricDisagreement' { return 'movement_metric_disagreement' }
            'CheckpointObserved' { return 'movement_checkpoint_observed' }
            'DistanceObserved' { return 'movement_distance_observed' }
        }
        return 'movement_checkpoint_observed'
    }
    if (($ForegroundLoss -or $OperatorInterruptionObserved) -and $CommandAcknowledged) {
        return 'foreground_interruption_prevented_observation'
    }
    if ($CommandAcknowledged -and $MovementIntentSet -and $TravelClockRunning -and (-not $MovementProofPresent -or [string]$MovementProofClassification -in @('', 'Unknown', 'MovementObservationIndeterminate', 'MovementCommandAckWithoutDurableEvidence'))) {
        return 'movement_observation_indeterminate'
    }
    if ([string]$MovementProofClassification -match 'ForegroundInterruptionPreventedObservation') {
        return 'foreground_interruption_prevented_observation'
    }
    if ([string]$MovementProofClassification -match 'MovementNotObservedAfterFairWindow' -or $FairWindowElapsed) {
        return 'movement_not_observed_after_fair_window'
    }
    if ([string]$MovementProofClassification -match 'MovementObservationIndeterminate|MovementCommandAckWithoutDurableEvidence') {
        return 'movement_observation_indeterminate'
    }
    return 'unknown'
}

function Get-RebootCountBucket {
    param($Count)
    $value = 0
    if ($null -ne $Count) { [int]::TryParse([string]$Count, [ref]$value) | Out-Null }
    if ($value -le 0) { return '0' }
    if ($value -eq 1) { return '1' }
    if ($value -le 4) { return '2_4' }
    if ($value -le 9) { return '5_9' }
    return '10_plus'
}

function Get-RebootLastMeaningfulCheckpoint {
    param([object[]]$Events)
    if (-not $Events -or $Events.Count -eq 0) { return $null }
    for ($i = $Events.Count - 1; $i -ge 0; $i--) {
        $event = $Events[$i]
        if ($event.checkpointName -and $event.checkpointName -notin @('summary_written','finalization_started')) {
            return [string]$event.checkpointName
        }
    }
    return $null
}

function Get-RebootActionTimeoutSec {
    param(
        [ValidateSet('normal','long_distance_travel','large_smithing','mass_trade')]
        [string]$ActionClass = 'normal',
        [int]$NormalActionTimeoutSec = 30,
        [int]$LongTravelTimeoutSec = 180,
        [int]$LargeSmithingTimeoutSec = 300,
        [int]$MassTradeTimeoutSec = 300
    )
    switch ($ActionClass) {
        'long_distance_travel' { return $LongTravelTimeoutSec }
        'large_smithing' { return $LargeSmithingTimeoutSec }
        'mass_trade' { return $MassTradeTimeoutSec }
        default { return $NormalActionTimeoutSec }
    }
}

function Get-RebootLikelyOwner {
    param($Context)
    if ($Context.operatorInterruptionObserved -or $Context.foregroundLoss) { return 'operator interruption' }
    if ($Context.handoffMissingTarget) { return 'engine destination handoff' }
    if ($Context.movementObservationClass -in @('movement_metric_disagreement','movement_observation_indeterminate')) { return 'movement evidence/classification' }
    if ($Context.movementObservationClass -eq 'movement_not_observed_after_fair_window') { return 'runtime movement' }
    if ($Context.staleEvidence) { return 'evidence/staleness' }
    if ($Context.movementIntentSet -and -not $Context.partyMovementObserved) { return 'runtime movement' }
    if ([string]$Context.failureClass -match 'build|deploy|launcher|continue|attach|process_disappeared|game_exited') { return 'launcher/deploy' }
    if ([string]$Context.safeIdleClass -like 'safe_idle_*') { return 'runner orchestration' }
    return 'unknown'
}

function Get-RebootLikelyFiles {
    param([string]$Owner)
    switch ($Owner) {
        'engine destination handoff' { return @('scripts/run-autonomous-assist-session.ps1','src/BlacksmithGuild/DevTools/RecursiveCampaignBranchState.cs','src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeRegent.cs') }
        'runtime movement' { return @('src/BlacksmithGuild/DevTools/Assistive/AssistiveLeaveTownTravelService.cs','src/BlacksmithGuild/DevTools/CampaignMapMovementHelper.cs','scripts/pr11-assistive-execute-contract.ps1') }
        'movement evidence/classification' { return @('src/BlacksmithGuild/DevTools/Assistive/MovementProofLedgerService.cs','src/BlacksmithGuild/DevTools/Assistive/AssistiveTravelEvidenceWriter.cs','scripts/run-autonomous-assist-session.ps1','scripts/reboot-context-classifier.ps1') }
        'operator interruption' { return @('src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeRegent.cs','scripts/pr11-runtime-state-consumer.ps1','scripts/run-autonomous-assist-session.ps1') }
        'launcher/deploy' { return @('forge.ps1','scripts/install-mod.ps1','scripts/launcher-auto-nav.ps1','scripts/run-autonomous-assist-session.ps1') }
        'evidence/staleness' { return @('scripts/run-autonomous-assist-session.ps1','scripts/automation-checkpoint-contract.ps1','scripts/process-lifecycle-authority.ps1') }
        default { return @('scripts/run-autonomous-assist-session.ps1','scripts/autonomous-assist-session.ps1') }
    }
}

function New-RebootNormalizedContext {
    param([string]$EvidencePath)
    $summary = Read-RebootJsonFile (Join-Path $EvidencePath 'assist-loop-summary.json')
    $campaign = Read-RebootJsonFile (Join-Path $EvidencePath 'campaign-loop-summary.json')
    $manifest = Read-RebootJsonFile (Join-Path $EvidencePath 'session-manifest.json')
    $execution = Read-RebootJsonFile (Join-Path $EvidencePath 'BlacksmithGuild_AssistiveTravelExecution.json')
    $movementProofFile = Read-RebootJsonFile (Join-Path $EvidencePath 'BlacksmithGuild_MovementProof.json')
    $states = Read-RebootJsonlFile (Join-Path $EvidencePath 'state-snapshots.jsonl')
    $commands = Read-RebootJsonlFile (Join-Path $EvidencePath 'command-timeline.jsonl')
    $safety = Read-RebootJsonlFile (Join-Path $EvidencePath 'safety-decisions.jsonl')
    $events = Read-RebootJsonlFile (Join-Path $EvidencePath 'checkpoint-events.jsonl')
    $lastState = Get-RebootLastItem $states
    $lastCommand = Get-RebootLastItem $commands
    $lastSafety = Get-RebootLastItem $safety
    $movementProof = if ($movementProofFile) { $movementProofFile } elseif ($execution -and $execution.movementProof) { $execution.movementProof } else { $null }
    $movementBucket = Get-RebootMovementBucket $(if ($execution) { $execution.partyMovedDistance } else { 0 })
    $checkpoints = @($events | ForEach-Object { $_.checkpointName } | Where-Object { $_ })
    $stopReason = Get-RebootFirstValue @($summary.stopReason, $lastSafety.reason)
    $failureClass = Get-RebootFirstValue @($summary.failureClass, $stopReason)
    $commandSent = Get-RebootFirstValue @($lastCommand.commandSent)
    $partyMovedDistance = 0.0
    foreach ($candidate in @($execution.partyMovedDistance, $movementProof.partyMovedDistance)) {
        if ($null -eq $candidate) { continue }
        if ([double]::TryParse([string]$candidate, [ref]$partyMovedDistance)) { break }
    }
    $movementProofClassification = Get-RebootMovementProofClassification -Execution $execution -MovementProof $movementProof
    $movementMetricDisagreement = [bool](($execution.movementMetricDisagreement -eq $true) -or ($movementProofClassification -in @('MovementMetricDisagreement', 'movement_metric_disagreement')))
    $movementCheckpointObserved = [bool](($execution.movementCheckpointObserved -eq $true) -or ($movementProofClassification -in @('MovementCheckpointObserved', 'movement_checkpoint_observed', 'MovementMetricDisagreement', 'movement_metric_disagreement')))
    $durableMovementObserved = Test-RebootDurableMovementObserved -Execution $execution -MovementProof $movementProof
    $movementProofPresent = [bool]$movementProof
    $movementDeltas = [ordered]@{
        positionChanged = [bool]$movementProof.deltas.positionChanged
        distanceToTargetChanged = [bool]$movementProof.deltas.distanceToTargetChanged
        mapTimeAdvanced = [bool]$movementProof.deltas.mapTimeAdvanced
        currentSettlementChanged = [bool]$movementProof.deltas.currentSettlementChanged
        nearestSettlementChanged = [bool]$movementProof.deltas.nearestSettlementChanged
        targetChanged = [bool]$movementProof.deltas.targetChanged
        partyMovedDistanceChanged = [bool]$movementProof.deltas.partyMovedDistanceChanged
        maxDistanceFromStart = Get-RebootFirstValue @($movementProof.deltas.maxDistanceFromStart)
        startDistanceToTarget = Get-RebootFirstValue @($movementProof.deltas.startDistanceToTarget)
        lastDistanceToTarget = Get-RebootFirstValue @($movementProof.deltas.lastDistanceToTarget)
    }
    $travelClockRunning = (ConvertTo-RebootBool $(if ($execution) { $execution.travelClockRunning } else { $false }))
    $movementIntentSet = (ConvertTo-RebootBool $(if ($execution) { $execution.movementIntentSet } else { $false }))
    $operatorInterruptionObserved = [bool]((ConvertTo-RebootBool $lastState.operatorInterruptionObserved) -or ([string]$stopReason -like 'operator_interruption*'))
    $foregroundLoss = [bool](([string]$stopReason -eq 'operator_interruption_foreground_lost') -or ($lastState.foregroundLossSeconds -gt 0))
    $fairWindowElapsed = [bool]([string]$stopReason -in @('safe_idle_route_set_no_motion','safe_idle_clock_stopped'))
    $movementObservationClass = Get-RebootMovementObservationClass -MovementProofClassification $movementProofClassification `
        -DurableMovementObserved:$durableMovementObserved -PartyMovedDistance $partyMovedDistance `
        -CommandAcknowledged:$([bool]((-not [string]::IsNullOrWhiteSpace($commandSent)) -and ($lastCommand.result -eq 'Success' -or ($checkpoints -contains 'execute_ack') -or ($checkpoints -contains 'campaign_clock_resume_ack')))) `
        -MovementIntentSet:$movementIntentSet -TravelClockRunning:$travelClockRunning `
        -OperatorInterruptionObserved:$operatorInterruptionObserved -ForegroundLoss:$foregroundLoss `
        -FairWindowElapsed:$fairWindowElapsed -MovementProofPresent:$movementProofPresent
    $ctx = [ordered]@{
        schemaVersion = 1
        failureClass = $failureClass
        stopReason = $stopReason
        visibleMechanicsProven = (ConvertTo-RebootBool $summary.visibleMechanicsProven)
        proofMode = Get-RebootFirstValue @($summary.proofMode)
        surface = Get-RebootFirstValue @($campaign.gameplaySurface, $lastState.stateMachine.gameplaySurface, $lastCommand.surface, $lastSafety.surface)
        plannedBranch = Get-RebootFirstValue @($campaign.nextPlannedBranch, $summary.nextPlannedBranch, $lastState.nextPlannedBranch, $lastCommand.plannedBranch)
        target = Get-RebootFirstValue @($campaign.targetSettlement, $manifest.targetSettlement, $lastState.resolvedTravelTarget, $lastCommand.target)
        targetSource = Get-RebootFirstValue @($lastCommand.targetSource, $lastState.resolvedTravelTargetSource, $lastCommand.engineTargetSource)
        commandSent = $commandSent
        commandAcknowledged = [bool]((-not [string]::IsNullOrWhiteSpace($commandSent)) -and ($lastCommand.result -eq 'Success' -or ($checkpoints -contains 'execute_ack') -or ($checkpoints -contains 'campaign_clock_resume_ack')))
        travelClockRunning = $travelClockRunning
        movementIntentSet = $movementIntentSet
        partyMovedDistance = $partyMovedDistance
        partyMovedDistanceBucket = $movementBucket
        partyMovementObserved = [bool]$durableMovementObserved
        movementProofClassification = $movementProofClassification
        movementObservationClass = $movementObservationClass
        movementMetricDisagreement = $movementMetricDisagreement
        movementCheckpointObserved = $movementCheckpointObserved
        movementProofPath = if ($movementProofFile) { 'BlacksmithGuild_MovementProof.json' } elseif ($execution -and $execution.movementProof) { 'BlacksmithGuild_AssistiveTravelExecution.json.movementProof' } else { $null }
        movementDeltas = [pscustomobject]$movementDeltas
        operatorInterruptionObserved = $operatorInterruptionObserved
        operatorInterruptionReason = Get-RebootFirstValue @($lastState.operatorInterruptionReason, $(if ([string]$stopReason -like 'operator_interruption*') { $stopReason } else { $null }))
        foregroundLoss = $foregroundLoss
        handoffMissingTarget = [bool](@($failureClass, $stopReason, $lastSafety.reason) -contains 'handoff_missing_travel_target')
        staleEvidence = [bool]([string]$failureClass -match 'stale|heartbeat_stale|evidence_missing')
        safeIdleClass = Get-RebootFirstValue @($summary.lastSafeIdleClass, $lastCommand.safeIdleClass, $lastSafety.safeIdleClass)
        consecutiveSafeIdleCycles = Get-RebootCountBucket $(Get-RebootFirstValue @($summary.maxConsecutiveSafeIdleCycles, $lastState.consecutiveSafeIdleCycles, $lastCommand.consecutiveSafeIdleCycles))
        lastMeaningfulCheckpoint = Get-RebootLastMeaningfulCheckpoint -Events $events
    }
    $owner = Get-RebootLikelyOwner -Context ([pscustomobject]$ctx)
    $ctx['likelyOwner'] = $owner
    $ctx['likelyFiles'] = @(Get-RebootLikelyFiles -Owner $owner)
    return [pscustomobject]$ctx
}

function ConvertTo-RebootContextFingerprint {
    param($Context)
    return ($Context | ConvertTo-Json -Depth 8 -Compress)
}

function Test-RebootContextRepeat {
    param($A, $B)
    if (-not $A -or -not $B) { return $false }
    return (ConvertTo-RebootContextFingerprint $A) -eq (ConvertTo-RebootContextFingerprint $B)
}

function Write-RebootJson {
    param([object]$Object, [string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    return $Path
}

function Write-RebootSummaryMarkdown {
    param([object]$Summary, [string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $ctxJson = $Summary.latestNormalizedContext | ConvertTo-Json -Depth 8
    $lines = @(
        '# REBOOT SUMMARY', '',
        "- iterations run: $($Summary.iterationsRun)",
        "- final classification: $($Summary.finalClassification)",
        "- repeated context: $($Summary.repeatedContext)",
        "- latest evidence path: $($Summary.latestEvidencePath)",
        "- next local action: $($Summary.nextLocalAction)",
        "- next patch owner: $($Summary.nextPatchOwner)",
        "- user action needed: $($Summary.userActionNeeded)", '',
        '## Latest normalized context', '```json', $ctxJson, '```'
    )
    if ($Summary.repeatedContext) {
        $lines += @('', '## READY GAP HANDOFF', '',
            "- stable gap: $($Summary.finalClassification)",
            "- evidence A: $($Summary.evidenceA)",
            "- evidence B: $($Summary.evidenceB)",
            "- recommended patch target: $($Summary.recommendedPatchTarget)",
            '- why this is not a wait problem: the same normalized context repeated at the configured threshold.')
    }
    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
    return $Path
}

function Write-RebootStableGapHandoff {
    param(
        [object]$Context,
        [string]$EvidenceA,
        [string]$EvidenceB,
        [string]$OutputDir,
        [object[]]$CommandsRun = @(),
        [string]$ValidationState = 'not_run',
        [bool]$UserActionNeeded = $false
    )
    if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
    $payload = [ordered]@{ classification = 'stable_gap'; repeatedContext = $Context; evidenceA = $EvidenceA; evidenceB = $EvidenceB; generatedUtc = (Get-Date).ToUniversalTime().ToString('o') }
    $jsonPath = Write-RebootJson -Object $payload -Path (Join-Path $OutputDir 'stable-gap-context.json')
    $owner = [string]$Context.likelyOwner
    $files = @($Context.likelyFiles) -join ', '
    $ctxJson = $Context | ConvertTo-Json -Depth 8
    $movementJson = $Context.movementDeltas | ConvertTo-Json -Depth 6 -Compress
    $cmdText = if ($CommandsRun) { @($CommandsRun | ForEach-Object { "- $_" }) } else { @('- none recorded') }
    $lines = @('# STABLE GAP HANDOFF', '',
        '- classification: stable_gap',
        "- likely owner: $owner",
        "- likely files to inspect: $files",
        "- evidence A: $EvidenceA",
        "- evidence B: $EvidenceB",
        "- validation state: $ValidationState",
        "- user action needed: $UserActionNeeded", '',
        '## Repeated normalized context', '```json', $ctxJson, '```', '',
        '## Why stable', 'The same normalized context appeared consecutively at the repeat threshold after noisy fields were removed.', '',
        '## Movement Evidence',
        "- movement proof path: $($Context.movementProofPath)",
        "- movement proof classification: $($Context.movementProofClassification)",
        "- movement observation class: $($Context.movementObservationClass)",
        "- partyMovedDistance: $($Context.partyMovedDistance)",
        "- movementMetricDisagreement: $($Context.movementMetricDisagreement)",
        "- movementCheckpointObserved: $($Context.movementCheckpointObserved)",
        "- deltas: $movementJson",
        "- command ACK: $($Context.commandAcknowledged)",
        "- target: $($Context.target)",
        "- foreground/operator state: foregroundLoss=$($Context.foregroundLoss) operatorInterruptionObserved=$($Context.operatorInterruptionObserved)", '',
        '## Recommended next patch', "Patch the $owner seam first. Inspect: $files", '',
        '## Commands already run') + $cmdText
    $mdPath = Join-Path $OutputDir 'stable-gap-handoff.md'
    Set-Content -LiteralPath $mdPath -Value $lines -Encoding UTF8
    return [pscustomobject]@{ markdownPath = $mdPath; jsonPath = $jsonPath }
}