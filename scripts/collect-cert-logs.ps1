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
    @{ Label = 'SmithingRefineProbe.json'; Path = Join-Path $root 'BlacksmithGuild_SmithingRefineProbe.json'; Tail = 0 }
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
