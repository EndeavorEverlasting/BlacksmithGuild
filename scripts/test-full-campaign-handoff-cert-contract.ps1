# Offline full-campaign-handoff cert contract regression. No game launch.
# Proves movement-only / arrival-only / trade-only collapses cannot PASS, and that
# full_campaign_handoff cannot treat movement_observed as a terminal stop.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
. (Join-Path $PSScriptRoot 'automation-boundary-contract.ps1')
. (Join-Path $PSScriptRoot 'full-campaign-handoff-cert.ps1')

$script:PassCount = 0
$script:FailCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        Write-Host "  PASS: $Name"
        $script:PassCount++
    } else {
        Write-Host "  FAIL: $Name"
        $script:FailCount++
    }
}

function New-FullCampaignValidFixture {
    $sessionId = 'offline-full-campaign'
    $runtime = New-Object System.Collections.Generic.List[object]
    $checkpoints = New-Object System.Collections.Generic.List[object]
    $trades = New-Object System.Collections.Generic.List[object]
    $branchLog = New-Object System.Collections.Generic.List[object]

    $cmdId = 'cmd-1'
    Add-AutomationRuntimeEvent -List $runtime -Type 'command.started' -SessionId $sessionId -CycleId 1 `
        -Payload ([pscustomobject]@{ commandId = $cmdId; command = 'AssistiveLeaveTownAndTravel' }) | Out-Null
    Add-AutomationRuntimeEvent -List $runtime -Type 'command.completed' -SessionId $sessionId -CycleId 1 `
        -Payload ([pscustomobject]@{ commandId = $cmdId }) | Out-Null

    $trades.Add((New-TradeIterationRecord -Iteration 1 -ItemName 'iron' -Direction 'buy' `
        -GoldBefore 1000 -GoldAfter 880 -InventoryBefore 0 -InventoryAfter 1 -SessionId $sessionId -CycleId 2)) | Out-Null
    $trades[-1] | Add-Member -NotePropertyName itemClassification -NotePropertyValue 'Ordinary' -Force
    $trades.Add((New-TradeIterationRecord -Iteration 2 -ItemName 'mule' -Direction 'buy' `
        -GoldBefore 880 -GoldAfter 680 -InventoryBefore 0 -InventoryAfter 1 -SessionId $sessionId -CycleId 3)) | Out-Null
    $trades[-1] | Add-Member -NotePropertyName itemClassification -NotePropertyValue 'PackAnimal' -Force
    $trades.Add((New-TradeIterationRecord -Iteration 3 -ItemName 'grain' -Direction 'buy' `
        -GoldBefore 680 -GoldAfter 650 -InventoryBefore 2 -InventoryAfter 3 -SessionId $sessionId -CycleId 4)) | Out-Null
    $trades[-1] | Add-Member -NotePropertyName itemClassification -NotePropertyValue 'Food' -Force

    Add-AutomationCheckpointEvent -List $checkpoints -CheckpointName 'party_movement_observed' `
        -SessionId $sessionId -Phase 'assist_loop' -Runner 'test' -Reason 'moved' | Out-Null
    Add-AutomationCheckpointEvent -List $checkpoints -CheckpointName 'summary_written' `
        -SessionId $sessionId -Phase 'finalize' -Runner 'test' -Reason 'done' | Out-Null
    Complete-AutomationFinalization -List $checkpoints -State pass -SessionId $sessionId `
        -Reason 'full_campaign_handoff_complete' -SummaryWritten $true | Out-Null

    $branchLog.Add([pscustomobject]@{ branch = 'travel'; status = 'executed' }) | Out-Null
    $branchLog.Add([pscustomobject]@{ branch = 'ordinary_trade'; status = 'executed' }) | Out-Null

    $manpower = [pscustomobject]@{
        proven = $true
        acquisitionType = 'companion_recruitment'
        rosterBefore = 3
        rosterAfter = 4
        directInjection = $false
    }

    return [pscustomobject]@{
        runtime = $runtime
        checkpoints = $checkpoints
        trades = $trades
        branchLog = $branchLog
        manpower = $manpower
    }
}

Write-Host ''
Write-Host '=== Full Campaign Handoff Cert Contract Tests ==='

# Source guard: runner must not terminal-stop full_campaign_handoff on movement_observed
$runner = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\run-autonomous-assist-session.ps1') -Raw
Assert-True ($runner -match "ValidateSet\('default', 'economic_loop', 'full_campaign_handoff'\)") 'ValidateSet includes full_campaign_handoff'
Assert-True ($runner -match 'continuing for arrival/town handoff') 'movement_observed continues for full_campaign_handoff'
Assert-True ($runner -match "CertSegment = 'attach'") 'default cert segment is attach (no mega-run)'
Assert-True ($runner -match 'segment_movement_observed') 'segment movement stop reason exists'
Assert-True ($runner -notmatch "allowedPassStops = @\('full_campaign_handoff_complete'\)") 'full-chain complete is not a single-run PASS stop'
Assert-True (Test-FullCampaignHandoffMovementTerminalForbidden -StopReason 'movement_observed' -CertProfile 'full_campaign_handoff') `
    'movement_observed terminal is forbidden for full-chain profile'

$attachBudget = Get-FullCampaignHandoffSegmentBudget -CertSegment 'attach'
$moveBudget = Get-FullCampaignHandoffSegmentBudget -CertSegment 'movement'
Assert-True ($attachBudget.maxRuntimeSec -ge 120) 'attach budget may exceed 30s for campaign load'
Assert-True ($moveBudget.maxRuntimeSec -le 30) 'movement segment budget is <=30s'
Assert-True ((Get-FullCampaignHandoffSegmentBudget -CertSegment 'trade').maxRuntimeSec -le 30) 'trade segment budget is <=30s'
Assert-True ((Get-FullCampaignHandoffSegmentBudget -CertSegment 'manpower').maxRuntimeSec -le 30) 'manpower segment budget is <=30s'

$segMove = Test-FullCampaignHandoffSegmentComplete -CertSegment 'movement' -MovementObserved:$true
Assert-True ($segMove.complete -and -not $segMove.fullChainPass) 'segment movement PASS is not full-chain PASS'
$segTradeFail = Test-FullCampaignHandoffSegmentComplete -CertSegment 'trade' -OrdinaryTradeDone:$false
Assert-True ($segTradeFail.failureClass -eq 'ordinary_trade_delta_missing') 'trade segment names ordinary_trade_delta_missing'

$fx = New-FullCampaignValidFixture
$valid = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true `
    -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades.ToArray()) `
    -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($fx.runtime.ToArray()) `
    -CheckpointEvents @($fx.checkpoints.ToArray()) `
    -BranchConsiderationLog @($fx.branchLog.ToArray())
Assert-True ($valid.pass -eq $true) 'complete valid chain PASSes'

$movementOnly = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'movement_observed' `
    -MovementObserved:$true -ArrivalObserved:$false -TownEntryObserved:$false `
    -GovernorHandoffPresent:$false `
    -TradeIterations @() -ManpowerEvidence $null `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True (($movementOnly.pass -eq $false) -and ($movementOnly.failureClasses -contains 'movement_observed_terminal_forbidden')) `
    'movement-only / movement_observed terminal rejected'
Assert-True ($movementOnly.failureClasses -contains 'arrival_not_observed') 'movement-only missing arrival'

$arrivalOnly = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'timeout' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$false `
    -GovernorHandoffPresent:$false `
    -TradeIterations @($fx.trades[0]) -ManpowerEvidence $null `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($arrivalOnly.failureClasses -contains 'town_entry_not_observed') 'arrival-only missing town entry'

$tradeOnly = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'timeout' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true `
    -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades[0]) -ManpowerEvidence $null `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($tradeOnly.failureClasses -contains 'horse_delta_missing') 'trade-only missing horse'
Assert-True ($tradeOnly.failureClasses -contains 'provision_delta_missing') 'trade-only missing provision'
Assert-True ($tradeOnly.failureClasses -contains 'manpower_delta_missing') 'trade-only missing manpower'

$missingHorse = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades[0], $fx.trades[2]) -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($missingHorse.failureClasses -contains 'horse_delta_missing') 'missing horse rejected'

$missingFood = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades[0], $fx.trades[1]) -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($missingFood.failureClasses -contains 'provision_delta_missing') 'missing provision rejected'

$missingManpower = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades.ToArray()) `
    -ManpowerEvidence ([pscustomobject]@{ proven = $false; directInjection = $false }) `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($missingManpower.failureClasses -contains 'manpower_delta_missing') 'missing manpower rejected'

$dup = New-FullCampaignValidFixture
$dup.trades[1] = $dup.trades[0]
$reused = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($dup.trades.ToArray()) -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($reused.failureClasses -contains 'reused_delta_counted_twice' -or $reused.failureClasses -contains 'horse_delta_missing') `
    'reused delta / missing distinct horse rejected'

$blockedSuccess = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades.ToArray()) -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray()) `
    -BranchConsiderationLog @([pscustomobject]@{ branch = 'trade'; status = 'blocked'; countedAsSuccess = $true })
Assert-True ($blockedSuccess.failureClasses -contains 'blocked_branch_counted_as_success') 'blocked branch counted as success rejected'

$orphanRuntime = New-Object System.Collections.Generic.List[object]
Add-AutomationRuntimeEvent -List $orphanRuntime -Type 'command.started' -SessionId 'x' -CycleId 1 `
    -Payload ([pscustomobject]@{ commandId = 'orphan-1' }) | Out-Null
$orphan = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades.ToArray()) -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($orphanRuntime.ToArray()) -CheckpointEvents @($fx.checkpoints.ToArray())
Assert-True ($orphan.failureClasses -contains 'orphan_command_started') 'orphan command rejected'

$noTerminal = Test-FullCampaignHandoffPassCriteria `
    -StopReason 'full_campaign_handoff_complete' `
    -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -GovernorHandoffPresent:$true `
    -TradeIterations @($fx.trades.ToArray()) -ManpowerEvidence $fx.manpower `
    -RuntimeEvents @($fx.runtime.ToArray()) -CheckpointEvents @()
Assert-True ($noTerminal.failureClasses -contains 'missing_terminal_finalized_pass') 'missing terminal rejected'

$phase = Get-FullCampaignHandoffNextCommand -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true `
    -OrdinaryTradeDone:$false -HorseDone:$false -ProvisionDone:$false -ManpowerDone:$false -Surface 'trading'
Assert-True ($phase.commandSent -eq 'ProbeVanillaTradeExecutionNow') 'phase driver starts with ordinary trade'

$stale = Get-ProvenTradesByClassification -TradeIterations @(
    [pscustomobject]@{
        goldDelta = -10; inventoryDelta = 1; fakeGameplayDelta = $false
        itemClassification = 'Ordinary'; atUtc = '2020-01-01T00:00:00.0000000Z'
    }
) -SinceUtc ([datetime]::Parse('2026-07-18T00:00:00Z').ToUniversalTime())
Assert-True (@($stale.ordinary).Count -eq 0) 'stale trade rows excluded by SinceUtc'

Write-Host ''
Write-Host "=== Results: $($script:PassCount) passed, $($script:FailCount) failed ==="
if ($script:FailCount -gt 0) { exit 1 }
exit 0
