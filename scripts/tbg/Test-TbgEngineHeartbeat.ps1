<#
.SYNOPSIS
Detects engine health by monitoring Phase1.log freshness.
A Phase1.log that stopped writing without an engine stop token = crash.
#>
param(
    [string]$BannerlordRoot,
    [int]$StaleSeconds = 30,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-BannerlordRootFromRepo {
    param([string]$RepoRoot)
    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }
    throw 'Bannerlord install not found.'
}

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $BannerlordRoot) {
    $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
}

$logPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'

$checks = @()
$passed = 0
$failed = 0

# Check 1: log exists
$logExists = Test-Path -LiteralPath $logPath -PathType Leaf
$checks += @{ name = 'Phase1.log exists'; passed = $logExists }
if ($logExists) { $passed++ } else { $failed++ }

if (-not $logExists) {
    $result = [pscustomobject]@{ verdict = 'FAIL'; checks = $checks; passed = $passed; failed = $failed; detail = 'Phase1.log not found' }
    if ($PassThru) { Write-Output $result }
    exit 1
}

$logFile = Get-Item -LiteralPath $logPath
$ageSeconds = [Math]::Round(([DateTime]::Now - $logFile.LastWriteTime).TotalSeconds, 1)
$isStale = $ageSeconds -gt $StaleSeconds
$checks += @{ name = "Phase1.log fresh (age=$ageSeconds`s, threshold=${StaleSeconds}s)"; passed = (-not $isStale) }
if (-not $isStale) { $passed++ } else { $failed++ }

# Check 3: search for stop token
$content = Get-Content -LiteralPath $logPath -Tail 50 -Encoding UTF8
$hasStopToken = $content | Where-Object { $_ -match '\[TBG ENGINE STOP\]|\[TBG ENGINE DONE\]|engine_stop|clean_shutdown' }
$checks += @{ name = 'Engine stop token present'; passed = ($null -ne $hasStopToken -and $hasStopToken.Count -gt 0) }
if ($checks[-1].passed) { $passed++ } else { $failed++ }

# Check 4: search for error log
$hasError = $content | Where-Object { $_ -match '\[TBG ENGINE ERROR\]|engine_failed|engine_crash|CRASH' }
$checks += @{ name = 'Engine error log absent (no crash detected)'; passed = ($null -eq $hasError -or $hasError.Count -eq 0) }
if ($checks[-1].passed) { $passed++ } else { $failed++ }

# Check 5: game process running
$gameRunning = Get-Process -Name 'Bannerlord*' -ErrorAction SilentlyContinue
$launcherRunning = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue
$checks += @{ name = 'Bannerlord.exe running'; passed = ($null -ne $gameRunning) }
if ($checks[-1].passed) { $passed++ } else { $failed++ }

$verdict = if ($failed -eq 0) { 'PASS' } elseif ($failed -eq 1) { 'ATTENTION' } else { 'CRASH' }

$result = [pscustomobject]@{
    schema = 'tbg.engine-heartbeat.v1'
    timestamp = [DateTime]::UtcNow.ToString('o')
    verdict = $verdict
    passed = $passed
    failed = $failed
    total = $checks.Count
    logAge = "${ageSeconds}s"
    logPath = $logPath
    detail = if ($isStale) { "Phase1.log is stale (${ageSeconds}s old). Game likely crashed." } else { "Phase1.log fresh." }
    checks = $checks
}

Write-Host "=== Engine Heartbeat ===" -ForegroundColor Cyan
Write-Host "Verdict: $verdict" -ForegroundColor $(switch ($verdict) { 'PASS' { 'Green' } 'ATTENTION' { 'Yellow' } 'CRASH' { 'Red' } })
Write-Host "Log age: $($result.logAge)"
Write-Host "Passed: $passed/$($checks.Count)"
foreach ($c in $checks) {
    $mark = if ($c.passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($c.passed) { 'Green' } else { 'Red' }
    Write-Host "  $mark $($c.name)" -ForegroundColor $color
}
Write-Host "Detail: $($result.detail)"

$outputPath = Join-Path $RepoRoot 'artifacts\latest\engine-heartbeat.result.json'
$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Output: $outputPath"

if ($PassThru) { Write-Output $result }
exit $(if ($verdict -eq 'PASS') { 0 } else { 1 })
