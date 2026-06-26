# Offline regression: assistive travel execute inbox contract, observation, and certSummary.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Parse-AssistiveInboxPayload {
    param([string]$Json)
    $payload = [ordered]@{
        ExecuteRequested = $null
        TargetSettlement = $null
    }
    if ([string]::IsNullOrWhiteSpace($Json)) {
        return $payload
    }
    if ($Json -match '"execute"\s*:\s*(true|false)') {
        $payload.ExecuteRequested = [bool]::Parse($Matches[1])
    }
    if ($Json -match '"targetSettlement"\s*:\s*"([^"]+)"') {
        $payload.TargetSettlement = $Matches[1]
    }
    return $payload
}

function Get-AssistiveTravelCommandMode {
    param(
        [bool]$ExecuteRequested,
        [bool]$ExecuteAllowed,
        [bool]$TravelApiCallSucceeded,
        [bool]$MovementIntentSet,
        [bool]$ActualExecutionObserved,
        [string]$FallbackReason
    )
    if (-not $ExecuteRequested) {
        return [ordered]@{
            travelCommandMode = 'advisory_only'
            fallbackReason    = 'execute_not_requested'
        }
    }
    if (-not $ExecuteAllowed) {
        return [ordered]@{
            travelCommandMode = 'advisory_only'
            fallbackReason    = $(if ($FallbackReason) { $FallbackReason } else { 'surface_not_execute_eligible' })
        }
    }
    if ($TravelApiCallSucceeded -and $MovementIntentSet -and $ActualExecutionObserved) {
        return [ordered]@{
            travelCommandMode = 'execute'
            fallbackReason    = $null
        }
    }
    return [ordered]@{
        travelCommandMode = 'advisory_only'
        fallbackReason    = $(if ($FallbackReason) { $FallbackReason } else { 'movement_intent_not_observed' })
    }
}

function Get-AssistiveTravelCertSummary {
    param(
        [bool]$ExecuteRequested,
        [bool]$ExecuteAllowed,
        [string]$TravelCommandMode,
        [bool]$TravelApiCallSucceeded,
        [bool]$MovementIntentSet,
        [bool]$ActualExecutionObserved,
        [string]$FallbackReason
    )
    $passCandidate = $ExecuteRequested -and $ExecuteAllowed -and $TravelCommandMode -eq 'execute' `
        -and $TravelApiCallSucceeded -and $MovementIntentSet -and $ActualExecutionObserved
    $summary = [ordered]@{
        executeRequested = $ExecuteRequested
        executeAllowed   = $ExecuteAllowed
        travelCommandMode = $TravelCommandMode
        passCandidate    = $passCandidate
        blockingReason   = $(if ($passCandidate) { $null } else { $FallbackReason })
        routeOwner       = $(if ($passCandidate) { 'AgentA' } else { $null })
        nextRouteOnFail  = $null
    }
    if (-not $passCandidate -and $ExecuteRequested) {
        $agentBReasons = @(
            'movement_intent_not_observed',
            'actual_execution_not_observed',
            'leave_town_failed',
            'leave_town_incomplete',
            'map_surface_not_reached',
            'travel_api_call_failed'
        )
        if ($FallbackReason -like 'surface_not_execute_eligible:*' -or ($agentBReasons -contains $FallbackReason)) {
            $summary.nextRouteOnFail = 'AgentB'
        } else {
            $summary.nextRouteOnFail = 'AgentA'
        }
    }
    return $summary
}

function Test-MovementObservationTimeout {
    param(
        [int]$MaxObservationMs = 500,
        [int]$IntervalMs = 50,
        [scriptblock]$Probe
    )
    $attempts = 0
    $maxAttempts = [Math]::Max(1, [int]($MaxObservationMs / $IntervalMs))
    $passed = $false
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $attempts = $attempt
        if (& $Probe) {
            $passed = $true
            break
        }
    }
    return [ordered]@{
        movementObservationAttempts      = $attempts
        movementObservationPassed        = $passed
        movementObservationFailureReason = $(if ($passed) { $null } else { 'movement_intent_not_observed' })
    }
}

# execute absent -> advisory_only
$absent = Parse-AssistiveInboxPayload -Json '{"sequence":1,"command":"AssistiveLeaveTownAndTravel","source":"test"}'
if ($null -ne $absent.ExecuteRequested) { throw 'execute absent must leave ExecuteRequested null' }
$modeAbsent = Get-AssistiveTravelCommandMode -ExecuteRequested $false -ExecuteAllowed $true -TravelApiCallSucceeded $true -MovementIntentSet $true -ActualExecutionObserved $true
if ($modeAbsent.travelCommandMode -ne 'advisory_only' -or $modeAbsent.fallbackReason -ne 'execute_not_requested') {
    throw "execute absent expected advisory_only/execute_not_requested got $($modeAbsent | ConvertTo-Json -Compress)"
}

# execute false -> advisory_only
$falsePayload = Parse-AssistiveInboxPayload -Json '{"execute":false,"command":"x"}'
if ($falsePayload.ExecuteRequested -ne $false) { throw 'execute false parse failed' }
$modeFalse = Get-AssistiveTravelCommandMode -ExecuteRequested $false -ExecuteAllowed $true -TravelApiCallSucceeded $true -MovementIntentSet $true -ActualExecutionObserved $true
if ($modeFalse.travelCommandMode -ne 'advisory_only') { throw 'execute false must be advisory_only' }

# execute true records executeRequested=true
$truePayload = Parse-AssistiveInboxPayload -Json '{"execute":true,"targetSettlement":"Ortysia"}'
if ($truePayload.ExecuteRequested -ne $true -or $truePayload.TargetSettlement -ne 'Ortysia') {
    throw 'execute true + targetSettlement parse failed'
}

# execute true + safe fixture -> execute
$modeExecute = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $true -TravelApiCallSucceeded $true -MovementIntentSet $true -ActualExecutionObserved $true
if ($modeExecute.travelCommandMode -ne 'execute') { throw 'safe execute fixture must yield execute mode' }

# invalid target
$modeInvalid = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $false -TravelApiCallSucceeded $false -MovementIntentSet $false -ActualExecutionObserved $false -FallbackReason 'invalid_target'
if ($modeInvalid.fallbackReason -ne 'invalid_target') { throw 'invalid_target fallback expected' }

# target equals current settlement
$modeSame = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $false -TravelApiCallSucceeded $false -MovementIntentSet $false -ActualExecutionObserved $false -FallbackReason 'target_is_current_settlement'
if ($modeSame.fallbackReason -ne 'target_is_current_settlement') { throw 'target_is_current_settlement fallback expected' }

# execute true + unsafe surface
$modeUnsafe = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $false -TravelApiCallSucceeded $false -MovementIntentSet $false -ActualExecutionObserved $false -FallbackReason 'mission_active'
if ($modeUnsafe.travelCommandMode -ne 'advisory_only' -or $modeUnsafe.fallbackReason -ne 'mission_active') {
    throw 'unsafe surface must be advisory_only with fallbackReason'
}

# movement observation timeout
$obs = Test-MovementObservationTimeout -Probe { $false }
if ($obs.movementObservationPassed) { throw 'observation timeout must not pass' }
if ($obs.movementObservationFailureReason -ne 'movement_intent_not_observed') {
    throw "observation timeout expected movement_intent_not_observed got $($obs.movementObservationFailureReason)"
}

# certSummary passCandidate false when execute not observed
$certFail = Get-AssistiveTravelCertSummary -ExecuteRequested $true -ExecuteAllowed $true -TravelCommandMode 'advisory_only' `
    -TravelApiCallSucceeded $true -MovementIntentSet $false -ActualExecutionObserved $false -FallbackReason 'movement_intent_not_observed'
if ($certFail.passCandidate) { throw 'certSummary passCandidate must be false when movement not observed' }
if ($certFail.nextRouteOnFail -ne 'AgentB') { throw 'movement_intent_not_observed should route nextRouteOnFail=AgentB' }

# certSummary pass candidate
$certPass = Get-AssistiveTravelCertSummary -ExecuteRequested $true -ExecuteAllowed $true -TravelCommandMode 'execute' `
    -TravelApiCallSucceeded $true -MovementIntentSet $true -ActualExecutionObserved $true -FallbackReason $null
if (-not $certPass.passCandidate) { throw 'certSummary passCandidate must be true for execute fixture' }
if ($certPass.routeOwner -ne 'AgentA') { throw 'pass candidate routeOwner must be AgentA' }

# legacy probe-only inbox unchanged
$legacy = Parse-AssistiveInboxPayload -Json '{"sequence":2,"command":"AssistiveTownToTownProbe","source":"forge.ps1"}'
if ($null -ne $legacy.ExecuteRequested) { throw 'legacy probe inbox must not set execute' }
$legacyMode = Get-AssistiveTravelCommandMode -ExecuteRequested $false -ExecuteAllowed $true -TravelApiCallSucceeded $false -MovementIntentSet $false -ActualExecutionObserved $false
if ($legacyMode.travelCommandMode -ne 'advisory_only') { throw 'legacy probe must stay advisory_only' }

Write-Host 'PASS offline assistive travel execute mode regression'
