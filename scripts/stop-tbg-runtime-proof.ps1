# Safe stop for TBG runtime with correlated cancellation event.
# Uses the existing ForgeStop path and writes a correlated stop event.

param(
    [switch]$ForceKill,
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$latestResultPath = Join-Path $RepoRoot 'artifacts\latest\visible-trade-proof.result.json'
$runId = 'stop-' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')

function Read-SafeJson {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

$result = Read-SafeJson -Path $latestResultPath
$correlationId = if ($result) { [string]$result.runId } else { 'uncorrelated' }

Write-Host ''
Write-Host 'TBG Runtime Stop' -ForegroundColor Cyan
Write-Host "Correlation ID: $correlationId"
Write-Host "Force kill: $ForceKill"
Write-Host ''

$stopEvent = [ordered]@{
    schema = 'TbgRuntimeStopEvent.v1'
    runId = $runId
    correlationId = $correlationId
    timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    action = 'stop'
    forceKill = [bool]$ForceKill
    sentence = "The operator requested a TBG runtime stop with correlation ID $correlationId."
}
$stopEvent | ConvertTo-Json -Depth 4 | Out-File -FilePath (Join-Path ([System.IO.Path]::GetTempPath()) "tbg-stop-event-$runId.json") -Encoding UTF8

if ($ForceKill) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'forge-stop.ps1') -ForceKill -RepoRoot $RepoRoot
} else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'forge-stop.ps1') -RepoRoot $RepoRoot
}

$exit = $LASTEXITCODE
Write-Host ''
Write-Host "Stop completed with exit code $exit."
exit $exit
