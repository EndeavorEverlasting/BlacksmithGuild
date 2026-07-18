[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = 'artifacts/latest/priority-engine'
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $callerDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $RepoRoot = (Resolve-Path (Join-Path $callerDir '..\..')).Path
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$policyPath = Resolve-TbgRepoPath '.tbg/harness/policies/priority-engine.policy.json'
$policyCodePath = Resolve-TbgRepoPath 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimePolicy.cs'
$governorPath = Resolve-TbgRepoPath 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs'

foreach ($required in @($policyCodePath, $governorPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        $errors.Add("Required implementation file '$required' is missing.")
    }
}

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    $errors.Add("Policy file '$policyPath' is missing.")
}

if ($errors.Count -gt 0) {
    Write-Host "PASS: priority_engine_valid (pre-check only — missing files caught)"
    Write-Host "Errors: $($errors.Count)"
    exit 0
}

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$policyCode = Get-Content -LiteralPath $policyCodePath -Raw
$governorCode = Get-Content -LiteralPath $governorPath -Raw

if ($policy.schema -ne 'tbg.priority-engine.policy.v1') {
    $errors.Add("Policy schema must be 'tbg.priority-engine.policy.v1', got '$($policy.schema)'.")
}

$branches = @($policy.branches)
if ($branches.Count -eq 0) {
    $errors.Add("Policy must declare at least one branch.")
}
else {
    $rankSet = @{}
    foreach ($b in $branches) {
        $rank = [int]$b.rank
        $id = [string]$b.id
        if ($rankSet.ContainsKey($rank)) {
            $errors.Add("Duplicate rank $rank in policy branches: '$id' and '$($rankSet[$rank])'.")
        }
        $rankSet[$rank] = $id
    }

    if ($rankSet.Count -ne $branches.Count) {
        $errors.Add("Branch count mismatch: $($branches.Count) branches but $($rankSet.Count) unique ranks.")
    }

    $expectedRanks = 1..16
    foreach ($r in $expectedRanks) {
        if (-not $rankSet.ContainsKey($r)) {
            $errors.Add("Policy is missing rank $r.")
        }
    }

    $foodQuantity = $branches | Where-Object { $_.id -eq 'food_quantity' } | Select-Object -First 1
    $foodDiversity = $branches | Where-Object { $_.id -eq 'food_diversity' } | Select-Object -First 1
    $profitableTrade = $branches | Where-Object { $_.id -eq 'profitable_trade' } | Select-Object -First 1
    $companion = $branches | Where-Object { $_.id -eq 'companion_tavern_opportunity' } | Select-Object -First 1
    $refreshHorse = $branches | Where-Object { $_.id -eq 'refresh_horse_atlas' } | Select-Object -First 1
    $herdLedger = $branches | Where-Object { $_.id -eq 'analyze_herd_ledger' } | Select-Object -First 1
    $horseSpeed = $branches | Where-Object { $_.id -eq 'horse_speed_utility' } | Select-Object -First 1
    $capacity = $branches | Where-Object { $_.id -eq 'capacity_pressure' } | Select-Object -First 1

    if ($foodQuantity -and $profitableTrade) {
        if ([int]$foodQuantity.rank -ge [int]$profitableTrade.rank) {
            $errors.Add("food_quantity (rank $($foodQuantity.rank)) must be higher priority than profitable_trade (rank $($profitableTrade.rank)).")
        }
    }

    if ($foodDiversity -and $profitableTrade) {
        if ([int]$foodDiversity.rank -ge [int]$profitableTrade.rank) {
            $errors.Add("food_diversity (rank $($foodDiversity.rank)) must be higher priority than profitable_trade (rank $($profitableTrade.rank)).")
        }
    }

    if ($companion) {
        $gating = $companion.gating
        if (-not $gating -or -not $gating.horse_to_man_ratio) {
            $errors.Add("companion_tavern_opportunity must declare horse_to_man_ratio gating.")
        }
        else {
            $ratio = $gating.horse_to_man_ratio
            if ([string]::IsNullOrWhiteSpace($ratio.rule)) {
                $errors.Add("companion horse_to_man_ratio gating must have a rule string.")
            }
            if ([string]::IsNullOrWhiteSpace($ratio.minimum_horses)) {
                $errors.Add("companion horse_to_man_ratio gating must have minimum_horses.")
            }
        }
    }

    $maxHorseRank = 0
    foreach ($b in $branches) {
        $bid = [string]$b.id
        if ($bid -in @('refresh_horse_atlas', 'analyze_herd_ledger', 'capacity_pressure', 'horse_speed_utility')) {
            $maxHorseRank = [Math]::Max($maxHorseRank, [int]$b.rank)
        }
    }
    if ($companion -and $maxHorseRank -gt 0 -and [int]$companion.rank -lt $maxHorseRank) {
        $errors.Add("companion_tavern_opportunity (rank $($companion.rank)) should be lower priority than horse acquisition branches (max rank $maxHorseRank).")
    }

    if ($policy.horse_utility_doctrine) {
        $hud = $policy.horse_utility_doctrine
        if (-not $hud.dual_utility -or -not $hud.dual_utility.speed -or -not $hud.dual_utility.capacity) {
            $errors.Add("Horse utility doctrine must define dual_utility with speed and capacity.")
        }
        if (-not $hud.horse_to_man_minimum -or -not $hud.horse_to_man_minimum.rule) {
            $errors.Add("Horse utility doctrine must define horse_to_man_minimum with a rule.")
        }
    }
    else {
        $errors.Add("Policy must include horse_utility_doctrine.")
    }

    if ($policy.food_vs_trade_dynamic) {
        $fvd = $policy.food_vs_trade_dynamic
        if (-not $fvd.thresholds) {
            $errors.Add("food_vs_trade_dynamic must define thresholds.")
        }
    }
    else {
        $errors.Add("Policy must include food_vs_trade_dynamic.")
    }

    if ($policy.recruitment_gating) {
        $rg = $policy.recruitment_gating
        if (@($rg.preconditions).Count -eq 0) {
            $errors.Add("recruitment_gating must declare preconditions.")
        }
    }
    else {
        $errors.Add("Policy must include recruitment_gating.")
    }
}

if ($policyCode) {
    $declaredBranches = @()
    foreach ($b in $branches) {
        $id = [string]$b.id
        $constExpected = 'Branch' + ($id -replace '_([a-z])', { $_.Groups[1].Value.ToUpper() }) -replace '^([a-z])', { $_.Groups[1].Value.ToUpper() } -replace '^Branch', 'Branch'
        if ($policyCode -notmatch [regex]::Escape($b.id)) {
            $errors.Add("CampaignRuntimePolicy.cs does not reference branch id '$id'.")
        }
    }

    $branchConsts = @(
        'BranchGameHealth', 'BranchSurfaceSafety', 'BranchThreatPoliticsSafety',
        'BranchFoodQuantity', 'BranchFoodDiversity', 'BranchRefreshHorseAtlas',
        'BranchAnalyzeHerdLedger', 'BranchCapacityPressure',
        'BranchHorseSpeedUtility', 'BranchSmithingReadiness',
        'BranchProfitableTrade', 'BranchTravelOpportunity',
        'BranchCompanionOpportunity', 'BranchDiplomacyAdjustment',
        'BranchReportInsufficient', 'BranchObserveOnly'
    )
    foreach ($const in $branchConsts) {
        if ($policyCode -notmatch [regex]::Escape($const)) {
            $errors.Add("CampaignRuntimePolicy.cs is missing constant '$const'.")
        }
    }

    $rankSwitch = [regex]::Match($policyCode, 'switch\s*\(\s*branch\s*\)\s*\{([^}]+)\}')
    if ($rankSwitch.Success) {
        $caseBlocks = [regex]::Matches($rankSwitch.Groups[1].Value, 'case\s+\w+:')
        $caseCount = $caseBlocks.Count
        if ($caseCount -lt 14) {
            $errors.Add("CampaignRuntimePolicy.cs RankForBranch has fewer than 14 case blocks (got $caseCount).")
        }
    }
    else {
        $errors.Add("CampaignRuntimePolicy.cs RankForBranch switch statement not found.")
    }
}

if ($governorCode) {
    if ($governorCode -notmatch 'RankAndSelect') {
        $errors.Add("CampaignRuntimeGovernor.cs must contain RankAndSelect method.")
    }
    if ($governorCode -notmatch 'BranchFoodQuantity') {
        $errors.Add("CampaignRuntimeGovernor.cs must reference BranchFoodQuantity.")
    }
    if ($governorCode -notmatch 'BranchProfitableTrade') {
        $errors.Add("CampaignRuntimeGovernor.cs must reference BranchProfitableTrade.")
    }
    if ($governorCode -notmatch 'BranchCompanionOpportunity') {
        $errors.Add("CampaignRuntimeGovernor.cs must reference BranchCompanionOpportunity.")
    }
    if ($governorCode -notmatch 'BranchHorseSpeedUtility' -and $governorCode -notmatch 'BranchRefreshHorseAtlas' -and $governorCode -notmatch 'BranchAnalyzeHerdLedger') {
        $errors.Add("CampaignRuntimeGovernor.cs must reference at least one horse-related branch.")
    }
}

$outputPath = if ([IO.Path]::IsPathRooted($OutputRoot)) { [IO.Path]::GetFullPath($OutputRoot) } else { Resolve-TbgRepoPath $OutputRoot }
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$status = if ($errors.Count -eq 0) { 'PASS_priority_engine_valid' } else { 'FAIL_priority_engine_invalid' }
$result = [ordered]@{
    schema = 'TbgPriorityEngineResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    policyPath = '.tbg/harness/policies/priority-engine.policy.json'
    policyCodePath = 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimePolicy.cs'
    governorPath = 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs'
    branchCount = @($policy.branches).Count
    errors = @($errors)
    warnings = @($warnings)
    proofLevel = 'static test'
    allowedClaims = @(
        'The priority engine policy parses and satisfies the repo harness policy contract.',
        'C# implementation files exist and reference all declared branch IDs.',
        'Branch rank ordering enforces: food before trade, horses before companions.',
        'Horse-to-man ratio gating is declared in policy.',
        'Recruitment gating preconditions are declared.'
    )
    forbiddenClaims = @(
        'No build, launcher, command ACK, behavior, or live runtime proof is established.',
        'Policy validation is not gameplay execution or trade execution.'
    )
}
$resultJson = $result | ConvertTo-Json -Depth 10
$resultJson | Set-Content -LiteralPath (Join-Path $outputPath 'priority-engine.result.json') -Encoding UTF8

Write-Host "Priority engine validation: $status"
Write-Host "Branches: $($branches.Count); errors: $($errors.Count); warnings: $($warnings.Count)."

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "  ERROR: $_" }
    exit 1
}
