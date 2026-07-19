[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [switch]$RemoteReviewNeeded,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Read-TbgJson([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
function Hash-Tbg([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-TbgJson($Value, [string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 32), [Text.UTF8Encoding]::new($false))
}

if (-not $RemoteReviewNeeded) { throw 'A sanitized capsule is produced only when -RemoteReviewNeeded is explicitly supplied.' }
$root = if ([IO.Path]::IsPathRooted($RunRoot)) { $RunRoot } else { Join-Path $repoRoot $RunRoot }
$context = Read-TbgJson (Join-Path $root 'run-context.json')
$incident = Read-TbgJson (Join-Path $root 'incident-result.json')
$events = @(Get-Content -LiteralPath (Join-Path $root 'events.jsonl') -Encoding UTF8 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
$open = @($events | Where-Object { $_.eventType -eq 'span.started' } | Select-Object -Last 1)
$classification = [string]$incident.classification
$crashObserved = $classification -in @('native_crash_suspected','native_crash_confirmed')
$externalRefs = @($incident.externalTerminalEvidenceRefs)
if ($classification -eq 'native_crash_confirmed' -and $externalRefs.Count -eq 0) { throw 'native_crash_confirmed requires external terminal evidence before capsule creation.' }
$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
$failureSummary = "Correlated incident assembled as $classification; proven cause remains null."
$capsule = [ordered]@{
    schema = 'TbgRuntimeContextCapsule.v1'; runId = $context.runId; generatedUtc = [DateTime]::UtcNow.ToString('o')
    repo = 'EndeavorEverlasting/BlacksmithGuild'; branch = (& git -C $repoRoot branch --show-current).Trim(); commitSha = $commit
    sprint = 'Sprint 6'; lane = 'runtime-incident-assembly'; worktreeLabel = $context.worktreeLabel; sessionOwner = $null; loadedAssemblySha256 = $null
    runtimeClassification = 'ambiguous'
    processes = @([ordered]@{ canonicalName = $context.processIdentity.canonicalName; pid = $context.processIdentity.pid; ownership = $context.processIdentity.ownership; windowIdentity = $null })
    handoff = [ordered]@{ lastCompleted = $null; active = $null; nextIntended = $null }
    failure = [ordered]@{ classification = $classification; summary = $failureSummary; crashObserved = $crashObserved; externalTerminalEvidenceRefs = @($externalRefs) }
    evidenceRefs = @(
        [ordered]@{ role = 'runtime-observer-events'; sha256 = (Hash-Tbg (Join-Path $root 'events.jsonl')); sanitizedExcerpt = $null },
        [ordered]@{ role = 'runtime-incident-result'; sha256 = (Hash-Tbg (Join-Path $root 'incident-result.json')); sanitizedExcerpt = $null }
    )
    runtimeObserverEventArtifactPath = $null; runtimeObserverTimelineArtifactPath = $null; proofLevel = 'harness'
    redaction = [ordered]@{ sanitized = $true; containsSecrets = $false; containsSaveData = $false; containsAbsolutePersonalPaths = $false; rawLogsCommitted = $false }
    nextDecision = 'Review bounded observations and collect external terminal evidence only when needed; do not infer a root cause from the open boundary.'
}
if ($crashObserved) {
    $started = if ($open.Count -gt 0) { $open[0] } else { $null }
    $capsule.crashObservability = [ordered]@{
        commandId = if ($started) { $started.commandId } else { $null }; correlationId = $context.correlationId
        spanId = if ($started) { $started.spanId } else { 'no-span' }; parentSpanId = if ($started) { $started.parentSpanId } else { $null }
        operation = if ($started) { $started.operation } else { 'unobserved_operation' }; startedAtUtc = if ($started) { $started.observedUtc } else { $context.startedUtc }
        completedAtUtc = $null; terminalStatus = 'process_lost'; preState = @{}; postState = $null
        expectedSignals = @(); observedSignals = @('process_lost'); negativeEvidence = @()
        lastMarkerBoundaryOnly = $true; balancedSpan = $false; unrelatedDoneClosedSpan = $false
        causality = [ordered]@{ observation = 'Process loss was correlated by normalized observer events.'; inference = $null; hypotheses = @(); provenCause = $null; rootCauseEvidenceRefs = @() }
        reconstructable = $true
    }
}
Write-TbgJson $capsule $OutputPath
if ((Get-Item -LiteralPath $OutputPath).Length -gt 65536) { Remove-Item -LiteralPath $OutputPath; throw 'Sanitized capsule exceeds the 64 KiB limit.' }
if ($PassThru) { return $capsule }
