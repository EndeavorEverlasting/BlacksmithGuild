# Stage C disposable charcoal refine cert — clears stale inbox, runs probe + safe action, collects logs.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot

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

$safeActionPath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingSafeAction.json'
if (Test-Path -LiteralPath $safeActionPath) {
    try {
        $safe = Get-Content -LiteralPath $safeActionPath -Raw | ConvertFrom-Json
        if ($safe.executed -eq $true) {
            Write-Host ''
            Write-Host 'Stage C candidate PASS: executed=true. Paste SafeAction + RefineProbe JSON and Phase1 tail for agent verdict.' -ForegroundColor Green
        } elseif ($safe.blockedReason -eq 'hardwood shortage') {
            Write-Host ''
            Write-Host 'Stage C blocked: buy hardwood first.' -ForegroundColor Yellow
            Write-Host 'In game: enter town -> Trade -> buy 1-5 Hardwood -> return to campaign map -> rerun RunStageCCharcoalCert.cmd' -ForegroundColor Yellow
        } elseif ($safe.blockedReason) {
            Write-Host ''
            Write-Host "Stage C blocked: $($safe.blockedReason)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not read SafeAction JSON: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

Write-Host ''
Write-Host 'Evidence files:' -ForegroundColor Cyan
Write-Host "  $(Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingRefineProbe.json')"
Write-Host "  $(Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingSafeAction.json')"
Write-Host "  $(Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log')"
Write-Host ''
