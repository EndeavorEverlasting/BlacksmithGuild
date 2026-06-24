# Offline regression: PR #11 execute cert parser accepts execute proof fields.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')

$passJson = [pscustomobject]@{
    executeRequested = $true
    executeAllowed = $true
    travelCommandMode = 'execute'
    movementIntentSet = $true
    actualExecutionObserved = $true
    fakeGameplayDelta = $false
    leaveTownAttempted = $true
}
$result = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $passJson -RequireLeaveTown
if (-not $result.pass) { throw "execute pass fixture must pass got $($result.failureClass)" }

$failJson = [pscustomobject]@{
    executeRequested = $true
    executeAllowed = $true
    travelCommandMode = 'advisory_only'
    movementIntentSet = $false
    actualExecutionObserved = $false
    fakeGameplayDelta = $false
    fallbackReason = 'movement_intent_not_observed'
}
$fail = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $failJson
if ($fail.pass) { throw 'advisory_only execution must fail' }
if ($fail.failureClass -notmatch 'movement_intent') { throw "expected movement intent failure got $($fail.failureClass)" }

$settlementReady = [pscustomobject]@{ readinessSurface = 'settlement_menu' }
$noLeave = [pscustomobject]@{
    executeRequested = $true; executeAllowed = $true; travelCommandMode = 'execute'
    movementIntentSet = $true; actualExecutionObserved = $true; fakeGameplayDelta = $false
    leaveTownAttempted = $false
}
$leaveFail = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $noLeave -Readiness $settlementReady
if ($leaveFail.pass -or $leaveFail.failureClass -ne 'execute_fallback_leave_town_failed') {
    throw 'settlement start requires leaveTownAttempted'
}

# legacy advisory probe fixture path — execute contract must not require fields when json null
$legacy = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $null
if ($legacy.pass) { throw 'null execution json must not pass execute cert' }

Write-Host 'PASS offline PR11 execute cert parser regression'
