# Stage B smithing crew advisory cert (Tier 1) — advisory only, no mutation.
$ErrorActionPreference = 'Stop'

function Get-StageBPhase1Pass {
    param([string]$Phase1Path)

    if (-not (Test-Path -LiteralPath $Phase1Path)) {
        return $null
    }

    $matches = Select-String -LiteralPath $Phase1Path -Pattern 'SMITHING ADVISORY|SMITHING CREW|\[TBG SMITHING\]' -AllMatches
    if (-not $matches) {
        return $null
    }

    return $matches[-1].Line.Trim()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'
$advisoryPath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingAdvisory.json'
$guildPath = Join-Path $bannerlordRoot 'BlacksmithGuild_GuildLoopReport.json'

Write-Host ''
Write-Host '=== Stage B smithing advisory cert (Tier 1) ===' -ForegroundColor Cyan
Write-Host "Repo:   $repoRoot"
Write-Host "Game:   $bannerlordRoot"
Write-Host ''
Write-Host 'Expect Bannerlord on campaign map. Ctrl+Alt+M first optional (material context).' -ForegroundColor DarkGray
Write-Host ''

Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null

Write-Host '[1/3] RunSmithingAdvisoryNow' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'RunSmithingAdvisoryNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 90

Write-Host ''
Write-Host '[2/3] RunGuildLoopNow (optional combined report)' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'RunGuildLoopNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 90

Write-Host ''
Write-Host '[3/3] CollectCertLogs' -ForegroundColor Yellow
& (Join-Path $repoRoot 'scripts\collect-cert-logs.ps1')

$verdict = 'INDETERMINATE'
$verdictDetail = 'No SmithingAdvisory.json and no Phase1 SMITHING lines.'
$advisory = $null
$phase1Line = Get-StageBPhase1Pass -Phase1Path $phase1Path

if (Test-Path -LiteralPath $advisoryPath) {
    try {
        $advisory = Get-Content -LiteralPath $advisoryPath -Raw | ConvertFrom-Json
        $crewCount = @($advisory.crew).Count
        $recCount = @($advisory.recommendations).Count
        if ($advisory.status -eq 'ok' -and ($crewCount -gt 0 -or $recCount -gt 0)) {
            $verdict = 'PASS'
            $verdictDetail = "Advisory JSON: status=ok crew=$crewCount recommendations=$recCount"
        } elseif ($phase1Line) {
            $verdict = 'PASS'
            $verdictDetail = 'Phase1 SMITHING advisory present; JSON incomplete.'
        } else {
            $verdict = 'FAIL'
            $verdictDetail = "Advisory JSON status=$($advisory.status) crew=$crewCount recommendations=$recCount"
        }
    } catch {
        if ($phase1Line) {
            $verdict = 'PASS'
            $verdictDetail = 'Phase1 SMITHING present; JSON unreadable.'
        }
    }
} elseif ($phase1Line) {
    $verdict = 'PASS'
    $verdictDetail = 'Phase1 SMITHING present; JSON missing.'
}

Write-Host ''
Write-Host '=== Stage B cert verdict ===' -ForegroundColor Cyan
Write-Host "Verdict: $verdict"
Write-Host "Detail:  $verdictDetail"
if ($advisory) {
    Write-Host ("Advisory: status={0} crew={1} recommendations={2} charcoal={3} hardwood={4}" -f `
        $advisory.status, `
        @($advisory.crew).Count, `
        @($advisory.recommendations).Count, `
        $advisory.reserveHealth.charcoalHave, `
        $advisory.reserveHealth.hardwoodHave)
}
if ($phase1Line) {
    Write-Host "Phase1: $phase1Line"
}
if (Test-Path -LiteralPath $guildPath) {
    Write-Host "GuildLoopReport: $guildPath"
}

Write-Host ''
Write-Host 'Evidence files:' -ForegroundColor Cyan
Write-Host "  $advisoryPath"
Write-Host "  $guildPath"
Write-Host "  $phase1Path"
Write-Host ''

if ($verdict -eq 'FAIL') { exit 1 }
if ($verdict -eq 'INDETERMINATE') { exit 2 }
exit 0
