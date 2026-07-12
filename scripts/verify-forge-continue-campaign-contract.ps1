$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Need {
    param([string]$Path, [string]$Needle)
    if ((Read-Text $Path).IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$Path missing '$Needle'") | Out-Null
    }
}

function Forbid {
    param([string]$Path, [string]$Needle)
    if ((Read-Text $Path).IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $failures.Add("$Path contains forbidden '$Needle'") | Out-Null
    }
}

$cmd = 'ForgeContinue.cmd'
$runner = 'scripts\run-forge-continue-campaign.ps1'
$contractPath = '.tbg\workflows\forge-continue-campaign.contract.json'

Need $cmd 'scripts\run-forge-continue-campaign.ps1'
Need $cmd 'forge-continue-campaign.result.json'
Forbid $cmd 'forge.ps1" -Launch'
Forbid $cmd 'launcher-fast-frontdoor.ps1'

foreach ($needle in @(
    'TbgForgeContinueCampaignEvent.v1',
    'TbgForgeContinueCampaignResult.v1',
    'run-tbg-visible-trade-cycle.ps1',
    'RunForgeHandoffAfterTradeNow',
    'ScanHorseAtlas',
    'AnalyzeHerdLedger',
    'AnalyzeHorseMarket',
    'ProbePackAnimalBuyNow',
    'ResumeCampaignGovernorAutomation',
    'RunCampaignGovernorCycleNow',
    'RunAutonomousGuildLoopNow',
    'BlacksmithGuild_HorseAtlas.json',
    'BlacksmithGuild_HerdLedger.json',
    'BlacksmithGuild_HorseMarketIntel.json',
    'BlacksmithGuild_MapTradePackAnimalProbe.json',
    'BlacksmithGuild_CampaignGovernorDecision.json',
    'BlacksmithGuild_AutonomousGuildLoop.json',
    'fresh_runtime_artifact',
    'real_or_blocked_trade_delta',
    'asynchronous_engine_handoff',
    'A command acknowledgement alone is not downstream engine completion.'
)) { Need $runner $needle }

foreach ($needle in @(
    'git reset --hard',
    'git clean -',
    'git stash',
    'git push --force',
    'gh pr merge',
    'Remove-Item *sav',
    'worktree remove --force',
    'branch -D'
)) { Forbid $runner $needle }

$runnerText = Read-Text $runner
$ordered = @(
    'run-tbg-visible-trade-cycle.ps1',
    'RunForgeHandoffAfterTradeNow',
    'ScanHorseAtlas',
    'AnalyzeHerdLedger',
    'AnalyzeHorseMarket',
    'ProbePackAnimalBuyNow',
    'RunCampaignGovernorCycleNow',
    'RunAutonomousGuildLoopNow'
)
$last = -1
foreach ($needle in $ordered) {
    $index = $runnerText.IndexOf($needle, [StringComparison]::Ordinal)
    if ($index -le $last) { $failures.Add("runner stage order invalid at '$needle'") | Out-Null }
    $last = $index
}

try {
    $contract = Get-Content -LiteralPath (Join-Path $repoRoot $contractPath) -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($contract.id -ne 'forge-continue-campaign') { $failures.Add('contract id mismatch') | Out-Null }
    if ($contract.operatorEntry.command -ne '.\ForgeContinue.cmd') { $failures.Add('ForgeContinue is not the contract operator entry') | Out-Null }
    if (@($contract.orderedStages).Count -lt 8) { $failures.Add('contract must define at least eight ordered stages') | Out-Null }
    if (-not $contract.proofBoundary.commandAckIsCompletion -eq $false) { $failures.Add('contract must reject command ACK as completion') | Out-Null }
    if (-not $contract.proofBoundary.blockedHorseAttemptIsAcquisition -eq $false) { $failures.Add('contract must reject blocked horse attempts as acquisitions') | Out-Null }
} catch {
    $failures.Add("contract parse failed: $($_.Exception.Message)") | Out-Null
}

foreach ($path in @($runner, 'scripts\verify-forge-continue-campaign-contract.ps1')) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot $path), [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { $failures.Add("PowerShell parse failed for $path: $($errors.Message -join '; ')") | Out-Null }
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: Forge Continue campaign contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: ForgeContinue owns the ordered launcher, save, visible-trade, horse, governor, guild-loop, and evidence pipeline.' -ForegroundColor Green
exit 0
