# Automation boundary contract (Agent A).
#
# Boundaries wrap each major runner section with a start/terminal lifecycle so the economic-loop
# certifier can prove that (a) every started section closed, (b) gameplay deltas were observed,
# and (c) no collapse path (one-trade / travel-only / checkpoint-only / observe-only) can PASS.
#
# This file is dot-sourced (no game launch). It depends on the runtime-event envelope defined in
# automation-checkpoint-contract.ps1; dot-source that first, or this file will load it.

if (-not (Get-Command New-AutomationRuntimeEvent -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
}

$script:AutomationBoundarySchemaVersion = 1

# 14 named section boundaries that a recursive economic-loop cycle may open.
$script:AutomationBoundarySectionNames = @(
    'session_bootstrap',
    'observe_runtime_state',
    'select_recursive_branch',
    'validate_branch_gate',
    'map_traversal',
    'execute_trade_iteration',
    'horse_acquisition',
    'inventory_management',
    'smithing_or_prep',
    'rest_wait',
    'evaluate_threat_state',
    'observe_only',
    'write_cycle_summary',
    'finalize_session'
)

# 22 failure classes. Every boundary failure must name exactly one of these.
$script:AutomationBoundaryFailureClasses = @(
    'trade_delta_missing',
    'horse_delta_missing',
    'inventory_delta_missing',
    'smithing_delta_missing',
    'stamina_delta_missing',
    'movement_delta_missing',
    'threat_state_unknown_blocked',
    'branch_gate_blocked',
    'runtime_state_stale',
    'evidence_file_missing',
    'boundary_open_at_finalization',
    'orphan_command_started',
    'fake_gameplay_delta',
    'trade_iteration_target_not_reached',
    'no_non_trade_branch_considered',
    'observe_only_terminal_attempt',
    'checkpoint_only_pass_attempt',
    'malformed_evidence_row',
    'command_completion_missing',
    'branch_selection_invalid',
    'duplicate_terminal_finalization',
    'gameplay_surface_unsafe'
)

# Section -> default emitted runtime event prefix for start/terminal correlation.
$script:AutomationBoundaryStatuses = @('started', 'completed', 'failed', 'blocked', 'skipped')

function Test-AutomationBoundarySectionName {
    param([string]$SectionName)
    return ($script:AutomationBoundarySectionNames -contains $SectionName)
}

function Test-AutomationBoundaryFailureClass {
    param([string]$FailureClass)
    return ($script:AutomationBoundaryFailureClasses -contains $FailureClass)
}

function Start-AutomationBoundary {
    param(
        [Parameter(Mandatory = $true)][string]$SectionName,
        [System.Collections.Generic.List[object]]$Boundaries,
        [System.Collections.Generic.List[object]]$RuntimeEvents = $null,
        [string]$BranchName = $null,
        [string]$SessionId = $null,
        [nullable[int]]$CycleId = $null,
        [string]$Source = 'runner',
        [string]$Reason = $null
    )
    if (-not (Test-AutomationBoundarySectionName -SectionName $SectionName)) {
        throw "Unknown automation boundary sectionName: $SectionName"
    }

    $boundary = [ordered]@{
        schemaVersion = $script:AutomationBoundarySchemaVersion
        boundaryId = [guid]::NewGuid().ToString()
        sessionId = $SessionId
        sectionName = $SectionName
        branchName = $BranchName
        status = 'started'
        startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        endedAtUtc = $null
        failureClass = $null
        reason = $Reason
        evidenceFiles = @()
        eventIds = @()
    }
    if ($null -ne $CycleId) { $boundary.cycleId = [int]$CycleId }
    $boundaryObj = [pscustomobject]$boundary
    if ($null -ne $Boundaries) { $Boundaries.Add($boundaryObj) | Out-Null }

    $evt = Add-AutomationRuntimeEvent -List $RuntimeEvents -Type 'boundary.started' `
        -SessionId $SessionId -CycleId $CycleId -BoundaryId $boundaryObj.boundaryId -Source $Source `
        -Reason $Reason -Payload ([pscustomobject]@{ sectionName = $SectionName; branchName = $BranchName })
    if ($evt) { $boundaryObj.eventIds = @($boundaryObj.eventIds + $evt.eventId) }
    return $boundaryObj
}

function Find-AutomationBoundary {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Boundaries,
        [Parameter(Mandatory = $true)][string]$BoundaryId
    )
    return @($Boundaries.ToArray() | Where-Object { [string]$_.boundaryId -eq $BoundaryId } | Select-Object -First 1)
}

function Set-AutomationBoundaryTerminal {
    param(
        [Parameter(Mandatory = $true)]$Boundary,
        [Parameter(Mandatory = $true)][ValidateSet('completed', 'failed', 'blocked', 'skipped')][string]$Status,
        [System.Collections.Generic.List[object]]$RuntimeEvents = $null,
        [string]$FailureClass = $null,
        [string]$Reason = $null,
        [string[]]$EvidenceFiles = @(),
        [string]$Source = 'runner'
    )
    if ($null -eq $Boundary) { throw 'Set-AutomationBoundaryTerminal requires a boundary object.' }
    if ([string]$Boundary.status -ne 'started') {
        throw "Boundary '$([string]$Boundary.sectionName)' already terminal ($([string]$Boundary.status)); cannot re-close."
    }
    if ($Status -in @('failed', 'blocked')) {
        if ([string]::IsNullOrWhiteSpace($FailureClass)) {
            throw "Boundary $Status requires a failureClass."
        }
        if (-not (Test-AutomationBoundaryFailureClass -FailureClass $FailureClass)) {
            throw "Unknown boundary failureClass: $FailureClass"
        }
    }

    $Boundary.status = $Status
    $Boundary.endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    if ($FailureClass) { $Boundary.failureClass = $FailureClass }
    if ($Reason) { $Boundary.reason = $Reason }
    if ($EvidenceFiles -and $EvidenceFiles.Count -gt 0) { $Boundary.evidenceFiles = @($EvidenceFiles) }

    $cycleId = if ($Boundary.PSObject.Properties.Name -contains 'cycleId') { [int]$Boundary.cycleId } else { $null }
    $evt = Add-AutomationRuntimeEvent -List $RuntimeEvents -Type "boundary.$Status" `
        -SessionId $Boundary.sessionId -CycleId $cycleId -BoundaryId $Boundary.boundaryId -Source $Source `
        -Reason $Reason -Payload ([pscustomobject]@{
            sectionName = $Boundary.sectionName
            branchName = $Boundary.branchName
            failureClass = $FailureClass
            evidenceFiles = @($EvidenceFiles)
        })
    if ($evt) { $Boundary.eventIds = @($Boundary.eventIds + $evt.eventId) }
    return $Boundary
}

function Complete-AutomationBoundary {
    param(
        [Parameter(Mandatory = $true)]$Boundary,
        [System.Collections.Generic.List[object]]$RuntimeEvents = $null,
        [string[]]$EvidenceFiles = @(),
        [string]$Reason = $null
    )
    return Set-AutomationBoundaryTerminal -Boundary $Boundary -Status 'completed' `
        -RuntimeEvents $RuntimeEvents -EvidenceFiles $EvidenceFiles -Reason $Reason
}

function Fail-AutomationBoundary {
    param(
        [Parameter(Mandatory = $true)]$Boundary,
        [Parameter(Mandatory = $true)][string]$FailureClass,
        [System.Collections.Generic.List[object]]$RuntimeEvents = $null,
        [string]$Reason = $null,
        [string[]]$EvidenceFiles = @()
    )
    return Set-AutomationBoundaryTerminal -Boundary $Boundary -Status 'failed' -FailureClass $FailureClass `
        -RuntimeEvents $RuntimeEvents -Reason $Reason -EvidenceFiles $EvidenceFiles
}

function Block-AutomationBoundary {
    param(
        [Parameter(Mandatory = $true)]$Boundary,
        [Parameter(Mandatory = $true)][string]$FailureClass,
        [System.Collections.Generic.List[object]]$RuntimeEvents = $null,
        [string]$Reason = $null
    )
    return Set-AutomationBoundaryTerminal -Boundary $Boundary -Status 'blocked' -FailureClass $FailureClass `
        -RuntimeEvents $RuntimeEvents -Reason $Reason
}

function Skip-AutomationBoundary {
    param(
        [Parameter(Mandatory = $true)]$Boundary,
        [System.Collections.Generic.List[object]]$RuntimeEvents = $null,
        [string]$Reason = $null
    )
    return Set-AutomationBoundaryTerminal -Boundary $Boundary -Status 'skipped' -RuntimeEvents $RuntimeEvents -Reason $Reason
}

function Test-AutomationBoundaryClosure {
    param([object[]]$Boundaries = @())
    $open = @($Boundaries | Where-Object { [string]$_.status -eq 'started' })
    return [pscustomobject][ordered]@{
        closed = ($open.Count -eq 0)
        openCount = $open.Count
        openSections = @($open | ForEach-Object { [string]$_.sectionName })
        totalBoundaries = @($Boundaries).Count
    }
}

function New-TradeIterationRecord {
    param(
        [Parameter(Mandatory = $true)][int]$Iteration,
        [string]$ItemName = $null,
        [Parameter(Mandatory = $true)][int]$GoldBefore,
        [Parameter(Mandatory = $true)][int]$GoldAfter,
        [Parameter(Mandatory = $true)][int]$InventoryBefore,
        [Parameter(Mandatory = $true)][int]$InventoryAfter,
        [string]$Direction = $null,
        [bool]$FakeGameplayDelta = $false,
        [string]$SessionId = $null,
        [nullable[int]]$CycleId = $null
    )
    $rec = [ordered]@{
        schemaVersion = $script:AutomationBoundarySchemaVersion
        iteration = $Iteration
        sessionId = $SessionId
        atUtc = (Get-Date).ToUniversalTime().ToString('o')
        itemName = $ItemName
        direction = $Direction
        goldBefore = $GoldBefore
        goldAfter = $GoldAfter
        goldDelta = ($GoldAfter - $GoldBefore)
        inventoryBefore = $InventoryBefore
        inventoryAfter = $InventoryAfter
        inventoryDelta = ($InventoryAfter - $InventoryBefore)
        fakeGameplayDelta = [bool]$FakeGameplayDelta
    }
    if ($null -ne $CycleId) { $rec.cycleId = [int]$CycleId }
    return [pscustomobject]$rec
}

function Test-TradeIterationProven {
    # A proven trade iteration must show a real, non-faked gold AND inventory change.
    param([Parameter(Mandatory = $true)]$Iteration)
    if ($Iteration.fakeGameplayDelta -eq $true) { return $false }
    $goldDelta = if ($Iteration.PSObject.Properties.Name -contains 'goldDelta') {
        [int]$Iteration.goldDelta
    } else {
        [int]$Iteration.goldAfter - [int]$Iteration.goldBefore
    }
    $invDelta = if ($Iteration.PSObject.Properties.Name -contains 'inventoryDelta') {
        [int]$Iteration.inventoryDelta
    } else {
        [int]$Iteration.inventoryAfter - [int]$Iteration.inventoryBefore
    }
    return (($goldDelta -ne 0) -and ($invDelta -ne 0))
}

function Get-AutomationOrphanCommandStarts {
    # Returns command.started runtime events that never reached command.completed/command.failed.
    param([object[]]$RuntimeEvents = @())
    $byId = @{}
    $unkeyedStarted = 0
    $unkeyedClosed = 0
    foreach ($evt in @($RuntimeEvents)) {
        $type = [string]$evt.type
        if ($type -notmatch '^command\.') { continue }
        $cmdId = $null
        if ($evt.payload -and ($evt.payload.PSObject.Properties.Name -contains 'commandId')) {
            $cmdId = [string]$evt.payload.commandId
        }
        if ([string]::IsNullOrWhiteSpace($cmdId)) {
            if ($type -eq 'command.started') { $unkeyedStarted++ }
            elseif ($type -in @('command.completed', 'command.failed')) { $unkeyedClosed++ }
            continue
        }
        if (-not $byId.ContainsKey($cmdId)) { $byId[$cmdId] = @{ started = $false; closed = $false } }
        if ($type -eq 'command.started') { $byId[$cmdId].started = $true }
        elseif ($type -in @('command.completed', 'command.failed')) { $byId[$cmdId].closed = $true }
    }
    $orphans = New-Object System.Collections.Generic.List[string]
    foreach ($k in $byId.Keys) {
        if ($byId[$k].started -and -not $byId[$k].closed) { $orphans.Add($k) | Out-Null }
    }
    $unkeyedOrphans = [Math]::Max(0, $unkeyedStarted - $unkeyedClosed)
    return [pscustomobject][ordered]@{
        orphanCount = ($orphans.Count + $unkeyedOrphans)
        keyedOrphans = @($orphans.ToArray())
        unkeyedOrphans = $unkeyedOrphans
    }
}

function Test-AutomationEconomicLoopPassCriteria {
    param(
        [object[]]$Boundaries = @(),
        [object[]]$RuntimeEvents = @(),
        [object[]]$TradeIterations = @(),
        [object[]]$BranchConsiderationLog = @(),
        [object[]]$CheckpointEvents = @(),
        [int]$TradeIterationTarget = 10
    )

    $closure = Test-AutomationBoundaryClosure -Boundaries $Boundaries

    $provenTrades = @($TradeIterations | Where-Object { Test-TradeIterationProven -Iteration $_ })
    $fakeTrades = @($TradeIterations | Where-Object { $_.fakeGameplayDelta -eq $true })

    # Non-trade branch must have been considered with executed/blocked evidence (not observe_only alone).
    $nonTradeConsidered = @($BranchConsiderationLog | Where-Object {
        ([string]$_.branch -notin @('trade', 'observe_only', '')) -and
        ([string]$_.status -in @('executed', 'completed', 'blocked'))
    })

    $orphans = Get-AutomationOrphanCommandStarts -RuntimeEvents $RuntimeEvents

    $finalizedPass = @($CheckpointEvents | Where-Object { $_.eventType -eq 'finalized_pass' -and $_.isTerminal -eq $true })
    $terminalEvents = @($CheckpointEvents | Where-Object { $_.isTerminal -eq $true })

    $criteria = [ordered]@{
        pass = $false
        tradeIterationTarget = $TradeIterationTarget
        targetIsTen = ($TradeIterationTarget -eq 10)
        provenTradeIterationCount = $provenTrades.Count
        tradeIterationTargetReached = ($provenTrades.Count -ge $TradeIterationTarget)
        noFakeGameplayDelta = ($fakeTrades.Count -eq 0)
        boundariesClosed = $closure.closed
        openBoundaryCount = $closure.openCount
        nonTradeBranchConsidered = ($nonTradeConsidered.Count -gt 0)
        noOrphanCommandStarted = ($orphans.orphanCount -eq 0)
        singleFinalizedPass = ($finalizedPass.Count -eq 1 -and $terminalEvents.Count -eq 1)
        failureClasses = @()
    }

    $failures = New-Object System.Collections.Generic.List[string]
    if (-not $criteria.targetIsTen) { $failures.Add('trade_iteration_target_not_reached') | Out-Null }
    if (-not $criteria.tradeIterationTargetReached) { $failures.Add('trade_iteration_target_not_reached') | Out-Null }
    if (-not $criteria.noFakeGameplayDelta) { $failures.Add('fake_gameplay_delta') | Out-Null }
    if (-not $criteria.boundariesClosed) { $failures.Add('boundary_open_at_finalization') | Out-Null }
    if (-not $criteria.nonTradeBranchConsidered) { $failures.Add('no_non_trade_branch_considered') | Out-Null }
    if (-not $criteria.noOrphanCommandStarted) { $failures.Add('orphan_command_started') | Out-Null }
    if (-not $criteria.singleFinalizedPass) { $failures.Add('checkpoint_only_pass_attempt') | Out-Null }

    $criteria.failureClasses = @($failures.ToArray() | Select-Object -Unique)
    $criteria.pass = ($criteria.failureClasses.Count -eq 0)
    return [pscustomobject]$criteria
}

function Write-AutomationBoundaryEventsFile {
    param(
        [object[]]$Boundaries,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $lines = @($Boundaries | Where-Object { $null -ne $_ } | ForEach-Object { $_ | ConvertTo-Json -Depth 12 -Compress })
    if ($lines.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value '' -Encoding UTF8
    } else {
        Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
    }
    return $Path
}
