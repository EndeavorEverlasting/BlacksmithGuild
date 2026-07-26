$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch $Pattern) {
        throw $Message
    }
}

Assert-Contains `
    -Path 'src/BlacksmithGuild/DevTools/GameReadinessService.cs' `
    -Pattern 'public static bool CanRunSettlementTrade\(out string reason\)' `
    -Message 'Settlement trade commands need a dedicated readiness gate.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/DevTools/GameReadinessService.cs' `
    -Pattern 'IsSettlementInteriorReady' `
    -Message 'Settlement trade readiness must require a live settlement surface.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/DevTools/GameReadinessService.cs' `
    -Pattern 'ResolveCurrentSettlement\(\) == null' `
    -Message 'Settlement trade readiness must require an exact current settlement.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' `
    -Pattern '(?s)IsSettlementTradeCommand\(commandName\).*CanRunSettlementTrade' `
    -Message 'Trade probes must route through the settlement-safe readiness gate.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' `
    -Pattern 'public static void OnRealtimeTick\(\)' `
    -Message 'MapTrade needs a realtime arrival reconciler while campaign time is paused.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' `
    -Pattern 'IsMapMenuOpen \|\| !IsAtTargetSettlement\(\)' `
    -Message 'Realtime reconciliation must stay scoped to the exact target settlement menu.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' `
    -Pattern '(?s)_activeReport\.LatestPosition = DescribePartyPosition\(\);.*BeginSettlementEntry\(\);.*TickSettlementAndTrade\(\);' `
    -Message 'Realtime reconciliation must capture arrival before entering the trade phase.'
Assert-Contains `
    -Path 'src/BlacksmithGuild/SubModule.cs' `
    -Pattern 'MapTradeAutonomousService\.OnRealtimeTick\(\);' `
    -Message 'The application tick must drive paused settlement reconciliation.'

Write-Host 'MapTrade settlement handoff contract PASS' -ForegroundColor Green
