# Live-safe collector for route-owned clock proof artifacts.
# This script assumes Bannerlord may still be running.
# It must not require ForgeStop unless explicitly added by a future operator command.

param(
    [string]$BannerlordRoot = "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord",
    [string]$DocumentsRoot = $null,
    [string]$ProofRoot = $null,
    [int]$FreshMinutes = 240,
    [switch]$NoWrite
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $DocumentsRoot -and $env:USERPROFILE) {
    $DocumentsRoot = Join-Path $env:USERPROFILE "Documents\Mount and Blade II Bannerlord"
}

if (-not $ProofRoot) {
    $ProofRoot = Join-Path $repoRoot "artifacts\route-owned-clock-live-proof"
}

$now = Get-Date
$freshWindow = [TimeSpan]::FromMinutes($FreshMinutes)

function Invoke-RepoGit {
    param([Parameter(Mandatory = $true)][string[]]$Args)

    $oldPreference = $ErrorActionPreference
    try {
        $script:ErrorActionPreference = "Continue"
        $output = & git -C $repoRoot @Args 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $output = @($_.Exception.Message)
        $exitCode = -1
    } finally {
        $script:ErrorActionPreference = $oldPreference
    }

    return [pscustomobject]@{
        ok = ($exitCode -eq 0)
        exitCode = $exitCode
        text = (($output | ForEach-Object { [string]$_ }) -join "`n")
    }
}

function Get-RuntimeProcessState {
    $names = @(
        "Bannerlord",
        "Bannerlord.Native",
        "TaleWorlds.MountAndBlade.Launcher",
        "TaleWorlds.MountAndBlade"
    )

    $processes = @()
    foreach ($name in $names) {
        $processes += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }

    return @($processes | Sort-Object Id -Unique | ForEach-Object {
        $started = $null
        try {
            $started = $_.StartTime.ToString("o")
        } catch {
            $started = $null
        }

        [pscustomobject]@{
            processName = $_.ProcessName
            id = $_.Id
            startTime = $started
            mainWindowTitle = $_.MainWindowTitle
        }
    })
}
function Test-FreshItem {
    param([System.IO.FileInfo]$Item)

    if (-not $Item) {
        return $false
    }

    return (($now - $Item.LastWriteTime) -le $freshWindow)
}

function Read-TextLiveSafe {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Tail = 300
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            if (-not (Test-Path -LiteralPath $Path)) {
                return [pscustomobject]@{
                    ok = $false
                    text = ""
                    error = "missing"
                }
            }

            $text = (Get-Content -LiteralPath $Path -Tail $Tail -ErrorAction Stop) -join "`n"

            return [pscustomobject]@{
                ok = $true
                text = $text
                error = $null
            }
        } catch {
            Start-Sleep -Milliseconds (150 * $attempt)
            $lastError = $_.Exception.Message
        }
    }

    return [pscustomobject]@{
        ok = $false
        text = ""
        error = $lastError
    }
}

function Read-JsonLiveSafe {
    param([Parameter(Mandatory = $true)][string]$Path)

    $read = Read-TextLiveSafe -Path $Path -Tail 10000
    if (-not $read.ok) {
        return [pscustomobject]@{
            ok = $false
            value = $null
            error = $read.error
        }
    }

    try {
        return [pscustomobject]@{
            ok = $true
            value = ($read.text | ConvertFrom-Json -ErrorAction Stop)
            error = $null
        }
    } catch {
        return [pscustomobject]@{
            ok = $false
            value = $null
            error = $_.Exception.Message
        }
    }
}

function Copy-LiveSafe {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            if (-not (Test-Path -LiteralPath $Source)) {
                return [pscustomobject]@{
                    ok = $false
                    copiedTo = $null
                    error = "missing"
                }
            }

            Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop

            return [pscustomobject]@{
                ok = $true
                copiedTo = $Destination
                error = $null
            }
        } catch {
            Start-Sleep -Milliseconds (150 * $attempt)
            $lastError = $_.Exception.Message
        }
    }

    return [pscustomobject]@{
        ok = $false
        copiedTo = $null
        error = $lastError
    }
}

function New-SafeArtifactName {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ($Path -replace "^[A-Za-z]:\\", "" -replace "[\\/:*?`"<>| ]", "_")
}

function Add-CandidatePath {
    param(
        [Parameter(Mandatory = $true)]$List,
        [string]$Root,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        return
    }

    $candidate = Join-Path $Root $Name
    if (Test-Path -LiteralPath $candidate) {
        $List.Add($candidate) | Out-Null
    }
}

function Add-RecentMatchingFiles {
    param(
        [Parameter(Mandatory = $true)]$List,
        [string]$Root,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        return
    }

    if (-not (Test-Path -LiteralPath $Root)) {
        return
    }

    try {
        Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Name -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                $List.Add($_.FullName) | Out-Null
            }
    } catch {
        # Live runtime folders can shift. This collector reports partial evidence instead of dying.
    }
}

New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$proofDir = Get-ChildItem -LiteralPath $ProofRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $proofDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $newProofDir = Join-Path $ProofRoot $stamp
    New-Item -ItemType Directory -Force -Path $newProofDir | Out-Null
    $proofDir = Get-Item -LiteralPath $newProofDir
}

$copiedDir = Join-Path $proofDir.FullName "collected"
if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path $copiedDir | Out-Null
}

$runtimeProcesses = @(Get-RuntimeProcessState)

$branch = (Invoke-RepoGit -Args @("rev-parse", "--abbrev-ref", "HEAD")).text.Trim()
$headSha = (Invoke-RepoGit -Args @("rev-parse", "HEAD")).text.Trim()
$statusShort = (Invoke-RepoGit -Args @("status", "--short")).text.Trim()
$diffCheck = Invoke-RepoGit -Args @("diff", "--check")

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

$roots = @(
    $BannerlordRoot,
    (Join-Path $BannerlordRoot "Modules\BlacksmithGuild"),
    $DocumentsRoot
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

$candidatePaths = New-Object System.Collections.Generic.List[string]

foreach ($root in $roots) {
    foreach ($name in $targetNames) {
        Add-CandidatePath -List $candidatePaths -Root $root -Name $name
    }
}

# Evidence sessions may contain copied tails/summaries. Pull recent matching files from docs/evidence too.
$docsEvidenceRoot = Join-Path $repoRoot "docs\evidence"
foreach ($name in $targetNames) {
    Add-RecentMatchingFiles -List $candidatePaths -Root $docsEvidenceRoot -Name $name
}

$candidatePaths = @($candidatePaths | Sort-Object -Unique)

$evidenceItems = New-Object System.Collections.Generic.List[object]
$patternHits = New-Object System.Collections.Generic.List[object]
$allText = New-Object System.Text.StringBuilder

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

foreach ($pathItem in $candidatePaths) {
    $item = $null
    try {
        $item = Get-Item -LiteralPath $pathItem -ErrorAction Stop
    } catch {
        $evidenceItems.Add([pscustomobject]@{
            path = $pathItem
            name = Split-Path -Leaf $pathItem
            exists = $false
            fresh = $false
            lastWriteUtc = $null
            length = $null
            copiedTo = $null
            copyOk = $false
            readOk = $false
            readError = $_.Exception.Message
        }) | Out-Null
        continue
    }

    $safeName = New-SafeArtifactName -Path $pathItem
    $copyResult = [pscustomobject]@{ ok = $false; copiedTo = $null; error = "NoWrite" }

    if (-not $NoWrite) {
        $copyResult = Copy-LiveSafe -Source $pathItem -Destination (Join-Path $copiedDir $safeName)
    }

    $read = Read-TextLiveSafe -Path $pathItem -Tail 500
    if ($read.text) {
        [void]$allText.AppendLine($read.text)
    }

    foreach ($pattern in $patterns) {
        if ($read.text -and $read.text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matches = $read.text -split "`r?`n" |
                Where-Object { $_.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 } |
                Select-Object -First 8

            foreach ($line in $matches) {
                $patternHits.Add([pscustomobject]@{
                    path = $pathItem
                    pattern = $pattern
                    line = $line
                }) | Out-Null
            }
        }
    }

    $evidenceItems.Add([pscustomobject]@{
        path = $pathItem
        name = $item.Name
        exists = $true
        fresh = (Test-FreshItem -Item $item)
        lastWriteUtc = $item.LastWriteTimeUtc.ToString("o")
        length = $item.Length
        copiedTo = $copyResult.copiedTo
        copyOk = $copyResult.ok
        copyError = $copyResult.error
        readOk = $read.ok
        readError = $read.error
    }) | Out-Null
}

$configPath = ($candidatePaths | Where-Object { (Split-Path -Leaf $_) -eq "BlacksmithGuild_AgentIterationConfig.json" } | Select-Object -First 1)
$certPath = ($candidatePaths | Where-Object { (Split-Path -Leaf $_) -eq "BlacksmithGuild_MapTradeCert.json" } | Select-Object -First 1)

$configRead = if ($configPath) { Read-JsonLiveSafe -Path $configPath } else { [pscustomobject]@{ ok = $false; value = $null; error = "not found" } }
$certRead = if ($certPath) { Read-JsonLiveSafe -Path $certPath } else { [pscustomobject]@{ ok = $false; value = $null; error = "not found" } }

$configJson = $configRead.value
$certJson = $certRead.value

$routeClockEvidence = $null
if ($certJson -and ($certJson.PSObject.Properties.Name -contains "routeClockEvidence")) {
    $routeClockEvidence = $certJson.routeClockEvidence
}

$runtimeProofClaim = $null
if ($routeClockEvidence -and ($routeClockEvidence.PSObject.Properties.Name -contains "runtimeProofClaim")) {
    $runtimeProofClaim = [bool]$routeClockEvidence.runtimeProofClaim
}

$hitText = $allText.ToString()

$checks = [ordered]@{
    gameRunning = (@($runtimeProcesses).Count -gt 0)
    configFound = [bool]$configPath
    configReadOk = [bool]$configRead.ok
    configAutoMapTradeRouteTrue = [bool]($configJson -and $configJson.autoMapTradeRoute -eq $true)
    agentIterationConfigLoaded = [bool]($hitText -match "loaded AgentIterationConfig")
    routeTriggerObserved = [bool]($hitText -match "AgentAutoMapTradeRoute")
    startRouteNowObserved = [bool]($hitText -match "StartRouteNow")
    mapTradeServiceObserved = [bool]($hitText -match "MapTradeAutonomousService")
    mapTradeCertProduced = [bool]$certPath
    mapTradeCertReadOk = [bool]$certRead.ok
    routeClockEvidencePresent = [bool]$routeClockEvidence
    runtimeProofClaim = $runtimeProofClaim
    movementObserved = [bool]($hitText -match "movementObserved|partyMovedDistance|position|settlement|destination")
    blockedReasonObserved = [bool]($hitText -match "blockedReason|blocked|Blocked")
    interactiveLaunchIntentPromptObserved = [bool]($hitText -match "Supply values for the following parameters|LaunchIntent:")
}

$allowedClaims = New-Object System.Collections.Generic.List[string]
$forbiddenClaims = New-Object System.Collections.Generic.List[string]
$blockers = New-Object System.Collections.Generic.List[object]
$nextActions = New-Object System.Collections.Generic.List[string]

$classification = "insufficient_evidence"

if ($checks.interactiveLaunchIntentPromptObserved) {
    $classification = "runtime_blocked"
    $blockers.Add([pscustomobject]@{
        kind = "interactive_launch_intent_prompt"
        summary = "LaunchIntent prompt evidence was observed."
    }) | Out-Null
    $allowedClaims.Add("A LaunchIntent interactive prompt blocker was observed.") | Out-Null
    $forbiddenClaims.Add("Do not claim route proof from a prompt blocker.") | Out-Null
    $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
    $nextActions.Add("Verify the launch intent propagation fix is committed and rerun proof without manual input.") | Out-Null
}
elseif ($checks.mapTradeCertProduced -and $checks.routeClockEvidencePresent) {
    if ($checks.runtimeProofClaim -eq $true -and -not $checks.movementObserved) {
        $classification = "invalid_overclaim"
        $blockers.Add([pscustomobject]@{
            kind = "runtime_proof_claim_without_movement_observation"
            summary = "runtimeProofClaim=true but no movement observation signal was found."
        }) | Out-Null
        $forbiddenClaims.Add("Do not accept runtimeProofClaim=true without movement observation.") | Out-Null
        $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
        $nextActions.Add("Inspect routeClockEvidence and movement observation logic.") | Out-Null
    } else {
        $classification = "route_checkpoint_reached"
        $allowedClaims.Add("MapTrade cert exists with routeClockEvidence.") | Out-Null
        $forbiddenClaims.Add("Do not claim movement proof unless movement observation is present.") | Out-Null
        $nextActions.Add("Inspect whether StartRouteNow issued actual campaign movement.") | Out-Null
    }
}
elseif ($checks.routeTriggerObserved -or $checks.startRouteNowObserved -or $checks.mapTradeServiceObserved) {
    $classification = "route_attempt_observed"
    $allowedClaims.Add("Route trigger or route service evidence was observed.") | Out-Null
    $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
    $forbiddenClaims.Add("Do not claim cert proof unless MapTrade cert exists and is readable.") | Out-Null
    $nextActions.Add("Patch the seam after the last observed route signal.") | Out-Null
}
elseif ($checks.configAutoMapTradeRouteTrue -and -not $checks.agentIterationConfigLoaded) {
    $classification = "runtime_not_reached_or_no_config_load_evidence"
    $allowedClaims.Add("Config file contains autoMapTradeRoute=true.") | Out-Null
    $forbiddenClaims.Add("Do not claim the game loaded AgentIterationConfig.") | Out-Null
    $forbiddenClaims.Add("Do not claim AgentAutoMapTradeRoute started.") | Out-Null
    $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
    $nextActions.Add("Inspect campaign map-ready hook and config load path.") | Out-Null
}
else {
    $classification = "insufficient_evidence"
    $forbiddenClaims.Add("Do not claim route proof.") | Out-Null
    $forbiddenClaims.Add("Do not claim movement proof.") | Out-Null
    $nextActions.Add("Collect fresh route/runtime artifacts while preserving current game state.") | Out-Null
}

$copiedEvidenceDir = $null
if (-not $NoWrite) {
    $copiedEvidenceDir = [string]$copiedDir
}

$runtimeProcessesArray = @($runtimeProcesses | ForEach-Object { $_ })
$evidenceArray = @($evidenceItems | ForEach-Object { $_ })
$patternHitArray = @($patternHits | ForEach-Object { $_ })
$allowedClaimArray = @($allowedClaims | ForEach-Object { $_ })
$forbiddenClaimArray = @($forbiddenClaims | ForEach-Object { $_ })
$blockerArray = @($blockers | ForEach-Object { $_ })
$nextActionArray = @($nextActions | ForEach-Object { $_ })

$repoState = @{
    branch = [string]$branch
    headSha = [string]$headSha
    statusShort = [string]$statusShort
    diffCheckOk = [bool]$diffCheck.ok
    diffCheckText = [string]$diffCheck.text
}

$rootsState = @{
    bannerlordRoot = [string]$BannerlordRoot
    documentsRoot = [string]$DocumentsRoot
    searchedRoots = @($roots)
}

$summary = @{
    schema = "TbgRouteOwnedClockLiveProof.v1"
    generatedUtc = (Get-Date).ToUniversalTime().ToString("o")
    proofDir = [string]$proofDir.FullName
    copiedEvidenceDir = $copiedEvidenceDir
    runtimeProcesses = $runtimeProcessesArray
    repoState = $repoState
    roots = $rootsState
    classification = [string]$classification
    checks = $checks
    routeClockEvidence = $routeClockEvidence
    evidence = $evidenceArray
    patternHits = $patternHitArray
    allowedClaims = $allowedClaimArray
    forbiddenClaims = $forbiddenClaimArray
    blockers = $blockerArray
    nextActions = $nextActionArray
}
$outputPath = Join-Path $proofDir.FullName "BlacksmithGuild_RouteOwnedClockLiveProof.json"

if (-not $NoWrite) {
    $json = $summary | ConvertTo-Json -Depth 24
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($outputPath, $json, $utf8NoBom)
}

Write-Host ""
Write-Host "== ROUTE OWNED CLOCK LIVE PROOF SUMMARY =="
Write-Host "classification: $classification"
Write-Host "gameRunning: $($checks.gameRunning)"
Write-Host "proofDir: $($proofDir.FullName)"
Write-Host "output: $outputPath"
Write-Host ""
Write-Host "checks:"
$checks.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0}: {1}" -f $_.Key, $_.Value)
}

Write-Host ""
Write-Host "allowedClaims:"
@($allowedClaims) | ForEach-Object { Write-Host "  - $_" }

Write-Host ""
Write-Host "forbiddenClaims:"
@($forbiddenClaims) | ForEach-Object { Write-Host "  - $_" }

if ($blockers.Count -gt 0) {
    Write-Host ""
    Write-Host "blockers:"
    @($blockers) | ForEach-Object {
        Write-Host "  - $($_.kind): $($_.summary)"
    }
}

Write-Host ""
Write-Host "nextActions:"
@($nextActions) | ForEach-Object { Write-Host "  - $_" }

if ($classification -in @("runtime_blocked", "invalid_overclaim", "insufficient_evidence")) {
    exit 2
}

exit 0