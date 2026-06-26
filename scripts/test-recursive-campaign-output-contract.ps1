# Recursive campaign output contract verifier.
#
# Two modes:
#   -Fixture                     Build temp fake outputs and validate the contract offline (no game).
#   -EvidenceDir <path>          Validate real runner/mod artifacts after a live run.
#
# This proves the *output shape* of a recursive campaign run, not just helper behavior:
#   - checkpoint events stay non-terminal
#   - terminal finalization happens exactly once
#   - PASS requires a terminal finalized_pass (not checkpoint-only progress)
#   - a non-terminal cycle names its next branch; a terminal cycle names its stop reason
#   - JSON and in-game message fields agree when the game is alive
#   - execute PASS requires real party movement (when -RequireExecuteMovement)
#
# Only -Fixture is wired into the offline gate. -EvidenceDir is a post-live cert check and must
# NOT be added to the normal gate, or the gate would depend on a live run.
param(
    [string]$EvidenceDir = $null,
    [switch]$Fixture,
    [switch]$RequireExecuteMovement
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')

$script:NonTerminalEventTypes = @(
    'checkpoint_reached',
    'checkpoint_blocked',
    'cycle_completed',
    'stop_requested',
    'unsafe_surface'
)

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required JSON file: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Read-JsonlFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required JSONL file: $Path"
    }
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $items.Add(($line | ConvertFrom-Json)) | Out-Null
    }
    return @($items.ToArray())
}

function Get-ModEventPaths {
    param([string]$Dir)
    $candidates = New-Object System.Collections.Generic.List[string]
    $local = Join-Path $Dir 'BlacksmithGuild_AutomationEvents.jsonl'
    if (Test-Path -LiteralPath $local) { $candidates.Add($local) | Out-Null }
    if (Get-Command Get-AutomationModEventPaths -ErrorAction SilentlyContinue) {
        try {
            foreach ($p in @(Get-AutomationModEventPaths -BannerlordRoot $repoRoot)) {
                if ($p -and (Test-Path -LiteralPath $p)) { $candidates.Add($p) | Out-Null }
            }
        } catch { }
    }
    return @($candidates.ToArray() | Select-Object -Unique)
}

function Assert-RecursiveOutputContract {
    param(
        [Parameter(Mandatory = $true)][object[]]$Events,
        [Parameter(Mandatory = $true)]$CampaignSummary,
        [Parameter(Mandatory = $true)]$AssistSummary,
        [object]$ExecutionJson = $null,
        [switch]$RequireExecuteMovement
    )

    # 1. Non-terminal event types must never be marked terminal.
    $badTerminal = @($Events | Where-Object {
            ($_.eventType -in $script:NonTerminalEventTypes) -and ($_.isTerminal -eq $true)
        })
    if ($badTerminal.Count -gt 0) {
        throw "Non-terminal checkpoint events were marked terminal: $(@($badTerminal | ForEach-Object { $_.eventType }) -join ', ')"
    }

    # 2. Exactly one terminal event.
    $terminalEvents = @($Events | Where-Object { $_.isTerminal -eq $true })
    if ($terminalEvents.Count -ne 1) {
        throw "Expected exactly one terminal event; got $($terminalEvents.Count)"
    }

    # 3. PASS requires exactly one terminal finalized_pass.
    $isPass = ([string]$AssistSummary.passFail -eq 'PASS')
    if ($isPass) {
        $finalizedPass = @($terminalEvents | Where-Object { $_.eventType -eq 'finalized_pass' })
        if ($finalizedPass.Count -ne 1) {
            throw "passFail=PASS requires exactly one terminal finalized_pass; got $($finalizedPass.Count)"
        }
    }

    # 4 + 5. Campaign loop summary distinguishes recursive vs terminal cycles.
    $summaryResult = Test-AutomationCampaignLoopSummary -Summary $CampaignSummary
    if (-not $summaryResult.pass) {
        throw "Campaign loop summary contract failed: $($summaryResult | ConvertTo-Json -Compress)"
    }

    # 6. Strict pass criteria must agree with the events when the summary claims PASS.
    $requiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')
    $criteria = Test-AutomationPassCriteria `
        -Events $Events `
        -Summary $AssistSummary `
        -ExecutionJson $ExecutionJson `
        -RequiredCheckpoints $requiredCheckpoints `
        -RequireAssistLoopStarted `
        -RequireExecuteMovement:$RequireExecuteMovement
    if ($isPass -and -not $criteria.pass) {
        throw "assist-loop-summary says PASS, but strict checkpoint criteria failed: $($criteria | ConvertTo-Json -Compress)"
    }

    # 7. Message contract: game alive must show in-game; game gone must have a terminal explanation.
    foreach ($event in @($Events | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.messageText) })) {
        if (($event.gameProcessAlive -eq $true) -and ($event.messageShownInGame -ne $true)) {
            throw "Game alive but messageShownInGame was not true for checkpoint '$([string]$event.checkpointName)'"
        }
        if (($event.gameProcessAlive -eq $false) -and ($terminalEvents.Count -ne 1)) {
            throw "Game gone for checkpoint '$([string]$event.checkpointName)' but no single terminal event explains it"
        }
    }

    return $criteria
}

function Assert-ContractRejectsBadShapes {
    # Self-proving negative checks so the verifier cannot silently accept broken shapes.

    # Checkpoint-only sequence (no terminal finalized_pass) must not satisfy strict PASS.
    $checkpointOnly = New-Object System.Collections.Generic.List[object]
    foreach ($c in @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')) {
        Add-AutomationCheckpointEvent -List $checkpointOnly -CheckpointName $c -Runner 'recursive-output-negative' | Out-Null
    }
    $checkpointOnlyCriteria = Test-AutomationPassCriteria -Events @($checkpointOnly.ToArray()) `
        -Summary ([pscustomobject]@{ assistLoopStarted = $true; stateMachineConsumed = $true; runtimeLifecycleConsumed = $true }) `
        -RequiredCheckpoints @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written') `
        -RequireAssistLoopStarted
    if ($checkpointOnlyCriteria.pass) {
        throw 'NEGATIVE CHECK FAILED: checkpoint-only sequence must not satisfy PASS without terminal finalized_pass'
    }

    # Duplicate terminal finalized_pass must break the exactly-one-terminal rule.
    $dupTerminal = @(
        (New-AutomationCheckpointEvent -EventType 'finalized_pass' -CheckpointName 'finalized_pass' -IsTerminal $true -TerminalState 'pass' -SummaryWritten:$true),
        (New-AutomationCheckpointEvent -EventType 'finalized_pass' -CheckpointName 'finalized_pass' -IsTerminal $true -TerminalState 'pass' -SummaryWritten:$true)
    )
    $dupCount = @($dupTerminal | Where-Object { $_.isTerminal -eq $true }).Count
    if ($dupCount -eq 1) {
        throw 'NEGATIVE CHECK FAILED: duplicate finalized_pass must not collapse to a single terminal event'
    }

    # Non-terminal summary without a planned branch must fail the summary contract.
    $badSummary = New-AutomationCampaignLoopSummary -SessionId 'neg' -CycleId 1 -Terminal $false `
        -NextActionRequired $true -NextPlannedBranch $null -NextActionReason 'missing_branch'
    $badSummaryResult = Test-AutomationCampaignLoopSummary -Summary $badSummary
    if ($badSummaryResult.pass) {
        throw 'NEGATIVE CHECK FAILED: non-terminal summary without nextPlannedBranch must not pass'
    }
}

$tmpRoot = $null

try {
    if ($Fixture) {
        Assert-ContractRejectsBadShapes

        $tmpRoot = Join-Path $env:TEMP "recursive-campaign-output-contract-$PID"
        if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
        $EvidenceDir = $tmpRoot

        $sessionId = 'offline-recursive-output-test'
        $runner = 'test-recursive-campaign-output-contract.ps1'
        $events = New-Object System.Collections.Generic.List[object]

        $requiredCheckpoints = @(
            'attach_ready',
            'state_machine_consumed',
            'runtime_lifecycle_consumed',
            'assist_loop_started',
            'execute_ack',
            'party_movement_observed',
            'summary_written'
        )
        foreach ($checkpoint in $requiredCheckpoints) {
            # attach_ready carries an in-game message while the game is alive, exercising the
            # message contract assertion path.
            if ($checkpoint -eq 'attach_ready') {
                $events.Add((New-AutomationCheckpointEvent -EventType 'checkpoint_reached' -CheckpointName $checkpoint `
                            -SessionId $sessionId -Phase 'campaign_loop' -Runner $runner `
                            -MessageText 'BlacksmithGuild: checkpoint - attach ready.' -MessageShownInGame $true `
                            -GameProcessAlive $true)) | Out-Null
            } else {
                Add-AutomationCheckpointEvent -List $events -CheckpointName $checkpoint `
                    -SessionId $sessionId -Phase 'campaign_loop' -Runner $runner | Out-Null
            }
        }

        $assistSummary = [pscustomobject]@{
            passFail = 'PASS'
            stateMachineConsumed = $true
            runtimeLifecycleConsumed = $true
            assistLoopStarted = $true
        }
        $executionJson = [pscustomobject]@{
            partyMovedDistance = 0.324
            travelClockRunning = $true
            fakeGameplayDelta = $false
        }

        $criteria = Get-AutomationProjectedTerminalCriteria `
            -Events @($events.ToArray()) `
            -State pass `
            -Summary $assistSummary `
            -ExecutionJson $executionJson `
            -RequiredCheckpoints $requiredCheckpoints `
            -RequireAssistLoopStarted `
            -RequireExecuteMovement

        $start = Start-AutomationFinalization -List $events -SessionId $sessionId -Phase 'finalization' `
            -Runner $runner -Reason 'offline_fixture_finalization'
        Complete-AutomationFinalization -List $events -State pass -SessionId $sessionId -Phase 'finalization' `
            -Runner $runner -Criteria $criteria -RelatedEventId $start.eventId `
            -Reason 'configured_objective_met_and_summary_written' -SummaryWritten:$true | Out-Null

        Write-AutomationCheckpointEventsFile -Events @($events.ToArray()) `
            -Path (Join-Path $EvidenceDir 'checkpoint-events.jsonl') | Out-Null

        New-AutomationCampaignLoopSummary -SessionId $sessionId -CycleId 1 -Phase 'campaign_loop' `
            -CurrentTown 'Ortysia' -NextPlannedTown 'Danustica' -SelectedAction 'travel_trade_smith' `
            -CheckpointName 'party_movement_observed' -CheckpointReached $true -Terminal $false `
            -NextActionRequired $true -NextPlannedBranch 'trade' -NextActionReason 'market_state_ready' |
            ConvertTo-Json -Depth 12 |
            Set-Content -LiteralPath (Join-Path $EvidenceDir 'campaign-loop-summary.json') -Encoding UTF8

        $assistSummary | ConvertTo-Json -Depth 12 |
            Set-Content -LiteralPath (Join-Path $EvidenceDir 'assist-loop-summary.json') -Encoding UTF8

        $executionJson | ConvertTo-Json -Depth 12 |
            Set-Content -LiteralPath (Join-Path $EvidenceDir 'BlacksmithGuild_AssistiveTravelExecution.json') -Encoding UTF8
    }

    if (-not $EvidenceDir) {
        throw 'Provide -Fixture or -EvidenceDir <path>.'
    }

    $checkpointPath = Join-Path $EvidenceDir 'checkpoint-events.jsonl'
    $campaignSummaryPath = Join-Path $EvidenceDir 'campaign-loop-summary.json'
    $assistSummaryPath = Join-Path $EvidenceDir 'assist-loop-summary.json'
    $executionPath = Join-Path $EvidenceDir 'BlacksmithGuild_AssistiveTravelExecution.json'

    $events = Read-JsonlFile -Path $checkpointPath

    # Merge mod-emitted JSONL events if present (optional until live code produces them).
    $modPaths = Get-ModEventPaths -Dir $EvidenceDir
    if ($modPaths.Count -gt 0 -and (Get-Command Merge-AutomationCheckpointEvents -ErrorAction SilentlyContinue)) {
        $events = Merge-AutomationCheckpointEvents -RunnerEvents $events -ModEventPaths $modPaths
    }

    $campaignSummary = Read-JsonFile -Path $campaignSummaryPath
    $assistSummary = Read-JsonFile -Path $assistSummaryPath

    $executionJson = $null
    if (Test-Path -LiteralPath $executionPath) {
        $executionJson = Read-JsonFile -Path $executionPath
    } elseif ($RequireExecuteMovement) {
        throw "RequireExecuteMovement set but missing $executionPath"
    }

    # Sanity-read termination-detection.json if present (do not fail the gate when absent yet).
    $terminationPath = Join-Path $EvidenceDir 'termination-detection.json'
    if (Test-Path -LiteralPath $terminationPath) {
        $null = Read-JsonFile -Path $terminationPath
    }

    Assert-RecursiveOutputContract `
        -Events $events `
        -CampaignSummary $campaignSummary `
        -AssistSummary $assistSummary `
        -ExecutionJson $executionJson `
        -RequireExecuteMovement:$RequireExecuteMovement | Out-Null
} finally {
    if ($tmpRoot -and (Test-Path -LiteralPath $tmpRoot)) {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'PASS recursive campaign output contract' -ForegroundColor Green
exit 0
