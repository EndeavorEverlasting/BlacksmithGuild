[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$CorrelationId,
    [string]$LogPath,
    [int]$StallSeconds = 60,
    [int]$ConfirmHangSeconds = 180,
    [switch]$ObserverActive,
    [string]$ExpectedRunMarker,
    [string]$OutputRoot = '.local/tbg-runtime-observer',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$names = @('Bannerlord','Bannerlord.Native','TaleWorlds.MountAndBlade','TaleWorlds.MountAndBlade.Launcher')
function New-HeartbeatEvent($type,$severity,$process,$payload,$freshness) {
    [ordered]@{
        schema='TbgRuntimeObserverEvent.v1';version=1;eventId="heartbeat-$([Guid]::NewGuid().ToString('N').Substring(0,20))";runId=$RunId;commandId=$null;correlationId=$CorrelationId;spanId=$null;parentSpanId=$null
        observerId='runtime-heartbeat-evidence';sourceKind=if($type -match '^hang'){'process_responsiveness'}else{'heartbeat_log_progress'};eventType=$type;severity=$severity;observedUtc=[DateTime]::UtcNow.ToString('o');sourceTimestamp=$null
        processIdentity=[ordered]@{canonicalName=if($process){$process.ProcessName}else{'unknown'};pid=if($process){$process.Id}else{$null}};windowIdentity=$null;operation='heartbeat_and_responsiveness_observation';expectedSignalId=$null
        payload=$payload;evidenceRefs=@();freshness=$freshness;proofLevel='harness';redactionState='sanitized'
    }
}
$process = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName } | Select-Object -First 1)[0]
$events = New-Object Collections.Generic.List[object]
if (-not $ObserverActive) {
    $events.Add((New-HeartbeatEvent 'observer.gap' 'warning' $process @{reason='observer_missing'; logConclusion='unknown_not_negative_evidence'} 'unknown')) | Out-Null
} elseif ($null -eq $process) {
    $events.Add((New-HeartbeatEvent 'process.unobserved' 'warning' $null @{reason='canonical_process_absent'; logConclusion='no_crash_inference'} 'unknown')) | Out-Null
} elseif ([string]::IsNullOrWhiteSpace($LogPath) -or -not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
    $events.Add((New-HeartbeatEvent 'observer.gap' 'warning' $process @{reason='log_missing'; processAlive=$true; logConclusion='unknown_not_negative_evidence'} 'unknown')) | Out-Null
} else {
    $item = Get-Item -LiteralPath $LogPath
    $age = ([DateTime]::UtcNow - $item.LastWriteTimeUtc).TotalSeconds
    $markerMatches = $true
    if (-not [string]::IsNullOrWhiteSpace($ExpectedRunMarker)) {
        $tail = Get-Content -LiteralPath $LogPath -Tail 80 -Encoding UTF8 -ErrorAction SilentlyContinue
        $markerMatches = (($tail -join "`n").Contains($ExpectedRunMarker))
    }
    if (-not $markerMatches) {
        $events.Add((New-HeartbeatEvent 'observer.gap' 'warning' $process @{reason='wrong_run'; processAlive=$true; logConclusion='wrong_run_not_negative_evidence'} 'unknown')) | Out-Null
    } elseif ($age -le $StallSeconds) {
        $events.Add((New-HeartbeatEvent 'heartbeat.fresh' 'info' $process @{ageSeconds=[math]::Round($age,1);processAlive=$true} 'fresh')) | Out-Null
    } else {
        $events.Add((New-HeartbeatEvent 'heartbeat.stalled' 'warning' $process @{ageSeconds=[math]::Round($age,1);processAlive=$true;staleLogIsNotCrash=$true} 'stale')) | Out-Null
        if ($age -ge $ConfirmHangSeconds) {
            $responsive = $null; try { $responsive = $process.Responding } catch {}
            $type = if ($responsive -eq $false) {'hang.confirmed'} else {'hang.suspected'}
            $events.Add((New-HeartbeatEvent $type $(if($type -eq 'hang.confirmed'){'error'}else{'warning'}) $process @{ageSeconds=[math]::Round($age,1);processAlive=$true;responding=$responsive;classificationRule='alive_plus_stalled_activity'} 'stale')) | Out-Null
        }
    }
}
$base=if([IO.Path]::IsPathRooted($OutputRoot)){$OutputRoot}else{Join-Path $repoRoot $OutputRoot};$path=Join-Path (Join-Path $base $RunId) 'heartbeat-evidence.jsonl'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
[IO.File]::WriteAllText($path, (@($events.ToArray()|ForEach-Object{$_|ConvertTo-Json -Compress -Depth 20}) -join [Environment]::NewLine),[Text.UTF8Encoding]::new($false))
if($PassThru){return @($events.ToArray())}
Write-Host "Heartbeat evidence: $($events.Count) event(s); stale logs never classify a crash."
