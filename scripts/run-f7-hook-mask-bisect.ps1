# Autonomous F7 hook-mask bisect — runs masks sequentially, writes summary JSON.
param(
    [string[]]$Masks = @('0x0F', '0x01', '0x00', '0x1DF', '0x1BF')
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$summaryPath = Join-Path $repoRoot 'docs\evidence\live-cert\f7-bisect-summary.json'
$results = @()

foreach ($mask in $Masks) {
    Write-Host ''
    Write-Host "========== HOOK MASK $mask ==========" -ForegroundColor Cyan
    Get-Process -Name Bannerlord,TaleWorlds.MountAndBlade.Launcher -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4

    $started = Get-Date
    & (Join-Path $repoRoot 'Run-F7GateContinue.cmd') -HookMask $mask -TimeoutSeconds 300 -StableSeconds 60
    $exitCode = $LASTEXITCODE
    $elapsed = ((Get-Date) - $started).TotalSeconds

    $latest = Get-ChildItem (Join-Path $repoRoot 'docs\evidence\live-cert') -Directory |
        Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1

    $manifest = $null
    if ($latest) {
        $manifestPath = Join-Path $latest.FullName 'checkpoint-01-f7-gate\manifest.json'
        if (Test-Path -LiteralPath $manifestPath) {
            try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { }
        }
    }

    $results += [ordered]@{
        mask = $mask
        exitCode = $exitCode
        elapsedSec = [int]$elapsed
        sessionId = if ($manifest) { $manifest.sessionId } else { $null }
        passFail = if ($manifest) { $manifest.passFail } else { 'UNKNOWN' }
        launchState = if ($manifest) { $manifest.launchState } else { $null }
        mapReadySeen = if ($manifest.goldenPathCheck) { $manifest.goldenPathCheck.mapReadySeen } else { $false }
        tbgReadySeen = if ($manifest.goldenPathCheck) { $manifest.goldenPathCheck.tbgReadySeen } else { $false }
        firstMissingStep = if ($manifest.goldenPathCheck) { $manifest.goldenPathCheck.firstMissingStep } else { $null }
    }

    if ($exitCode -eq 0) {
        Write-Host "PASS at mask $mask — stopping bisect." -ForegroundColor Green
        break
    }
}

[ordered]@{ generatedUtc = (Get-Date).ToUniversalTime().ToString('o'); results = $results } |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ''
Write-Host "Bisect summary: $summaryPath" -ForegroundColor Cyan
