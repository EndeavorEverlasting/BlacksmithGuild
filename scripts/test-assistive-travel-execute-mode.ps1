# Offline regression: assistive travel execute inbox contract and mode decision table.
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
    if ($MovementIntentSet -and $ActualExecutionObserved) {
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

# execute absent -> advisory_only
$absent = Parse-AssistiveInboxPayload -Json '{"sequence":1,"command":"AssistiveLeaveTownAndTravel","source":"test"}'
if ($null -ne $absent.ExecuteRequested) { throw 'execute absent must leave ExecuteRequested null' }
$modeAbsent = Get-AssistiveTravelCommandMode -ExecuteRequested $false -ExecuteAllowed $true -MovementIntentSet $true -ActualExecutionObserved $true
if ($modeAbsent.travelCommandMode -ne 'advisory_only' -or $modeAbsent.fallbackReason -ne 'execute_not_requested') {
    throw "execute absent expected advisory_only/execute_not_requested got $($modeAbsent | ConvertTo-Json -Compress)"
}

# execute false -> advisory_only
$falsePayload = Parse-AssistiveInboxPayload -Json '{"execute":false,"command":"x"}'
if ($falsePayload.ExecuteRequested -ne $false) { throw 'execute false parse failed' }
$modeFalse = Get-AssistiveTravelCommandMode -ExecuteRequested $false -ExecuteAllowed $true -MovementIntentSet $true -ActualExecutionObserved $true
if ($modeFalse.travelCommandMode -ne 'advisory_only') { throw 'execute false must be advisory_only' }

# execute true + safe fixture -> execute
$truePayload = Parse-AssistiveInboxPayload -Json '{"execute":true,"targetSettlement":"Ortysia"}'
if ($truePayload.ExecuteRequested -ne $true -or $truePayload.TargetSettlement -ne 'Ortysia') {
    throw 'execute true + targetSettlement parse failed'
}
$modeExecute = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $true -MovementIntentSet $true -ActualExecutionObserved $true
if ($modeExecute.travelCommandMode -ne 'execute') { throw 'safe execute fixture must yield execute mode' }

# execute true + unsafe surface -> advisory_only + fallbackReason
$modeUnsafe = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $false -MovementIntentSet $false -ActualExecutionObserved $false -FallbackReason 'mission_active'
if ($modeUnsafe.travelCommandMode -ne 'advisory_only' -or $modeUnsafe.fallbackReason -ne 'mission_active') {
    throw 'unsafe surface must be advisory_only with fallbackReason'
}

# execute true + invalid target (simulated via executeAllowed false)
$modeInvalid = Get-AssistiveTravelCommandMode -ExecuteRequested $true -ExecuteAllowed $false -MovementIntentSet $false -ActualExecutionObserved $false -FallbackReason 'invalid_target'
if ($modeInvalid.fallbackReason -ne 'invalid_target') { throw 'invalid_target fallback expected' }

# legacy probe-only inbox unchanged
$legacy = Parse-AssistiveInboxPayload -Json '{"sequence":2,"command":"AssistiveTownToTownProbe","source":"forge.ps1"}'
if ($null -ne $legacy.ExecuteRequested) { throw 'legacy probe inbox must not set execute' }
$legacyMode = Get-AssistiveTravelCommandMode -ExecuteRequested $false -ExecuteAllowed $true -MovementIntentSet $false -ActualExecutionObserved $false
if ($legacyMode.travelCommandMode -ne 'advisory_only') { throw 'legacy probe must stay advisory_only' }

Write-Host 'PASS offline assistive travel execute mode regression'
