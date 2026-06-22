# Print cert log tails in one block — paste output into next agent chat.
$ErrorActionPreference = 'Stop'

function Get-BannerlordRoot {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $csproj = Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }
    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }
    throw 'Bannerlord install not found.'
}

$root = Get-BannerlordRoot
$files = @(
    @{ Label = 'Phase1.log (tail 220)'; Path = Join-Path $root 'BlacksmithGuild_Phase1.log'; Tail = 220 },
    @{ Label = 'Launch.log (tail 120)'; Path = Join-Path $root 'BlacksmithGuild_Launch.log'; Tail = 120 },
    @{ Label = 'Status.json'; Path = Join-Path $root 'BlacksmithGuild_Status.json'; Tail = 0 },
    @{ Label = 'MarketIntel.json'; Path = Join-Path $root 'BlacksmithGuild_MarketIntel.json'; Tail = 0 },
    @{ Label = 'ForgeRecommendations.json'; Path = Join-Path $root 'BlacksmithGuild_ForgeRecommendations.json'; Tail = 0 },
    @{ Label = 'SmithingAdvisory.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingAdvisory.json'; Tail = 0 },
    @{ Label = 'SmithingSafeAction.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingSafeAction.json'; Tail = 0 },
    @{ Label = 'SmithingRefineProbe.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingRefineProbe.json'; Tail = 0 },
    @{ Label = 'SmithingSmeltProbe.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingSmeltProbe.json'; Tail = 0 },
    @{ Label = 'SmithingSmeltExecution.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingSmeltExecution.json'; Tail = 0 },
    @{ Label = 'AutonomousGuildLoop.json'; Path = Join-Path $root 'BlacksmithGuild_AutonomousGuildLoop.json'; Tail = 0 },
    @{ Label = 'MapTradeCert.json'; Path = Join-Path $root 'BlacksmithGuild_MapTradeCert.json'; Tail = 0 },
    @{ Label = 'MapTradeProbe.json'; Path = Join-Path $root 'BlacksmithGuild_MapTradeProbe.json'; Tail = 0 },
    @{ Label = 'MapTradePackAnimalProbe.json'; Path = Join-Path $root 'BlacksmithGuild_MapTradePackAnimalProbe.json'; Tail = 0 },
    @{ Label = 'ClanContext.json'; Path = Join-Path $root 'BlacksmithGuild_ClanContext.json'; Tail = 0 },
    @{ Label = 'GuildLoopReport.json'; Path = Join-Path $root 'BlacksmithGuild_GuildLoopReport.json'; Tail = 0 },
    @{ Label = 'CommandSurface.json'; Path = Join-Path $root 'BlacksmithGuild_CommandSurface.json'; Tail = 0 },
    @{ Label = 'SmithingRestPlan.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingRestPlan.json'; Tail = 0 }
)

Write-Host ''
Write-Host '=== BlacksmithGuild cert log bundle ===' -ForegroundColor Cyan
Write-Host "Root: $root"
Write-Host ''

foreach ($item in $files) {
    Write-Host ('--- ' + $item.Label + ' ---') -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $item.Path)) {
        Write-Host '(file not found)'
        Write-Host ''
        continue
    }
    if ($item.Tail -gt 0) {
        Get-Content -LiteralPath $item.Path -Tail $item.Tail
    } else {
        Get-Content -LiteralPath $item.Path
    }
    Write-Host ''
}

Write-Host 'Tip: grep Launch.log for UIA: CLICK or AUDIT if something opened unexpectedly.' -ForegroundColor DarkGray

$safeActionPath = Join-Path $root 'BlacksmithGuild_SmithingSafeAction.json'
$phase1Path = Join-Path $root 'BlacksmithGuild_Phase1.log'
if ((Test-Path -LiteralPath $safeActionPath) -and (Test-Path -LiteralPath $phase1Path)) {
    try {
        $safe = Get-Content -LiteralPath $safeActionPath -Raw | ConvertFrom-Json
        if ($safe.executed -ne $true) {
            $pattern = '\[TBG FORGE\] action=RefineCharcoal .* reserveBefore charcoal=(\d+) .* reserveAfter charcoal=(\d+)'
            $phase1Matches = Select-String -LiteralPath $phase1Path -Pattern $pattern -AllMatches
            if ($phase1Matches) {
                $last = $phase1Matches[-1]
                $cb = [int]$last.Matches[0].Groups[1].Value
                $ca = [int]$last.Matches[0].Groups[2].Value
                if ($ca -gt $cb) {
                    Write-Host ''
                    Write-Host 'Note: Phase1 shows Stage C mutation PASS but SafeAction JSON is blocked/stale.' -ForegroundColor DarkYellow
                    Write-Host "  $($last.Line.Trim())" -ForegroundColor DarkYellow
                }
            }
        }
    } catch {
        # ignore parse errors in optional hint
    }
}
