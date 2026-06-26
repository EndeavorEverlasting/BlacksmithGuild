# PR #11 assistive travel execute cert PASS/FAIL contract (runner-side only).

function Get-AssistiveTravelExecutionJsonPath {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_AssistiveTravelExecution.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_AssistiveTravelExecution.json')
}

function Test-Pr11AssistiveTravelExecutePass {
    param(
        [object]$ExecutionJson,
        [object]$Readiness = $null,
        [switch]$RequireLeaveTown
    )

    if (-not $ExecutionJson) {
        return [ordered]@{ pass = $false; failureClass = 'evidence_missing'; routeAgent = 'Agent C' }
    }

    $partyMovedDistance = 0.0
    if ($null -ne $ExecutionJson.partyMovedDistance) {
        [double]::TryParse([string]$ExecutionJson.partyMovedDistance, [ref]$partyMovedDistance) | Out-Null
    }

    $checks = @{
        executeRequested = ($ExecutionJson.executeRequested -eq $true)
        executeAllowed = ($ExecutionJson.executeAllowed -eq $true)
        travelCommandMode = ([string]$ExecutionJson.travelCommandMode -eq 'execute')
        movementIntentSet = ($ExecutionJson.movementIntentSet -eq $true)
        actualExecutionObserved = ($ExecutionJson.actualExecutionObserved -eq $true)
        partyMoved = ($partyMovedDistance -gt 0)
        fakeGameplayDelta = ($ExecutionJson.fakeGameplayDelta -eq $false)
    }

    foreach ($key in @($checks.Keys)) {
        if (-not $checks[$key]) {
            $failure = Get-Pr11ExecuteFailureClass -ExecutionJson $ExecutionJson -FailedCheck $key
            return [ordered]@{
                pass = $false
                failureClass = $failure.failureClass
                routeAgent = $failure.routeAgent
                checks = $checks
            }
        }
    }

    if ($RequireLeaveTown -or ($Readiness -and $Readiness.readinessSurface -eq 'settlement_menu')) {
        if ($ExecutionJson.leaveTownAttempted -ne $true) {
            return [ordered]@{
                pass = $false
                failureClass = 'execute_fallback_leave_town_failed'
                routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
                checks = $checks
            }
        }
    }

    return [ordered]@{ pass = $true; failureClass = $null; routeAgent = $null; checks = $checks }
}

function Get-Pr11ExecuteFailureClass {
    param([object]$ExecutionJson, [string]$FailedCheck = $null)

    $fallback = if ($ExecutionJson -and $ExecutionJson.fallbackReason) { [string]$ExecutionJson.fallbackReason } else { $null }
    $routeB = 'Agent B - Runtime / Readiness / Gameplay safety'
    $routeC = 'Agent C - External State Classifier / Assistive Runner'

    if ($fallback) {
        switch -Regex ($fallback) {
            'leave_town' { return @{ failureClass = 'execute_fallback_leave_town_failed'; routeAgent = $routeB } }
            'incomplete' { return @{ failureClass = 'execute_fallback_leave_town_incomplete'; routeAgent = $routeB } }
            'travel_api' { return @{ failureClass = 'execute_fallback_travel_api_unavailable'; routeAgent = $routeB } }
            'movement_intent' { return @{ failureClass = 'execute_fallback_movement_intent_not_observed'; routeAgent = $routeB } }
            'surface_not_execute' { return @{ failureClass = 'execute_fallback_surface_not_execute_eligible'; routeAgent = $routeB } }
            'invalid_target' { return @{ failureClass = 'execute_invalid_target'; routeAgent = $routeB } }
        }
    }

    switch ($FailedCheck) {
        'executeRequested' { return @{ failureClass = 'inbox_command_failed'; routeAgent = $routeC } }
        'executeAllowed' { return @{ failureClass = 'execute_fallback_surface_not_execute_eligible'; routeAgent = $routeB } }
        'travelCommandMode' { return @{ failureClass = 'execute_fallback_movement_intent_not_observed'; routeAgent = $routeB } }
        'movementIntentSet' { return @{ failureClass = 'execute_fallback_movement_intent_not_observed'; routeAgent = $routeB } }
        'actualExecutionObserved' { return @{ failureClass = 'execute_fallback_movement_intent_not_observed'; routeAgent = $routeB } }
        'partyMoved' { return @{ failureClass = 'execute_fallback_actual_execution_not_observed'; routeAgent = $routeB } }
        'fakeGameplayDelta' { return @{ failureClass = 'probe_failed'; routeAgent = $routeB } }
        default { return @{ failureClass = 'evidence_missing'; routeAgent = $routeC } }
    }
}

function Copy-Pr11EvidenceArtifact {
    param(
        [string]$SourcePath,
        [string]$CheckpointDir,
        [string]$DestName
    )
    if (-not $SourcePath -or -not (Test-Path -LiteralPath $SourcePath)) { return $false }
    $dest = Join-Path $CheckpointDir $DestName
    Copy-Item -LiteralPath $SourcePath -Destination $dest -Force
    return $true
}
