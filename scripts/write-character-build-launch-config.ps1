# Writes BlacksmithGuild_CharacterBuildVariantConfig.json for launch-mode separation (008C-Fix).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('AgentHeadless', 'UserVisible', 'Replay')]
    [string]$Mode,

    [string]$BannerlordRoot,

    [ValidateSet('catalog', 'variant')]
    [string]$AgentSubMode = 'catalog',

    [object]$Candidate,

    [string]$BestJsonPath
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

$configPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CharacterBuildVariantConfig.json'

switch ($Mode) {
    'AgentHeadless' {
        if ($AgentSubMode -eq 'variant') {
            if (-not $Candidate) {
                throw 'AgentHeadless variant mode requires -Candidate.'
            }

            $config = [ordered]@{
                mode              = 'variant'
                candidateId       = $Candidate.candidateId
                selectedBuildMode = $Candidate.profile
                visibleMode       = $false
                decisionPauseMs   = 0
                catalogMode       = $false
                replayMode        = $false
                score             = [double]$Candidate.score
                testSavePrefix    = 'BSG_ASR_TEST_'
                testSaveName      = "BSG_ASR_TEST_$($Candidate.candidateId)"
                route             = @($Candidate.route)
            }
        } else {
            $config = [ordered]@{
                mode            = 'catalog'
                catalogMode     = $true
                visibleMode     = $false
                replayMode      = $false
                legitimacyMode  = 'VanillaLegit'
                testSavePrefix  = 'BSG_ASR_TEST_'
            }
        }

        Write-Host 'AGENT HEADLESS - not valid for TBGPersonalAserai001 cert' -ForegroundColor Yellow
    }

    'UserVisible' {
        $config = [ordered]@{
            mode              = 'personal'
            visibleMode       = $true
            decisionPauseMs   = 2000
            catalogMode       = $false
            replayMode        = $false
            selectedBuildMode = 'AseraiTradeSmith'
        }
    }

    'Replay' {
        if (-not $BestJsonPath) {
            $BestJsonPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CharacterBuildBest.json'
        }

        if (-not (Test-Path -LiteralPath $BestJsonPath)) {
            throw "Best JSON missing: $BestJsonPath - run SelectCharacterBuildBestNow first."
        }

        $best = Get-Content -LiteralPath $BestJsonPath -Raw | ConvertFrom-Json
        if ($best.blockedReason) {
            throw "Best selection blocked: $($best.blockedReason)"
        }

        $config = [ordered]@{
            mode              = 'replay'
            replayMode        = $true
            visibleMode       = $true
            decisionPauseMs   = 750
            catalogMode       = $false
            candidateId       = $best.selectedCandidateId
            selectedBuildMode = $best.selectedBuildMode
            score             = [double]$best.score
            route             = @($best.selectedRoute)
        }
    }
}

($config | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $configPath -Encoding UTF8
Write-Host "Character build launch config ($Mode) -> $configPath" -ForegroundColor Cyan
return $configPath
