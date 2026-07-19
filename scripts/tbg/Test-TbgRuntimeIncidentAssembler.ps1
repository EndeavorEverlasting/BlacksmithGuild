[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Assert-Tbg([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
    else { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
}
function Write-TbgJson($Value, [string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
function New-TbgEvent([string]$Token, [int]$Index, [string]$Run, [string]$Correlation) {
    $type = $Token.Split('.')[0..([Math]::Min(1, $Token.Split('.').Count - 1))] -join '.'
    $source = 'process_lifecycle'; $eventType = $Token; $payload = @{}; $span = $null; $operation = $null; $refs = @()
    switch -Wildcard ($Token) {
        'window.*' { $source = 'window_lifecycle' }
        'span.started' { $source = 'in_process_span'; $span = 'span-open'; $operation = 'fixture-operation' }
        'span.error' { $source = 'in_process_span'; $span = 'span-open'; $operation = 'fixture-operation' }
        'span.completed.unrelated' { $source = 'in_process_span'; $eventType = 'span.completed'; $span = 'different-span'; $operation = 'other-operation' }
        'process.exited.clean' { $eventType = 'process.exited'; $payload.cleanExit = $true }
        'external_terminal_evidence.wer' { $source = 'windows_error_reporting'; $eventType = 'external_terminal_evidence'; $refs = @('wer-fixture-hash') }
        'external_terminal_evidence.taleworlds' { $source = 'taleworlds_crash'; $eventType = 'external_terminal_evidence'; $refs = @('taleworlds-fixture-hash') }
        'heartbeat.stalled' { $source = 'heartbeat_log_progress' }
        'hang.confirmed' { $source = 'process_responsiveness' }
        'observer.gap' { $source = 'observer_health' }
        'negative-evidence-claim' { $source = 'heartbeat_log_progress'; $eventType = 'heartbeat.stalled'; $payload.negativeEvidenceClaim = $true }
        'wrong-run' { $eventType = 'process.unobserved'; $Run = 'other-run' }
    }
    [ordered]@{
        schema='TbgRuntimeObserverEvent.v1';version=1;eventId="event-$Index-$Token";runId=$Run;commandId=$null;correlationId=$Correlation
        spanId=$span;parentSpanId=$null;observerId=if ($source -eq 'window_lifecycle') {'window-event-listener'} elseif ($source -eq 'in_process_span') {'runtime-span-writer'} else {'game-runtime-observer'}
        sourceKind=$source;eventType=$eventType;severity='warning';observedUtc=("2026-01-01T00:00:{0:d2}.0000000Z" -f $Index);sourceTimestamp=$null
        processIdentity=[ordered]@{canonicalName='Bannerlord';pid=42};windowIdentity=$null;operation=$operation;expectedSignalId=$null;payload=$payload;evidenceRefs=@($refs);freshness='fresh';proofLevel='harness';redactionState='sanitized'
    }
}
function New-TbgRun([object]$Case, [string]$Root) {
    $run = "fixture-$($Case.id)"; $correlation = "corr-$($Case.id)"
    $context = [ordered]@{
        schema='TbgRuntimeObserverRunContext.v1';runId=$run;correlationId=$correlation;sourceCommit='0000000';branch='fixture';worktreeLabel='fixture'
        observers=@(
            [ordered]@{observerId='window-event-listener';version='1';sourceKind='window_lifecycle'},
            [ordered]@{observerId='game-runtime-observer';version='1';sourceKind='process_lifecycle'},
            [ordered]@{observerId='runtime-span-writer';version='1';sourceKind='in_process_span'}
        );processIdentity=[ordered]@{canonicalName='Bannerlord';pid=42;imageName='Bannerlord.exe';ownership='unknown'}
        startedUtc='2026-01-01T00:00:00.0000000Z';completedUtc='2026-01-01T00:05:00.0000000Z';mode='fixture';authority='static fixture';proofCeiling='harness'
        artifactRoot=".local/tbg-runtime-observer/$run/";redactionPolicy=[ordered]@{rawEvidenceLocalOnly=$true;forbiddenContent=@('token')}
    }
    Write-TbgJson $context (Join-Path $Root 'run-context.json')
    $events = @(); $index = 1
    foreach ($token in @($Case.events)) { $events += (New-TbgEvent $token $index $run $correlation); $index++ }
    [IO.File]::WriteAllText((Join-Path $Root 'events.jsonl'), (($events | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 }) -join "`n"), [Text.UTF8Encoding]::new($false))
    Write-TbgJson ([ordered]@{schema='TbgRuntimeObserverArtifactRegistry.v1';runId=$run;generatedUtc='2026-01-01T00:05:00.0000000Z';artifacts=@()} ) (Join-Path $Root 'artifact-registry.json')
    Write-TbgJson ([ordered]@{schema='TbgObserverStatus.v1';status='completed';observers=@()} ) (Join-Path $Root 'observer-status.json')
}
function Test-TbgRuntimeContextCapsule([object]$Capsule) {
    $required = @('schema','runId','generatedUtc','repo','branch','commitSha','sprint','lane','runtimeClassification','processes','handoff','failure','evidenceRefs','proofLevel','redaction','nextDecision')
    $propertyNames = @($Capsule.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($name in $required) {
        if ($propertyNames -notcontains $name) { return $false }
    }
    if ($Capsule.schema -ne 'TbgRuntimeContextCapsule.v1' -or $Capsule.repo -ne 'EndeavorEverlasting/BlacksmithGuild') { return $false }
    if ([string]$Capsule.commitSha -notmatch '^[0-9a-fA-F]{40}$') { return $false }
    if (-not ($Capsule.redaction.sanitized -and -not $Capsule.redaction.containsSecrets -and -not $Capsule.redaction.containsSaveData -and -not $Capsule.redaction.containsAbsolutePersonalPaths -and -not $Capsule.redaction.rawLogsCommitted)) { return $false }
    foreach ($evidence in @($Capsule.evidenceRefs)) { if ([string]$evidence.sha256 -notmatch '^[0-9a-fA-F]{64}$') { return $false } }
    if ($Capsule.failure.classification -eq 'native_crash_confirmed' -and @($Capsule.failure.externalTerminalEvidenceRefs).Count -eq 0) { return $false }
    if ($Capsule.failure.crashObserved) {
        $crash = $Capsule.crashObservability
        if ($null -eq $crash -or -not $crash.lastMarkerBoundaryOnly -or -not $crash.reconstructable -or $crash.terminalStatus -ne 'process_lost' -or $null -ne $crash.postState -or $crash.balancedSpan) { return $false }
        if ($crash.causality.provenCause -ne $null -or @($crash.causality.rootCauseEvidenceRefs).Count -ne 0) { return $false }
    }
    return $true
}

$fixturePath = Join-Path $repoRoot '.tbg/harness/fixtures/runtime-incident-assembler.fixtures.json'
$fixtures = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Tbg ($fixtures.schema -eq 'TbgRuntimeIncidentAssemblerFixture.v1') 'fixture schema'
foreach ($required in @('Resolve-TbgRuntimeIncident.ps1','New-TbgRuntimeIncidentCapsule.ps1','Test-TbgRuntimeIncidentAssembler.ps1')) {
    Assert-Tbg (Test-Path (Join-Path $PSScriptRoot $required)) "owned script $required"
}
$base = Join-Path $repoRoot '.local/tbg-runtime-observer/incident-assembler-test'
Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
foreach ($case in @($fixtures.cases)) {
    $root = Join-Path $base $case.id; New-TbgRun $case $root
    $one = & (Join-Path $PSScriptRoot 'Resolve-TbgRuntimeIncident.ps1') -RunRoot $root -LatestOutputRoot (Join-Path $base 'latest') -PassThru
    $first = Get-Content -LiteralPath (Join-Path $root 'incident-result.json') -Raw -Encoding UTF8
    $two = & (Join-Path $PSScriptRoot 'Resolve-TbgRuntimeIncident.ps1') -RunRoot $root -LatestOutputRoot (Join-Path $base 'latest') -PassThru
    $second = Get-Content -LiteralPath (Join-Path $root 'incident-result.json') -Raw -Encoding UTF8
    Assert-Tbg ([string]$one.classification -eq [string]$case.expected) "fixture $($case.id) classification"
    Assert-Tbg ($first -eq $second) "fixture $($case.id) deterministic replay"
    if ($case.PSObject.Properties.Name -contains 'quarantine') { Assert-Tbg (@($one.quarantine | Where-Object { $_.reason -eq $case.quarantine }).Count -gt 0) "fixture $($case.id) quarantine" }
    if ($case.PSObject.Properties.Name -contains 'capsule' -and $case.capsule) {
        $capsulePath = Join-Path $root 'sanitized-capsule.json'
        $capsule = & (Join-Path $PSScriptRoot 'New-TbgRuntimeIncidentCapsule.ps1') -RunRoot $root -OutputPath $capsulePath -RemoteReviewNeeded -PassThru
        $serializedCapsule = Get-Content -LiteralPath $capsulePath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Tbg (Test-TbgRuntimeContextCapsule $serializedCapsule) "fixture $($case.id) capsule validates TbgRuntimeContextCapsule.v1"
        if ($case.expected -eq 'native_crash_confirmed') { Assert-Tbg (@($capsule.failure.externalTerminalEvidenceRefs).Count -gt 0) "fixture $($case.id) external terminal evidence" }
    }
}
$result = [ordered]@{schema='tbg.runtime-incident-assembler.validation.v1';generatedUtc=[DateTime]::UtcNow.ToString('o');pass=($failures.Count -eq 0);passCount=$passes;failureCount=$failures.Count;failures=@($failures);proofLevel='static_test';proofCeiling='static_test'}
$output = Join-Path $repoRoot 'artifacts/latest/runtime-incident/runtime-incident-assembler.result.json'
Write-TbgJson $result $output
if ($failures.Count) { exit 1 }
Write-Host "Runtime incident assembler: PASS ($passes checks)" -ForegroundColor Green
