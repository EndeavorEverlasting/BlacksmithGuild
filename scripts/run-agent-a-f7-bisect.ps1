# Agent A: sequential F7 hook mask bisect (0x01, 0x03, 0x07, 0x0F).
param(
    [string[]]$Masks = @('0x01', '0x03', '0x07', '0x0F'),
    [string]$LogPath = (Join-Path $PSScriptRoot '..\docs\evidence\live-cert\agent-a-bisect-run.log')
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Write-BisectLog {
    param([string]$Line)
    $ts = Get-Date -Format 'o'
    $full = "[$ts] $Line"
    Write-Host $full
    Add-Content -LiteralPath $LogPath -Value $full -Encoding UTF8
}

Write-BisectLog "Agent A bisect start HEAD=$(git rev-parse --short HEAD)"

foreach ($mask in $Masks) {
    Write-BisectLog "=== HookMask $mask ==="
    & (Join-Path $repoRoot 'Run-F7GateContinue.cmd') -HookMask $mask
    $ec = $LASTEXITCODE
    Write-BisectLog "=== Exit $ec mask $mask ==="
    if ($ec -eq 0) {
        Write-BisectLog 'PASS - stopping bisect early'
        exit 0
    }
}

Write-BisectLog 'All masks failed - bisect complete'
exit 1
