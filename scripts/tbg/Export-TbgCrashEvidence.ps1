<#
.SYNOPSIS
Extracts crash evidence from Phase1.log and writes to a tracked evidence file.
Commits the machine-readable crash edge so the remote repo preserves diagnostics.
#>
param(
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',
    [string]$OutputDir = '.tbg/evidence',
    [int]$ContextLines = 10,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$phase1Path = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$outputFile = Join-Path $RepoRoot "$OutputDir\crash-evidence.json"

if (-not (Test-Path -LiteralPath $phase1Path -PathType Leaf)) {
    Write-Warning "Phase1.log not found: $phase1Path"
    exit 1
}

$lines = Get-Content -LiteralPath $phase1Path -Tail 2000 -Encoding UTF8

# Find last engine heartbeat start without matching done/error
$starts = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\[TBG ENGINE START\]') { $starts += @{ Index = $i; Line = $lines[$i] } }
}

if ($starts.Count -eq 0) {
    Write-Host "No engine heartbeat starts found in last 2000 lines."
    $evidence = [ordered]@{
        extractedUtc = [DateTime]::UtcNow.ToString('o')
        crashDetected = $false
        note = "No engine heartbeat starts in recent log. Game may be alive or Phase1.log truncated."
        lastLines = ($lines | Select-Object -Last 5)
    }
    $evidence | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outputFile -Encoding UTF8
    Write-Host "Written: $outputFile"
    if ($PassThru) { Write-Output $evidence }
    exit 0
}

$lastStart = $starts[-1]

# Extract context around crash
$startIdx = [Math]::Max(0, $lastStart.Index - $ContextLines)
$endIdx = [Math]::Min($lines.Count - 1, $lastStart.Index + $ContextLines)
$contextLines = $lines[$startIdx..$endIdx]

# Determine if crash (no DONE/ERROR after START)
$hasDone = ($lines[$lastStart.Index..$lines.Count] | Where-Object { $_ -match '\[TBG ENGINE DONE\]' })
$hasError = ($lines[$lastStart.Index..$lines.Count] | Where-Object { $_ -match '\[TBG ENGINE ERROR\]' })
$crashed = (-not $hasDone) -and (-not $hasError)

$evidence = [ordered]@{
    extractedUtc = [DateTime]::UtcNow.ToString('o')
    phase1Path = $phase1Path
    logLastWrite = (Get-Item -LiteralPath $phase1Path).LastWriteTime.ToString('o')
    crashDetected = $crashed
    lastEngineStart = $lastStart.Line
    context = $contextLines
    verdict = if ($crashed) { 'CRASH' } else { 'ALIVE' }
}

$evidence | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outputFile -Encoding UTF8

Write-Host "Crash evidence extracted: $outputFile" -ForegroundColor $(if ($crashed) { 'Red' } else { 'Green' })
Write-Host "Verdict: $($evidence.verdict)"
Write-Host "Last engine start: $($lastStart.Line)"

if ($PassThru) { Write-Output $evidence }
exit $(if ($crashed) { 1 } else { 0 })
