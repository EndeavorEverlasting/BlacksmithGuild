[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunRoot,
    [string]$LatestOutputRoot = 'artifacts/latest/runtime-incident',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Read-TbgJson([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
function Write-TbgJson($Value, [string]$Path) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 32), [Text.UTF8Encoding]::new($false))
}
function Test-TbgUtc([object]$Value) {
    $parsed = [DateTime]::MinValue
    return ($null -ne $Value -and [DateTime]::TryParse([string]$Value, [ref]$parsed) -and $parsed.Kind -ne [DateTimeKind]::Unspecified)
}
function Get-TbgEvents([string]$Path) {
    $events = @()
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $events += [pscustomobject]@{ ingestionIndex = $lineNumber; value = ($line | ConvertFrom-Json -ErrorAction Stop) } }
        catch { throw "Malformed JSON event at events.jsonl line $lineNumber." }
    }
    return @($events)
}

$runRootPath = if ([IO.Path]::IsPathRooted($RunRoot)) { $RunRoot } else { Join-Path $repoRoot $RunRoot }
$contextPath = Join-Path $runRootPath 'run-context.json'
$registryPath = Join-Path $runRootPath 'artifact-registry.json'
$eventsPath = Join-Path $runRootPath 'events.jsonl'
$statusPath = Join-Path $runRootPath 'observer-status.json'
foreach ($path in @($contextPath, $registryPath, $eventsPath, $statusPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing required runtime-observer input: $path" }
}
$context = Read-TbgJson $contextPath
$registry = Read-TbgJson $registryPath
$status = Read-TbgJson $statusPath
if ($context.schema -ne 'TbgRuntimeObserverRunContext.v1' -or $registry.schema -ne 'TbgRuntimeObserverArtifactRegistry.v1') { throw 'Run context or artifact registry schema is invalid.' }
if ([string]$registry.runId -ne [string]$context.runId) { throw 'Artifact registry runId does not match run context.' }
if (-not (Test-TbgUtc $context.startedUtc) -or ($null -ne $context.completedUtc -and -not (Test-TbgUtc $context.completedUtc))) { throw 'Run context has malformed timestamps.' }

$declaredObservers = @($context.observers | ForEach-Object { [string]$_.observerId })
$events = Get-TbgEvents $eventsPath
$accepted = @()
$quarantine = [System.Collections.Generic.List[object]]::new()
$seen = @{}
foreach ($record in $events) {
    $event = $record.value
    $reason = $null
    if ([string]$event.runId -ne [string]$context.runId -or [string]$event.correlationId -ne [string]$context.correlationId) { $reason = 'identity_mismatch' }
    elseif ([string]::IsNullOrWhiteSpace([string]$event.eventId) -or $seen.ContainsKey([string]$event.eventId)) { $reason = 'duplicate_event_id' }
    elseif (-not (Test-TbgUtc $event.observedUtc) -or ($null -ne $event.sourceTimestamp -and -not (Test-TbgUtc $event.sourceTimestamp))) { $reason = 'malformed_timestamp' }
    elseif ($declaredObservers -notcontains [string]$event.observerId) { $reason = 'unknown_observer' }
    elseif ([string]$event.freshness -eq 'stale') { $reason = 'stale_source' }
    elseif ([DateTime]$event.observedUtc -lt ([DateTime]$context.startedUtc) -or ($null -ne $context.completedUtc -and [DateTime]$event.observedUtc -gt ([DateTime]$context.completedUtc).AddMinutes(1))) { $reason = 'outside_observation_window' }
    if ($reason) {
        $quarantine.Add([ordered]@{ eventId = $event.eventId; ingestionIndex = $record.ingestionIndex; reason = $reason }) | Out-Null
        continue
    }
    $seen[[string]$event.eventId] = $true
    $accepted += $record
}
if ($accepted.Count -eq 0) { throw 'No valid events remain after quarantine.' }

$ordered = @($accepted | Sort-Object @{ Expression = { [DateTime]$_.value.observedUtc } }, @{ Expression = { $_.ingestionIndex } })
$eventTypes = @($accepted | ForEach-Object { [string]$_.value.eventType })
$external = @($accepted | Where-Object { $_.value.eventType -eq 'external_terminal_evidence' -and @($_.value.evidenceRefs).Count -gt 0 })
$processLost = @($accepted | Where-Object { $_.value.eventType -in @('process_lost', 'process.unobserved') })
$processExited = @($accepted | Where-Object { $_.value.eventType -eq 'process.exited' })
$spanErrors = @($accepted | Where-Object { $_.value.eventType -eq 'span.error' })
$hangConfirmed = @($accepted | Where-Object { $_.value.eventType -eq 'hang.confirmed' })
$hangSuspected = @($accepted | Where-Object { $_.value.eventType -eq 'hang.suspected' })
$stalled = @($accepted | Where-Object { $_.value.eventType -eq 'heartbeat.stalled' })
$cleanExit = @($accepted | Where-Object {
    $_.value.eventType -eq 'process.exited' -and
    $null -ne $_.value.payload.PSObject.Properties['cleanExit'] -and
    $_.value.payload.PSObject.Properties['cleanExit'].Value -eq $true
})
$startedSpans = @($accepted | Where-Object { $_.value.eventType -eq 'span.started' })
$terminalSpans = @($accepted | Where-Object { $_.value.eventType -in @('span.completed','span.error','span.blocked','span.abandoned') } | ForEach-Object { [string]$_.value.spanId })
$openSpan = @($startedSpans | Where-Object { $terminalSpans -notcontains [string]$_.value.spanId } | Select-Object -Last 1)
$healthObserved = @($accepted | Where-Object { $_.value.sourceKind -eq 'observer_health' -and $_.value.eventType -eq 'observer.health' }).Count -gt 0
$negativeClaims = @($accepted | Where-Object {
    $claim = $_.value.payload.PSObject.Properties['negativeEvidenceClaim']
    $null -ne $claim -and $claim.Value -eq $true
})
$invalidNegative = $negativeClaims.Count -gt 0 -and -not $healthObserved

$classification = 'unknown_failure'
if ($cleanExit.Count -gt 0) { $classification = 'clean_exit' }
elseif ($spanErrors.Count -gt 0) { $classification = 'managed_exception_confirmed' }
elseif ($invalidNegative) { $classification = 'observer_failure' }
elseif ($hangConfirmed.Count -gt 0) { $classification = 'hang_confirmed' }
elseif ($hangSuspected.Count -gt 0) { $classification = 'hang_suspected' }
elseif ($stalled.Count -gt 0 -and $processLost.Count -eq 0) { $classification = 'log_stalled' }
elseif ($processLost.Count -gt 0 -and $external.Count -gt 0) { $classification = 'native_crash_confirmed' }
elseif ($processLost.Count -gt 0) { $classification = 'native_crash_suspected' }
elseif ($processExited.Count -gt 0) { $classification = 'process_unobserved' }
elseif (@($accepted | Where-Object { $_.value.eventType -eq 'observer.gap' }).Count -gt 0 -or $quarantine.Count -gt 0 -or $invalidNegative) { $classification = 'observer_failure' }

$observations = @("Accepted $($accepted.Count) normalized event(s); quarantined $($quarantine.Count).")
if ($openSpan.Count -gt 0) { $observations += "Open span '$($openSpan[0].value.spanId)' is an unresolved execution boundary, not a cause." }
if ($invalidNegative) { $observations += 'Negative-evidence claim was not accepted because observer health was missing.' }
$inference = if ($classification -eq 'native_crash_confirmed') { 'Correlated process loss and external terminal evidence support native crash confirmation.' } elseif ($classification -eq 'native_crash_suspected') { 'Process loss was observed without correlated external terminal evidence.' } else { $null }
$timeline = [ordered]@{
    schema = 'TbgRuntimeIncidentTimeline.v1'; runId = $context.runId; correlationId = $context.correlationId
    orderedEventIds = @($ordered | ForEach-Object { [string]$_.value.eventId })
    ingestionOrderEventIds = @($accepted | Sort-Object ingestionIndex | ForEach-Object { [string]$_.value.eventId })
    classificationsAllowed = @('clean_exit','managed_exception_confirmed','native_crash_suspected','native_crash_confirmed','hang_suspected','hang_confirmed','log_stalled','process_unobserved','observer_failure','unknown_failure')
    observations = @($observations); inferences = @($inference | Where-Object { $null -ne $_ }); hypotheses = @(); provenCause = $null
}
$result = [ordered]@{
    schema = 'TbgRuntimeIncidentResult.v1'; runId = $context.runId; correlationId = $context.correlationId; classification = $classification
    status = if ($quarantine.Count -gt 0) { 'quarantined_with_valid_evidence' } else { 'assembled' }
    quarantine = @($quarantine); openSpanBoundary = if ($openSpan.Count -gt 0) { [string]$openSpan[0].value.spanId } else { $null }
    negativeEvidence = [ordered]@{ claimed = ($negativeClaims.Count -gt 0); valid = (-not $invalidNegative); reason = if ($invalidNegative) { 'missing_observer_health' } else { $null } }
    causality = [ordered]@{ observations = @($observations); boundedInferences = @($inference | Where-Object { $null -ne $_ }); hypotheses = @(); provenCause = $null; rootCauseEvidenceRefs = @() }
    externalTerminalEvidenceRefs = @($external | ForEach-Object { @($_.value.evidenceRefs) } | Select-Object -Unique)
    proofLevel = 'harness'
}
Write-TbgJson $timeline (Join-Path $runRootPath 'incident-timeline.json')
Write-TbgJson $result (Join-Path $runRootPath 'incident-result.json')
$suspectedText = if ($null -eq $inference) { 'No bounded failure inference was available.' } else { $inference }
$report = @"
# Runtime incident operator report

## Known
- Classification: `$($classification)`.
- Accepted events: `$($accepted.Count)`; quarantined events: `$($quarantine.Count)`.
- An open span is an unresolved boundary, never a cause.

## Unknown
- `provenCause` is null. This assembler does not guess a root cause.

## Suspected
- `$suspectedText`

## Forbidden claims
- Event order, stale log silence, a window transition, or an open span does not prove a root cause.
- Native crash confirmation requires correlated external terminal evidence.
"@
[IO.File]::WriteAllText((Join-Path $runRootPath 'operator-report.md'), $report, [Text.UTF8Encoding]::new($false))
$latest = if ([IO.Path]::IsPathRooted($LatestOutputRoot)) { $LatestOutputRoot } else { Join-Path $repoRoot $LatestOutputRoot }
Write-TbgJson $result (Join-Path $latest 'runtime-incident.result.json')
if ($PassThru) { return $result }
