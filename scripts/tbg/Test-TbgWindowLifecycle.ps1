[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-TbgLifecycleTrue {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-TbgLifecycleEqual {
    param($Actual, $Expected, [Parameter(Mandatory = $true)][string]$Message)
    if ([string]$Actual -ne [string]$Expected) {
        throw "$Message Expected '$Expected' but received '$Actual'."
    }
}

function Read-TbgLifecycleJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-TbgLifecycleTrue (Test-Path -LiteralPath $Path -PathType Leaf) "Expected lifecycle JSON file is missing: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-TbgLifecyclePowerShellParses {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) {
        throw "$Path does not parse: $(@($errors | ForEach-Object { $_.Message }) -join '; ')"
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$resolverPath = Join-Path $repoRoot 'scripts\tbg\Resolve-TbgWindowLifecycle.ps1'
$stateSchemaPath = Join-Path $repoRoot '.tbg\harness\schemas\window-lifecycle-state.schema.json'
$transitionSchemaPath = Join-Path $repoRoot '.tbg\harness\schemas\window-lifecycle-transition.schema.json'
$fixturePath = Join-Path $repoRoot '.tbg\harness\fixtures\window-intelligence\window-lifecycle-sequences.fixture.json'

foreach ($path in @($resolverPath, $stateSchemaPath, $transitionSchemaPath, $fixturePath)) {
    Assert-TbgLifecycleTrue (Test-Path -LiteralPath $path -PathType Leaf) "Required window lifecycle surface is missing: $path"
}

Assert-TbgLifecyclePowerShellParses -Path $resolverPath
Assert-TbgLifecyclePowerShellParses -Path $PSCommandPath
. $resolverPath

$stateSchema = Read-TbgLifecycleJson -Path $stateSchemaPath
$transitionSchema = Read-TbgLifecycleJson -Path $transitionSchemaPath
$fixture = Read-TbgLifecycleJson -Path $fixturePath

Assert-TbgLifecycleEqual $stateSchema.properties.schema.const 'TbgWindowLifecycleState.v1' 'The lifecycle state schema constant is wrong.'
Assert-TbgLifecycleEqual $transitionSchema.properties.schema.const 'TbgWindowLifecycleTransition.v1' 'The lifecycle transition schema constant is wrong.'
Assert-TbgLifecycleEqual $fixture.schema 'TbgWindowLifecycleFixture.v1' 'The lifecycle fixture schema is wrong.'

$resolverText = Get-Content -LiteralPath $resolverPath -Raw -Encoding UTF8
foreach ($requiredNeedle in @(
    'Resolve-TbgWindowLifecycleTransition',
    'Invoke-TbgWindowLifecycleReduction',
    'invalid_transition:',
    'action_dispatch',
    'unknown_quarantined',
    'host_handoff_requires_singleplayer_identity'
)) {
    Assert-TbgLifecycleTrue ($resolverText.Contains($requiredNeedle)) "The lifecycle reducer is missing '$requiredNeedle'."
}
foreach ($forbiddenNeedle in @('Start-Process', 'InvokePattern', 'SendKeys', 'SetCursorPos', 'mouse_event', 'CopyFromScreen', 'Tesseract', 'Windows.Media.Ocr')) {
    Assert-TbgLifecycleTrue (-not $resolverText.Contains($forbiddenNeedle)) "The pure lifecycle reducer unexpectedly contains runtime or pixel primitive '$forbiddenNeedle'."
}

foreach ($case in @($fixture.cases)) {
    $before = $case | ConvertTo-Json -Depth 30 -Compress
    $reduction = Invoke-TbgWindowLifecycleReduction -WindowKey ([string]$case.windowKey) -Events @($case.events)
    $after = $case | ConvertTo-Json -Depth 30 -Compress

    Assert-TbgLifecycleEqual $after $before "The reducer mutated fixture input for case '$($case.caseId)'."
    Assert-TbgLifecycleEqual $reduction.finalState.phase $case.expected.phase "Case '$($case.caseId)' ended in the wrong phase."
    Assert-TbgLifecycleEqual $reduction.finalState.identityId $case.expected.identityId "Case '$($case.caseId)' ended with the wrong identity."
    Assert-TbgLifecycleEqual $reduction.finalState.actionId $case.expected.actionId "Case '$($case.caseId)' ended with the wrong action."
    Assert-TbgLifecycleEqual $reduction.finalState.proofLevel $case.expected.proofLevel "Case '$($case.caseId)' ended with the wrong proof level."
    Assert-TbgLifecycleEqual $reduction.finalState.terminal $case.expected.terminal "Case '$($case.caseId)' ended with the wrong terminal flag."
    Assert-TbgLifecycleEqual $reduction.acceptedTransitions $case.expected.acceptedTransitions "Case '$($case.caseId)' accepted the wrong number of transitions."
    Assert-TbgLifecycleEqual $reduction.rejectedTransitions $case.expected.rejectedTransitions "Case '$($case.caseId)' rejected the wrong number of transitions."

    foreach ($transition in @($reduction.transitions)) {
        Assert-TbgLifecycleEqual $transition.schema 'TbgWindowLifecycleTransition.v1' "Case '$($case.caseId)' produced the wrong transition schema."
        Assert-TbgLifecycleTrue ([string]$transition.transitionId -match '^window-transition:[a-f0-9]{20}$') "Case '$($case.caseId)' produced a non-deterministic transition id."
        Assert-TbgLifecycleTrue ([string]$transition.proofBoundary -match 'does not prove application acceptance') "Case '$($case.caseId)' collapsed the action-dispatch proof boundary."
    }
}

$dispatchCase = @($fixture.cases | Where-Object { [string]$_.caseId -eq 'dependency-caution-dispatch-does-not-prove-acceptance' })[0]
$dispatchReduction = Invoke-TbgWindowLifecycleReduction -WindowKey ([string]$dispatchCase.windowKey) -Events @($dispatchCase.events)
Assert-TbgLifecycleEqual $dispatchReduction.finalState.phase 'disappeared' 'The dispatched modal should end as disappeared after the observation closes.'
Assert-TbgLifecycleEqual $dispatchReduction.finalState.proofLevel 'action_dispatch' 'Window disappearance must not promote dispatch into acceptance proof.'
Assert-TbgLifecycleTrue (-not (@($dispatchReduction.finalState.PSObject.Properties.Name) -contains 'acceptedByApplication')) 'The lifecycle state must not invent application acceptance.'

$unknownCase = @($fixture.cases | Where-Object { [string]$_.caseId -eq 'unknown-window-requires-explicit-identity-resolution' })[0]
$unknownReduction = Invoke-TbgWindowLifecycleReduction -WindowKey ([string]$unknownCase.windowKey) -Events @($unknownCase.events)
$rejectedAction = @($unknownReduction.transitions | Where-Object { [string]$_.eventType -eq 'action_authorized' })[0]
Assert-TbgLifecycleTrue (-not [bool]$rejectedAction.accepted) 'An unknown quarantined window accepted action authority.'
Assert-TbgLifecycleEqual $rejectedAction.reason 'invalid_transition:unknown_quarantined->action_authorized' 'The unknown-window rejection reason changed.'

Write-Host 'PASS: window lifecycle schemas and pure reducer enforce known-modal progression, terminal host handoff, unknown-window quarantine, illegal-transition rejection, deterministic transition IDs, and the action-dispatch proof ceiling.'
