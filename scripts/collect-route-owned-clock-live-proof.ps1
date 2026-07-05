# Collect and classify route-owned clock live proof artifacts.
# Read-only except for route proof artifact output.

param(
    [string]$BannerlordRoot = "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord",
    [string]$DocumentsRoot = $null,
    [string]$ProofRoot = $null,
    [int]$FreshMinutes = 60,
    [switch]$NoWrite
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProofRoot) {
    $ProofRoot = Join-Path $repoRoot "artifacts\route-owned-clock-live-proof"
}
if (-not $DocumentsRoot -and $env:USERPROFILE) {
    $DocumentsRoot = Join-Path $env:USERPROFILE "Documents\Mount and Blade II Bannerlord"
}

$now = Get-Date
$freshWindow = [TimeSpan]::FromMinutes($FreshMinutes)

function Invoke-RepoGit {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    $output = & git -C $repoRoot @Args 2>&1
    [pscustomobject][ordered]@{
        ok = ($LASTEXITCODE -eq 0)
        exitCode = $LASTEXITCODE
        text = (($output | ForEach-Object { [string]$_ }) -join "`n")
    }
}

function Test-FreshPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path
    return (($now - $item.LastWriteTime) -le $freshWindow)
}

function Read-JsonSafe {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-TailTextSafe {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$Tail = 200)
    try {
        if (Test-Path -LiteralPath $Path) {
            return (Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop) -join "`n"
        }
    } catch {}
    return ""
}

function New-SafeArtifactName {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "^[A-Za-z]:\\", "" -replace "[\\/:*?`"<>| ]", "_")
}

function Add-PatternHit {
    param(
        [Parameter(Mandatory = $true)]$List,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Line
    )
    $List.Add([pscustomobject][ordered]@{
        path = $Path
        pattern = $Pattern
        line = $Line
    }) | Out-Null
}

New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$proofDir = Get-ChildItem -LiteralPath $ProofRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $proofDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $proofDirPath = Join-Path $ProofRoot $stamp
    New-Item -ItemType Directory -Force -Path $proofDirPath | Out-Null
    $proofDir = Get-Item -LiteralPath $proofDirPath
}

$copiedDir = Join-Path $proofDir.FullName "collected"
if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path $copiedDir | Out-Null
}

$branch = (Invoke-RepoGit -Args @("rev-parse", "--abbrev-ref", "HEAD")).text.Trim()
$headSha = (Invoke-RepoGit -Args @("rev-parse", "HEAD")).text.Trim()
$statusShort = (Invoke-RepoGit -Args @("status", "--short")).text.Trim()
$diffCheck = Invoke-RepoGit -Args @("diff", "--check")

$roots = New-Object System.Collections.Generic.List[string]
foreach ($candidate in @(
    $BannerlordRoot,
    (Join-Path $BannerlordRoot "Modules\BlacksmithGuild"),
    $DocumentsRoot
)) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
        $roots.Add($candidate) | Out-Null
    }
}

$targetNames = @(
    "BlacksmithGuild_AgentIterationConfig.json",
    "BlacksmithGuild_MapTradeCert.json",
    "BlacksmithGuild_Launch.log",
    "BlacksmithGuild_Phase1.log",
    "BlacksmithGuild_Status.json",
    "BlacksmithGuild_AgentIterationSummary.json",
    "BlacksmithGuild_RuntimeLifecycle.json",
    "BlacksmithGuild_CommandAck.json"
)

$found = New-Object System.Collections.Generic.List[object]
foreach ($root in $roots) {
    foreach ($name in $targetNames) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter $name -ErrorAction SilentlyContinue |
            ForEach-Object {
                $found.Add($_) | Out-Null
            }
    }
}

$found = $found |
    Sort-Object FullName -Unique |
    Sort-Object LastWriteTime -Descending

$evidenceItems = New-Object System.Collections.Generic.List[object]
foreach ($file in $found) {
    $fresh = Test-FreshPath -Path $file.FullName
    $copiedTo = $null

    if (-not $NoWrite) {
        $safeName = New-SafeArtifactName -Path $file.FullName
        $copiedTo = Join-Path $copiedDir $safeName
        Copy-Item -LiteralPath $file.FullName -Destination $copiedTo -Force
    }

    $evidenceItems.Add([pscustomobject][ordered]@{
        path = $file.FullName
        name = $file.Name
        kind = $file.Extension.TrimStart(".")
        fresh = $fresh
        lastWriteUtc = $file.LastWriteTimeUtc.ToString("o")
        length = $file.Length
        copiedTo = $copiedTo
    }) | Out-Null
}

$configFile = $found |
    Where-Object { $_.Name -eq "BlacksmithGuild_AgentIterationConfig.json" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$certFile = $found |
    Where-Object { $_.Name -eq "BlacksmithGuild_MapTradeCert.json" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$configJson = if ($configFile) { Read-JsonSafe -Path $configFile.FullName } else { $null }
$certJson = if ($certFile) { Read-JsonSafe -Path $certFile.FullName } else { $null }

$patternHits = New-Object System.Collections.Generic.List[object]
$patterns = @(
    "loaded AgentIterationConfig",
    "AgentIterationConfig",
    "autoMapTradeRoute",
    "AgentAutoMapTradeRoute",
    "MapTradeAutonomousService",
    "StartRouteNow",
    "BlacksmithGuild_MapTradeCert",
    "routeClockEvidence",
    "runtimeProofClaim",
    "blocked",
    "Blocked",
    "blockedReason",
    "UsedDisposableQuickStartPath",
    "CampaignSetupStateTracker",
    "movementObserved",
    "partyMovedDistance",
    "position",
    "settlement",
    "destination",
    "Supply values for the following parameters",
    "LaunchIntent"
)

$logLike = $found | Where-Object { $_.Extension -in ".log", ".json", ".txt" }
foreach ($file in $logLike) {
    $tail = Get-TailTextSafe -Path $file.FullName -Tail 300
    foreach ($pattern in $patterns) {
        if ($tail.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matchingLines = $tail -split "`r?`n" | Where-Object {
                $_.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            } | Select-Object -First 8

            foreach ($line in $matchingLines) {
                Add-PatternHit -List $patternHits -Path $file.FullName -Pattern $pattern -Line $line
            }
        }
    }
}

$routeClockEvidence = if ($certJson -and ($certJson.PSObject.Properties.Name -contains "routeClockEvidence")) {
    $certJson.routeClockEvidence
} else {
    $null
}

$runtimeProofClaim = if ($routeClockEvidence -and ($routeClockEvidence.PSObject.Properties.Name -contains "runtimeProofClaim")) {
    [bool]$routeClockEvidence.runtimeProofClaim
} else {
    $null
}

$hitText = (($patternHits | ForEach-Object { "$($_.pattern) $($_.line)" }) -join "`n")

$checks = [ordered]@{
    configFound = [bool]$configFile
    configFresh = [bool]($configFile -and (Test-FreshPath -Path $configFile.FullName))
    configAutoMapTradeRouteTrue = [bool]($configJson -and ($configJson.autoMapTradeRoute -eq $true))
    agentIterationConfigLoaded = ($hitText -match "loaded AgentIterationConfig")
    routeTriggerObserved = ($hitText -match "AgentAutoMapTradeRoute")
    startRouteNowObserved = ($hitText -match "StartRouteNow")
    mapTradeServiceObserved = ($hitText -match "MapTradeAutonomousService")
    mapTradeCertProduced = [bool]$certFile
    mapTradeCertFresh = [bool]($certFile -and (Test-FreshPath -Path $certFile.FullName))
    routeClockEvidencePresent = [bool]$routeClockEvidence
    runtimeProofClaim = $runtimeProofClaim
    movementObserved = ($hitText -match "movementObserved|partyMovedDistance|position|settlement|destination")
    blockedReasonObserved = ($hitText -match "blockedReason|blocked|Blocked")
    interactiveLaunchIntentPromptObserved = ($hitText -match "Supply values for the following parameters[\s\S]*LaunchIntent|Supply values for the following parameters|LaunchIntent:")
}

$classification = "unclassified"
$allowedClaims = New-Object System.Collections.Generic.List[string]
$forbiddenClaims = New-Object System.Collections.Generic.List[string]
$blockers = New-Object System.Collections.Generic.List[object]
$nextActions = New-Object System.Collections.Generic.List[string]

if ($checks.interactiveLaunchIntentPromptObserved) {
    $classification = "runtime_blocked"
    $blockers.Add([pscustomobject][ordered]@{
        kind = "interactive_launch_intent_prompt"
        summary = "Automated route proof was blocked by an interactive LaunchIntent prompt."
    }) | Out-Null
    $allowedClaims.Add("The harness reached an interactive LaunchIntent blocker.") | Out-Null
    $forbiddenClaims.Add("Do not claim AgentIterationConfig loaded in game from this blocker alone.") | Out-Null
    $forbiddenClaims.Add("Do not claim route start or movement proof.") | Out-Null
    $nextActions.Add("Patch the LaunchIntent handoff seam, validate, rerun live proof.") | Out-Null
} elseif ($checks.mapTradeCertProduced -and $checks.routeClockEvidencePresent) {
    if ($checks.runtimeProofClaim -eq $true -and -not $checks.movementObserved) {
        $classification = "invalid_overclaim"
        $blockers.Add([pscustomobject][ordered]@{
            kind = "runtime_proof_claim_without_movement_observation"
            summary = "Cert claims runtime proof but collector did not find movement observation signals."
        }) | Out-Null
        $forbiddenClaims.Add("Do not accept runtimeProofClaim=true unless movement observation is present and fresh.") | Out-Null
        $nextActions.Add("Inspect cert and movement observation logic before accepting proof.") | Out-Null
    } else {
        $classification = "route_checkpoint_reached"
        $allowedClaims.Add("MapTrade cert exists with routeClockEvidence.") | Out-Null
        $allowedClaims.Add("Route assignment/start checkpoint may be claimed if StartRouteNow or service evidence is present.") | Out-Null
        if ($checks.runtimeProofClaim -eq $false) {
            $allowedClaims.Add("runtimeProofClaim=false is correct unless movement was observed.") | Out-Null
        }
        $forbiddenClaims.Add("Do not claim movement proof unless movement observation is present.") | Out-Null
        $nextActions.Add("Review copied cert and routeClockEvidence, then decide whether current branch can close.") | Out-Null
    }
} elseif ($checks.routeTriggerObserved -or $checks.startRouteNowObserved -or $checks.mapTradeServiceObserved) {
    $classification = "route_attempt_observed"
    $allowedClaims.Add("Route trigger/service evidence was observed.") | Out-Null
    $forbiddenClaims.Add("Do not claim cert production unless BlacksmithGuild_MapTradeCert.json is fresh.") | Out-Null
    $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
    $nextActions.Add("Inspect route blocker or missing cert reason from logs.") | Out-Null
} elseif ($checks.configAutoMapTradeRouteTrue -and -not $checks.agentIterationConfigLoaded) {
    $classification = "runtime_not_reached_or_no_config_load_evidence"
    $allowedClaims.Add("Runtime config file is present with autoMapTradeRoute=true.") | Out-Null
    $forbiddenClaims.Add("Do not claim the game loaded AgentIterationConfig.") | Out-Null
    $forbiddenClaims.Add("Do not claim AgentAutoMapTradeRoute started.") | Out-Null
    $nextActions.Add("Rerun live proof and inspect launcher/runtime readiness evidence.") | Out-Null
} else {
    $classification = "insufficient_evidence"
    $forbiddenClaims.Add("Do not claim route proof.") | Out-Null
    $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
    $nextActions.Add("Collect fresh runtime logs and cert artifacts.") | Out-Null
}

if ($checks.movementObserved -and $checks.runtimeProofClaim -ne $true) {
    $allowedClaims.Add("Movement-related signals were observed, but cert runtimeProofClaim is not true. Inspect before upgrading claim.") | Out-Null
}

$summary = [pscustomobject][ordered]@{
    schema = "TbgRouteOwnedClockLiveProof.v1"
    generatedUtc = (Get-Date).ToUniversalTime().ToString("o")
    proofDir = $proofDir.FullName
    copiedEvidenceDir = if ($NoWrite) { $null } else { $copiedDir }
    repoState = [ordered]@{
        branch = $branch
        headSha = $headSha
        statusShort = $statusShort
        diffCheckOk = $diffCheck.ok
        diffCheckText = $diffCheck.text
    }
    roots = [ordered]@{
        bannerlordRoot = $BannerlordRoot
        documentsRoot = $DocumentsRoot
        searchedRoots = @($roots)
    }
    classification = $classification
    checks = $checks
    routeClockEvidence = $routeClockEvidence
    evidence = @($evidenceItems)
    patternHits = @($patternHits)
    allowedClaims = @($allowedClaims)
    forbiddenClaims = @($forbiddenClaims)
    blockers = @($blockers)
    nextActions = @($nextActions)
}

$outputPath = Join-Path $proofDir.FullName "BlacksmithGuild_RouteOwnedClockLiveProof.json"
if (-not $NoWrite) {
    $json = $summary | ConvertTo-Json -Depth 20
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($outputPath, $json, $utf8NoBom)
}

Write-Host ""
Write-Host "== ROUTE OWNED CLOCK LIVE PROOF SUMMARY =="
Write-Host "classification: $classification"
Write-Host "proofDir: $($proofDir.FullName)"
Write-Host "output: $outputPath"
Write-Host ""
Write-Host "checks:"
$checks.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0}: {1}" -f $_.Key, $_.Value)
}
Write-Host ""
Write-Host "allowedClaims:"
$allowedClaims | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "forbiddenClaims:"
$forbiddenClaims | ForEach-Object { Write-Host "  - $_" }

if ($blockers.Count -gt 0) {
    Write-Host ""
    Write-Host "blockers:"
    $blockers | ForEach-Object { Write-Host "  - $($_.kind): $($_.summary)" }
}

if ($classification -in @("invalid_overclaim", "runtime_blocked", "insufficient_evidence")) {
    exit 2
}

exit 0