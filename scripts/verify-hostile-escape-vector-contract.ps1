$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path $PSScriptRoot -Parent
$policyPath = Join-Path $repoRoot '.tbg/operator/hostile-escape-vector.json'
$fixturePath = Join-Path $repoRoot '.tbg/harness/fixtures/hostile-escape-vector.fixtures.json'
$analyzerPath = Join-Path $repoRoot 'src/BlacksmithGuild/Cohesion/HostileEscapeVectorAnalyzer.cs'
$adapterPath = Join-Path $repoRoot 'src/BlacksmithGuild/MapTrade/MapTradeBanditAvoidanceService.cs'
$providerPath = Join-Path $repoRoot 'src/BlacksmithGuild/Cohesion/CampaignThreatSnapshotProvider.cs'
$autoTravelPath = Join-Path $repoRoot 'src/BlacksmithGuild/DevTools/AutoTravelService.cs'
$evidencePath = Join-Path $repoRoot 'src/BlacksmithGuild/MapTrade/HostileEscapeEvidenceWriter.cs'
$routeSafetyPath = Join-Path $repoRoot 'src/BlacksmithGuild/MapTrade/MapTradeRouteSafetyAnalyzer.cs'
$docPath = Join-Path $repoRoot 'docs/architecture/hostile-escape-and-escort-vector.md'
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
    Write-Host "FAIL $Message" -ForegroundColor Red
}

function Require-Text {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Label
    )

    if (-not $Text.Contains($Needle)) {
        Add-Failure "$Label missing '$Needle'"
    }
}

foreach ($path in @($policyPath, $fixturePath, $analyzerPath, $adapterPath, $providerPath, $autoTravelPath, $evidencePath, $routeSafetyPath, $docPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "required file missing: $path"
    }
}

if ($failures.Count -gt 0) {
    throw "Hostile escape-vector contract failed before fixture execution ($($failures.Count) failure(s))."
}

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
$analyzerText = Get-Content -LiteralPath $analyzerPath -Raw
$adapterText = Get-Content -LiteralPath $adapterPath -Raw
$providerText = Get-Content -LiteralPath $providerPath -Raw
$autoTravelText = Get-Content -LiteralPath $autoTravelPath -Raw
$evidenceText = Get-Content -LiteralPath $evidencePath -Raw
$routeSafetyText = Get-Content -LiteralPath $routeSafetyPath -Raw
$docText = Get-Content -LiteralPath $docPath -Raw

if ($policy.contractId -ne 'hostile-escape-vector/v1') { Add-Failure 'policy contractId must be hostile-escape-vector/v1' }
if (-not $policy.runtimeBoundary.recommendationOnly) { Add-Failure 'policy must remain recommendation-only' }
if ($policy.runtimeBoundary.movementMutationAllowed) { Add-Failure 'policy must prohibit movement mutation' }
if ($policy.runtimeBoundary.teleportAllowed) { Add-Failure 'policy must prohibit teleport' }
if ($policy.snapshotContract.maximumCampaignEnumerationsPerDecision -ne 1) { Add-Failure 'policy must allow exactly one campaign enumeration per decision' }
if ($policy.snapshotContract.algorithmicComplexity -ne 'O(n)') { Add-Failure 'policy complexity must remain O(n)' }
if ($policy.snapshotContract.perFrameScanningAllowed) { Add-Failure 'policy must prohibit per-frame scans' }
if ($policy.failureContract.campaignSnapshotUnavailable -ne 'hold_or_block') { Add-Failure 'unavailable snapshot must fail closed' }
if ($policy.evidenceContract.storageMode -ne 'latest_snapshot_overwrite') { Add-Failure 'evidence must overwrite latest snapshot' }
if ($policy.futureEscortContract.escortControllerOwnsMovement -ne $true) { Add-Failure 'future escort controller must own movement separately' }

foreach ($forbidden in @('using TaleWorlds', 'MobileParty.All', 'SetMove', 'Teleport')) {
    if ($analyzerText.Contains($forbidden)) {
        Add-Failure "pure analyzer contains forbidden runtime token '$forbidden'"
    }
}

Require-Text $analyzerText 'strength_proximity_weighted_repulsion' 'analyzer source marker'
Require-Text $analyzerText 'ThreatsSurroundProtectedParty' 'analyzer surrounding output'
Require-Text $analyzerText 'ProjectedMinimumClearanceMargin' 'analyzer clearance output'
Require-Text $analyzerText 'MovementMutationApplied = false' 'analyzer mutation boundary'

$campaignEnumerationCount = ([regex]::Matches($providerText, [regex]::Escape('new List<MobileParty>(MobileParty.All)'))).Count
if ($campaignEnumerationCount -ne 1) {
    Add-Failure "shared threat provider must contain exactly one MobileParty.All enumeration; found $campaignEnumerationCount"
}

if ($adapterText.Contains('MobileParty.All')) { Add-Failure 'MapTrade adapter must reuse the shared threat snapshot' }
if ($autoTravelText.Contains('foreach (var party in MobileParty.All)')) { Add-Failure 'AutoTravel must reuse the shared threat snapshot' }
if ($adapterText.Contains('CohesionPartyScanner.Scan')) { Add-Failure 'MapTrade risk level must not launch a second cohesion scan' }
Require-Text $providerText 'new List<MobileParty>(MobileParty.All)' 'defensive single snapshot'
Require-Text $providerText 'Stopwatch.GetTimestamp()' 'monotonic shared snapshot cache'
Require-Text $adapterText 'CampaignThreatSnapshotProvider.Capture' 'MapTrade shared snapshot consumer'
Require-Text $autoTravelText 'CampaignThreatSnapshotProvider.Capture' 'AutoTravel shared snapshot consumer'
Require-Text $adapterText 'HostileEscapeVectorAnalyzer.Analyze' 'pure analyzer adapter'
Require-Text $adapterText 'IsBlocking = true' 'fail-closed unavailable snapshot'
Require-Text $routeSafetyText 'CaptureSafetySnapshot()' 'explicit route-safety snapshot'
Require-Text $routeSafetyText 'HostileEscapeEvidenceWriter.Write(hostileSnapshot, source)' 'explicit evidence wiring'
Require-Text $routeSafetyText 'if (!hostileSnapshot.ScanSucceeded)' 'fail-closed explicit route safety'
Require-Text $evidenceText 'latest_snapshot_overwrite' 'bounded evidence storage'
Require-Text $evidenceText 'File.WriteAllText' 'overwrite evidence writer'
if ($evidenceText.Contains('AppendAllText')) { Add-Failure 'hostile evidence must never append' }
Require-Text $docText 'player caravan' 'future caravan protection documentation'
Require-Text $docText 'clan companion party' 'future companion protection documentation'
Require-Text $docText 'same immutable hostile snapshot' 'snapshot reuse documentation'

try {
    Add-Type -Path $analyzerPath -ErrorAction Stop
}
catch {
    Add-Failure "pure analyzer did not compile independently: $($_.Exception.Message)"
}

if ($failures.Count -eq 0) {
    foreach ($fixture in $fixtures.fixtures) {
        $request = New-Object BlacksmithGuild.Cohesion.HostileEscapeVectorRequest
        $request.ProtectedPartyId = [string]$fixture.request.protectedPartyId
        $request.ProtectedPositionX = [single]$fixture.request.protectedPositionX
        $request.ProtectedPositionY = [single]$fixture.request.protectedPositionY
        $request.ProtectedStrength = [int]$fixture.request.protectedStrength
        $request.MinimumClearance = [single]$fixture.request.minimumClearance
        $request.MaximumInfluenceDistance = [single]$fixture.request.maximumInfluenceDistance
        $request.SuggestedStepDistance = [single]$fixture.request.suggestedStepDistance
        $request.PredictionHorizonSeconds = [single]$fixture.request.predictionHorizonSeconds

        foreach ($inputThreat in $fixture.request.hostiles) {
            $threat = New-Object BlacksmithGuild.Cohesion.HostileThreatVectorSnapshot
            $threat.PartyId = [string]$inputThreat.partyId
            $threat.PositionX = [single]$inputThreat.positionX
            $threat.PositionY = [single]$inputThreat.positionY
            $threat.VelocityX = [single]$inputThreat.velocityX
            $threat.VelocityY = [single]$inputThreat.velocityY
            $threat.Strength = [int]$inputThreat.strength
            $threat.ClearanceRadius = [single]$inputThreat.clearanceRadius
            $request.Hostiles.Add($threat)
        }

        $actual = [BlacksmithGuild.Cohesion.HostileEscapeVectorAnalyzer]::Analyze($request)
        $expect = $fixture.expect
        $label = [string]$fixture.name
        if ($actual.ThreatsConsidered -ne [int]$expect.threatsConsidered) { Add-Failure "$label threatsConsidered mismatch" }
        if ($actual.EscapeHeadingX -lt [double]$expect.headingXMin -or $actual.EscapeHeadingX -gt [double]$expect.headingXMax) { Add-Failure "$label headingX out of range: $($actual.EscapeHeadingX)" }
        if ($actual.EscapeHeadingY -lt [double]$expect.headingYMin -or $actual.EscapeHeadingY -gt [double]$expect.headingYMax) { Add-Failure "$label headingY out of range: $($actual.EscapeHeadingY)" }
        if ($actual.ThreatsSurroundProtectedParty -ne [bool]$expect.threatsSurroundProtectedParty) { Add-Failure "$label surrounding flag mismatch" }
        if ($actual.FallbackDirectionUsed -ne [bool]$expect.fallbackDirectionUsed) { Add-Failure "$label fallback flag mismatch" }
        if ($actual.ImprovesMinimumClearance -ne [bool]$expect.improvesMinimumClearance) { Add-Failure "$label clearance-improvement flag mismatch" }
        if ($actual.GeometryConfidence -ne [string]$expect.geometryConfidence) { Add-Failure "$label confidence mismatch: $($actual.GeometryConfidence)" }
        if ($actual.PairEvaluations -ne (2 * $actual.ThreatsConsidered)) { Add-Failure "$label must use two linear pair passes" }
        if (-not $actual.RecommendationOnly -or $actual.MovementMutationApplied) { Add-Failure "$label crossed recommendation-only boundary" }
        if ([single]::IsNaN($actual.EscapeHeadingX) -or [single]::IsInfinity($actual.EscapeHeadingX)) { Add-Failure "$label produced a non-finite heading" }
        $headingLength = [math]::Sqrt(($actual.EscapeHeadingX * $actual.EscapeHeadingX) + ($actual.EscapeHeadingY * $actual.EscapeHeadingY))
        if ($actual.ThreatsConsidered -gt 0 -and ($headingLength -lt 0.999 -or $headingLength -gt 1.001)) { Add-Failure "$label heading must be normalized: $headingLength" }
        if ($actual.ThreatsConsidered -eq 0 -and $headingLength -gt 0.001) { Add-Failure "$label clear field must not invent a heading" }
    }
}

if ($failures.Count -gt 0) {
    throw "Hostile escape-vector contract failed with $($failures.Count) failure(s)."
}

Write-Host "PASS: hostile escape-vector policy, wiring, and $($fixtures.fixtures.Count) executable geometry fixtures verified." -ForegroundColor Green
