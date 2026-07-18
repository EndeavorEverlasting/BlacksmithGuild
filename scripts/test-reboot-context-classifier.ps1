$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'reboot-context-classifier.ps1')

$tmpRoot = Join-Path $env:TEMP "reboot-context-classifier-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

function Write-FixtureJson($Path, $Obj) { $Obj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8 }
function Write-FixtureJsonl($Path, [object[]]$Rows) { @($Rows | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) | Set-Content -LiteralPath $Path -Encoding UTF8 }
function New-RebootEvidenceFixture {
    param(
        [string]$Name,
        [string]$FailureClass = 'handoff_missing_travel_target',
        [string]$TargetSource = 'recursiveBranchState',
        [double]$Moved = 0,
        [string]$Surface = 'campaign_map',
        [string]$MovementProofClassification = $null,
        [hashtable]$MovementDeltas = @{}
    )
    $dir = Join-Path $tmpRoot $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-FixtureJson (Join-Path $dir 'session-manifest.json') @{ sessionId = "volatile-$Name"; startedAtUtc = (Get-Date).ToString('o'); targetSettlement = 'Saneopa' }
    Write-FixtureJson (Join-Path $dir 'assist-loop-summary.json') @{ sessionId = "volatile-$Name"; failureClass = $FailureClass; stopReason = $FailureClass; proofMode = 'attach_readiness_proof'; visibleMechanicsProven = ($Moved -gt 0); lastSafeIdleClass = 'safe_idle_no_branch_progress'; maxConsecutiveSafeIdleCycles = 12 }
    Write-FixtureJson (Join-Path $dir 'campaign-loop-summary.json') @{ gameplaySurface = $Surface; nextPlannedBranch = 'travel'; targetSettlement = 'Saneopa' }
    Write-FixtureJsonl (Join-Path $dir 'state-snapshots.jsonl') @(@{ atUtc = (Get-Date).ToString('o'); pid = 111; stateMachine = @{ gameplaySurface = $Surface }; nextPlannedBranch = 'travel'; resolvedTravelTarget = 'Saneopa'; resolvedTravelTargetSource = $TargetSource })
    Write-FixtureJsonl (Join-Path $dir 'command-timeline.jsonl') @(@{ atUtc = (Get-Date).ToString('o'); processId = 222; surface = $Surface; plannedBranch = 'travel'; commandSent = 'AssistiveLeaveTownAndTravel'; result = 'Success'; target = 'Saneopa'; targetSource = $TargetSource; safeIdleClass = 'safe_idle_no_branch_progress' })
    Write-FixtureJsonl (Join-Path $dir 'checkpoint-events.jsonl') @(@{ timestampUtc = (Get-Date).ToString('o'); checkpointName = 'execute_ack' })
    $execution = @{ travelClockRunning = $true; movementIntentSet = $true; partyMovedDistance = $Moved }
    if ($MovementProofClassification) {
        $execution.movementProofClassification = $MovementProofClassification
        $execution.movementMetricDisagreement = ($MovementProofClassification -eq 'MovementMetricDisagreement')
        $execution.movementCheckpointObserved = ($MovementProofClassification -in @('MovementCheckpointObserved', 'MovementMetricDisagreement'))
        $execution.movementProof = @{
            classification = $MovementProofClassification
            partyMovedDistance = $Moved
            deltas = @{
                positionChanged = [bool]$MovementDeltas.positionChanged
                distanceToTargetChanged = [bool]$MovementDeltas.distanceToTargetChanged
                mapTimeAdvanced = [bool]$MovementDeltas.mapTimeAdvanced
                currentSettlementChanged = [bool]$MovementDeltas.currentSettlementChanged
                nearestSettlementChanged = [bool]$MovementDeltas.nearestSettlementChanged
                targetChanged = [bool]$MovementDeltas.targetChanged
            }
        }
        Write-FixtureJson (Join-Path $dir 'BlacksmithGuild_MovementProof.json') @{
            schemaVersion = 1
            classification = $MovementProofClassification
            partyMovedDistance = $Moved
            deltas = $execution.movementProof.deltas
        }
    }
    Write-FixtureJson (Join-Path $dir 'BlacksmithGuild_AssistiveTravelExecution.json') $execution
    return $dir
}

$surfaceCampaign = [pscustomobject]@{ surface = 'campaign_map'; staleEvidence = $false; operatorInterruptionObserved = $false; foregroundLoss = $false; failureClass = $null }
$campaignOwner = Resolve-RebootSurfaceOwnership -Surface $surfaceCampaign.surface -Context $surfaceCampaign
if ($campaignOwner.surfaceGroup -ne 'outside_town') { throw "Expected campaign_map to route to outside_town, got $($campaignOwner.surfaceGroup)" }
if ($campaignOwner.stableGapOwner -ne 'outside_town_movement') { throw "Expected outside_town_movement, got $($campaignOwner.stableGapOwner)" }

$surfaceTown = [pscustomobject]@{ surface = 'settlement_menu'; staleEvidence = $false; operatorInterruptionObserved = $false; foregroundLoss = $false; failureClass = $null }
$townOwner = Resolve-RebootSurfaceOwnership -Surface $surfaceTown.surface -Context $surfaceTown
if ($townOwner.surfaceGroup -ne 'inside_town') { throw "Expected settlement_menu to route to inside_town, got $($townOwner.surfaceGroup)" }
if ($townOwner.stableGapOwner -ne 'inside_town_settlement_work') { throw "Expected inside_town_settlement_work, got $($townOwner.stableGapOwner)" }

$surfaceInterrupted = [pscustomobject]@{ surface = 'campaign_map'; staleEvidence = $false; operatorInterruptionObserved = $true; foregroundLoss = $true; failureClass = $null }
$interruptedOwner = Resolve-RebootSurfaceOwnership -Surface $surfaceInterrupted.surface -Context $surfaceInterrupted
if ($interruptedOwner.surfaceGroup -ne 'interruption_recovery') { throw "Expected foreground loss to route to interruption_recovery, got $($interruptedOwner.surfaceGroup)" }

$surfaceStale = [pscustomobject]@{ surface = 'settlement_menu'; staleEvidence = $true; operatorInterruptionObserved = $false; foregroundLoss = $false; failureClass = 'runner_evidence_missing' }
$staleOwner = Resolve-RebootSurfaceOwnership -Surface $surfaceStale.surface -Context $surfaceStale
if ($staleOwner.surfaceGroup -ne 'evidence_staleness') { throw "Expected stale evidence to route to evidence_staleness, got $($staleOwner.surfaceGroup)" }

$a = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'run-a')
$b = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'run-b')
if (-not (Test-RebootContextRepeat -A $a -B $b)) { throw 'volatile timestamp/session/pid/path fields must not prevent stable repeat detection' }
if ((ConvertTo-RebootContextFingerprint $a) -match [regex]::Escape($tmpRoot)) { throw 'fingerprint must not include evidence directory path' }
if ($a.surfaceGroup -ne 'outside_town') { throw "campaign map fixture should classify outside_town, got $($a.surfaceGroup)" }
if ($a.stableGapOwner -ne 'outside_town_movement') { throw "campaign map fixture should classify outside_town_movement, got $($a.stableGapOwner)" }
if ($a.likelyOwner -ne $a.stableGapOwner) { throw 'likelyOwner should route through stableGapOwner for current consumers' }
if (-not $a.legacyLikelyOwner) { throw 'legacyLikelyOwner should preserve old heuristic owner' }

$differentFailure = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'different-failure' -FailureClass 'attach_not_ready')
if (Test-RebootContextRepeat -A $a -B $differentFailure) { throw 'different failureClass must not match' }
if ($differentFailure.surfaceGroup -ne 'launcher_attach') { throw "attach_not_ready should route to launcher_attach, got $($differentFailure.surfaceGroup)" }

$differentTargetSource = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'different-target-source' -TargetSource 'RouteCouncil')
if (Test-RebootContextRepeat -A $a -B $differentTargetSource) { throw 'different targetSource must not match' }

$movementPositive = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'movement-positive' -Moved 3.5)
if (Test-RebootContextRepeat -A $a -B $movementPositive) { throw 'movement zero vs positive must not match' }
if ($movementPositive.partyMovedDistanceBucket -eq 'zero' -or -not $movementPositive.partyMovementObserved) { throw 'positive movement must be bucketed and observed' }
if ($movementPositive.surfaceGroup -ne 'outside_town') { throw 'positive campaign movement should still route to outside_town' }

$metricDisagreement = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'metric-disagreement' -Moved 0 `
    -MovementProofClassification 'MovementMetricDisagreement' -MovementDeltas @{ positionChanged = $true; distanceToTargetChanged = $true })
if (-not $metricDisagreement.partyMovementObserved) { throw 'zero distance + metric disagreement must still count as observed movement' }
if ($metricDisagreement.legacyLikelyOwner -eq 'runtime movement') { throw 'metric disagreement should preserve legacy route to movement evidence/classification, not runtime movement' }
if ($metricDisagreement.likelyOwner -ne 'outside_town_movement') { throw 'metric disagreement should route current likelyOwner through outside_town_movement' }
if ($metricDisagreement.movementObservationClass -ne 'movement_metric_disagreement') { throw 'metric disagreement fixture must classify movement_metric_disagreement' }

$indeterminate = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'movement-indeterminate' -Moved 0 `
    -FailureClass 'route_ack_no_motion_proof' -MovementProofClassification 'MovementObservationIndeterminate')
if ($indeterminate.partyMovementObserved) { throw 'indeterminate movement without durable deltas must not count as observed movement' }
if ($indeterminate.legacyLikelyOwner -ne 'movement evidence/classification') { throw 'indeterminate movement should preserve legacy movement evidence/classification owner' }
if ($indeterminate.likelyOwner -ne 'outside_town_movement') { throw 'indeterminate movement should route current likelyOwner through outside_town_movement' }
if ($indeterminate.movementObservationClass -ne 'movement_observation_indeterminate') { throw 'indeterminate movement must classify movement_observation_indeterminate' }

$townContext = New-RebootNormalizedContext -EvidencePath (New-RebootEvidenceFixture -Name 'town-context' -Surface 'settlement_menu' -FailureClass 'town_work_loop_no_action_selected')
if ($townContext.surfaceGroup -ne 'inside_town') { throw "settlement_menu fixture should route to inside_town, got $($townContext.surfaceGroup)" }
if ($townContext.stableGapOwner -ne 'inside_town_settlement_work') { throw "settlement_menu fixture should route to inside_town_settlement_work, got $($townContext.stableGapOwner)" }

$handoffDir = Join-Path $tmpRoot 'handoff'
$handoff = Write-RebootStableGapHandoff -Context $a -EvidenceA 'evidence-A' -EvidenceB 'evidence-B' -OutputDir $handoffDir -CommandsRun @('cmd one') -ValidationState 'offline_test'
$handoffText = Get-Content -LiteralPath $handoff.markdownPath -Raw
foreach ($needle in @('stable_gap','evidence-A','evidence-B','Recommended next patch', 'Movement Evidence', $a.likelyOwner, 'surface group', 'surface owner', 'stable gap owner', 'next patch lane')) {
    if ($handoffText -notmatch [regex]::Escape($needle)) { throw "stable-gap handoff missing $needle" }
}
if (-not (Test-Path -LiteralPath $handoff.jsonPath)) { throw 'stable-gap context json missing' }

Write-Host 'PASS reboot context classifier regression'
