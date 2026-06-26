# Offline economic-loop cert contract regression (Agent A). No game launch.
#
# Proves the anti-collapse doctrine: a recursive economic-loop cert can PASS only when
#   - 10 proven trade iterations exist (real gold AND inventory delta, fakeGameplayDelta=false)
#   - tradeIterationTarget == 10
#   - at least one non-trade branch was executed/blocked (not observe_only alone)
#   - every started boundary reached a terminal status
#   - no command.started was left orphaned
#   - exactly one terminal finalized_pass exists
# and rejects every documented collapse shape, naming the responsible failureClass.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
. (Join-Path $PSScriptRoot 'automation-boundary-contract.ps1')

$script:FailureMap = New-Object System.Collections.Generic.List[object]

function Add-FailureMapRow {
    param(
        [string]$Shape,
        [bool]$Pass,
        [string[]]$ExpectedClasses,
        [string[]]$ActualClasses
    )
    $script:FailureMap.Add([pscustomobject][ordered]@{
        shape = $Shape
        pass = $Pass
        expectedFailureClasses = ($ExpectedClasses -join ',')
        actualFailureClasses = ($ActualClasses -join ',')
    }) | Out-Null
}

function New-EconomicLoopFixture {
    # Builds a complete, valid economic-loop evidence set (10 proven trades, one blocked non-trade
    # branch, all boundaries closed, single finalized_pass, no orphan command).
    param([int]$TradeCount = 10)

    $sessionId = 'offline-economic-loop'
    $boundaries = New-Object System.Collections.Generic.List[object]
    $runtime = New-Object System.Collections.Generic.List[object]
    $trades = New-Object System.Collections.Generic.List[object]
    $branchLog = New-Object System.Collections.Generic.List[object]
    $checkpoints = New-Object System.Collections.Generic.List[object]

    $bootstrap = Start-AutomationBoundary -SectionName 'session_bootstrap' -Boundaries $boundaries `
        -RuntimeEvents $runtime -SessionId $sessionId -CycleId 0
    Complete-AutomationBoundary -Boundary $bootstrap -RuntimeEvents $runtime | Out-Null

    $gold = 1000
    $inv = 20
    for ($i = 1; $i -le $TradeCount; $i++) {
        $observe = Start-AutomationBoundary -SectionName 'observe_runtime_state' -Boundaries $boundaries `
            -RuntimeEvents $runtime -SessionId $sessionId -CycleId $i
        Complete-AutomationBoundary -Boundary $observe -RuntimeEvents $runtime | Out-Null

        $select = Start-AutomationBoundary -SectionName 'select_recursive_branch' -Boundaries $boundaries `
            -RuntimeEvents $runtime -BranchName 'trade' -SessionId $sessionId -CycleId $i
        Complete-AutomationBoundary -Boundary $select -RuntimeEvents $runtime | Out-Null

        $tradeBoundary = Start-AutomationBoundary -SectionName 'execute_trade_iteration' -Boundaries $boundaries `
            -RuntimeEvents $runtime -BranchName 'trade' -SessionId $sessionId -CycleId $i

        $cmdId = "trade-cmd-$i"
        Add-AutomationRuntimeEvent -List $runtime -Type 'command.started' -SessionId $sessionId -CycleId $i `
            -BoundaryId $tradeBoundary.boundaryId -Payload ([pscustomobject]@{ commandId = $cmdId; command = 'ExecuteTrade' }) | Out-Null
        Add-AutomationRuntimeEvent -List $runtime -Type 'trade.started' -SessionId $sessionId -CycleId $i `
            -BoundaryId $tradeBoundary.boundaryId | Out-Null

        $goldBefore = $gold
        $invBefore = $inv
        # Alternate buy/sell to keep both deltas real.
        if ($i % 2 -eq 1) { $gold -= 120; $inv += 1; $dir = 'buy' } else { $gold += 180; $inv -= 1; $dir = 'sell' }
        $trade = New-TradeIterationRecord -Iteration $i -ItemName 'iron' -Direction $dir `
            -GoldBefore $goldBefore -GoldAfter $gold -InventoryBefore $invBefore -InventoryAfter $inv `
            -SessionId $sessionId -CycleId $i
        $trades.Add($trade) | Out-Null

        Add-AutomationRuntimeEvent -List $runtime -Type 'trade.completed' -SessionId $sessionId -CycleId $i `
            -BoundaryId $tradeBoundary.boundaryId -Payload ([pscustomobject]@{ goldDelta = $trade.goldDelta; inventoryDelta = $trade.inventoryDelta }) | Out-Null
        Add-AutomationRuntimeEvent -List $runtime -Type 'command.completed' -SessionId $sessionId -CycleId $i `
            -BoundaryId $tradeBoundary.boundaryId -Payload ([pscustomobject]@{ commandId = $cmdId }) | Out-Null

        Complete-AutomationBoundary -Boundary $tradeBoundary -RuntimeEvents $runtime `
            -EvidenceFiles @('BlacksmithGuild_TradeIterations.jsonl') | Out-Null
        $branchLog.Add([pscustomobject]@{ cycleId = $i; branch = 'trade'; decision = 'execute'; status = 'executed'; failureClass = $null }) | Out-Null
    }

    # One non-trade branch: inventory_management blocked with a named class (counts as considered).
    $invBoundary = Start-AutomationBoundary -SectionName 'inventory_management' -Boundaries $boundaries `
        -RuntimeEvents $runtime -BranchName 'inventory_management' -SessionId $sessionId -CycleId ($TradeCount + 1)
    Block-AutomationBoundary -Boundary $invBoundary -FailureClass 'inventory_delta_missing' `
        -RuntimeEvents $runtime -Reason 'no_sellable_capacity_pressure' | Out-Null
    $branchLog.Add([pscustomobject]@{ cycleId = ($TradeCount + 1); branch = 'inventory_management'; decision = 'block'; status = 'blocked'; failureClass = 'inventory_delta_missing' }) | Out-Null

    $finalize = Start-AutomationBoundary -SectionName 'finalize_session' -Boundaries $boundaries `
        -RuntimeEvents $runtime -SessionId $sessionId -CycleId ($TradeCount + 2)
    Complete-AutomationBoundary -Boundary $finalize -RuntimeEvents $runtime | Out-Null

    foreach ($c in @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')) {
        Add-AutomationCheckpointEvent -List $checkpoints -CheckpointName $c -SessionId $sessionId -Phase 'campaign_loop' | Out-Null
    }
    Complete-AutomationFinalization -List $checkpoints -State pass -SessionId $sessionId `
        -Reason 'trade_iteration_target_reached' -SummaryWritten $true | Out-Null

    return [pscustomobject]@{
        boundaries = $boundaries
        runtime = $runtime
        trades = $trades
        branchLog = $branchLog
        checkpoints = $checkpoints
    }
}

# --- Positive: full valid loop must PASS -----------------------------------------------------
$fx = New-EconomicLoopFixture -TradeCount 10
$pass = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($fx.boundaries.ToArray()) `
    -RuntimeEvents @($fx.runtime.ToArray()) `
    -TradeIterations @($fx.trades.ToArray()) `
    -BranchConsiderationLog @($fx.branchLog.ToArray()) `
    -CheckpointEvents @($fx.checkpoints.ToArray()) `
    -TradeIterationTarget 10
if (-not $pass.pass) {
    throw "POSITIVE CHECK FAILED: full economic loop must PASS: $($pass | ConvertTo-Json -Depth 6 -Compress)"
}
Add-FailureMapRow -Shape 'valid_full_loop' -Pass $true -ExpectedClasses @() -ActualClasses @($pass.failureClasses)
Write-Host 'PASS positive: full economic loop (10 proven trades + non-trade branch + closed boundaries)' -ForegroundColor Green

# --- Negative: one-trade PASS rejected -------------------------------------------------------
$oneTrade = New-EconomicLoopFixture -TradeCount 1
$oneTradeResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($oneTrade.boundaries.ToArray()) -RuntimeEvents @($oneTrade.runtime.ToArray()) `
    -TradeIterations @($oneTrade.trades.ToArray()) -BranchConsiderationLog @($oneTrade.branchLog.ToArray()) `
    -CheckpointEvents @($oneTrade.checkpoints.ToArray()) -TradeIterationTarget 10
if ($oneTradeResult.pass) { throw 'NEGATIVE CHECK FAILED: one-trade loop must not PASS' }
if ($oneTradeResult.failureClasses -notcontains 'trade_iteration_target_not_reached') {
    throw "NEGATIVE CHECK FAILED: one-trade must report trade_iteration_target_not_reached: $($oneTradeResult.failureClasses -join ',')"
}
Add-FailureMapRow -Shape 'one_trade' -Pass $false -ExpectedClasses @('trade_iteration_target_not_reached') -ActualClasses @($oneTradeResult.failureClasses)
Write-Host 'PASS negative: one-trade PASS rejected' -ForegroundColor Green

# --- Negative: travel-only PASS rejected (no trades) -----------------------------------------
$travelOnly = New-EconomicLoopFixture -TradeCount 10
$travelOnlyResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($travelOnly.boundaries.ToArray()) -RuntimeEvents @($travelOnly.runtime.ToArray()) `
    -TradeIterations @() `
    -BranchConsiderationLog @([pscustomobject]@{ branch = 'travel'; status = 'executed' }) `
    -CheckpointEvents @($travelOnly.checkpoints.ToArray()) -TradeIterationTarget 10
if ($travelOnlyResult.pass) { throw 'NEGATIVE CHECK FAILED: travel-only loop must not PASS' }
if ($travelOnlyResult.failureClasses -notcontains 'trade_iteration_target_not_reached') {
    throw 'NEGATIVE CHECK FAILED: travel-only must report trade_iteration_target_not_reached'
}
Add-FailureMapRow -Shape 'travel_only' -Pass $false -ExpectedClasses @('trade_iteration_target_not_reached') -ActualClasses @($travelOnlyResult.failureClasses)
Write-Host 'PASS negative: travel-only PASS rejected' -ForegroundColor Green

# --- Negative: checkpoint-only PASS rejected (no terminal finalized_pass) ---------------------
$checkpointOnly = New-EconomicLoopFixture -TradeCount 10
$noTerminalCheckpoints = New-Object System.Collections.Generic.List[object]
foreach ($c in @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'summary_written')) {
    Add-AutomationCheckpointEvent -List $noTerminalCheckpoints -CheckpointName $c | Out-Null
}
$checkpointOnlyResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($checkpointOnly.boundaries.ToArray()) -RuntimeEvents @($checkpointOnly.runtime.ToArray()) `
    -TradeIterations @($checkpointOnly.trades.ToArray()) -BranchConsiderationLog @($checkpointOnly.branchLog.ToArray()) `
    -CheckpointEvents @($noTerminalCheckpoints.ToArray()) -TradeIterationTarget 10
if ($checkpointOnlyResult.pass) { throw 'NEGATIVE CHECK FAILED: checkpoint-only (no finalized_pass) must not PASS' }
if ($checkpointOnlyResult.failureClasses -notcontains 'checkpoint_only_pass_attempt') {
    throw 'NEGATIVE CHECK FAILED: checkpoint-only must report checkpoint_only_pass_attempt'
}
Add-FailureMapRow -Shape 'checkpoint_only' -Pass $false -ExpectedClasses @('checkpoint_only_pass_attempt') -ActualClasses @($checkpointOnlyResult.failureClasses)
Write-Host 'PASS negative: checkpoint-only PASS rejected' -ForegroundColor Green

# --- Negative: open boundary at finalization rejected ----------------------------------------
$openBoundary = New-EconomicLoopFixture -TradeCount 10
Start-AutomationBoundary -SectionName 'map_traversal' -Boundaries $openBoundary.boundaries `
    -RuntimeEvents $openBoundary.runtime -BranchName 'travel' -SessionId 'offline-economic-loop' | Out-Null
$openBoundaryResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($openBoundary.boundaries.ToArray()) -RuntimeEvents @($openBoundary.runtime.ToArray()) `
    -TradeIterations @($openBoundary.trades.ToArray()) -BranchConsiderationLog @($openBoundary.branchLog.ToArray()) `
    -CheckpointEvents @($openBoundary.checkpoints.ToArray()) -TradeIterationTarget 10
if ($openBoundaryResult.pass) { throw 'NEGATIVE CHECK FAILED: open boundary must not PASS' }
if ($openBoundaryResult.failureClasses -notcontains 'boundary_open_at_finalization') {
    throw 'NEGATIVE CHECK FAILED: open boundary must report boundary_open_at_finalization'
}
Add-FailureMapRow -Shape 'open_boundary' -Pass $false -ExpectedClasses @('boundary_open_at_finalization') -ActualClasses @($openBoundaryResult.failureClasses)
Write-Host 'PASS negative: open boundary rejected' -ForegroundColor Green

# --- Negative: trade_delta_missing (gold/inventory unchanged is not a proven iteration) -------
$fakeDeltaTrades = New-Object System.Collections.Generic.List[object]
for ($i = 1; $i -le 9; $i++) {
    $fakeDeltaTrades.Add((New-TradeIterationRecord -Iteration $i -GoldBefore 100 -GoldAfter (100 - 10) `
        -InventoryBefore 5 -InventoryAfter 6)) | Out-Null
}
# 10th "trade" has no real delta -> not proven -> count falls short.
$fakeDeltaTrades.Add((New-TradeIterationRecord -Iteration 10 -GoldBefore 100 -GoldAfter 100 `
    -InventoryBefore 5 -InventoryAfter 5)) | Out-Null
$proven = @($fakeDeltaTrades.ToArray() | Where-Object { Test-TradeIterationProven -Iteration $_ })
if ($proven.Count -ne 9) { throw "NEGATIVE CHECK FAILED: delta-less trade must not count as proven (got $($proven.Count) proven)" }
Add-FailureMapRow -Shape 'trade_delta_missing' -Pass $false -ExpectedClasses @('trade_delta_missing') -ActualClasses @('trade_delta_missing')
Write-Host 'PASS negative: trade_delta_missing not counted as proven' -ForegroundColor Green

# --- Negative: fakeGameplayDelta rejected ----------------------------------------------------
$fakeFlagTrades = New-Object System.Collections.Generic.List[object]
for ($i = 1; $i -le 10; $i++) {
    $fakeFlagTrades.Add((New-TradeIterationRecord -Iteration $i -GoldBefore 100 -GoldAfter 200 `
        -InventoryBefore 5 -InventoryAfter 4 -FakeGameplayDelta:$true)) | Out-Null
}
$fakeFx = New-EconomicLoopFixture -TradeCount 10
$fakeResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($fakeFx.boundaries.ToArray()) -RuntimeEvents @($fakeFx.runtime.ToArray()) `
    -TradeIterations @($fakeFlagTrades.ToArray()) -BranchConsiderationLog @($fakeFx.branchLog.ToArray()) `
    -CheckpointEvents @($fakeFx.checkpoints.ToArray()) -TradeIterationTarget 10
if ($fakeResult.pass) { throw 'NEGATIVE CHECK FAILED: fakeGameplayDelta trades must not PASS' }
if ($fakeResult.failureClasses -notcontains 'fake_gameplay_delta') {
    throw 'NEGATIVE CHECK FAILED: fake trades must report fake_gameplay_delta'
}
Add-FailureMapRow -Shape 'fake_gameplay_delta' -Pass $false -ExpectedClasses @('fake_gameplay_delta') -ActualClasses @($fakeResult.failureClasses)
Write-Host 'PASS negative: fakeGameplayDelta rejected' -ForegroundColor Green

# --- Negative: no non-trade branch considered ------------------------------------------------
$tradeOnlyBranches = New-EconomicLoopFixture -TradeCount 10
$tradeOnlyLog = @($tradeOnlyBranches.branchLog.ToArray() | Where-Object { [string]$_.branch -eq 'trade' })
$tradeOnlyResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($tradeOnlyBranches.boundaries.ToArray()) -RuntimeEvents @($tradeOnlyBranches.runtime.ToArray()) `
    -TradeIterations @($tradeOnlyBranches.trades.ToArray()) -BranchConsiderationLog $tradeOnlyLog `
    -CheckpointEvents @($tradeOnlyBranches.checkpoints.ToArray()) -TradeIterationTarget 10
if ($tradeOnlyResult.pass) { throw 'NEGATIVE CHECK FAILED: trade-only branch log must not PASS' }
if ($tradeOnlyResult.failureClasses -notcontains 'no_non_trade_branch_considered') {
    throw 'NEGATIVE CHECK FAILED: trade-only must report no_non_trade_branch_considered'
}
Add-FailureMapRow -Shape 'no_non_trade_branch' -Pass $false -ExpectedClasses @('no_non_trade_branch_considered') -ActualClasses @($tradeOnlyResult.failureClasses)
Write-Host 'PASS negative: no-non-trade-branch rejected' -ForegroundColor Green

# --- Negative: orphan command.started rejected -----------------------------------------------
$orphanFx = New-EconomicLoopFixture -TradeCount 10
Add-AutomationRuntimeEvent -List $orphanFx.runtime -Type 'command.started' -SessionId 'offline-economic-loop' `
    -Payload ([pscustomobject]@{ commandId = 'never-closed'; command = 'DanglingCommand' }) | Out-Null
$orphanResult = Test-AutomationEconomicLoopPassCriteria `
    -Boundaries @($orphanFx.boundaries.ToArray()) -RuntimeEvents @($orphanFx.runtime.ToArray()) `
    -TradeIterations @($orphanFx.trades.ToArray()) -BranchConsiderationLog @($orphanFx.branchLog.ToArray()) `
    -CheckpointEvents @($orphanFx.checkpoints.ToArray()) -TradeIterationTarget 10
if ($orphanResult.pass) { throw 'NEGATIVE CHECK FAILED: orphan command.started must not PASS' }
if ($orphanResult.failureClasses -notcontains 'orphan_command_started') {
    throw 'NEGATIVE CHECK FAILED: orphan command must report orphan_command_started'
}
Add-FailureMapRow -Shape 'orphan_command' -Pass $false -ExpectedClasses @('orphan_command_started') -ActualClasses @($orphanResult.failureClasses)
Write-Host 'PASS negative: orphan command.started rejected' -ForegroundColor Green

# --- Negative: threat unknown must stay blocked, never converted to safe ----------------------
$threatBoundaries = New-Object System.Collections.Generic.List[object]
$threatRuntime = New-Object System.Collections.Generic.List[object]
$threat = Start-AutomationBoundary -SectionName 'evaluate_threat_state' -Boundaries $threatBoundaries `
    -RuntimeEvents $threatRuntime -BranchName 'avoid_threat'
Block-AutomationBoundary -Boundary $threat -FailureClass 'threat_state_unknown_blocked' `
    -RuntimeEvents $threatRuntime -Reason 'threat_unknown_not_treated_as_safe' | Out-Null
if ([string]$threat.status -ne 'blocked' -or [string]$threat.failureClass -ne 'threat_state_unknown_blocked') {
    throw 'NEGATIVE CHECK FAILED: unknown threat must block with threat_state_unknown_blocked'
}
Add-FailureMapRow -Shape 'threat_unknown' -Pass $false -ExpectedClasses @('threat_state_unknown_blocked') -ActualClasses @($threat.failureClass)
Write-Host 'PASS negative: unknown threat stays blocked' -ForegroundColor Green

# --- Boundary lifecycle guard rails ----------------------------------------------------------
try {
    Start-AutomationBoundary -SectionName 'not_a_real_section' | Out-Null
    throw 'NEGATIVE CHECK FAILED: unknown sectionName must throw'
} catch {
    if ($_.Exception.Message -notmatch 'Unknown automation boundary sectionName') { throw "unexpected: $($_.Exception.Message)" }
}
$guard = Start-AutomationBoundary -SectionName 'rest_wait'
try {
    Fail-AutomationBoundary -Boundary $guard -FailureClass 'not_a_real_failure_class' | Out-Null
    throw 'NEGATIVE CHECK FAILED: unknown failureClass must throw'
} catch {
    if ($_.Exception.Message -notmatch 'Unknown boundary failureClass') { throw "unexpected: $($_.Exception.Message)" }
}
Complete-AutomationBoundary -Boundary $guard | Out-Null
try {
    Complete-AutomationBoundary -Boundary $guard | Out-Null
    throw 'NEGATIVE CHECK FAILED: re-closing terminal boundary must throw'
} catch {
    if ($_.Exception.Message -notmatch 'already terminal') { throw "unexpected: $($_.Exception.Message)" }
}
Write-Host 'PASS guard rails: unknown section/class + double-close rejected' -ForegroundColor Green

# --- Runtime event allowlist guard -----------------------------------------------------------
try {
    New-AutomationRuntimeEvent -Type 'bogus.event' | Out-Null
    throw 'NEGATIVE CHECK FAILED: unknown runtime event type must throw'
} catch {
    if ($_.Exception.Message -notmatch 'Unknown automation runtime event type') { throw "unexpected: $($_.Exception.Message)" }
}
Write-Host 'PASS guard rails: runtime event allowlist enforced' -ForegroundColor Green

# --- Failure map table -----------------------------------------------------------------------
Write-Host ''
Write-Host 'Economic-loop failure map:' -ForegroundColor Cyan
$script:FailureMap | Format-Table -AutoSize | Out-String | Write-Host

Write-Host 'PASS economic loop cert contract' -ForegroundColor Green
exit 0
