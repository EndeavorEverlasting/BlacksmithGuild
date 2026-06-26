# Writes BlacksmithGuild_AgentIterationConfig.json for agent/manual iteration control.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('AutoLoop', 'Manual')]
    [string]$Mode,

    [string]$BannerlordRoot,

    [ValidateSet('continue', 'play')]
    [string]$LaunchIntent = 'continue',

    [switch]$AllowContinueRecruit
)

$ErrorActionPreference = 'Stop'

function Get-BannerlordRootLocal {
    param([string]$RepoRoot)

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }

    throw 'Bannerlord install not found. Set GameFolder in BlacksmithGuild.csproj.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BannerlordRoot) {
    $BannerlordRoot = Get-BannerlordRootLocal -RepoRoot $repoRoot
}

$configPath = Join-Path $BannerlordRoot 'BlacksmithGuild_AgentIterationConfig.json'
$autoLoop = $Mode -eq 'AutoLoop'
$requireDisposable = -not $AllowContinueRecruit

$config = [ordered]@{
    autoLoop                          = $autoLoop
    launchIntent                      = $LaunchIntent
    targetState                       = 'TavernHeroReady'
    visibleMode                       = $true
    decisionPauseMs                   = 750
    tavernHeroSafeGoldReserve         = 500
    tavernHeroMaxRecruitmentsPerCommand = 1
    tavernHeroAllowDirectInjection    = $false
    requireDisposableSaveForRecruit   = $requireDisposable
}

$config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8
Write-Host "Agent iteration config: $Mode -> $configPath" -ForegroundColor Cyan
