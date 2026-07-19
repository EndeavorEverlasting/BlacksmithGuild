[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$CorrelationId,
    [datetime]$SinceUtc = ([DateTime]::UtcNow.AddMinutes(-10)),
    [string]$OutputRoot = '.local/tbg-runtime-observer',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$names = @('Bannerlord','Bannerlord.Native','TaleWorlds.MountAndBlade','TaleWorlds.MountAndBlade.Launcher')
function New-Event($name, $pid, $source, $record) {
    $excerpt = (($record.Message -replace '(?i)([A-Z]:\\Users\\)[^ \r\n]+','$1<redacted>') -replace '(?i)(token|password)\s*[:=]\s*\S+','$1=<redacted>')
    if ($excerpt.Length -gt 800) { $excerpt = $excerpt.Substring(0,800) }
    $hash = if ([string]::IsNullOrWhiteSpace($excerpt)) { $null } else { (([Security.Cryptography.SHA256]::Create()).ComputeHash([Text.Encoding]::UTF8.GetBytes($excerpt)) | ForEach-Object ToString x2) -join '' }
    [ordered]@{
        schema='TbgRuntimeObserverEvent.v1'; version=1; eventId="wer-$([Guid]::NewGuid().ToString('N').Substring(0,20))"; runId=$RunId; commandId=$null; correlationId=$CorrelationId; spanId=$null; parentSpanId=$null
        observerId='windows-crash-evidence'; sourceKind=$source; eventType='external_terminal_evidence'; severity='warning'; observedUtc=[DateTime]::UtcNow.ToString('o'); sourceTimestamp=if($record.TimeCreated){$record.TimeCreated.ToUniversalTime().ToString('o')}else{$null}
        processIdentity=[ordered]@{canonicalName=$name;pid=$pid}; windowIdentity=$null; operation='external_crash_evidence_collection'; expectedSignalId=$null
        payload=[ordered]@{ provider=$record.ProviderName; eventId=$record.Id; excerpt=$excerpt; excerptSha256=$hash; correlation='name_or_pid_candidate_only' }
        evidenceRefs=@("windows-event:$($record.ProviderName):$($record.Id)"); freshness='fresh'; proofLevel='harness'; redactionState='sanitized'
    }
}
$records = @()
try {
    $filter = @{ LogName='Application'; StartTime=$SinceUtc; Id=@(1000,1001) }
    $records = @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop | Select-Object -First 100)
} catch {}
$events = foreach($record in $records) {
    $message = [string]$record.Message
    $candidate = $names | Where-Object { $message -match [regex]::Escape($_) } | Select-Object -First 1
    if ($candidate) { New-Event $candidate $null $(if($record.ProviderName -match 'Windows Error Reporting'){'windows_error_reporting'}else{'windows_error_reporting'}) $record }
}
$root = if ([IO.Path]::IsPathRooted($OutputRoot)) {$OutputRoot} else {Join-Path $repoRoot $OutputRoot}
$path = Join-Path (Join-Path $root $RunId) 'windows-crash-evidence.jsonl'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
[IO.File]::WriteAllText($path, (@($events | ForEach-Object {$_|ConvertTo-Json -Compress -Depth 20}) -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
if ($PassThru) { return @($events) }
Write-Host "Windows crash evidence: $(@($events).Count) correlated candidate(s); no record alone confirms a crash."
