param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )

    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing file: $Path"
    }

    $text = Get-Content -LiteralPath $full -Raw
    if ($text -notmatch [regex]::Escape($Pattern)) {
        throw "Missing '$Label' in $Path"
    }
}

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/ICampaignActivityAdapter.cs' -Pattern 'interface ICampaignActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/ICampaignActivityAdapter.cs' -Pattern 'bool CanHandle(CampaignActivityRequest request)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/ICampaignActivityAdapter.cs' -Pattern 'CampaignActivityResult TryHandle(CampaignActivityRequest request)'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'public static CampaignActivityResult Dispatch(CampaignActivityRequest request)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'ICampaignActivityAdapter[] Adapters'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'request.MutationAuthorized'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'public sealed class FoodActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'AcquireFoodBeforeRunwayBreach'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodInventoryAnalyzer.Analyze'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodDemandPolicy.TargetFoodBufferDays'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public CampaignActivityResult LatestActivityResult'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignActivityDispatcher.Dispatch(decision.ProposedActivity)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'latestActivityResult'

Write-Host 'Campaign activity dispatcher contract: PASS'
