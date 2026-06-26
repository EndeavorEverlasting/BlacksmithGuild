$script:AutomationCheckpointSchemaVersion = 1
$script:AutomationCheckpointEventTypes = @(
    'checkpoint_reached',
    'checkpoint_blocked',
    'cycle_completed',
    'stop_requested',
    'unsafe_surface',
    'finalization_started',
    'finalized_pass',
    'finalized_fail',
    'finalized_abort'
)
$script:AutomationCheckpointNames = @(
    'session_started',
    'launcher_open',
    'continue_visible',
    'continue_clicked',
    'game_spawned',
    'attach_ready',
    'state_machine_consumed',
    'runtime_lifecycle_consumed',
    'travel_gate_ready',
    'probe_ack',
    'execute_ack',
    'party_movement_observed',
    'market_evaluated',
    'smithing_refine_completed',
    'tavern_companion_scan_completed',
    'companion_roster_decision_recorded',
    'cycle_completed',
    'next_action_planned',
    'unsafe_surface',
    'stop_requested',
    'toggle_received',
    'assist_loop_started',
    'summary_written',
    'automation_not_running',
    'previous_run_terminal_notice',
    'finalization_started',
    'finalized_pass',
    'finalized_fail',
    'finalized_abort'
)

if (-not $script:AutomationCheckpointEvents) {
    $script:AutomationCheckpointEvents = New-Object System.Collections.Generic.List[object]
}
if (-not $script:AutomationCheckpointThrottle) {
    $script:AutomationCheckpointThrottle = @{}
}

function Test-AutomationCheckpointEventType {
    param([string]$EventType)
    return ($script:AutomationCheckpointEventTypes -contains $EventType)
}

function Test-AutomationCheckpointName {
    param([string]$CheckpointName)
    return ($script:AutomationCheckpointNames -contains $CheckpointName)
}

function Test-AutomationCheckpointThrottle {
    param(
        [Parameter(Mandatory = $true)][string]$CheckpointName,
        [int]$ThrottleSeconds = 5
    )
    $now = (Get-Date).ToUniversalTime()
    if ($ThrottleSeconds -le 0) {
        $script:AutomationCheckpointThrottle[$CheckpointName] = $now
        return $true
    }
    if ($script:AutomationCheckpointThrottle.ContainsKey($CheckpointName)) {
        $last = [datetime]$script:AutomationCheckpointThrottle[$CheckpointName]
        if (($now - $last).TotalSeconds -lt $ThrottleSeconds) {
            return $false
        }
    }
    $script:AutomationCheckpointThrottle[$CheckpointName] = $now
    return $true
}

function New-AutomationCheckpointEvent {
    param(
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$CheckpointName,
        [string]$SessionId = $null,
        [string]$RunId = $null,
        [string]$Phase = $null,
        [string]$Source = 'runner',
        [string]$Runner = $null,
        [bool]$IsTerminal = $false,
        [string]$TerminalState = $null,
        [string]$Reason = $null,
        [string]$MessageText = $null,
        [bool]$MessageShownInGame = $false,
        [object]$Criteria = $null,
        [object]$Details = $null,
        [string]$RelatedEventId = $null,
        [nullable[bool]]$GameProcessAlive = $null,
        [nullable[bool]]$SummaryWritten = $null
    )
    if (-not (Test-AutomationCheckpointEventType -EventType $EventType)) {
        throw "Unknown automation checkpoint eventType: $EventType"
    }
    if (-not (Test-AutomationCheckpointName -CheckpointName $CheckpointName)) {
        throw "Unknown automation checkpointName: $CheckpointName"
    }

    $event = [ordered]@{
        schemaVersion = $script:AutomationCheckpointSchemaVersion
        eventId = [guid]::NewGuid().ToString()
        sessionId = $SessionId
        runId = $RunId
        atUtc = (Get-Date).ToUniversalTime().ToString('o')
        eventType = $EventType
        checkpointName = $CheckpointName
        isTerminal = [bool]$IsTerminal
        terminalState = $TerminalState
        phase = $Phase
        source = $Source
        runner = $Runner
        reason = $Reason
        messageShownInGame = [bool]$MessageShownInGame
        messageText = $MessageText
        criteria = $Criteria
        details = $Details
        relatedEventId = $RelatedEventId
    }
    if ($null -ne $GameProcessAlive) { $event.gameProcessAlive = [bool]$GameProcessAlive }
    if ($null -ne $SummaryWritten) { $event.summaryWritten = [bool]$SummaryWritten }
    return [pscustomobject]$event
}

function Add-AutomationCheckpointEvent {
    param(
        [System.Collections.Generic.List[object]]$List = $script:AutomationCheckpointEvents,
        [object]$Event = $null,
        [string]$EventType = 'checkpoint_reached',
        [string]$CheckpointName = $null,
        [string]$SessionId = $null,
        [string]$RunId = $null,
        [string]$Phase = $null,
        [string]$Source = 'runner',
        [string]$Runner = $null,
        [string]$Reason = $null,
        [object]$Details = $null,
        [int]$ThrottleSeconds = 0
    )
    if ($Event) {
        $List.Add($Event) | Out-Null
        return $Event
    }
    if (-not $CheckpointName) {
        throw 'CheckpointName is required when Event is not supplied.'
    }
    if ($ThrottleSeconds -gt 0 -and -not (Test-AutomationCheckpointThrottle -CheckpointName $CheckpointName -ThrottleSeconds $ThrottleSeconds)) {
        return $null
    }
    $created = New-AutomationCheckpointEvent -EventType $EventType -CheckpointName $CheckpointName `
        -SessionId $SessionId -RunId $RunId -Phase $Phase -Source $Source -Runner $Runner `
        -Reason $Reason -Details $Details
    $List.Add($created) | Out-Null
    return $created
}

function Start-AutomationFinalization {
    param(
        [System.Collections.Generic.List[object]]$List = $script:AutomationCheckpointEvents,
        [string]$SessionId = $null,
        [string]$RunId = $null,
        [string]$Phase = $null,
        [string]$Runner = $null,
        [string]$Reason = $null,
        [object]$Details = $null
    )
    return Add-AutomationCheckpointEvent -List $List -Event (
        New-AutomationCheckpointEvent -EventType 'finalization_started' -CheckpointName 'finalization_started' `
            -SessionId $SessionId -RunId $RunId -Phase $Phase -Source 'runner' -Runner $Runner `
            -Reason $Reason -Details $Details -TerminalState 'pending'
    )
}

function Complete-AutomationFinalization {
    param(
        [System.Collections.Generic.List[object]]$List = $script:AutomationCheckpointEvents,
        [Parameter(Mandatory = $true)][ValidateSet('pass', 'fail', 'abort')][string]$State,
        [string]$SessionId = $null,
        [string]$RunId = $null,
        [string]$Phase = $null,
        [string]$Runner = $null,
        [string]$Reason = $null,
        [object]$Criteria = $null,
        [object]$Details = $null,
        [string]$RelatedEventId = $null,
        [nullable[bool]]$GameProcessAlive = $null,
        [nullable[bool]]$SummaryWritten = $null
    )
    $eventType = "finalized_$State"
    return Add-AutomationCheckpointEvent -List $List -Event (
        New-AutomationCheckpointEvent -EventType $eventType -CheckpointName $eventType `
            -SessionId $SessionId -RunId $RunId -Phase $Phase -Source 'runner' -Runner $Runner `
            -IsTerminal $true -TerminalState $State -Reason $Reason -Criteria $Criteria -Details $Details `
            -RelatedEventId $RelatedEventId -GameProcessAlive $GameProcessAlive -SummaryWritten $SummaryWritten
    )
}

function Test-AutomationPassCriteria {
    param(
        [object[]]$Events = @(),
        [object]$Summary = $null,
        [object]$Readiness = $null,
        [object]$ExecutionJson = $null,
        [string[]]$RequiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'summary_written'),
        [switch]$RequireAssistLoopStarted,
        [switch]$RequireExecuteMovement,
        [switch]$AllowPreFinalizationPreview
    )
    $names = @($Events | ForEach-Object { [string]$_.checkpointName })
    $missing = @($RequiredCheckpoints | Where-Object { $names -notcontains $_ })
    $criteria = [ordered]@{
        pass = $true
        previewMode = [bool]$AllowPreFinalizationPreview
        missingCheckpoints = @($missing)
        finalizedPassCount = [int](@($Events | Where-Object { $_.eventType -eq 'finalized_pass' -and $_.isTerminal -eq $true }).Count)
        finalizedPassPresent = [bool](@($Events | Where-Object { $_.eventType -eq 'finalized_pass' -and $_.isTerminal -eq $true }).Count -gt 0)
        terminalEventCount = [int](@($Events | Where-Object { $_.isTerminal -eq $true }).Count)
        summaryWritten = ($names -contains 'summary_written')
        stateMachineConsumed = $true
        runtimeLifecycleConsumed = $true
        assistLoopStarted = $true
        executeAck = $true
        partyMoved = $true
        travelClockRunning = $true
        fakeGameplayDelta = $true
    }

    if ($Summary) {
        if ($Summary.PSObject.Properties.Name -contains 'stateMachineConsumed') {
            $criteria.stateMachineConsumed = [bool]$Summary.stateMachineConsumed
        }
        if ($Summary.PSObject.Properties.Name -contains 'runtimeLifecycleConsumed') {
            $criteria.runtimeLifecycleConsumed = [bool]$Summary.runtimeLifecycleConsumed
        }
        if ($Summary.PSObject.Properties.Name -contains 'assistLoopStarted') {
            $criteria.assistLoopStarted = [bool]$Summary.assistLoopStarted
        }
    }
    if ($Readiness) {
        if ($Readiness.stateMachine -and ($Readiness.stateMachine.PSObject.Properties.Name -contains 'hasStateMachine')) {
            $criteria.stateMachineConsumed = [bool]$Readiness.stateMachine.hasStateMachine
        }
        if ($Readiness.runtimeLifecycle -and ($Readiness.runtimeLifecycle.PSObject.Properties.Name -contains 'parseOk')) {
            $criteria.runtimeLifecycleConsumed = [bool]$Readiness.runtimeLifecycle.parseOk
        }
    }
    if ($RequireAssistLoopStarted) {
        $criteria.assistLoopStarted = [bool]($criteria.assistLoopStarted -and ($names -contains 'assist_loop_started'))
    }
    if ($RequireExecuteMovement) {
        $dist = 0.0
        if ($ExecutionJson -and $null -ne $ExecutionJson.partyMovedDistance) {
            [double]::TryParse([string]$ExecutionJson.partyMovedDistance, [ref]$dist) | Out-Null
        }
        $criteria.executeAck = ($names -contains 'execute_ack')
        $criteria.partyMoved = ($dist -gt 0)
        $criteria.travelClockRunning = [bool]($ExecutionJson -and $ExecutionJson.travelClockRunning -eq $true)
        $criteria.fakeGameplayDelta = [bool]($ExecutionJson -and $ExecutionJson.fakeGameplayDelta -eq $false)
    }

    $terminalOk = if ($AllowPreFinalizationPreview) {
        $true
    } else {
        ($criteria.finalizedPassCount -eq 1 -and $criteria.terminalEventCount -eq 1)
    }

    $criteria.pass = ($criteria.missingCheckpoints.Count -eq 0 `
        -and $terminalOk `
        -and $criteria.summaryWritten `
        -and $criteria.stateMachineConsumed `
        -and $criteria.runtimeLifecycleConsumed `
        -and $criteria.assistLoopStarted `
        -and $criteria.executeAck `
        -and $criteria.partyMoved `
        -and $criteria.travelClockRunning `
        -and $criteria.fakeGameplayDelta)
    return [pscustomobject]$criteria
}

function Get-AutomationProjectedTerminalCriteria {
    param(
        [object[]]$Events = @(),
        [Parameter(Mandatory = $true)][ValidateSet('pass', 'fail', 'abort')][string]$State,
        [object]$Summary = $null,
        [object]$Readiness = $null,
        [object]$ExecutionJson = $null,
        [string[]]$RequiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'summary_written'),
        [switch]$RequireAssistLoopStarted,
        [switch]$RequireExecuteMovement
    )

    $terminal = New-AutomationCheckpointEvent -EventType "finalized_$State" -CheckpointName "finalized_$State" `
        -IsTerminal $true -TerminalState $State -SummaryWritten:$true
    return Test-AutomationPassCriteria -Events @(@($Events) + $terminal) -Summary $Summary -Readiness $Readiness `
        -ExecutionJson $ExecutionJson -RequiredCheckpoints $RequiredCheckpoints `
        -RequireAssistLoopStarted:$RequireAssistLoopStarted -RequireExecuteMovement:$RequireExecuteMovement
}

function New-AutomationCampaignLoopSummary {
    param(
        [string]$SessionId = $null,
        [int]$CycleId = 0,
        [string]$Phase = 'campaign_loop',
        [string]$CurrentTown = $null,
        [string]$NextPlannedTown = $null,
        [string]$SelectedAction = $null,
        [string]$CheckpointName = $null,
        [bool]$CheckpointReached = $false,
        [bool]$Terminal = $false,
        [string]$TerminalState = $null,
        [string]$PassFail = $null,
        [bool]$NextActionRequired = $true,
        [string]$NextPlannedBranch = $null,
        [string]$NextActionReason = $null,
        [string]$Reason = $null
    )

    return [pscustomobject][ordered]@{
        schemaVersion = $script:AutomationCheckpointSchemaVersion
        sessionId = $SessionId
        cycleId = $CycleId
        phase = $Phase
        currentTown = $CurrentTown
        nextPlannedTown = $NextPlannedTown
        selectedAction = $SelectedAction
        checkpointName = $CheckpointName
        checkpointReached = [bool]$CheckpointReached
        terminal = [bool]$Terminal
        terminalState = $TerminalState
        passFail = $PassFail
        nextActionRequired = [bool]$NextActionRequired
        nextPlannedBranch = $NextPlannedBranch
        nextActionReason = $NextActionReason
        reason = $Reason
    }
}

function Test-AutomationCampaignLoopSummary {
    param([Parameter(Mandatory = $true)]$Summary)

    $result = [ordered]@{
        pass = $true
        terminalHasNoNextAction = $true
        nonTerminalHasNextAction = $true
        nonTerminalHasPlannedBranch = $true
        terminalHasReason = $true
    }

    if ($Summary.terminal -eq $true) {
        $result.terminalHasNoNextAction = ($Summary.nextActionRequired -eq $false)
        $result.terminalHasReason = -not [string]::IsNullOrWhiteSpace([string]$Summary.reason)
    } else {
        $result.nonTerminalHasNextAction = ($Summary.nextActionRequired -eq $true)
        $result.nonTerminalHasPlannedBranch = -not [string]::IsNullOrWhiteSpace([string]$Summary.nextPlannedBranch)
    }

    $result.pass = ($result.terminalHasNoNextAction `
        -and $result.nonTerminalHasNextAction `
        -and $result.nonTerminalHasPlannedBranch `
        -and $result.terminalHasReason)
    return [pscustomobject]$result
}

function Write-AutomationCheckpointEventsFile {
    param(
        [object[]]$Events,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $lines = @($Events | Where-Object { $null -ne $_ } | ForEach-Object { $_ | ConvertTo-Json -Depth 12 -Compress })
    if ($lines.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value '' -Encoding UTF8
    } else {
        Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
    }
    return $Path
}

function Merge-AutomationCheckpointEvents {
    param(
        [object[]]$RunnerEvents = @(),
        [string[]]$ModEventPaths = @()
    )
    $merged = New-Object System.Collections.Generic.List[object]
    foreach ($event in @($RunnerEvents)) {
        if ($event) { $merged.Add($event) | Out-Null }
    }
    foreach ($path in @($ModEventPaths)) {
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }
        foreach ($line in @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $merged.Add(($line | ConvertFrom-Json)) | Out-Null } catch { }
        }
    }
    return @($merged.ToArray() | Sort-Object atUtc, eventId)
}

if ($MyInvocation.InvocationName -ne '.') {
    $events = New-Object System.Collections.Generic.List[object]
    Add-AutomationCheckpointEvent -List $events -CheckpointName 'attach_ready' -Phase 'campaign_loop' | Out-Null
    Add-AutomationCheckpointEvent -List $events -CheckpointName 'state_machine_consumed' -Phase 'campaign_loop' | Out-Null
    Add-AutomationCheckpointEvent -List $events -CheckpointName 'runtime_lifecycle_consumed' -Phase 'campaign_loop' | Out-Null
    Add-AutomationCheckpointEvent -List $events -CheckpointName 'summary_written' -Phase 'campaign_loop' | Out-Null

    $checkpointOnly = Test-AutomationPassCriteria -Events @($events.ToArray())
    if ($checkpointOnly.pass) {
        throw 'checkpoint-only events must not satisfy PASS criteria without terminal finalized_pass'
    }

    $preFinalizationPreview = Test-AutomationPassCriteria -Events @($events.ToArray()) -AllowPreFinalizationPreview
    if (-not $preFinalizationPreview.pass) {
        throw "pre-finalization preview should allow selecting a pass terminal state: $($preFinalizationPreview | ConvertTo-Json -Compress)"
    }

    $projectedPass = Get-AutomationProjectedTerminalCriteria -Events @($events.ToArray()) -State pass
    if (-not $projectedPass.pass) {
        throw "projected terminal pass should satisfy strict PASS criteria: $($projectedPass | ConvertTo-Json -Compress)"
    }

    Complete-AutomationFinalization -List $events -State pass -Reason 'configured_objective_met_and_summary_written' -SummaryWritten $true | Out-Null
    $terminalPass = Test-AutomationPassCriteria -Events @($events.ToArray())
    if (-not $terminalPass.pass) {
        throw "terminal finalized_pass should satisfy base PASS criteria: $($terminalPass | ConvertTo-Json -Compress)"
    }

    Complete-AutomationFinalization -List $events -State pass -Reason 'duplicate_terminal' -SummaryWritten $true | Out-Null
    $duplicateTerminal = Test-AutomationPassCriteria -Events @($events.ToArray())
    if ($duplicateTerminal.pass) {
        throw 'duplicate terminal finalized_pass events must not satisfy PASS criteria'
    }

    $cycleSummary = New-AutomationCampaignLoopSummary -SessionId 'offline' -CycleId 1 `
        -CurrentTown 'Ortysia' -SelectedAction 'travel_trade_smith' -CheckpointName 'party_movement_observed' `
        -CheckpointReached $true -Terminal $false -NextActionRequired $true `
        -NextPlannedBranch 'trade' -NextActionReason 'market_state_ready'
    $cycleSummaryResult = Test-AutomationCampaignLoopSummary -Summary $cycleSummary
    if (-not $cycleSummaryResult.pass) {
        throw "non-terminal cycle summary should require next action: $($cycleSummaryResult | ConvertTo-Json -Compress)"
    }

    $badCycleSummary = New-AutomationCampaignLoopSummary -SessionId 'offline' -CycleId 2 `
        -CheckpointName 'party_movement_observed' -CheckpointReached $true -Terminal $false `
        -NextActionRequired $false
    $badCycleSummaryResult = Test-AutomationCampaignLoopSummary -Summary $badCycleSummary
    if ($badCycleSummaryResult.pass) {
        throw 'non-terminal cycle summary without next action/branch must fail'
    }

    $terminalSummary = New-AutomationCampaignLoopSummary -SessionId 'offline' -CycleId 3 `
        -Phase 'finalization' -Terminal $true -TerminalState 'finalized_pass' -PassFail 'PASS' `
        -NextActionRequired $false -Reason 'configured_objective_met_and_summary_written'
    $terminalSummaryResult = Test-AutomationCampaignLoopSummary -Summary $terminalSummary
    if (-not $terminalSummaryResult.pass) {
        throw "terminal summary should pass with reason and no next action: $($terminalSummaryResult | ConvertTo-Json -Compress)"
    }

    Write-Host 'PASS offline automation checkpoint contract regression'
}
