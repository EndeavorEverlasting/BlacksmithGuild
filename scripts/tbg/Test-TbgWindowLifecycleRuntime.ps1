[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-TbgRuntimeTrue {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-TbgRuntimeEqual {
    param($Actual, $Expected, [Parameter(Mandatory = $true)][string]$Message)
    if ([string]$Actual -ne [string]$Expected) {
        throw "$Message Expected '$Expected' but received '$Actual'."
    }
}

function Assert-TbgRuntimePowerShellParses {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) {
        throw "$Path does not parse: $(@($errors | ForEach-Object { $_.Message }) -join '; ')"
    }
}

function Read-TbgRuntimeJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-TbgRuntimeTrue (Test-Path -LiteralPath $Path -PathType Leaf) "Expected runtime JSON file is missing: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-TbgRuntimeUtf8Bom {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    Assert-TbgRuntimeTrue ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) "UTF-8 BOM missing: $Path"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$runtimePath = Join-Path $repoRoot 'scripts\tbg\Invoke-TbgWindowLifecycleRuntime.ps1'
$reducerPath = Join-Path $repoRoot 'scripts\tbg\Resolve-TbgWindowLifecycle.ps1'
$validatorPath = $PSCommandPath
$runContextSchemaPath = Join-Path $repoRoot '.tbg\harness\schemas\window-lifecycle-run-context.schema.json'
$runtimeEventSchemaPath = Join-Path $repoRoot '.tbg\harness\schemas\window-lifecycle-runtime-event.schema.json'
$fixturePath = Join-Path $repoRoot '.tbg\harness\fixtures\window-intelligence\window-lifecycle-runtime.fixture.json'
$wrapperPath = Join-Path $repoRoot 'ForgeWindowLifecycle.cmd'
$intelligencePath = Join-Path $repoRoot 'scripts\tbg\Invoke-TbgWindowIntelligence.ps1'
$launcherPath = Join-Path $repoRoot 'scripts\launcher-window-context.ps1'
$manifestPath = Join-Path $repoRoot '.tbg\harness\manifest.json'
$contractPath = Join-Path $repoRoot '.tbg\workflows\window-metadata-intelligence.contract.json'
$artifactTypesPath = Join-Path $repoRoot '.tbg\harness\e2e-artifact-types.registry.json'
$workflowPath = Join-Path $repoRoot '.github\workflows\window-lifecycle-harness.yml'

foreach ($path in @(
    $runtimePath,
    $reducerPath,
    $runContextSchemaPath,
    $runtimeEventSchemaPath,
    $fixturePath,
    $wrapperPath,
    $intelligencePath,
    $launcherPath,
    $manifestPath,
    $contractPath,
    $artifactTypesPath,
    $workflowPath
)) {
    Assert-TbgRuntimeTrue (Test-Path -LiteralPath $path -PathType Leaf) "Required window lifecycle runtime surface is missing: $path"
}

foreach ($path in @($runtimePath, $reducerPath, $validatorPath, $intelligencePath, $launcherPath)) {
    Assert-TbgRuntimePowerShellParses -Path $path
}

foreach ($path in @($runtimePath, $validatorPath)) {
    Test-TbgRuntimeUtf8Bom -Path $path
}

$runContextSchema = Read-TbgRuntimeJson -Path $runContextSchemaPath
$runtimeEventSchema = Read-TbgRuntimeJson -Path $runtimeEventSchemaPath
$fixture = Read-TbgRuntimeJson -Path $fixturePath
$manifest = Read-TbgRuntimeJson -Path $manifestPath
$contract = Read-TbgRuntimeJson -Path $contractPath
$artifactTypes = Read-TbgRuntimeJson -Path $artifactTypesPath

Assert-TbgRuntimeEqual $runContextSchema.properties.schema.const 'TbgWindowLifecycleRunContext.v1' 'The run-context schema constant is wrong.'
Assert-TbgRuntimeEqual $runtimeEventSchema.properties.schema.const 'TbgWindowLifecycleRuntimeEvent.v1' 'The runtime-event schema constant is wrong.'
Assert-TbgRuntimeEqual $fixture.schema 'TbgWindowLifecycleRuntimeFixture.v1' 'The runtime fixture schema is wrong.'
Assert-TbgRuntimeTrue ($null -ne $manifest.paths.windowLifecycleRuntimeAdapter) 'The harness manifest is missing windowLifecycleRuntimeAdapter.'
Assert-TbgRuntimeTrue ($null -ne $manifest.paths.windowLifecycleRuntimeValidator) 'The harness manifest is missing windowLifecycleRuntimeValidator.'
Assert-TbgRuntimeTrue ($null -ne $contract.lifecycleRuntimeAdapterPath) 'The workflow contract is missing lifecycleRuntimeAdapterPath.'
Assert-TbgRuntimeTrue ($null -ne $artifactTypes.windowLifecycleRuntimeRoot) 'The artifact-type registry is missing windowLifecycleRuntimeRoot.'
Assert-TbgRuntimeEqual $artifactTypes.windowLifecycleRuntimeRoot '.local/tbg-window-lifecycle' 'The window lifecycle runtime root drifted.'

$runtimeText = Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8
$intelligenceText = Get-Content -LiteralPath $intelligencePath -Raw -Encoding UTF8
$launcherText = Get-Content -LiteralPath $launcherPath -Raw -Encoding UTF8
$wrapperText = Get-Content -LiteralPath $wrapperPath -Raw -Encoding UTF8
$workflowText = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8

foreach ($needle in @(
    'Resolve-TbgWindowLifecycle.ps1',
    'Invoke-TbgLifecycleReduceEvents',
    'duplicate_sequence',
    'out_of_order_sequence',
    'launcher_lifecycle_harness',
    'TbgWindowLifecycleRunContext.v1',
    'TbgWindowLifecycleRuntimeEvent.v1'
)) {
    Assert-TbgRuntimeTrue ($runtimeText.Contains($needle)) "The runtime adapter is missing '$needle'."
}
foreach ($forbiddenNeedle in @('Start-Process', 'InvokePattern', 'SendKeys', 'SetCursorPos', 'mouse_event', 'CopyFromScreen', 'Tesseract', 'Windows.Media.Ocr')) {
    Assert-TbgRuntimeTrue (-not $runtimeText.Contains($forbiddenNeedle)) "The runtime adapter unexpectedly contains runtime or pixel primitive '$forbiddenNeedle'."
}
foreach ($needle in @(
    'Invoke-TbgWindowLifecycleRuntime.ps1',
    'Publish-TbgWindowLifecycleRuntimeEvents',
    'host_handoff_observed',
    'window_disappeared'
)) {
    Assert-TbgRuntimeTrue ($intelligenceText.Contains($needle)) "Window intelligence lifecycle wiring is missing '$needle'."
}
Assert-TbgRuntimeTrue ($launcherText.Contains('-LifecycleRunId')) 'Launcher context must pass LifecycleRunId into the watcher.'
Assert-TbgRuntimeTrue ($launcherText.Contains('-LifecycleCorrelationId')) 'Launcher context must pass LifecycleCorrelationId into the watcher.'
Assert-TbgRuntimeTrue ($wrapperText.Contains('Invoke-TbgWindowLifecycleRuntime.ps1')) 'ForgeWindowLifecycle.cmd must call the runtime adapter.'
Assert-TbgRuntimeTrue ($wrapperText.Contains('Test-TbgWindowLifecycleRuntime.ps1')) 'ForgeWindowLifecycle.cmd must expose the runtime validator.'
Assert-TbgRuntimeTrue ($workflowText.Contains('Test-TbgWindowLifecycleRuntime.ps1')) 'CI must execute the runtime lifecycle validator.'

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-window-lifecycle-runtime-{0}' -f [Guid]::NewGuid().ToString('N'))
$latestRoot = Join-Path $tempRoot 'latest'
try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $replay = & $runtimePath -Command replay -FixturePath $fixturePath -OutputRoot $tempRoot -LatestOutputDirectory $latestRoot -PassThru
    Assert-TbgRuntimeEqual $replay.schema 'TbgWindowLifecycleRuntimeReplay.v1' 'Fixture replay returned the wrong schema.'
    Assert-TbgRuntimeEqual @($replay.cases).Count @($fixture.cases).Count 'Fixture replay did not execute every case.'

    foreach ($case in @($fixture.cases)) {
        $caseResult = @($replay.cases | Where-Object { [string]$_.caseId -eq [string]$case.caseId } | Select-Object -First 1)[0]
        Assert-TbgRuntimeTrue ($null -ne $caseResult) "Fixture replay omitted case '$($case.caseId)'."
        Assert-TbgRuntimeEqual $caseResult.finalState.phase $case.expected.phase "Case '$($case.caseId)' ended in the wrong phase."
        Assert-TbgRuntimeEqual $caseResult.finalState.identityId $case.expected.identityId "Case '$($case.caseId)' ended with the wrong identity."
        Assert-TbgRuntimeEqual $caseResult.finalState.actionId $case.expected.actionId "Case '$($case.caseId)' ended with the wrong action."
        Assert-TbgRuntimeEqual $caseResult.finalState.proofLevel $case.expected.proofLevel "Case '$($case.caseId)' ended with the wrong proof level."
        Assert-TbgRuntimeEqual $caseResult.finalState.terminal $case.expected.terminal "Case '$($case.caseId)' ended with the wrong terminal flag."
        Assert-TbgRuntimeEqual $caseResult.acceptedTransitions $case.expected.acceptedTransitions "Case '$($case.caseId)' accepted the wrong number of transitions."
        Assert-TbgRuntimeEqual $caseResult.rejectedTransitions $case.expected.rejectedTransitions "Case '$($case.caseId)' rejected the wrong number of transitions."

        if ($case.expected.PSObject.Properties['rejectedReasons']) {
            $reasons = @($caseResult.transitions | Where-Object { -not [bool]$_.accepted } | ForEach-Object { [string]$_.reason })
            foreach ($expectedReason in @($case.expected.rejectedReasons)) {
                Assert-TbgRuntimeTrue ($reasons -contains [string]$expectedReason) "Case '$($case.caseId)' is missing rejected reason '$expectedReason'."
            }
        }
        if ($case.expected.PSObject.Properties['forbidFields']) {
            foreach ($forbiddenField in @($case.expected.forbidFields)) {
                Assert-TbgRuntimeTrue (-not (@($caseResult.finalState.PSObject.Properties.Name) -contains [string]$forbiddenField)) "Case '$($case.caseId)' invented forbidden field '$forbiddenField'."
            }
        }

        foreach ($requiredArtifact in @(
            'run-context.json',
            'artifact-registry.json',
            'events.jsonl',
            'state.json',
            'result.json',
            'operator-report.md',
            'handoff.md'
        )) {
            $artifactPath = Join-Path $caseResult.paths.runRoot $requiredArtifact
            Assert-TbgRuntimeTrue (Test-Path -LiteralPath $artifactPath -PathType Leaf) "Case '$($case.caseId)' is missing artifact '$requiredArtifact'."
        }

        $runContext = Read-TbgRuntimeJson -Path (Join-Path $caseResult.paths.runRoot 'run-context.json')
        $artifactRegistry = Read-TbgRuntimeJson -Path (Join-Path $caseResult.paths.runRoot 'artifact-registry.json')
        Assert-TbgRuntimeEqual $runContext.schema 'TbgWindowLifecycleRunContext.v1' "Case '$($case.caseId)' wrote the wrong run-context schema."
        Assert-TbgRuntimeEqual $runContext.proofCeiling 'launcher_lifecycle_harness' "Case '$($case.caseId)' drifted from the proof ceiling."
        Assert-TbgRuntimeEqual $artifactRegistry.schema 'TbgWindowLifecycleArtifactRegistry.v1' "Case '$($case.caseId)' wrote the wrong artifact-registry schema."
        Assert-TbgRuntimeEqual @($artifactRegistry.artifacts).Count 7 "Case '$($case.caseId)' did not register all seven artifacts."

        $reportText = Get-Content -LiteralPath (Join-Path $caseResult.paths.runRoot 'operator-report.md') -Raw -Encoding UTF8
        $handoffText = Get-Content -LiteralPath (Join-Path $caseResult.paths.runRoot 'handoff.md') -Raw -Encoding UTF8
        Assert-TbgRuntimeTrue ($reportText -match '[.!?]') "Case '$($case.caseId)' report must contain complete sentences."
        Assert-TbgRuntimeTrue ($handoffText -match '[.!?]') "Case '$($case.caseId)' handoff must contain complete sentences."
        Assert-TbgRuntimeTrue ($reportText.Contains('does not prove application acceptance') -or $reportText.Contains('Action dispatch does not prove application acceptance')) "Case '$($case.caseId)' report collapsed the proof boundary."
    }

    $cautionCase = @($fixture.cases | Where-Object { [string]$_.caseId -eq 'dependency-caution-progression' })[0]
    $firstReplay = & $runtimePath -Command replay -FixturePath $fixturePath -CaseId dependency-caution-progression -OutputRoot (Join-Path $tempRoot 'det-a') -LatestOutputDirectory (Join-Path $tempRoot 'det-a-latest') -PassThru
    $secondReplay = & $runtimePath -Command replay -FixturePath $fixturePath -CaseId dependency-caution-progression -OutputRoot (Join-Path $tempRoot 'det-b') -LatestOutputDirectory (Join-Path $tempRoot 'det-b-latest') -PassThru
    $firstIds = @($firstReplay.cases[0].transitions | ForEach-Object { [string]$_.transitionId }) -join '|'
    $secondIds = @($secondReplay.cases[0].transitions | ForEach-Object { [string]$_.transitionId }) -join '|'
    Assert-TbgRuntimeEqual $secondIds $firstIds 'Deterministic replay produced different transition identifiers.'
    Assert-TbgRuntimeEqual $firstReplay.cases[0].finalState.phase $cautionCase.expected.phase 'Deterministic replay changed the final phase.'
    Assert-TbgRuntimeEqual $firstReplay.cases[0].finalState.proofLevel 'action_dispatch' 'Disappearance after dispatch must retain the action-dispatch proof ceiling.'

    foreach ($latestName in @(
        'window-lifecycle.run-context.json',
        'window-lifecycle.artifact-registry.json',
        'window-lifecycle.events.jsonl',
        'window-lifecycle.state.json',
        'window-lifecycle.result.json',
        'window-lifecycle.report.md',
        'window-lifecycle.handoff.md'
    )) {
        Assert-TbgRuntimeTrue (Test-Path -LiteralPath (Join-Path $latestRoot $latestName) -PathType Leaf) "Latest materialized view is missing '$latestName'."
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host 'PASS: window lifecycle runtime adapter enforces run-context and runtime-event contracts, materializes the registered artifact set, rejects duplicate and out-of-order sequences, preserves the action-dispatch proof ceiling, and produces complete-sentence reports under PowerShell-compatible scripts.'
