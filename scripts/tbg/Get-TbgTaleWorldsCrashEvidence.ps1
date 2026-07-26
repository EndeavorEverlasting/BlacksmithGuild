[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$CorrelationId,
    [string[]]$SearchRoots = @($env:LOCALAPPDATA, $env:APPDATA),
    [datetime]$SinceUtc = ([DateTime]::UtcNow.AddMinutes(-10)),
    [int]$ExpectedPid = 0,
    [string]$SteamGameProcessLogPath,
    [string]$OutputRoot = '.local/tbg-runtime-observer',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Get-SafeExcerpt([string]$Path) {
    try { $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop } catch { return $null }
    $text = $text -replace '(?i)([A-Z]:\\Users\\)[^ \r\n]+','$1<redacted>'
    $text = $text -replace '(?i)(token|password)\s*[:=]\s*\S+','$1=<redacted>'
    if ($text.Length -gt 800) { $text = $text.Substring(0,800) }
    return $text
}
function Get-TextSha256([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return (([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes) | ForEach-Object ToString x2) -join ''
}
function Get-SteamExitEvidence([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @(Get-Content -LiteralPath $Path -Tail 1000 -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($line -notmatch '^\[(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\].*no longer tracking PID (?<pid>\d+), exit code (?<code>-?\d+)\s*$') {
            continue
        }

        $pidValue = [int]$Matches.pid
        if ($ExpectedPid -gt 0 -and $pidValue -ne $ExpectedPid) {
            continue
        }

        $localTimestamp = [DateTime]::ParseExact(
            $Matches.time,
            'yyyy-MM-dd HH:mm:ss',
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None)
        $sourceUtc = [TimeZoneInfo]::ConvertTimeToUtc(
            [DateTime]::SpecifyKind($localTimestamp, [DateTimeKind]::Unspecified),
            [TimeZoneInfo]::Local)
        if ($sourceUtc -lt $SinceUtc.ToUniversalTime()) {
            continue
        }

        $signedExitCode = [int]$Matches.code
        $unsignedExitCode = [BitConverter]::ToUInt32([BitConverter]::GetBytes($signedExitCode), 0)
        $hexExitCode = '0x{0:X8}' -f $unsignedExitCode
        $win32Code = [int]($unsignedExitCode -band 0xffff)
        $excerpt = (($line -replace '(?i)([A-Z]:\\Users\\)[^ \r\n"]+','$1<redacted>') -replace '(?i)(token|password)\s*[:=]\s*\S+','$1=<redacted>')
        $excerptHash = Get-TextSha256 $excerpt
        $results.Add([ordered]@{
            schema='TbgRuntimeObserverEvent.v1'; version=1; eventId="steam-$([Guid]::NewGuid().ToString('N').Substring(0,20))"; runId=$RunId; commandId=$null; correlationId=$CorrelationId; spanId=$null; parentSpanId=$null
            observerId='taleworlds-crash-evidence'; sourceKind='steam_gameprocess_exit'; eventType='external_terminal_evidence'; severity='error'; observedUtc=[DateTime]::UtcNow.ToString('o'); sourceTimestamp=$sourceUtc.ToString('o')
            processIdentity=[ordered]@{canonicalName='TaleWorlds.MountAndBlade';pid=$pidValue}; windowIdentity=$null; operation='steam_gameprocess_exit_collection'; expectedSignalId=$null
            payload=[ordered]@{ exitCode=$signedExitCode; exitCodeHex=$hexExitCode; win32Code=$win32Code; stackOverflowSignature=($win32Code -eq 1001); excerpt=$excerpt; excerptSha256=$excerptHash; correlation='pid_and_timestamp' }
            evidenceRefs=@("steam-gameprocess-exit:$excerptHash"); freshness='fresh'; proofLevel='harness'; redactionState='sanitized'
        }) | Out-Null
    }

    return @($results.ToArray())
}
$events = New-Object Collections.Generic.List[object]
foreach ($root in @($SearchRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Container) })) {
    # Names are only discovery hints; tracked output contains no absolute source path.
    $candidates = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)(taleworlds|bannerlord).*(crash|report)|^(crash|report).*\.txt$' } |
        Select-Object -First 20)
    foreach ($file in $candidates) {
        if ($file.Extension -match '(?i)\.dmp|\.mdmp|\.hdmp') { continue }
        $excerpt = Get-SafeExcerpt $file.FullName
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $events.Add([ordered]@{
            schema='TbgRuntimeObserverEvent.v1'; version=1; eventId="tw-$([Guid]::NewGuid().ToString('N').Substring(0,20))"; runId=$RunId; commandId=$null; correlationId=$CorrelationId; spanId=$null; parentSpanId=$null
            observerId='taleworlds-crash-evidence'; sourceKind='taleworlds_crash'; eventType='external_terminal_evidence'; severity='warning'; observedUtc=[DateTime]::UtcNow.ToString('o'); sourceTimestamp=$file.LastWriteTimeUtc.ToString('o')
            processIdentity=[ordered]@{canonicalName='unknown';pid=$null}; windowIdentity=$null; operation='taleworlds_crash_discovery'; expectedSignalId=$null
            payload=[ordered]@{ fileName=$file.Name; length=$file.Length; sha256=$hash; excerpt=$excerpt; sourcePath='redacted_local_path'; dumpExcluded=$true }
            evidenceRefs=@("taleworlds-report:$hash"); freshness='fresh'; proofLevel='harness'; redactionState='sanitized'
        }) | Out-Null
    }
}
foreach ($event in @(Get-SteamExitEvidence $SteamGameProcessLogPath)) {
    $events.Add($event) | Out-Null
}
$base = if ([IO.Path]::IsPathRooted($OutputRoot)) {$OutputRoot} else {Join-Path $repoRoot $OutputRoot}
$path = Join-Path (Join-Path $base $RunId) 'taleworlds-crash-evidence.jsonl'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
[IO.File]::WriteAllText($path, (@($events.ToArray() | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 }) -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
if ($PassThru) { return @($events.ToArray()) }
Write-Host "TaleWorlds crash discovery: $($events.Count) metadata record(s); no-data is valid and dumps are excluded."
