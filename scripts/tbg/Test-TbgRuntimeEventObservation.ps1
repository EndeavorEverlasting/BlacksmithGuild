[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Assert-Observation([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
    else { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
}
function Read-ObservationJson([string]$RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    try { Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { Assert-Observation $false "valid JSON $RelativePath"; return $null }
}
function Contains-All([object[]]$Actual, [string[]]$Expected) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    @($Expected | Where-Object { $values -notcontains $_ }).Count -eq 0
}

$paths = [ordered]@{
    contract = '.tbg/workflows/runtime-event-observation.contract.json'
    runContext = '.tbg/harness/schemas/runtime-observer-run-context.schema.json'
    event = '.tbg/harness/schemas/runtime-observer-event.schema.json'
    registry = '.tbg/harness/schemas/runtime-observer-artifact-registry.schema.json'
    timeline = '.tbg/harness/schemas/runtime-incident-timeline.schema.json'
    fixtures = '.tbg/harness/fixtures/runtime-event-observation.fixtures.json'
    manifest = '.tbg/harness/manifest.json'
    artifactTypes = '.tbg/harness/e2e-artifact-types.registry.json'
}
$json = @{}
foreach ($item in $paths.GetEnumerator()) { $json[$item.Key] = Read-ObservationJson $item.Value }
$contract = $json.contract; $runContext = $json.runContext; $eventSchema = $json.event
$registrySchema = $json.registry; $timeline = $json.timeline; $fixtures = $json.fixtures

if ($contract) {
    Assert-Observation ($contract.id -eq 'runtime-event-observation') 'contract id'
    Assert-Observation ($contract.proofCeiling -eq 'static_test') 'contract proof ceiling'
    Assert-Observation ((@($contract.requiredArtifacts).Count -eq 7) -and ((@($contract.requiredArtifacts) -join '|') -eq 'run-context.json|artifact-registry.json|events.jsonl|observer-status.json|incident-timeline.json|incident-result.json|operator-report.md')) 'contract artifact set'
    Assert-Observation ($contract.doctrine.eventPresenceIsNotAcceptanceOrCause -and $contract.doctrine.lastOpenSpanIsBoundaryNotCause -and $contract.doctrine.nativeCrashConfirmedRequiresCorrelatedExternalTerminalEvidence) 'contract doctrine boundary'
}
if ($runContext) {
    Assert-Observation ($runContext.properties.schema.const -eq 'TbgRuntimeObserverRunContext.v1') 'run-context schema const'
    Assert-Observation (Contains-All @($runContext.required) @('schema','runId','correlationId','sourceCommit','branch','worktreeLabel','observers','processIdentity','startedUtc','completedUtc','mode','authority','proofCeiling','artifactRoot','redactionPolicy')) 'run-context required fields'
    Assert-Observation ((@($runContext.properties.mode.enum) -join '|') -eq 'fixture|observe|live-authorized') 'run-context modes'
}
if ($eventSchema) {
    Assert-Observation ($eventSchema.properties.schema.const -eq 'TbgRuntimeObserverEvent.v1') 'event schema const'
    Assert-Observation ($eventSchema.additionalProperties -eq $false) 'event additional properties forbidden'
    Assert-Observation (Contains-All @($eventSchema.properties.sourceKind.enum) @('window_lifecycle','process_lifecycle','windows_error_reporting','taleworlds_crash','heartbeat_log_progress','process_responsiveness','in_process_span','observer_health')) 'event source families'
    Assert-Observation (Contains-All @($eventSchema.properties.eventType.enum) @('window.created','window.shown','window.hidden','window.destroyed','window.title_changed','window.focus_changed','process.started','process.exited','process.unobserved','external_terminal_evidence','heartbeat.fresh','heartbeat.stalled','hang.suspected','hang.confirmed','span.started','span.completed','span.error','span.blocked','span.abandoned','observer.gap','observer.reconciled','observer.health','process_lost')) 'event type families'
}
if ($registrySchema) { Assert-Observation ($registrySchema.properties.schema.const -eq 'TbgRuntimeObserverArtifactRegistry.v1') 'artifact registry schema const' }
if ($timeline) {
    Assert-Observation ($timeline.properties.schema.const -eq 'TbgRuntimeIncidentTimeline.v1') 'timeline schema const'
    Assert-Observation ($timeline.properties.provenCause.type -eq 'null') 'timeline cannot declare cause'
}
if ($json.manifest) {
    $expected = [ordered]@{
        runtimeEventObservationContract = '.tbg/workflows/runtime-event-observation.contract.json'
        runtimeObserverRunContextSchema = '.tbg/harness/schemas/runtime-observer-run-context.schema.json'
        runtimeObserverEventSchema = '.tbg/harness/schemas/runtime-observer-event.schema.json'
        runtimeObserverArtifactRegistrySchema = '.tbg/harness/schemas/runtime-observer-artifact-registry.schema.json'
        runtimeIncidentTimelineSchema = '.tbg/harness/schemas/runtime-incident-timeline.schema.json'
        runtimeEventObservationFixtures = '.tbg/harness/fixtures/runtime-event-observation.fixtures.json'
        runtimeEventObservationValidator = 'scripts/tbg/Test-TbgRuntimeEventObservation.ps1'
        runtimeObserverRuntimeRoot = '.local/tbg-runtime-observer'
        runtimeEventObservationOutput = 'artifacts/latest/runtime-observer'
    }
    foreach ($item in $expected.GetEnumerator()) { Assert-Observation ([string]$json.manifest.paths.($item.Key) -eq $item.Value) "manifest $($item.Key)" }
}
if ($json.artifactTypes) {
    Assert-Observation ([string]$json.artifactTypes.runtimeObserverRuntimeRoot -eq '.local/tbg-runtime-observer') 'artifact registry runtime root'
    $ids = @($json.artifactTypes.types | ForEach-Object { [string]$_.id })
    Assert-Observation (Contains-All $ids @('runtime-observer-run-context','runtime-observer-artifact-registry','runtime-observer-events','runtime-observer-status','runtime-incident-timeline','runtime-incident-result','runtime-observer-operator-report')) 'artifact registry roles'
}

if ($fixtures) {
    Assert-Observation ($fixtures.schema -eq 'TbgRuntimeEventObservationFixture.v1') 'fixture schema'
    foreach ($case in @($fixtures.cases)) {
        $valid = $true; $caseFailures = [System.Collections.Generic.List[string]]::new()
        $seen = @{}
        foreach ($fixtureEvent in @($case.events)) {
            if ([string]$fixtureEvent.runId -ne [string]$fixtures.runContext.runId -or [string]$fixtureEvent.correlationId -ne [string]$fixtures.runContext.correlationId) { $valid = $false; $caseFailures.Add('wrong correlation') | Out-Null }
            if ($seen.ContainsKey([string]$fixtureEvent.eventId)) { $valid = $false; $caseFailures.Add('duplicate event id') | Out-Null }
            $seen[[string]$fixtureEvent.eventId] = $true
            if (@($eventSchema.properties.sourceKind.enum) -notcontains [string]$fixtureEvent.sourceKind -or @($eventSchema.properties.eventType.enum) -notcontains [string]$fixtureEvent.eventType) { $valid = $false; $caseFailures.Add('event shape') | Out-Null }
            if ($fixtureEvent.PSObject.Properties.Name -contains 'negativeEvidence') {
                $negative = $fixtureEvent.negativeEvidence
                if (-not ($negative.observerActive -and $negative.sourceFresh -and $negative.observationComplete -and -not $negative.observed)) { $valid = $false; $caseFailures.Add('invalid negative evidence') | Out-Null }
            }
        }
        $content = $case | ConvertTo-Json -Depth 20 -Compress
        if ($content -match '(?i)(password|token|\.dmp|C:\\Users\\|secrets?)') { $valid = $false; $caseFailures.Add('forbidden content') | Out-Null }
        if ($case.PSObject.Properties.Name -contains 'classification' -and $case.classification -eq 'native_crash_confirmed') {
            $external = @($case.events | Where-Object { $_.eventType -eq 'external_terminal_evidence' -and @($_.evidenceRefs).Count -gt 0 })
            if ($external.Count -eq 0) { $valid = $false; $caseFailures.Add('native crash lacks external evidence') | Out-Null }
        }
        if ($case.PSObject.Properties.Name -contains 'timeline' -and $case.timeline) {
            $ingested = @($case.timeline.ingestionOrderEventIds)
            $actual = @($case.events | ForEach-Object { [string]$_.eventId })
            if (($ingested -join '|') -ne ($actual -join '|') -or @($case.timeline.orderedEventIds).Count -ne $actual.Count) { $valid = $false; $caseFailures.Add('timeline ingestion order') | Out-Null }
        }
        $actualExpectation = if ($valid) { 'pass' } else { 'fail' }
        Assert-Observation ($actualExpectation -eq [string]$case.expect) "fixture $($case.id)"
    }
}

$result = [ordered]@{
    schema = 'tbg.runtime-event-observation.validation.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    pass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    proofLevel = 'static_test'
    proofCeiling = 'static_test'
}
$output = Join-Path $repoRoot 'artifacts/latest/runtime-observer/runtime-event-observation.result.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
[IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { exit 1 }
Write-Host "Runtime event observation spine: PASS ($passes checks)" -ForegroundColor Green
