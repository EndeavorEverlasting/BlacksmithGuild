# Sprint 008C-Fix — visible assistive personal cert for TBGPersonalAserai001.
param(
    [ValidateSet('UserVisible', 'Replay')]
    [string]$Mode = 'UserVisible',
    [int]$ReadyTimeoutSec = 900,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')

function Wait-TbgReadyExtended {
    param(
        [string]$BannerlordRoot,
        [int]$TimeoutSec
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Phase1TbgReady -BannerlordRoot $BannerlordRoot) {
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

function Write-VisibleReplayResult {
    param(
        [string]$BannerlordRoot,
        [string]$Verdict,
        [string[]]$Failures,
        [string[]]$Warnings
    )

    $payload = [ordered]@{
        generatedUtc      = (Get-Date).ToUniversalTime().ToString('o')
        completed         = ($Verdict -eq 'PASS')
        visibleMode       = $true
        decisionPauseMs   = 750
        certMode          = $Mode
        blockedReason     = if ($Failures.Count -gt 0) { ($Failures -join '; ') } else { '' }
        legitimacyVerdict = if ($Verdict -eq 'PASS') { 'VanillaLegit' } else { 'Failed' }
        warnings          = @($Warnings)
        finalVerdict      = if ($Verdict -eq 'PASS') { 'TBGPersonalAserai001 cert ready' } else { 'blocked' }
    }

    $path = Join-Path $BannerlordRoot 'BlacksmithGuild_CharacterVisibleReplay.json'
    ($payload | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot

Write-Host ''
Write-Host '=== 008C Visible Assistive Personal Cert ===' -ForegroundColor Cyan
Write-Host "Mode: $Mode"
Write-Host "Repo: $repoRoot"
Write-Host "Game: $bannerlordRoot"
Write-Host ''
Write-Host 'Watch Aserai culture + each upbringing choice (~750ms pause + lower-left notices).' -ForegroundColor DarkGray
Write-Host 'On map: press F7, then save as TBGPersonalAserai001 if verdict PASS.' -ForegroundColor DarkGray
Write-Host ''

if ($WhatIf) {
    Write-Host "[WhatIf] ForgeStop -> $Mode config -> forge.ps1 -Launch play -> wait TBG READY -> assert -> export" -ForegroundColor Yellow
    exit 0
}

Write-Host '[1/5] ForgeStop (kill stale processes)' -ForegroundColor Yellow
& (Join-Path $repoRoot 'scripts\forge-stop.ps1')

Write-Host "[2/5] Write $Mode launch config" -ForegroundColor Yellow
if ($Mode -eq 'Replay') {
    & (Join-Path $repoRoot 'scripts\write-character-build-launch-config.ps1') `
        -Mode Replay `
        -BannerlordRoot $bannerlordRoot | Out-Null
} else {
    & (Join-Path $repoRoot 'scripts\write-character-build-launch-config.ps1') `
        -Mode UserVisible `
        -BannerlordRoot $bannerlordRoot | Out-Null
}

Write-Host '[3/5] Launch new game (UserVisible — personal cert path)' -ForegroundColor Yellow
& (Join-Path $repoRoot 'forge.ps1') -Launch -LaunchIntent play -SkipSaveBackup

Write-Host "[4/5] Wait for TBG READY (timeout ${ReadyTimeoutSec}s)" -ForegroundColor Yellow
if (-not (Wait-TbgReadyExtended -BannerlordRoot $bannerlordRoot -TimeoutSec $ReadyTimeoutSec)) {
    Write-Host 'BLOCKED — TBG READY not observed within timeout.' -ForegroundColor Red
    $replayPath = Write-VisibleReplayResult -BannerlordRoot $bannerlordRoot -Verdict 'FAIL' `
        -Failures @('TBG READY timeout') -Warnings @()
    & (Join-Path $repoRoot 'scripts\export-tbg-evidence.ps1')
    Write-Host "Replay JSON: $replayPath" -ForegroundColor Yellow
    exit 2
}

Write-Host ''
Write-Host 'Map ready — press F7 in-game to confirm VanillaLegit + Assistive + postMapInjection off.' -ForegroundColor Cyan
Write-Host 'Waiting 15s for manual F7 check (optional)…' -ForegroundColor DarkGray
Start-Sleep -Seconds 15

Write-Host '[5/5] Assert legitimacy + export evidence' -ForegroundColor Yellow
$assertScript = Join-Path $repoRoot 'scripts\assert-character-legitimacy.ps1'
$assertJson = & $assertScript -BannerlordRoot $bannerlordRoot -PersonalCert | ConvertFrom-Json

& (Join-Path $repoRoot 'scripts\export-tbg-evidence.ps1')

$replayPath = Write-VisibleReplayResult `
    -BannerlordRoot $bannerlordRoot `
    -Verdict $assertJson.verdict `
    -Failures @($assertJson.failures) `
    -Warnings @($assertJson.warnings)

Write-Host ''
Write-Host "Replay JSON: $replayPath" -ForegroundColor Cyan

if ($assertJson.verdict -ne 'PASS') {
    Write-Host 'VISIBLE CERT FAIL — review failures above before saving TBGPersonalAserai001.' -ForegroundColor Red
    exit 1
}

Write-Host 'VISIBLE CERT PASS — save TBGPersonalAserai001 when satisfied with on-screen choices.' -ForegroundColor Green
exit 0
