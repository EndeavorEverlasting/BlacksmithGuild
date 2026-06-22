# Autonomous F7 hook-mask bisect — Agent A evidence runner.
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$masks = @('0x0F', '0x01', '0x00', '0x1DF', '0x1BF')
$summaryPath = Join-Path $repoRoot 'docs\evidence\live-cert\f7-bisect-summary.json'
$results = @()

foreach ($mask in $masks) {
    Write-Host ''
    Write-Host "========== HOOK MASK $mask ==========" -ForegroundColor Cyan
    taskkill /IM Bannerlord.exe /F 2>$null | Out-Null
    taskkill /IM TaleWorlds.MountAndBlade.Launcher.exe /F 2>$null
    Start-Sleep -Seconds 4

    $env:TBG_MAP_READY_HOOK_MASK = $mask
    $started = Get-Date
    & (Join-Path $repoRoot 'Run-F7GateContinue.cmd')
    $exitCode = $LASTEXITCODE
    $elapsed = ((Get-Date) - $started).TotalSeconds

    $latest = Get-ChildItem (Join-Path $repoRoot 'docs\evidence\live-cert') -Directory |
        Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1

    $manifestPath = $null
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
        sessionId = if ($manifest) { $manifest.sessionId } else { $latest.Name }
        passFail = if ($manifest) { $manifest.passFail } else { 'UNKNOWN' }
        stableSeconds = if ($manifest) { $manifest.stableSeconds } else { 0 }
        campaignReady = if ($manifest) { $manifest.campaignReady } else { $false }
        canPollFileInbox = if ($manifest) { $manifest.canPollFileInbox } else { $false }
        phase1TbgReady = if ($manifest) { $manifest.phase1TbgReady } else { $false }
        phase1QuickStartMapReady = if ($manifest) { $manifest.phase1QuickStartMapReady } else { $false }
        phase1LastSignal = if ($manifest) { $manifest.phase1LastSignal } else { $null }
        notes = if ($manifest) { $manifest.notes } else { $null }
        manifestPath = $manifestPath
    }

    Remove-Item Env:TBG_MAP_READY_HOOK_MASK -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
}

$out = [ordered]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    branch = (git rev-parse --abbrev-ref HEAD 2>$null)
    commit = (git rev-parse --short HEAD 2>$null)
    masks = $results
}
$out | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host ''
Write-Host "Bisect complete. Summary: $summaryPath" -ForegroundColor Green
$results | ForEach-Object { Write-Host ("  {0}: exit={1} {2}" -f $_.mask, $_.exitCode, $_.passFail) }
