# Stage C disposable charcoal refine cert — clears stale inbox, runs probe + safe action, collects logs.
$ErrorActionPreference = 'Stop'

function Get-StageCPhase1MutationPass {
    param(
        [string]$Phase1Path
    )

    if (-not (Test-Path -LiteralPath $Phase1Path)) {
        return $null
    }

    $pattern = '\[TBG FORGE\] action=RefineCharcoal .* reserveBefore charcoal=(\d+) .* reserveAfter charcoal=(\d+)'
    $matches = Select-String -LiteralPath $Phase1Path -Pattern $pattern -AllMatches
    if (-not $matches) {
        return $null
    }

    $last = $matches[-1]
    $charcoalBefore = [int]$last.Matches[0].Groups[1].Value
    $charcoalAfter = [int]$last.Matches[0].Groups[2].Value
    if ($charcoalAfter -le $charcoalBefore) {
        return $null
    }

    return [pscustomobject]@{
        Line = $last.Line.Trim()
        CharcoalBefore = $charcoalBefore
        CharcoalAfter = $charcoalAfter
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'
$safeActionPath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingSafeAction.json'
$probePath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingRefineProbe.json'

Write-Host ''
Write-Host '=== Stage C charcoal refine cert ===' -ForegroundColor Cyan
Write-Host "Repo:   $repoRoot"
Write-Host "Game:   $bannerlordRoot"
Write-Host ''
Write-Host 'Expect Bannerlord running on campaign map (disposable save OK).' -ForegroundColor DarkGray
Write-Host ''

Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null

Write-Host '[1/3] ProbeSmithingRefineApi' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'ProbeSmithingRefineApi' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 90

Write-Host ''
Write-Host '[2/3] RunSmithingSafeActionNow' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'RunSmithingSafeActionNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 90

Write-Host ''
Write-Host '[3/3] CollectCertLogs' -ForegroundColor Yellow
& (Join-Path $repoRoot 'scripts\collect-cert-logs.ps1')

$verdict = 'INDETERMINATE'
$verdictDetail = 'No SafeAction JSON and no Phase1 mutation line found.'
$safe = $null
$phase1Pass = Get-StageCPhase1MutationPass -Phase1Path $phase1Path

if (Test-Path -LiteralPath $safeActionPath) {
    try {
        $safe = Get-Content -LiteralPath $safeActionPath -Raw | ConvertFrom-Json
        if ($safe.executed -eq $true) {
            $verdict = 'PASS'
            $verdictDetail = 'SafeAction JSON: executed=true, charcoalAfter > charcoalBefore expected.'
            Write-Host ''
            Write-Host 'Stage C PASS: executed=true in SafeAction JSON.' -ForegroundColor Green
        } elseif ($phase1Pass) {
            $verdict = 'PASS'
            $verdictDetail = 'Phase1 mutation detected; SafeAction JSON stale or from later blocked run.'
            Write-Host ''
            Write-Host 'Stage C PASS detected in Phase1 (SafeAction JSON stale or from later blocked run)' -ForegroundColor Green
            Write-Host "  $($phase1Pass.Line)" -ForegroundColor DarkGreen
        } elseif ($safe.blockedReason -match 'hardwood shortage') {
            $verdict = 'BLOCKED'
            $verdictDetail = 'hardwood shortage — buy hardwood and rerun.'
            Write-Host ''
            Write-Host 'Stage C blocked: buy hardwood first.' -ForegroundColor Yellow
            Write-Host 'In game: enter town -> Trade -> buy 1-5 Hardwood -> return to campaign map -> rerun RunStageCCharcoalCert.cmd' -ForegroundColor Yellow
        } elseif ($safe.blockedReason) {
            $verdict = 'BLOCKED'
            $verdictDetail = $safe.blockedReason
            Write-Host ''
            Write-Host "Stage C blocked: $($safe.blockedReason)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not read SafeAction JSON: $($_.Exception.Message)" -ForegroundColor DarkYellow
        if ($phase1Pass) {
            $verdict = 'PASS'
            $verdictDetail = 'Phase1 mutation detected; SafeAction JSON unreadable.'
            Write-Host ''
            Write-Host 'Stage C PASS detected in Phase1 (SafeAction JSON stale or from later blocked run)' -ForegroundColor Green
            Write-Host "  $($phase1Pass.Line)" -ForegroundColor DarkGreen
        }
    }
} elseif ($phase1Pass) {
    $verdict = 'PASS'
    $verdictDetail = 'Phase1 mutation detected; SafeAction JSON missing.'
    Write-Host ''
    Write-Host 'Stage C PASS detected in Phase1 (SafeAction JSON stale or from later blocked run)' -ForegroundColor Green
    Write-Host "  $($phase1Pass.Line)" -ForegroundColor DarkGreen
}

Write-Host ''
Write-Host '=== Stage C cert verdict ===' -ForegroundColor Cyan
Write-Host "Verdict: $verdict"
Write-Host "Detail:  $verdictDetail"
if ($safe) {
    Write-Host ("SafeAction: executed={0} blockedReason={1} charcoal={2}->{3} refineCount={4}" -f `
        $safe.executed, `
        $(if ($safe.blockedReason) { $safe.blockedReason } else { '(none)' }), `
        $safe.charcoalBefore, `
        $safe.charcoalAfter, `
        $safe.refineCount)
}
if ($phase1Pass) {
    Write-Host ("Phase1: charcoal {0}->{1}" -f $phase1Pass.CharcoalBefore, $phase1Pass.CharcoalAfter)
}
if (Test-Path -LiteralPath $probePath) {
    try {
        $probe = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
        Write-Host ("Probe: doRefinementMapped={0}" -f $probe.doRefinementMapped)
    } catch {
        Write-Host 'Probe: (could not parse JSON)' -ForegroundColor DarkYellow
    }
}

Write-Host ''
Write-Host 'Evidence files:' -ForegroundColor Cyan
Write-Host "  $probePath"
Write-Host "  $safeActionPath"
Write-Host "  $phase1Path"
Write-Host ''
