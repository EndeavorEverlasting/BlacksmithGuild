# Offline contract verifier for Regent, Route Council, Horse Atlas, and Herd Ledger.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text -notlike "*$Needle*") {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text -like "*$Needle*") {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath must not contain '$Needle'$suffix") | Out-Null
    }
}

function Assert-GitDoesNotTrack {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $tracked = & git -C $repoRoot ls-files -- $RelativePath 2>$null
    if ($tracked) {
        $failures.Add("runtime evidence is tracked by git: $RelativePath") | Out-Null
    }
}

# Source files must exist.
foreach ($file in @(
    'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs',
    'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs',
    'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs',
    'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs'
)) {
    Read-RepoText -RelativePath $file | Out-Null
}

# Regent authority surface.
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'CampaignRuntimeRegent' 'Regent name must remain explicit'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'BlacksmithGuild_RuntimeRegent.json' 'regent runtime output'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'ShowRuntimeRegentStateCommand' 'regent command const'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'RegentStagnationClass' 'stagnation classification'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'RegentRecoveryAction' 'recovery action vocabulary'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeRegent.cs' 'MutationAllowed = false' 'regent never enables mutation'

# Route Council vote model and veto handling.
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'CampaignRouteVote' 'vote model'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'CampaignRouteCouncilDecision' 'decision model'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'CampaignRouteVoteKind' 'food/trade/horse/safety vote kinds'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'food critical override' 'food must outrank horse/trade'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'IsBlockingVeto' 'safety veto support'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'safety veto' 'safety veto reason must be explicit'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'horse capacity vs trade interaction' 'capacity must affect trade-vs-horse voting'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'horse profit only when bases covered' 'horse profit must wait for safety/food/capacity basics'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'ConveneRouteCouncilCommand' 'convene command const'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'BuildFromDecision' 'council can consume current governor decision'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'readOnly' 'route council is read-only'

# Horse Atlas read-only intelligence.
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'ScanHorseAtlasCommand' 'atlas scan command const'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'LayOfLandScan' 'lay-of-land scan mode'
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'HorseMarketAtlasMode.LayOfLandScan' 'LayOfLandScan default missing'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'DiscoveredOnly' 'discovered-only mode stub'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'Settlement.All' 'scans all settlements'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'HorseMarketClassifier.Classify' 'atlas classifies animal roster'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'GetItemPrice' 'atlas prices via market price helper'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'BestRecruitmentMountId' 'recruitment mount candidate'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'BestWarMountId' 'war/upgrade mount candidate'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'BestProfitBuyId' 'profit mount candidate'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'ScoreDestination' 'destination ranking policy'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'entries' 'runtime output includes entries'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'cheapestPackAnimalPrice' 'entry price field'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'localVerificationRequiredBeforeBuySell' 'local verification before buy/sell'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HorseMarketAtlasService.cs' 'readOnly' 'atlas is read-only'

# Herd Ledger forecast.
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'AnalyzeHerdLedgerCommand' 'ledger analyze command const'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'HerdLedgerPosture' 'posture vocabulary'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'ProjectedTradeLoadWeight' 'trade load forecast'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'ProjectedRecruitmentNeed' 'recruitment reserve forecast'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'ProjectedCavalryUpgradeNeed' 'upgrade reserve forecast'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'BlockedUnknownClassification' 'unknown classification mutation block'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'UnknownClassificationMutationBlocked' 'unknown classification mutation block output'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'PackAnimalReserveProtected' 'pack animal reserve protection'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'WarNobleReserveProtected' 'war/noble reserve protection'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'estimated_no_exact_route' 'conservative route-unknown load forecast'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'ProfitPostureBasesCovered' 'profit posture requires bases covered'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'RecruitmentPrepareMounts' 'recruitment posture'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'UpgradeReserveHold' 'upgrade reserve posture'
Assert-Contains 'src\BlacksmithGuild\HorseMarket\HerdLedgerService.cs' 'readOnly' 'ledger is read-only'

# Route Council must include functional vote coverage.
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'prepare_recruitment_mounts' 'horse recruitment vote'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'hold_or_find_war_mount_reserve' 'horse upgrade vote'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'CachedTradeRoutesAvailable' 'trade can win when routes exist'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'CampaignRouteVoteKind.Observe' 'observe vote only after actionable votes'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRouteCouncil.cs' 'CampaignRouteVoteKind.Recovery' 'recovery vote kind'

# Governor must surface useful next actions instead of silently observing.
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeGovernor.cs' 'ApplyRouteCouncil' 'governor attaches council decision'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeGovernor.cs' 'RefreshHorseAtlas' 'missing/stale atlas recommendation'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeGovernor.cs' 'AnalyzeHerdLedger' 'missing/stale ledger recommendation'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeGovernor.cs' 'route_council_safety_veto' 'safety veto blocks travel'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeGovernor.cs' 'AnnotateDeferredNextAction' 'deferred results include next action'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeDecision.cs' 'RouteCouncilWinningEngine' 'winning vote attached to governor decision'
Assert-Contains 'src\BlacksmithGuild\CampaignRuntime\CampaignRuntimeDecision.cs' 'NextAction' 'exact next action field'

# Operator docs must describe the spine and local-only outputs.
Assert-Contains 'docs\handoff\regent-route-horse-vision.md' 'The Regent prevents blind automation.' 'vision doctrine'
Assert-Contains 'docs\handoff\regent-route-horse-vision.md' 'The Route Council prevents one-engine tunnel vision.' 'vision doctrine'
Assert-Contains 'docs\handoff\regent-route-horse-vision.md' 'The Horse Atlas prevents blind travel.' 'vision doctrine'
Assert-Contains 'docs\handoff\regent-route-horse-vision.md' 'The Herd Ledger prevents dumb horse decisions.' 'vision doctrine'
Assert-Contains 'docs\operator\governor-test-harness.md' 'verify-regent-route-horse-contract.ps1' 'operator verifier docs'

# Config defaults must keep the spine read-only by default.
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'CampaignRuntimeGovernorAutonomousMode = false' 'autonomy disabled by default'
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'CampaignRuntimeGovernorAllowBoundedExecution = false' 'bounded execution disabled by default'
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'MapTradeAllowDirectInventoryMutation = false' 'direct inventory mutation disabled'
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'MapTradeAllowDirectGoldMutation = false' 'direct gold mutation disabled'
Assert-NotContains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'CampaignRuntimeGovernorAutonomousMode = true' 'governor autonomy must not default on'
Assert-NotContains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'CampaignRuntimeGovernorAllowBoundedExecution = true' 'bounded execution must not default on'
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'HorseMarketAtlasMode' 'atlas mode config'
Assert-Contains 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs' 'HorseMarketAtlasMaxDestinationCount' 'atlas destination cap config'

# Command registration across C# registry, bus, and PowerShell mirror.
foreach ($command in @(
    'ShowRuntimeRegentState',
    'ConveneRouteCouncil',
    'ShowRouteCouncil',
    'ScanHorseAtlas',
    'ShowHorseAtlas',
    'RankHorseDestinations',
    'AnalyzeHerdLedger',
    'ShowHerdLedger'
)) {
    Assert-Contains 'src\BlacksmithGuild\DevTools\DevCommandRegistry.cs' $command "registry must register $command"
    Assert-Contains 'src\BlacksmithGuild\DevTools\DevCommandBus.cs' $command "bus must dispatch $command"
    Assert-Contains 'scripts\dev-command-names.ps1' $command "PS mirror must list $command"
}

# Runtime evidence must never be committed.
foreach ($json in @(
    'BlacksmithGuild_RuntimeRegent.json',
    'BlacksmithGuild_RouteCouncil.json',
    'BlacksmithGuild_HorseAtlas.json',
    'BlacksmithGuild_HerdLedger.json'
)) {
    Assert-Contains '.gitignore' $json "runtime evidence $json must be git-ignored"
    Assert-GitDoesNotTrack $json
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: regent/route/horse contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: regent/route/horse contract verified.' -ForegroundColor Green
exit 0
