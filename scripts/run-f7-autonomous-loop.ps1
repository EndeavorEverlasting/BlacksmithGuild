# Autonomous F7 develop-test-analyze loop — build, gate, analyze manifest, rotate hook masks.
param(
    [int]$MaxRounds = 6,
    [string[]]$HookMasks = @('0x0F', '0x01', '0x00', '0x1DF', '0x1BF'),
    [int]$StableSeconds = 60,
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$summaryPath = Join-Path $repoRoot 'docs\evidence\live-cert\f7-autonomous-loop-summary.json'
$results = @()
$maskIndex = 0

function Stop-GameProcesses {
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 3
}

for ($round = 1; $round -le $MaxRounds; $round++) {
    $mask = $HookMasks[$maskIndex % $HookMasks.Count]
    $maskIndex++

    Write-Host ''
    Write-Host "========== F7 LOOP round $round/$MaxRounds mask=$mask ==========" -ForegroundColor Cyan

    Stop-GameProcesses

    Write-Host 'Building Release...' -ForegroundColor Yellow
    dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Build FAILED — stopping loop.' -ForegroundColor Red
        break
    }

    $started = Get-Date
    & (Join-Path $repoRoot 'scripts\run-f7-gate-continue.ps1') -HookMask $mask -StableSeconds $StableSeconds -TimeoutSeconds $TimeoutSeconds
    $exitCode = $LASTEXITCODE
    $elapsed = [int]((Get-Date) - $started).TotalSeconds

    $latest = Get-ChildItem (Join-Path $repoRoot 'docs\evidence\live-cert') -Directory |
        Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1

    $manifest = $null
    $manifestPath = $null
    if ($latest) {
        $manifestPath = Join-Path $latest.FullName 'checkpoint-01-f7-gate\manifest.json'
        if (Test-Path -LiteralPath $manifestPath) {
            try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { }
        }
    }

    $row = [ordered]@{
        round = $round
        mask = $mask
        exitCode = $exitCode
        elapsedSec = $elapsed
        sessionId = if ($manifest) { $manifest.sessionId } else { $latest.Name }
        passFail = if ($manifest) { $manifest.passFail } else { 'UNKNOWN' }
        stableSeconds = if ($manifest) { $manifest.stableSeconds } else { 0 }
        launchState = if ($manifest) { $manifest.launchState } else { $null }
        phase1QuickStartMapReady = if ($manifest) { $manifest.phase1QuickStartMapReady } else { $false }
        goldenFirstMissing = if ($manifest.goldenPathCheck) { $manifest.goldenPathCheck.firstMissingStep } else { $null }
        notes = if ($manifest) { $manifest.notes } else { $null }
        manifestPath = $manifestPath
    }
    $results += $row

    Write-Host ("Round {0}: exit={1} passFail={2} mapReady={3} missing={4}" -f $round, $exitCode, $row.passFail, $row.phase1QuickStartMapReady, $row.goldenFirstMissing) -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Yellow' })

    if ($exitCode -eq 0) {
        Write-Host 'F7 PASS — loop complete.' -ForegroundColor Green
        break
    }

    if ($manifest -and $manifest.launchAutomationError -match 'Cursor foreground') {
        Write-Host 'Launch tooling blocked by Cursor focus — waiting 30s before retry...' -ForegroundColor DarkYellow
        Start-Sleep -Seconds 30
    } else {
        Start-Sleep -Seconds 8
    }
}

$out = [ordered]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    branch = (git rev-parse --abbrev-ref HEAD 2>$null)
    commit = (git rev-parse --short HEAD 2>$null)
    maxRounds = $MaxRounds
    rounds = $results
}
$out | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host ''
Write-Host "Loop summary: $summaryPath" -ForegroundColor Cyan
if ($results | Where-Object { $_.exitCode -eq 0 }) { exit 0 }
exit 2
