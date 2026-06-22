# Export Bannerlord runtime evidence into docs/evidence/latest for agent inspection.
param(
    [switch]$WhatIf
)

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

function Read-JsonProperty {
    param(
        [object]$Json,
        [string[]]$Path
    )

    $current = $Json
    foreach ($segment in $Path) {
        if ($null -eq $current) { return $null }
        $current = $current.$segment
    }

    return $current
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$bannerlordRoot = Get-BannerlordRoot
$destRoot = Join-Path $repoRoot 'docs\evidence\latest'
$generatedUtc = (Get-Date).ToUniversalTime().ToString('o')

$evidenceFiles = @(
    'BlacksmithGuild_Status.json',
    'BlacksmithGuild_CommandSurface.json',
    'BlacksmithGuild_MarketIntel.json',
    'BlacksmithGuild_HorseMarketIntel.json',
    'BlacksmithGuild_ForgeRecommendations.json',
    'BlacksmithGuild_SmithingAdvisory.json',
    'BlacksmithGuild_GuildLoopReport.json',
    'BlacksmithGuild_SmithingSafeAction.json',
    'BlacksmithGuild_SmithingRefineProbe.json',
    'BlacksmithGuild_SmithingRestPlan.json',
    'BlacksmithGuild_CharacterBuildProvenance.json',
    'BlacksmithGuild_CharacterDoctrine.json',
    'BlacksmithGuild_BlacksmithAutomation.json',
    'BlacksmithGuild_CharacterChoiceCatalog.json',
    'BlacksmithGuild_CharacterBuildCandidateMatrix.json',
    'BlacksmithGuild_CharacterBuildBest.json',
    'BlacksmithGuild_CharacterVisibleReplay.json',
    'BlacksmithGuild_CharacterBuildVariantMatrixReport.json',
    'BlacksmithGuild_CohesionOpportunities.json',
    'BlacksmithGuild_CohesionMove.json',
    'BlacksmithGuild_MapTradeRouteSafety.json',
    'BlacksmithGuild_MapTradeCert.json',
    'BlacksmithGuild_ArmyPressureWindows.json',
    'BlacksmithGuild_MapTradeForgeHandoff.json',
    'BlacksmithGuild_AutonomousGuildLoop.json'
)

$phase1Source = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'
$phase1Dest = Join-Path $destRoot 'BlacksmithGuild_Phase1.tail.txt'

Write-Host ''
Write-Host '=== Export TBG evidence ===' -ForegroundColor Cyan
Write-Host "Game root: $bannerlordRoot"
Write-Host "Dest:      $destRoot"
Write-Host ''

if ($WhatIf) {
    Write-Host '[WhatIf] Would create directory and copy:' -ForegroundColor Yellow
    foreach ($name in $evidenceFiles) {
        $src = Join-Path $bannerlordRoot $name
        Write-Host "  $(if (Test-Path -LiteralPath $src) { 'COPY' } else { 'MISS' }) $name"
    }
    Write-Host "  $(if (Test-Path -LiteralPath $phase1Source) { 'TAIL 300' } else { 'MISS' }) BlacksmithGuild_Phase1.log -> BlacksmithGuild_Phase1.tail.txt"
    Write-Host '  WRITE docs/evidence/latest/README.md'
    exit 0
}

New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

$copied = @()
$missing = @()

foreach ($name in $evidenceFiles) {
    $src = Join-Path $bannerlordRoot $name
    $dest = Join-Path $destRoot $name
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination $dest -Force
        $copied += $name
        Write-Host "Copied $name" -ForegroundColor Green
    } else {
        $missing += $name
        Write-Host "Missing $name" -ForegroundColor DarkYellow
    }
}

if (Test-Path -LiteralPath $phase1Source) {
    Get-Content -LiteralPath $phase1Source -Tail 300 | Set-Content -LiteralPath $phase1Dest -Encoding UTF8
    Write-Host 'Copied Phase1 tail (300 lines)' -ForegroundColor Green
} else {
    $missing += 'BlacksmithGuild_Phase1.log (tail)'
    Write-Host 'Missing BlacksmithGuild_Phase1.log' -ForegroundColor DarkYellow
}

$characterRunsSrc = Join-Path $bannerlordRoot 'character_runs'
$characterRunsDest = Join-Path $destRoot 'character_runs'
if (Test-Path -LiteralPath $characterRunsSrc) {
    New-Item -ItemType Directory -Force -Path $characterRunsDest | Out-Null
    Copy-Item -LiteralPath (Join-Path $characterRunsSrc '*') -Destination $characterRunsDest -Recurse -Force
    Write-Host 'Copied character_runs subtree' -ForegroundColor Green
} else {
    $repoRuns = Join-Path $repoRoot 'docs\evidence\latest\character_runs'
    if (Test-Path -LiteralPath $repoRuns) {
        New-Item -ItemType Directory -Force -Path $characterRunsDest | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRuns '*') -Destination $characterRunsDest -Recurse -Force
        Write-Host 'Synced character_runs from repo evidence' -ForegroundColor Green
    }
}

function Get-JsonFromDest {
    param([string]$FileName)
    $path = Join-Path $destRoot $FileName
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

$commandSurface = Get-JsonFromDest 'BlacksmithGuild_CommandSurface.json'
$market = Get-JsonFromDest 'BlacksmithGuild_MarketIntel.json'
$forge = Get-JsonFromDest 'BlacksmithGuild_ForgeRecommendations.json'
$guildLoop = Get-JsonFromDest 'BlacksmithGuild_GuildLoopReport.json'
$smithing = Get-JsonFromDest 'BlacksmithGuild_SmithingAdvisory.json'
$safeAction = Get-JsonFromDest 'BlacksmithGuild_SmithingSafeAction.json'
$restPlan = Get-JsonFromDest 'BlacksmithGuild_SmithingRestPlan.json'
$status = Get-JsonFromDest 'BlacksmithGuild_Status.json'

$marketPlan = @()
if ($market -and $market.actionPlan) {
    $marketPlan = @($market.actionPlan | ForEach-Object { $_.text })
} elseif ($guildLoop -and $guildLoop.market -and $guildLoop.market.actionPlan) {
    $marketPlan = @($guildLoop.market.actionPlan | ForEach-Object { $_.text })
}

$guildPlan = @()
if ($guildLoop -and $guildLoop.actionPlan) {
    $guildPlan = @($guildLoop.actionPlan)
} elseif ($forge -and $forge.actionPlan) {
    $guildPlan = @($forge.actionPlan | ForEach-Object { $_.text })
}

$crewTop = @()
$crewSource = $null
if ($guildLoop -and $guildLoop.smithingCrew) {
    $crewSource = $guildLoop.smithingCrew
} elseif ($smithing -and $smithing.crew) {
    $crewSource = $smithing.crew
}
if ($crewSource) {
    $crewTop = @($crewSource | Select-Object -First 3 | ForEach-Object {
        if ($_.actor) {
            "[$($_.rank)] $($_.action) | $($_.target) x$($_.count) | $($_.stamina)"
        } else {
            "[$($_.rank)] $($_.heroName) | $($_.action) | $($_.target)"
        }
    })
}

$stageDExposed = $false
if ($commandSurface -and $commandSurface.stageD) {
    $stageDExposed = [bool]$commandSurface.stageD.exposed
} elseif ($guildLoop -and $guildLoop.verdict) {
    $stageDExposed = [bool]$guildLoop.verdict.stageDCommandExposed
}

$phase = if ($status -and $status.session) { $status.session.phase } else { 'missing' }
$mapReady = if ($status) { $status.campaignReady } else { 'missing' }
$lastCmd = if ($status -and $status.lastCommand) {
    "$($status.lastCommand.name) ($($status.lastCommand.result))"
} else {
    'missing'
}
$missingList = if ($missing.Count -gt 0) { ($missing -join ', ') } else { '(none)' }

$forgeSource = 'missing'
$forgeFallback = 'missing'
$topCraft = 'missing'
if ($forge) {
    $forgeSource = "$($forge.sourceKind) / $($forge.source)"
    $forgeFallback = $forge.fallbackUsed
    if ($forge.topCandidate) { $topCraft = $forge.topCandidate.name }
} elseif ($guildLoop -and $guildLoop.forge) {
    $forgeSource = "$($guildLoop.forge.sourceKind) / $($guildLoop.forge.source)"
    $forgeFallback = $guildLoop.forge.fallbackUsed
    $topCraft = $guildLoop.forge.topCandidate
}

$materialGapLines = @()
if ($forge -and $forge.materialGaps) {
    $materialGapLines = @($forge.materialGaps | ForEach-Object { "- $($_.itemName): need $($_.need), have $($_.have)" })
} elseif ($guildLoop -and $guildLoop.forge -and $guildLoop.forge.materialGaps) {
    $materialGapLines = @($guildLoop.forge.materialGaps | ForEach-Object { "- $($_.itemName): need $($_.need), have $($_.have)" })
}

$hotkeyLines = @()
if ($commandSurface -and $commandSurface.hotkeys) {
    $hotkeyLines = @($commandSurface.hotkeys | ForEach-Object {
        "- $($_.input) -> $($_.command) ($($_.description))"
    })
}

$restAction = if ($restPlan -and $restPlan.recommendation) { $restPlan.recommendation.action } else { 'missing (run RunSmithingRestPlanNow)' }
$restReason = if ($restPlan -and $restPlan.recommendation) { $restPlan.recommendation.reason } else { 'n/a' }

$safeActionLine = if ($safeAction) {
    $br = if ($safeAction.blockedReason) { $safeAction.blockedReason } else { '(none)' }
    "- executed: $($safeAction.executed); blockedReason: $br; charcoal $($safeAction.charcoalBefore)->$($safeAction.charcoalAfter)"
} else {
    '_SmithingSafeAction.json missing._'
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# TBG Evidence Snapshot')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Generated (UTC): $generatedUtc")
[void]$sb.AppendLine("Game root: $bannerlordRoot")
[void]$sb.AppendLine("Copied files: $($copied.Count)")
[void]$sb.AppendLine("Missing files: $missingList")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Session')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| Field | Value |")
[void]$sb.AppendLine('|-------|-------|')
[void]$sb.AppendLine("| Phase | $phase |")
[void]$sb.AppendLine("| Map ready | $mapReady |")
[void]$sb.AppendLine("| Last command | $lastCmd |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Commands (from CommandSurface)')
[void]$sb.AppendLine('')
if ($hotkeyLines.Count -gt 0) {
    foreach ($line in $hotkeyLines) { [void]$sb.AppendLine($line) }
} else {
    [void]$sb.AppendLine('_CommandSurface.json missing. Press F8 on map or run ListScenarios via inbox._')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Market action plan')
[void]$sb.AppendLine('')
if ($marketPlan.Count -gt 0) {
    foreach ($line in $marketPlan) { [void]$sb.AppendLine("- $line") }
} else {
    [void]$sb.AppendLine('_No market plan. Run Ctrl+Alt+M or RunGuildLoopNow._')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Forge')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| Field | Value |")
[void]$sb.AppendLine('|-------|-------|')
[void]$sb.AppendLine("| Source | $forgeSource |")
[void]$sb.AppendLine("| Fallback | $forgeFallback |")
[void]$sb.AppendLine("| Top craft | $topCraft |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Material gap')
[void]$sb.AppendLine('')
if ($materialGapLines.Count -gt 0) {
    foreach ($line in $materialGapLines) { [void]$sb.AppendLine($line) }
} else {
    [void]$sb.AppendLine('_No material gaps in snapshot._')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Smithing crew (top actions)')
[void]$sb.AppendLine('')
if ($crewTop.Count -gt 0) {
    foreach ($line in $crewTop) { [void]$sb.AppendLine("- $line") }
} else {
    [void]$sb.AppendLine('_No crew rows. Run Ctrl+Alt+G or RunSmithingAdvisoryNow._')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Guild action plan')
[void]$sb.AppendLine('')
if ($guildPlan.Count -gt 0) {
    foreach ($line in $guildPlan) { [void]$sb.AppendLine("- $line") }
} else {
    [void]$sb.AppendLine('_No guild action plan in snapshot._')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Stage C safe action')
[void]$sb.AppendLine('')
[void]$sb.AppendLine($safeActionLine)
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Stage D rest plan')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| Field | Value |")
[void]$sb.AppendLine('|-------|-------|')
[void]$sb.AppendLine("| Exposed in CommandSurface | $stageDExposed |")
[void]$sb.AppendLine("| Recommendation | $restAction |")
[void]$sb.AppendLine("| Reason | $restReason |")
[void]$sb.AppendLine('')

$characterDoctrine = Get-JsonFromDest 'BlacksmithGuild_CharacterDoctrine.json'
$characterProvenance = Get-JsonFromDest 'BlacksmithGuild_CharacterBuildProvenance.json'
$blacksmithAutomation = Get-JsonFromDest 'BlacksmithGuild_BlacksmithAutomation.json'
$choiceCatalog = Get-JsonFromDest 'BlacksmithGuild_CharacterChoiceCatalog.json'
$candidateMatrix = Get-JsonFromDest 'BlacksmithGuild_CharacterBuildCandidateMatrix.json'
$buildBest = Get-JsonFromDest 'BlacksmithGuild_CharacterBuildBest.json'
$visibleReplay = Get-JsonFromDest 'BlacksmithGuild_CharacterVisibleReplay.json'
$matrixReport = Get-JsonFromDest 'BlacksmithGuild_CharacterBuildVariantMatrixReport.json'

$doctrineBuild = if ($characterDoctrine) { $characterDoctrine.defaultBuild } else { 'missing' }
$doctrineMode = if ($characterDoctrine) { "$($characterDoctrine.legitimacyMode) + assistive=$($characterDoctrine.assistiveMode)" } else { 'missing' }
$provenanceCulture = if ($characterProvenance -and $characterProvenance.culture) { $characterProvenance.culture.selectedCultureName } else { 'missing' }
$provenanceVerdict = if ($characterProvenance) { $characterProvenance.verdict } else { 'missing (run Forge.cmd Path A)' }
$automationAction = if ($blacksmithAutomation) { $blacksmithAutomation.action } else { 'missing (run RunBlacksmithAutomationNow)' }
$automationExecuted = if ($blacksmithAutomation) { $blacksmithAutomation.executed } else { 'n/a' }

[void]$sb.AppendLine('## Character (008A)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| Field | Value |")
[void]$sb.AppendLine('|-------|-------|')
[void]$sb.AppendLine("| Doctrine build | $doctrineBuild |")
[void]$sb.AppendLine("| Mode | $doctrineMode |")
[void]$sb.AppendLine("| Provenance culture | $provenanceCulture |")
[void]$sb.AppendLine("| Provenance verdict | $provenanceVerdict |")
[void]$sb.AppendLine('')
$catalogVerdict = if ($choiceCatalog) { $choiceCatalog.verdict } else { 'missing (run run-character-build-catalog.ps1)' }
$catalogOptions = if ($choiceCatalog -and $choiceCatalog.options) { @($choiceCatalog.options).Count } else { 'n/a' }
$matrixCount = if ($candidateMatrix) { $candidateMatrix.candidateCount } else { 'missing' }
$matrixBlocked = if ($candidateMatrix -and $candidateMatrix.blockedReason) { $candidateMatrix.blockedReason } else { '(none)' }
$bestCandidate = if ($buildBest) { $buildBest.selectedCandidateId } else { 'missing' }
$bestVerdict = if ($buildBest) { $buildBest.legitimacyVerdict } else { 'n/a' }
$replayCompleted = if ($visibleReplay) { $visibleReplay.completed } else { 'missing' }
$replayVerdict = if ($visibleReplay) { $visibleReplay.legitimacyVerdict } else { 'n/a' }
$matrixRunsSucceeded = if ($matrixReport) { $matrixReport.runsSucceeded } else { 'n/a' }
[void]$sb.AppendLine('## Character build variant (008C)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| Field | Value |")
[void]$sb.AppendLine('|-------|-------|')
[void]$sb.AppendLine("| Catalog verdict | $catalogVerdict |")
[void]$sb.AppendLine("| Catalog options | $catalogOptions |")
[void]$sb.AppendLine("| Matrix candidates | $matrixCount |")
[void]$sb.AppendLine("| Matrix blocked | $matrixBlocked |")
[void]$sb.AppendLine("| Matrix runs succeeded | $matrixRunsSucceeded |")
[void]$sb.AppendLine("| Best candidate | $bestCandidate |")
[void]$sb.AppendLine("| Best legitimacy | $bestVerdict |")
[void]$sb.AppendLine("| Visible replay completed | $replayCompleted |")
[void]$sb.AppendLine("| Visible replay verdict | $replayVerdict |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Blacksmith automation')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| Field | Value |")
[void]$sb.AppendLine('|-------|-------|')
[void]$sb.AppendLine("| Last action | $automationAction |")
[void]$sb.AppendLine("| Executed | $automationExecuted |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Re-export')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('```powershell')
[void]$sb.AppendLine("cd $repoRoot")
[void]$sb.AppendLine('.\ExportTbgEvidence.cmd')
[void]$sb.AppendLine('```')

$readmePath = Join-Path $destRoot 'README.md'
Set-Content -LiteralPath $readmePath -Value $sb.ToString() -Encoding UTF8
Write-Host ''
Write-Host "Wrote $readmePath" -ForegroundColor Cyan
Write-Host ''
Write-Host "Done. Copied $($copied.Count) JSON files; missing $($missing.Count)." -ForegroundColor Green
