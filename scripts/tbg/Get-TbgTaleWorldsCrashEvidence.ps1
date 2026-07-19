[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunId,
    [Parameter(Mandatory = $true)][string]$CorrelationId,
    [string[]]$SearchRoots = @($env:LOCALAPPDATA, $env:APPDATA),
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
$base = if ([IO.Path]::IsPathRooted($OutputRoot)) {$OutputRoot} else {Join-Path $repoRoot $OutputRoot}
$path = Join-Path (Join-Path $base $RunId) 'taleworlds-crash-evidence.jsonl'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
[IO.File]::WriteAllText($path, (@($events.ToArray() | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 }) -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
if ($PassThru) { return @($events.ToArray()) }
Write-Host "TaleWorlds crash discovery: $($events.Count) metadata record(s); no-data is valid and dumps are excluded."
