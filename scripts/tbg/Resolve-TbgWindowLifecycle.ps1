Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TbgWindowLifecycleEventProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Event,
        [Parameter(Mandatory = $true)][string]$Name,
        $DefaultValue = $null
    )

    $property = $Event.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function Get-TbgWindowLifecycleTransitionTable {
    [CmdletBinding()]
    param()

    return @{
        'unseen|window_observed' = 'observed'
        'observed|identity_resolved' = 'recognized'
        'unknown_quarantined|identity_resolved' = 'recognized'
        'observed|unknown_detected' = 'unknown_quarantined'
        'recognized|action_authorized' = 'action_ready'
        'action_ready|action_dispatched' = 'action_dispatched'
        'recognized|host_handoff_observed' = 'terminal_observation'
        'observed|window_disappeared' = 'disappeared'
        'recognized|window_disappeared' = 'disappeared'
        'action_ready|window_disappeared' = 'disappeared'
        'action_dispatched|window_disappeared' = 'disappeared'
        'unknown_quarantined|window_disappeared' = 'disappeared'
        'recognized|action_rejected' = 'blocked'
        'action_ready|action_rejected' = 'blocked'
        'recognized|identity_invalidated' = 'blocked'
        'action_ready|identity_invalidated' = 'blocked'
        'action_dispatched|identity_invalidated' = 'blocked'
    }
}

function Get-TbgWindowLifecycleProofRank {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ProofLevel)

    $ranks = @{
        none = 0
        observation = 10
        identity = 20
        action_authority = 30
        action_dispatch = 40
        terminal_observation = 40
        quarantine = 50
    }
    if (-not $ranks.ContainsKey($ProofLevel)) {
        throw "Unknown window lifecycle proof level '$ProofLevel'."
    }
    return [int]$ranks[$ProofLevel]
}

function Get-TbgWindowLifecycleTransitionId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WindowKey,
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][string]$EventType
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes("$WindowKey|$Sequence|$EventType")
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = -join ($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $sha256.Dispose()
    }
    return "window-transition:$($hash.Substring(0, 20))"
}

function New-TbgWindowLifecycleState {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$WindowKey)

    if ([string]::IsNullOrWhiteSpace($WindowKey)) {
        throw 'WindowKey must not be empty.'
    }

    return [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleState.v1'
        windowKey = $WindowKey
        identityId = $null
        phase = 'unseen'
        generation = 0
        lastEventType = $null
        lastTransitionId = $null
        actionId = $null
        proofLevel = 'none'
        terminal = $false
        blockers = @()
        history = @()
    }
}

function Resolve-TbgWindowLifecycleTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$PreviousState,
        [Parameter(Mandatory = $true)]$Event
    )

    if ([string]$PreviousState.schema -ne 'TbgWindowLifecycleState.v1') {
        throw "Unsupported previous state schema '$($PreviousState.schema)'."
    }

    $windowKey = [string]$PreviousState.windowKey
    $eventWindowKey = [string](Get-TbgWindowLifecycleEventProperty -Event $Event -Name 'windowKey' -DefaultValue $windowKey)
    $sequence = [int](Get-TbgWindowLifecycleEventProperty -Event $Event -Name 'sequence' -DefaultValue 0)
    $eventType = [string](Get-TbgWindowLifecycleEventProperty -Event $Event -Name 'eventType' -DefaultValue '')
    $eventIdentityId = Get-TbgWindowLifecycleEventProperty -Event $Event -Name 'identityId'
    $eventActionId = Get-TbgWindowLifecycleEventProperty -Event $Event -Name 'actionId'

    if ($sequence -lt 1) { throw 'Window lifecycle event sequence must be at least 1.' }
    if ([string]::IsNullOrWhiteSpace($eventType)) { throw 'Window lifecycle eventType must not be empty.' }
    if ($eventWindowKey -ne $windowKey) { throw "Window lifecycle event key '$eventWindowKey' does not match state key '$windowKey'." }

    $transitionId = Get-TbgWindowLifecycleTransitionId -WindowKey $windowKey -Sequence $sequence -EventType $eventType
    $fromState = [string]$PreviousState.phase
    $transitionKey = "$fromState|$eventType"
    $table = Get-TbgWindowLifecycleTransitionTable
    $accepted = $table.ContainsKey($transitionKey)
    $reason = 'transition_allowed'
    $toState = $fromState

    if ($accepted) {
        $toState = [string]$table[$transitionKey]
        if ($eventType -eq 'identity_resolved' -and [string]::IsNullOrWhiteSpace([string]$eventIdentityId)) {
            $accepted = $false
            $reason = 'identity_resolved_requires_identity_id'
        }
        elseif (($eventType -eq 'action_authorized' -or $eventType -eq 'action_dispatched') -and [string]::IsNullOrWhiteSpace([string]$eventActionId)) {
            $accepted = $false
            $reason = 'action_transition_requires_action_id'
        }
        elseif ($eventType -eq 'host_handoff_observed') {
            $resolvedIdentity = [string]$PreviousState.identityId
            if (-not [string]::IsNullOrWhiteSpace([string]$eventIdentityId)) { $resolvedIdentity = [string]$eventIdentityId }
            if ($resolvedIdentity -ne 'bannerlord.singleplayer-host') {
                $accepted = $false
                $reason = 'host_handoff_requires_singleplayer_identity'
            }
        }
    }
    else {
        $reason = "invalid_transition:$fromState->$eventType"
    }

    if (-not $accepted) { $toState = $fromState }

    $transitionIdentityId = $PreviousState.identityId
    if ($null -ne $eventIdentityId) { $transitionIdentityId = [string]$eventIdentityId }
    $transitionActionId = $PreviousState.actionId
    if ($null -ne $eventActionId) { $transitionActionId = [string]$eventActionId }

    $transition = [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleTransition.v1'
        transitionId = $transitionId
        windowKey = $windowKey
        sequence = $sequence
        eventType = $eventType
        fromState = $fromState
        toState = $toState
        accepted = [bool]$accepted
        reason = $reason
        identityId = $transitionIdentityId
        actionId = $transitionActionId
        proofBoundary = 'A lifecycle transition proves deterministic harness state only. Action dispatch does not prove application acceptance, campaign readiness, movement, arrival, trade, or live product success.'
    }

    if (-not $accepted) {
        return [pscustomobject][ordered]@{
            state = $PreviousState
            transition = $transition
        }
    }

    $identityId = $PreviousState.identityId
    if ($eventType -eq 'identity_resolved' -or $eventType -eq 'host_handoff_observed') {
        if ($null -ne $eventIdentityId) { $identityId = [string]$eventIdentityId }
    }

    $actionId = $PreviousState.actionId
    if ($eventType -eq 'action_authorized' -or $eventType -eq 'action_dispatched') {
        $actionId = [string]$eventActionId
    }

    $candidateProof = switch ($toState) {
        'observed' { 'observation' }
        'recognized' { 'identity' }
        'action_ready' { 'action_authority' }
        'action_dispatched' { 'action_dispatch' }
        'terminal_observation' { 'terminal_observation' }
        'unknown_quarantined' { 'quarantine' }
        default { [string]$PreviousState.proofLevel }
    }
    $proofLevel = [string]$PreviousState.proofLevel
    if ((Get-TbgWindowLifecycleProofRank -ProofLevel $candidateProof) -gt (Get-TbgWindowLifecycleProofRank -ProofLevel $proofLevel)) {
        $proofLevel = $candidateProof
    }

    $blockers = @($PreviousState.blockers)
    if ($toState -eq 'blocked') {
        $blocker = [string](Get-TbgWindowLifecycleEventProperty -Event $Event -Name 'reason' -DefaultValue $eventType)
        if (-not [string]::IsNullOrWhiteSpace($blocker) -and -not ($blockers -contains $blocker)) {
            $blockers += $blocker
        }
    }

    $history = @($PreviousState.history)
    if (-not ($history -contains $transitionId)) { $history += $transitionId }
    $terminal = @('terminal_observation', 'disappeared', 'blocked') -contains $toState

    $nextState = [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleState.v1'
        windowKey = $windowKey
        identityId = $identityId
        phase = $toState
        generation = ([int]$PreviousState.generation + 1)
        lastEventType = $eventType
        lastTransitionId = $transitionId
        actionId = $actionId
        proofLevel = $proofLevel
        terminal = [bool]$terminal
        blockers = @($blockers)
        history = @($history)
    }

    return [pscustomobject][ordered]@{
        state = $nextState
        transition = $transition
    }
}

function Invoke-TbgWindowLifecycleReduction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WindowKey,
        [Parameter(Mandatory = $true)][object[]]$Events,
        $InitialState = $null
    )

    $state = $InitialState
    if ($null -eq $state) { $state = New-TbgWindowLifecycleState -WindowKey $WindowKey }
    if ([string]$state.windowKey -ne $WindowKey) { throw 'InitialState windowKey does not match WindowKey.' }

    $transitions = @()
    $acceptedCount = 0
    $rejectedCount = 0
    foreach ($event in @($Events | Sort-Object { [int](Get-TbgWindowLifecycleEventProperty -Event $_ -Name 'sequence' -DefaultValue 0) })) {
        $result = Resolve-TbgWindowLifecycleTransition -PreviousState $state -Event $event
        $transitions += $result.transition
        if ([bool]$result.transition.accepted) {
            $acceptedCount++
            $state = $result.state
        }
        else {
            $rejectedCount++
        }
    }

    return [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleReduction.v1'
        windowKey = $WindowKey
        finalState = $state
        acceptedTransitions = $acceptedCount
        rejectedTransitions = $rejectedCount
        transitions = @($transitions)
    }
}
