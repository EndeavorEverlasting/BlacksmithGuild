[CmdletBinding()]
param(
    [ValidateSet('start', 'status', 'stop')]
    [string]$Command = 'start',
    [string]$RunId,
    [string]$CorrelationId,
    [int]$DurationSeconds = 30,
    [string]$OutputRoot = '.local/tbg-runtime-observer',
    [string]$LeaseId,
    [Nullable[int]]$TestProcessId,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$canonicalNames = @('Bannerlord', 'Bannerlord.Native', 'TaleWorlds.MountAndBlade', 'TaleWorlds.MountAndBlade.Launcher')

function Get-TbgNow { [DateTime]::UtcNow.ToString('o') }
function Write-TbgJson([object]$Value, [string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
function Get-TbgGit([string[]]$Arguments) {
    try { $value = & git -C $repoRoot @Arguments 2>$null; if ($LASTEXITCODE -eq 0) { return (@($value) -join "`n").Trim() } } catch {}
    return 'unknown'
}
function Get-TbgCanonicalName([string]$Name) {
    $base = [IO.Path]::GetFileNameWithoutExtension($Name)
    if ($canonicalNames -contains $base) { return $base }
    return 'unknown'
}
function Get-TbgProcesses {
    $result = @()
    try {
        $all = Get-CimInstance Win32_Process -ErrorAction Stop
        foreach ($process in $all) {
            $canonical = Get-TbgCanonicalName ([string]$process.Name)
            if ($canonical -ne 'unknown' -or ($null -ne $TestProcessId -and [int]$process.ProcessId -eq [int]$TestProcessId)) {
                $result += [pscustomobject]@{
                    canonicalName = $canonical
                    pid = [int]$process.ProcessId
                    parentPid = if ($null -eq $process.ParentProcessId) { $null } else { [int]$process.ParentProcessId }
                    sessionId = $null
                    imageName = [string]$process.Name
                    creationDate = if ($null -eq $process.CreationDate) { $null } else { [Management.ManagementDateTimeConverter]::ToDateTime($process.CreationDate).ToUniversalTime().ToString('o') }
                }
            }
        }
    } catch {
        foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
            $canonical = Get-TbgCanonicalName ([string]$process.ProcessName)
            if ($canonical -ne 'unknown' -or ($null -ne $TestProcessId -and [int]$process.Id -eq [int]$TestProcessId)) {
                $result += [pscustomobject]@{
                    canonicalName = $canonical; pid = [int]$process.Id; parentPid = $null; sessionId = $null
                    imageName = [string]$process.ProcessName; creationDate = if ($null -eq $process.StartTime) { $null } else { $process.StartTime.ToUniversalTime().ToString('o') }
                }
            }
        }
    }
    return @($result)
}
function New-TbgEvent([string]$Run, [string]$Correlation, [string]$SourceKind, [string]$EventType, $Process, [string]$Severity = 'info', [hashtable]$Payload = @{}, [string[]]$EvidenceRefs = @(), [string]$Freshness = 'fresh') {
    $identity = if ($null -eq $Process) { [ordered]@{ canonicalName = 'unknown'; pid = $null } } else { [ordered]@{ canonicalName = [string]$Process.canonicalName; pid = [int]$Process.pid } }
    return [ordered]@{
        schema = 'TbgRuntimeObserverEvent.v1'; version = 1
        eventId = "gro-$([Guid]::NewGuid().ToString('N').Substring(0, 20))"
        runId = $Run; commandId = $null; correlationId = $Correlation; spanId = $null; parentSpanId = $null
        observerId = 'game-runtime-observer'; sourceKind = $SourceKind; eventType = $EventType; severity = $Severity
        observedUtc = Get-TbgNow; sourceTimestamp = $null; processIdentity = $identity; windowIdentity = $null
        operation = 'external_game_runtime_observation'; expectedSignalId = $null; payload = $Payload
        evidenceRefs = @($EvidenceRefs); freshness = $Freshness; proofLevel = 'harness'; redactionState = 'sanitized'
    }
}
function Write-TbgRun([string]$Root, [string]$Run, [string]$Correlation, [string]$Lease, [object[]]$Events, [string]$Status) {
    $runRoot = Join-Path $Root $Run
    $relativeRoot = ".local/tbg-runtime-observer/$Run/"
    $context = [ordered]@{
        schema = 'TbgRuntimeObserverRunContext.v1'; runId = $Run; correlationId = $Correlation
        sourceCommit = Get-TbgGit @('rev-parse','HEAD'); branch = Get-TbgGit @('branch','--show-current'); worktreeLabel = 'game-runtime-observer'
        observers = @([ordered]@{ observerId = 'game-runtime-observer'; version = '1.0.0'; sourceKind = 'process_lifecycle' })
        processIdentity = [ordered]@{ canonicalName = 'unknown'; pid = $null; imageName = $null; ownership = 'unknown' }
        startedUtc = Get-TbgNow; completedUtc = if ($Status -eq 'running') { $null } else { Get-TbgNow }
        mode = 'observe'; authority = 'read-only external observation; lease controls observer disposal only'; proofCeiling = 'harness'
        artifactRoot = $relativeRoot; redactionPolicy = [ordered]@{ rawEvidenceLocalOnly = $true; forbiddenContent = @('password','token','.dmp','absolute_personal_paths') }
    }
    $leaseObject = [ordered]@{ schema = 'TbgGameRuntimeObserverLease.v1'; leaseId = $Lease; runId = $Run; ownerPid = $PID; status = $Status; updatedUtc = Get-TbgNow }
    $eventLines = @($Events | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 })
    $timeline = [ordered]@{ schema='TbgRuntimeIncidentTimeline.v1'; runId=$Run; correlationId=$Correlation; orderedEventIds=@($Events | ForEach-Object eventId); ingestionOrderEventIds=@($Events | ForEach-Object eventId); classificationsAllowed=@('log_stalled','process_unobserved','process_exited','native_crash_suspected','clean_exit','unknown_failure'); observations=@('External observer events are read-only observations.'); inferences=@(); hypotheses=@(); provenCause=$null }
    $incident = [ordered]@{ schema='TbgRuntimeObserverIncidentResult.v1'; runId=$Run; correlationId=$Correlation; status='observation_only'; provenCause=$null; proofLevel='harness'; warning='No event, exit, or stale log alone confirms a native crash.' }
    Write-TbgJson $context (Join-Path $runRoot 'run-context.json')
    [IO.File]::WriteAllText((Join-Path $runRoot 'events.jsonl'), ($eventLines -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    Write-TbgJson $leaseObject (Join-Path $runRoot 'observer-status.json')
    Write-TbgJson $timeline (Join-Path $runRoot 'incident-timeline.json')
    Write-TbgJson $incident (Join-Path $runRoot 'incident-result.json')
    [IO.File]::WriteAllText((Join-Path $runRoot 'operator-report.md'), "# Game runtime observer`n`nRead-only observer status: **$Status**. It never starts, stops, clicks, or mutates Bannerlord. Stale logging alone is not a crash conclusion.`n", [Text.UTF8Encoding]::new($false))
    $artifacts = @('run-context.json','events.jsonl','observer-status.json','incident-timeline.json','incident-result.json','operator-report.md') | ForEach-Object {
        $p = Join-Path $runRoot $_
        [ordered]@{ role = $_; path = $_; sha256 = if (Test-Path $p) { (Get-FileHash $p -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }; generatedUtc = Get-TbgNow; sourceObserver='game-runtime-observer'; disposition='ignored_local'; retention='local_run' }
    }
    Write-TbgJson ([ordered]@{ schema='TbgRuntimeObserverArtifactRegistry.v1'; runId=$Run; generatedUtc=Get-TbgNow; artifacts=@($artifacts) }) (Join-Path $runRoot 'artifact-registry.json')
    return $runRoot
}

$baseRoot = if ([IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot } else { Join-Path $repoRoot $OutputRoot }
if ($Command -eq 'status') {
    if ([string]::IsNullOrWhiteSpace($RunId)) { throw 'status requires -RunId.' }
    $statusPath = Join-Path (Join-Path $baseRoot $RunId) 'observer-status.json'
    if (-not (Test-Path -LiteralPath $statusPath)) { throw "Observer run '$RunId' was not found." }
    $value = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($PassThru) { return $value }; $value | ConvertTo-Json -Depth 10; exit 0
}
if ($Command -eq 'stop') {
    if ([string]::IsNullOrWhiteSpace($RunId) -or [string]::IsNullOrWhiteSpace($LeaseId)) { throw 'stop requires -RunId and -LeaseId.' }
    $statusPath = Join-Path (Join-Path $baseRoot $RunId) 'observer-status.json'
    $existing = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$existing.leaseId -ne $LeaseId) { throw 'Lease mismatch: only the starter may stop or dispose this observer.' }
    $null = Write-TbgRun $baseRoot $RunId 'observer-stop' $LeaseId @((New-TbgEvent $RunId 'observer-stop' 'observer_health' 'observer.health' $null 'info' @{ disposition='observer_disposed_no_game_process_touched' })) 'stopped'
    Write-Host "Observer $RunId stopped; no Bannerlord process was touched."; exit 0
}

if ($DurationSeconds -lt 1 -or $DurationSeconds -gt 300) { throw 'DurationSeconds must be between 1 and 300.' }
if ([string]::IsNullOrWhiteSpace($RunId)) { $RunId = "gro-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))-$([Guid]::NewGuid().ToString('N').Substring(0,8))" }
if ([string]::IsNullOrWhiteSpace($CorrelationId)) { $CorrelationId = "gro-corr-$([Guid]::NewGuid().ToString('N').Substring(0,12))" }
$lease = [Guid]::NewGuid().ToString('N')
$events = New-Object Collections.Generic.List[object]
$events.Add((New-TbgEvent $RunId $CorrelationId 'observer_health' 'observer.health' $null 'info' @{ watcher='CIM_reconciliation_and_Process.Exited'; leaseId=$lease })) | Out-Null
$known = @{}
foreach ($p in Get-TbgProcesses) { $known[[string]$p.pid] = $p; $events.Add((New-TbgEvent $RunId $CorrelationId 'process_lifecycle' 'process.started' $p 'info' @{ parentPid=$p.parentPid; sessionId=$p.sessionId; observedAtStart=$true })) | Out-Null }
$deadline = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $current = @{}; foreach ($p in Get-TbgProcesses) { $current[[string]$p.pid] = $p }
    foreach ($key in $current.Keys) { if (-not $known.ContainsKey($key)) { $p=$current[$key]; $events.Add((New-TbgEvent $RunId $CorrelationId 'process_lifecycle' 'process.started' $p 'info' @{ parentPid=$p.parentPid; sessionId=$p.sessionId; reconciled=$true })) | Out-Null } }
    foreach ($key in $known.Keys) { if (-not $current.ContainsKey($key)) { $p=$known[$key]; $events.Add((New-TbgEvent $RunId $CorrelationId 'process_lifecycle' 'process.exited' $p 'warning' @{ exitCode=$null; parentPid=$p.parentPid; sessionId=$p.sessionId; reconciliationObserved=$true })) | Out-Null } }
    $known = $current
}
$runRoot = Write-TbgRun $baseRoot $RunId $CorrelationId $lease @($events.ToArray()) 'completed'
$result = [pscustomobject]@{ runId=$RunId; correlationId=$CorrelationId; leaseId=$lease; runRoot=$runRoot; eventCount=$events.Count; proofLevel='harness'; proofCeiling='harness' }
Write-Host "Game runtime observer completed: $RunId ($($events.Count) events)."
if ($PassThru) { return $result }
