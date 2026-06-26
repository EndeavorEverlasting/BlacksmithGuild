# Autonomous assist session loop — toggle, safety gates, iteration decisions, evidence writers.
# Dot-source after bannerlord-paths.ps1, pr11-runtime-state-consumer.ps1, process-lifecycle-authority.ps1

$script:AssistUnsafeSurfaces = @(
    'loading', 'main_menu', 'multiplayer', 'conversation', 'battle', 'tournament', 'arena',
    'hideout', 'inventory', 'party', 'character', 'kingdom', 'clan', 'escape_menu', 'unknown'
)

function Get-TbgAssistToggleJsonPath {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_AssistToggle.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_AssistToggle.json')
}

function Get-TbgAssistToggleWritePaths {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return @(Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot -FileName 'BlacksmithGuild_AssistToggle.json')
}

function Read-TbgAssistToggle {
    param([string]$BannerlordRoot)
    $path = Get-TbgAssistToggleJsonPath -BannerlordRoot $BannerlordRoot
    $result = [ordered]@{
        path = $path
        parseOk = $false
        enabled = $false
        requestedBy = $null
        reason = $null
        updatedAtUtc = $null
    }
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$result }
    try {
        $toggle = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $result.parseOk = $true
        $result.enabled = ($toggle.enabled -eq $true)
        $result.requestedBy = if ($toggle.requestedBy) { [string]$toggle.requestedBy } else { $null }
        $result.reason = if ($toggle.reason) { [string]$toggle.reason } else { $null }
        $result.updatedAtUtc = if ($toggle.updatedAtUtc) { [string]$toggle.updatedAtUtc } else { $null }
    } catch { }
    return [pscustomobject]$result
}

function Write-TbgAssistToggle {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][bool]$Enabled,
        [string]$RequestedBy = 'runner',
        [string]$Reason = $null
    )
    $payload = [ordered]@{
        enabled = [bool]$Enabled
        requestedBy = [string]$RequestedBy
        reason = [string]$Reason
        updatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    $json = $payload | ConvertTo-Json -Depth 4
    $written = $null
    foreach ($path in @(Get-TbgAssistToggleWritePaths -BannerlordRoot $BannerlordRoot)) {
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        $written = $path
    }
    return $written
}

function Test-TbgAssistToggleOff {
    param([string]$BannerlordRoot)
    $toggle = Read-TbgAssistToggle -BannerlordRoot $BannerlordRoot
    if (-not $toggle.parseOk) { return $false }
    return (-not $toggle.enabled)
}

function Test-AutonomousAssistLoopReadiness {
    param(
        [object]$Readiness
    )
    $result = [ordered]@{
        ready = $false
        reason = $null
        stateMachineConsumed = $false
        runtimeLifecycleConsumed = $false
        readinessConfidence = 'none'
    }
    if (-not $Readiness) {
        $result.reason = 'readiness_missing'
        return [pscustomobject]$result
    }
    $result.stateMachineConsumed = [bool]$Readiness.stateMachine.hasStateMachine
    $result.runtimeLifecycleConsumed = [bool]($Readiness.runtimeLifecycle -and $Readiness.runtimeLifecycle.parseOk)
    $result.readinessConfidence = [string]$Readiness.confidence

    if (-not $Readiness.stateMachine.hasStateMachine) {
        $result.reason = 'missing_stateMachine'
        return [pscustomobject]$result
    }
    if (-not $Readiness.runtimeLifecycle -or -not $Readiness.runtimeLifecycle.parseOk) {
        $result.reason = 'missing_RuntimeLifecycle'
        return [pscustomobject]$result
    }
    if (-not $Readiness.heartbeatFresh) {
        $result.reason = 'runtime_heartbeat_stale'
        return [pscustomobject]$result
    }
    if ($Readiness.confidence -ne 'state_machine') {
        $result.reason = "confidence_not_state_machine:$($Readiness.confidence)"
        return [pscustomobject]$result
    }
    if (-not $Readiness.canAcceptAssistiveCommand) {
        $result.reason = 'canAcceptAssistiveCommand_false'
        return [pscustomobject]$result
    }
    if (-not $Readiness.statusFresh) {
        $result.reason = 'status_stale'
        return [pscustomobject]$result
    }

    $result.ready = $true
    $result.reason = 'state_machine_assist_ready'
    return [pscustomobject]$result
}

function Get-RecursiveBranchGate {
    param(
        [object]$RecursiveBranchState,
        [string]$BranchName
    )
    if (-not $RecursiveBranchState -or -not $RecursiveBranchState.branches) { return $null }
    $branches = $RecursiveBranchState.branches
    if ($branches -is [hashtable] -and $branches.ContainsKey($BranchName)) {
        return $branches[$BranchName]
    }
    if ($branches.PSObject.Properties.Name -contains $BranchName) {
        return $branches.$BranchName
    }
    return $null
}

function Get-AutonomousAssistPlannedBranch {
    param([object]$Decision)
    if (-not $Decision) { return 'observe_only' }
    if ($Decision.plannedBranch) { return [string]$Decision.plannedBranch }
    $considered = if ($Decision.actionConsidered) { [string]$Decision.actionConsidered } else { $null }
    switch ($considered) {
        'travel_to_training_target' { return 'travel' }
        'observe_route' { return 'observe_only' }
        'smithing' { return 'smith' }
        'trade' { return 'trade' }
        default {
            if ($considered) { return $considered }
            switch ([string]$Decision.decision) {
                'wait' { return 'rest_wait' }
                'observe' { return 'observe_only' }
                'block' { return 'observe_only' }
                'stop_unsafe_surface' { return 'avoid_threat' }
                default { return 'observe_only' }
            }
        }
    }
}

function Merge-AutonomousAssistCampaignLoopSummary {
    param(
        [Parameter(Mandatory = $true)]$Summary,
        [string]$SessionId = $null,
        [string]$TargetSettlement = $null,
        [object]$LastDecision = $null,
        [int]$CycleId = 0,
        [string]$CurrentTown = $null,
        [object]$RecursiveBranchState = $null,
        [bool]$RecursiveBranchFresh = $false
    )

    if (-not (Get-Command New-AutomationCampaignLoopSummary -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
    }

    $passFail = if ($Summary.passFail) { [string]$Summary.passFail } else { $null }
    $stopReason = if ($Summary.stopReason) { [string]$Summary.stopReason } else { $null }
    $failureClass = if ($Summary.failureClass) { [string]$Summary.failureClass } else { $null }
    $terminalState = if ($Summary.terminalState) { [string]$Summary.terminalState } else { $null }
    $isDryRun = ($passFail -eq 'DRY_RUN')
    $isTerminal = (-not $isDryRun) -and (
        ($passFail -in @('PASS', 'FAIL')) -or
        ($terminalState -in @('pass', 'fail', 'abort'))
    )

    $branch = Get-AutonomousAssistPlannedBranch -Decision $LastDecision
    $nextReason = if ($LastDecision -and $LastDecision.reason) { [string]$LastDecision.reason } else { $null }
    $resolvedTown = $CurrentTown
    if ($RecursiveBranchFresh -and $RecursiveBranchState -and $RecursiveBranchState.hasRecursiveBranchState) {
        if ($RecursiveBranchState.currentTown) {
            $resolvedTown = [string]$RecursiveBranchState.currentTown
        }
        if (-not $isTerminal) {
            if ($RecursiveBranchState.nextPlannedBranch) {
                $branch = [string]$RecursiveBranchState.nextPlannedBranch
            }
            if ($RecursiveBranchState.nextActionReason) {
                $nextReason = [string]$RecursiveBranchState.nextActionReason
            }
        }
    }

    if ($isTerminal) {
        $reason = if ($stopReason) { $stopReason } elseif ($failureClass) { $failureClass } else { $passFail }
        $campaign = New-AutomationCampaignLoopSummary -SessionId $SessionId -CycleId $CycleId `
            -Phase 'campaign_loop' -CurrentTown $resolvedTown -NextPlannedTown $TargetSettlement `
            -Terminal:$true -TerminalState $terminalState -PassFail $passFail `
            -NextActionRequired:$false -Reason $reason
    } else {
        if ([string]::IsNullOrWhiteSpace($nextReason)) {
            $nextReason = if ($LastDecision -and $LastDecision.decision) {
                "decision=$([string]$LastDecision.decision)"
            } else {
                "next_branch=$branch"
            }
        }
        $campaign = New-AutomationCampaignLoopSummary -SessionId $SessionId -CycleId $CycleId `
            -Phase 'campaign_loop' -CurrentTown $resolvedTown -NextPlannedTown $TargetSettlement `
            -SelectedAction $(if ($LastDecision) { [string]$LastDecision.actionConsidered } else { $null }) `
            -Terminal:$false -NextActionRequired:$true -NextPlannedBranch $branch `
            -NextActionReason $nextReason -Reason $nextReason
    }

    $validation = Test-AutomationCampaignLoopSummary -Summary $campaign
    if (-not $validation.pass) {
        throw "campaign loop summary contract failed: $($validation | ConvertTo-Json -Compress)"
    }

    $Summary.nextActionRequired = $campaign.nextActionRequired
    $Summary.nextPlannedBranch = $campaign.nextPlannedBranch
    $Summary.nextActionReason = $campaign.nextActionReason
    $Summary.campaignLoopSummary = $campaign
    return $Summary
}

function Write-AutonomousAssistCycleCampaignSummary {
    param(
        [hashtable]$Evidence,
        [object]$LastDecision,
        [string]$SessionId,
        [string]$TargetSettlement,
        [int]$CycleId,
        [object]$RecursiveBranchState = $null,
        [bool]$RecursiveBranchFresh = $false
    )

    $cycleSummary = Merge-AutonomousAssistCampaignLoopSummary -Summary @{
        passFail = 'IN_PROGRESS'
        iterationCount = $CycleId
    } -SessionId $SessionId -TargetSettlement $TargetSettlement `
        -LastDecision $LastDecision -CycleId $CycleId `
        -RecursiveBranchState $RecursiveBranchState -RecursiveBranchFresh $RecursiveBranchFresh `
        -CurrentTown $(if ($RecursiveBranchState -and $RecursiveBranchState.currentTown) { [string]$RecursiveBranchState.currentTown } else { $null })

    $path = Join-Path $Evidence.checkpointDir 'campaign-loop-summary.json'
    if (Get-Command Save-Pr11JsonArtifact -ErrorAction SilentlyContinue) {
        Save-Pr11JsonArtifact -Object $cycleSummary.campaignLoopSummary -Path $path | Out-Null
    } else {
        $cycleSummary.campaignLoopSummary | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $path -Encoding UTF8
    }
    return $cycleSummary.campaignLoopSummary
}

function Test-TbgPostHandoffFastFail {
    param(
        [object]$Detection,
        [bool]$HandoffCompleted,
        [bool]$AttachReady,
        [bool]$GameProcessEverSeenAfterHandoff
    )
    if ($AttachReady -or -not $HandoffCompleted) { return $null }
    if ($Detection -and $Detection.gameProcessRunning) { return $null }

    if ($GameProcessEverSeenAfterHandoff) {
        return [pscustomobject][ordered]@{
            classification = 'process_disappeared_during_post_handoff'
            routeAgent = 'Agent C - External State Classifier / Assistive Runner'
            evidenceSignals = @('game_process_seen_after_handoff', 'game_process_gone_before_attach')
            missingSignals = @('attach_ready')
        }
    }

    return [pscustomobject][ordered]@{
        classification = 'game_exited_unexpectedly_before_attach'
        routeAgent = 'Agent C - External State Classifier / Assistive Runner'
        evidenceSignals = @('handoff_completed', 'attach_not_ready', 'game_process_not_running')
        missingSignals = @('game_process', 'attach_ready')
    }
}

function Invoke-TbgLauncherAutoNavChild {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$LaunchIntent,
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][string]$ExternalStateTimelinePath,
        [int]$TimeoutSec = 300,
        [int]$LauncherSelectionMaxMs = 30000,
        [bool]$RespectUserForeground = $false,
        [ValidateSet('continue', 'play', 'any')]
        [string]$CertTarget = 'any'
    )

    function ConvertTo-TbgPowerShellLiteral {
        param([string]$Value)
        return "'" + (($Value -replace "'", "''")) + "'"
    }

    $respectLiteral = if ($RespectUserForeground) { '$true' } else { '$false' }
    $command = @(
        '&',
        (ConvertTo-TbgPowerShellLiteral $ScriptPath),
        '-LaunchIntent', (ConvertTo-TbgPowerShellLiteral $LaunchIntent),
        '-BannerlordRoot', (ConvertTo-TbgPowerShellLiteral $BannerlordRoot),
        '-TimeoutSec', [string]$TimeoutSec,
        '-LaunchSetup',
        '-LauncherSelectionMaxMs', [string]$LauncherSelectionMaxMs,
        "-RespectUserForeground:$respectLiteral",
        '-CertTarget', (ConvertTo-TbgPowerShellLiteral $CertTarget),
        '-ExternalStateTimelinePath', (ConvertTo-TbgPowerShellLiteral $ExternalStateTimelinePath)
    ) -join ' '

    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1)
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    foreach ($line in $output) { Write-Host $line }

    return [pscustomobject][ordered]@{
        exitCode = $exitCode
        output = @($output | ForEach-Object { [string]$_ })
        text = [string](@($output | ForEach-Object { [string]$_ }) -join "`n")
    }
}

function Get-AutonomousAssistIterationDecision {
    param(
        [object]$Readiness,
        [string]$AssistProfile = 'training-map',
        [string]$TargetSettlement = 'Ortysia',
        [bool]$StopOnUnsafeState = $true,
        [nullable[datetime]]$LastTravelCommandUtc = $null,
        [int]$TravelCommandCooldownSec = 45
    )

    $nowUtc = (Get-Date).ToUniversalTime()
    $surface = if ($Readiness.stateMachine.gameplaySurface) { [string]$Readiness.stateMachine.gameplaySurface } else { 'unknown' }
    $lifecycle = if ($Readiness.stateMachine.gameLifecycle) { [string]$Readiness.stateMachine.gameLifecycle } else { $null }

    $base = [ordered]@{
        atUtc = $nowUtc.ToString('o')
        surface = $surface
        lifecycle = $lifecycle
        actionConsidered = $null
        decision = 'wait'
        commandSent = $null
        target = $null
        result = $null
        reason = $null
    }

    $loopReady = Test-AutonomousAssistLoopReadiness -Readiness $Readiness
    if (-not $loopReady.ready) {
        $base.reason = $loopReady.reason
        $base.decision = 'block'
        return [pscustomobject]$base
    }

    if ($surface -in $script:AssistUnsafeSurfaces) {
        $base.reason = "surface_blocks_assist:$surface"
        if ($StopOnUnsafeState) {
            $base.decision = 'stop_unsafe_surface'
        } else {
            $base.decision = 'wait'
        }
        return [pscustomobject]$base
    }

    $travelGate = Test-Pr11TravelExecuteAllowed -Readiness $Readiness

    $rbs = $Readiness.recursiveBranchState
    if ($Readiness.recursiveBranchFresh -and $rbs -and $rbs.hasRecursiveBranchState -and $rbs.nextActionRequired -and -not $rbs.terminal) {
        $planned = [string]$rbs.nextPlannedBranch
        if (-not [string]::IsNullOrWhiteSpace($planned)) {
            $gate = Get-RecursiveBranchGate -RecursiveBranchState $rbs -BranchName $planned
            $branchReason = if ($rbs.nextActionReason) { [string]$rbs.nextActionReason } elseif ($gate -and $gate.reason) { [string]$gate.reason } else { $null }

            switch ($planned) {
                'travel' {
                    if ($gate -and ($gate.state -eq 'available') -and $travelGate.allowed -and ($surface -eq 'settlement_menu')) {
                        $cooldownOk = $true
                        if ($LastTravelCommandUtc) {
                            $elapsed = ($nowUtc - $LastTravelCommandUtc).TotalSeconds
                            $cooldownOk = ($elapsed -ge $TravelCommandCooldownSec)
                        }
                        if ($cooldownOk) {
                            $base.actionConsidered = 'travel_to_training_target'
                            $base.decision = 'allowed'
                            $base.commandSent = 'AssistiveLeaveTownAndTravel'
                            $base.target = $TargetSettlement
                            $base.reason = $branchReason
                            $base.plannedBranch = 'travel'
                            $base.recursiveBranchConsumed = $true
                            return [pscustomobject]$base
                        }
                        $base.actionConsidered = 'travel_to_training_target'
                        $base.decision = 'wait'
                        $base.reason = 'travel_command_cooldown'
                        $base.plannedBranch = 'travel'
                        $base.recursiveBranchConsumed = $true
                        return [pscustomobject]$base
                    }
                    if ($surface -eq 'campaign_map') {
                        $base.actionConsidered = 'observe_route'
                        $base.decision = if ($travelGate.allowed) { 'observe' } else { 'wait' }
                        $base.reason = if ($branchReason) { $branchReason } elseif ($travelGate.reason) { $travelGate.reason } else { 'travel_planned_map_observe' }
                        $base.plannedBranch = 'travel'
                        $base.recursiveBranchConsumed = $true
                        return [pscustomobject]$base
                    }
                    $base.actionConsidered = 'travel_to_training_target'
                    $base.decision = 'wait'
                    $base.reason = if ($gate -and $gate.reason) { $gate.reason } elseif ($travelGate.reason) { $travelGate.reason } else { 'travel_branch_not_available' }
                    $base.plannedBranch = 'travel'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'rest_wait' {
                    $base.actionConsidered = 'rest_wait'
                    $base.decision = 'wait'
                    $base.reason = if ($gate -and ($gate.state -eq 'available') -and $branchReason) { $branchReason } elseif ($gate -and $gate.reason) { $gate.reason } else { 'rest_wait_not_available' }
                    $base.plannedBranch = 'rest_wait'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'observe_only' {
                    $base.actionConsidered = 'observe_route'
                    $base.decision = 'observe'
                    $base.reason = if ($branchReason) { $branchReason } else { 'recursive_branch_observe_only' }
                    $base.plannedBranch = 'observe_only'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'trade' {
                    $base.actionConsidered = 'trade'
                    $base.decision = 'observe'
                    $base.reason = if ($branchReason) { $branchReason } else { 'trade_requires_profitability_evidence' }
                    $base.plannedBranch = 'trade'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'smith_refine' {
                    $base.actionConsidered = 'smithing'
                    $base.decision = 'observe'
                    $base.reason = if ($branchReason) { $branchReason } else { 'smith_refine_requires_stamina_material_evidence' }
                    $base.plannedBranch = 'smith_refine'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'tavern_scan' {
                    $base.actionConsidered = 'tavern_scan'
                    $base.decision = 'observe'
                    $base.reason = if ($branchReason) { $branchReason } else { 'tavern_scan_command_not_available' }
                    $base.plannedBranch = 'tavern_scan'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'companion_roster' {
                    $base.actionConsidered = 'companion_roster'
                    $base.decision = 'observe'
                    $base.reason = if ($branchReason) { $branchReason } else { 'companion_roster_requires_capacity_evidence' }
                    $base.plannedBranch = 'companion_roster'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                'avoid_threat' {
                    $base.actionConsidered = 'avoid_threat'
                    if ($gate -and $gate.state -eq 'blocked') {
                        $base.decision = 'block'
                        $base.reason = if ($branchReason) { $branchReason } elseif ($gate.reason) { $gate.reason } else { 'avoid_threat_gate_blocked' }
                    } else {
                        $base.decision = 'observe'
                        $base.reason = if ($branchReason) { $branchReason } else { 'avoid_threat_observe_without_fake_scan' }
                    }
                    $base.plannedBranch = 'avoid_threat'
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
                default {
                    $base.actionConsidered = $planned
                    $base.decision = 'observe'
                    $base.reason = if ($gate -and $gate.reason) { $gate.reason } else { "branch_not_executable:$planned" }
                    $base.plannedBranch = $planned
                    $base.recursiveBranchConsumed = $true
                    return [pscustomobject]$base
                }
            }
        }
    }

    switch ($AssistProfile) {
        'training-map' {
            if ($surface -eq 'settlement_menu' -and $travelGate.allowed) {
                $cooldownOk = $true
                if ($LastTravelCommandUtc) {
                    $elapsed = ($nowUtc - $LastTravelCommandUtc).TotalSeconds
                    $cooldownOk = ($elapsed -ge $TravelCommandCooldownSec)
                }
                if ($cooldownOk) {
                    $base.actionConsidered = 'travel_to_training_target'
                    $base.decision = 'allowed'
                    $base.commandSent = 'AssistiveLeaveTownAndTravel'
                    $base.target = $TargetSettlement
                    return [pscustomobject]$base
                }
                $base.actionConsidered = 'travel_to_training_target'
                $base.decision = 'wait'
                $base.reason = 'travel_command_cooldown'
                return [pscustomobject]$base
            }
            if ($surface -eq 'campaign_map') {
                $base.actionConsidered = 'observe_route'
                $base.decision = if ($travelGate.allowed) { 'observe' } else { 'wait' }
                $base.reason = if ($travelGate.allowed) { 'campaign_map_observe_no_spam' } else { $travelGate.reason }
                return [pscustomobject]$base
            }
            if ($surface -eq 'blacksmithing') {
                $base.actionConsidered = 'smithing'
                $base.decision = 'wait'
                $base.reason = 'profile_training_map_no_auto_smithing'
                return [pscustomobject]$base
            }
            if ($surface -eq 'trading') {
                $base.actionConsidered = 'trade'
                $base.decision = 'wait'
                $base.reason = 'profile_training_map_no_auto_trade'
                return [pscustomobject]$base
            }
            $base.reason = if ($travelGate.reason) { $travelGate.reason } else { "surface_not_actionable:$surface" }
            return [pscustomobject]$base
        }
        default {
            $base.reason = "unknown_assist_profile:$AssistProfile"
            $base.decision = 'block'
            return [pscustomobject]$base
        }
    }
}

function New-AutonomousAssistSessionEvidence {
    param(
        [string]$SessionId,
        [string]$CheckpointDir,
        [string]$AssistProfile,
        [string]$LaunchIntent,
        [string]$TargetSettlement,
        [string]$CertProfile = 'default',
        [int]$TradeIterationTarget = 10
    )
    return [ordered]@{
        sessionId = $SessionId
        checkpointDir = $CheckpointDir
        assistProfile = $AssistProfile
        certProfile = $CertProfile
        launchIntent = $LaunchIntent
        targetSettlement = $TargetSettlement
        startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        endedAtUtc = $null
        assistLoopStarted = $false
        assistLoopStartedWithoutHotkey = $false
        iterationCount = 0
        tradeIterationCount = 0
        tradeIterationTarget = $TradeIterationTarget
        timeline = New-Object System.Collections.Generic.List[object]
        stateSnapshots = New-Object System.Collections.Generic.List[object]
        commandTimeline = New-Object System.Collections.Generic.List[object]
        toggleEvents = New-Object System.Collections.Generic.List[object]
        safetyDecisions = New-Object System.Collections.Generic.List[object]
        travelDecisions = New-Object System.Collections.Generic.List[object]
        trainingDecisions = New-Object System.Collections.Generic.List[object]
        checkpointEvents = New-Object System.Collections.Generic.List[object]
        boundaries = New-Object System.Collections.Generic.List[object]
        runtimeEvents = New-Object System.Collections.Generic.List[object]
        tradeIterations = New-Object System.Collections.Generic.List[object]
        branchConsiderationLog = New-Object System.Collections.Generic.List[object]
    }
}

function Add-AssistSessionJsonl {
    param(
        [System.Collections.Generic.List[object]]$List,
        [object]$Event
    )
    $List.Add($Event) | Out-Null
}

function Write-AssistSessionJsonlFile {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Path
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $lines = @($List.ToArray() | ForEach-Object { ($_ | ConvertTo-Json -Depth 10 -Compress) })
    if ($lines.Count -eq 0) {
        Set-Content -LiteralPath $Path -Value '' -Encoding UTF8
    } else {
        Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
    }
    return $Path
}

function Get-AutomationModEventPaths {
    param([string]$BannerlordRoot)
    $paths = New-Object System.Collections.Generic.List[string]
    if (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue) {
        foreach ($candidate in @(Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot -FileName 'BlacksmithGuild_AutomationEvents.jsonl')) {
            if ($candidate -and -not $paths.Contains($candidate)) {
                $paths.Add($candidate) | Out-Null
            }
        }
    }
    if (Get-Command Get-BannerlordDocsRoot -ErrorAction SilentlyContinue) {
        $docsPath = Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_AutomationEvents.jsonl'
        if ($docsPath -and -not $paths.Contains($docsPath)) {
            $paths.Add($docsPath) | Out-Null
        }
    }
    if ($BannerlordRoot) {
        $rootPath = Join-Path $BannerlordRoot 'BlacksmithGuild_AutomationEvents.jsonl'
        if (-not $paths.Contains($rootPath)) {
            $paths.Add($rootPath) | Out-Null
        }
    }
    return @($paths.ToArray())
}

function Copy-EconomicLoopArtifact {
    param(
        [string]$BannerlordRoot,
        [string]$CheckpointDir,
        [string]$FileName
    )
    if ([string]::IsNullOrWhiteSpace($BannerlordRoot)) { return $false }
    $src = Join-Path $BannerlordRoot $FileName
    if (-not (Test-Path -LiteralPath $src)) { return $false }
    if (Get-Command Copy-Pr11EvidenceArtifact -ErrorAction SilentlyContinue) {
        Copy-Pr11EvidenceArtifact -SourcePath $src -CheckpointDir $CheckpointDir -DestName $FileName | Out-Null
    } else {
        Copy-Item -LiteralPath $src -Destination (Join-Path $CheckpointDir $FileName) -Force
    }
    return $true
}

function Save-EconomicLoopCertEvidence {
    # Writes the economic-loop evidence streams the offline cert consumes:
    #   BlacksmithGuild_BoundaryEvents.jsonl, BlacksmithGuild_TradeIterations.jsonl,
    #   economic-loop-summary.json, economic-loop-cert.json
    # It also copies any mod-emitted boundary/trade/domain artifacts from BannerlordRoot.
    param(
        [hashtable]$Evidence,
        [string]$BannerlordRoot,
        [int]$TradeIterationTarget = 10
    )

    $dir = $Evidence.checkpointDir
    if (-not (Get-Command Test-AutomationEconomicLoopPassCriteria -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'automation-boundary-contract.ps1')
    }

    $boundaries = if ($Evidence.boundaries) { @($Evidence.boundaries.ToArray()) } else { @() }
    $runtimeEvents = if ($Evidence.runtimeEvents) { @($Evidence.runtimeEvents.ToArray()) } else { @() }
    $tradeIterations = if ($Evidence.tradeIterations) { @($Evidence.tradeIterations.ToArray()) } else { @() }
    $branchLog = if ($Evidence.branchConsiderationLog) { @($Evidence.branchConsiderationLog.ToArray()) } else { @() }

    # Prefer mod-emitted append-only streams if the runner harvested them; otherwise fall back to
    # the runner's in-memory accumulation. Copy first so on-disk mod truth wins.
    $copiedBoundary = Copy-EconomicLoopArtifact -BannerlordRoot $BannerlordRoot -CheckpointDir $dir -FileName 'BlacksmithGuild_BoundaryEvents.jsonl'
    $copiedTrades = Copy-EconomicLoopArtifact -BannerlordRoot $BannerlordRoot -CheckpointDir $dir -FileName 'BlacksmithGuild_TradeIterations.jsonl'
    foreach ($domain in @('BlacksmithGuild_MapTradeCert.json', 'BlacksmithGuild_HorseMarketIntel.json',
            'BlacksmithGuild_SmithingSafeAction.json', 'BlacksmithGuild_AutomationEvents.jsonl')) {
        Copy-EconomicLoopArtifact -BannerlordRoot $BannerlordRoot -CheckpointDir $dir -FileName $domain | Out-Null
    }

    if (-not $copiedBoundary -and (Get-Command Write-AutomationBoundaryEventsFile -ErrorAction SilentlyContinue)) {
        Write-AutomationBoundaryEventsFile -Boundaries $boundaries -Path (Join-Path $dir 'BlacksmithGuild_BoundaryEvents.jsonl') | Out-Null
    }
    if (-not $copiedTrades) {
        $tradeLines = @($tradeIterations | Where-Object { $null -ne $_ } | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress })
        Set-Content -LiteralPath (Join-Path $dir 'BlacksmithGuild_TradeIterations.jsonl') -Value $(if ($tradeLines.Count -eq 0) { '' } else { $tradeLines }) -Encoding UTF8
    }

    # If mod emitted trade rows on disk, count those; else count the in-memory rows.
    $diskTradePath = Join-Path $dir 'BlacksmithGuild_TradeIterations.jsonl'
    if ($copiedTrades -and (Test-Path -LiteralPath $diskTradePath)) {
        $tradeIterations = @(Get-Content -LiteralPath $diskTradePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    }
    $diskBoundaryPath = Join-Path $dir 'BlacksmithGuild_BoundaryEvents.jsonl'
    if ($copiedBoundary -and (Test-Path -LiteralPath $diskBoundaryPath)) {
        $boundaries = @(Get-Content -LiteralPath $diskBoundaryPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    }

    $proven = @($tradeIterations | Where-Object { Test-TradeIterationProven -Iteration $_ })
    $criteria = Test-AutomationEconomicLoopPassCriteria -Boundaries $boundaries -RuntimeEvents $runtimeEvents `
        -TradeIterations $tradeIterations -BranchConsiderationLog $branchLog `
        -CheckpointEvents @($Evidence.checkpointEvents.ToArray()) -TradeIterationTarget $TradeIterationTarget

    $economicSummary = [ordered]@{
        sessionId = $Evidence.sessionId
        certProfile = if ($Evidence.certProfile) { $Evidence.certProfile } else { 'economic_loop' }
        tradeIterationTarget = $TradeIterationTarget
        tradeIterationCount = $proven.Count
        boundaryCount = @($boundaries).Count
        branchConsiderationLog = @($branchLog)
        lastFailureClass = $(if ($criteria.failureClasses.Count -gt 0) { @($criteria.failureClasses)[-1] } else { $null })
    }
    if (Get-Command Save-Pr11JsonArtifact -ErrorAction SilentlyContinue) {
        Save-Pr11JsonArtifact -Object $economicSummary -Path (Join-Path $dir 'economic-loop-summary.json') | Out-Null
        Save-Pr11JsonArtifact -Object $criteria -Path (Join-Path $dir 'economic-loop-cert.json') | Out-Null
    } else {
        $economicSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $dir 'economic-loop-summary.json') -Encoding UTF8
        $criteria | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $dir 'economic-loop-cert.json') -Encoding UTF8
    }
    return $criteria
}

function Save-AutonomousAssistSessionEvidence {
    param(
        [hashtable]$Evidence,
        [hashtable]$Summary,
        [string]$BannerlordRoot,
        [string]$StatusPath,
        [string]$RuntimeLifecyclePath
    )

    $dir = $Evidence.checkpointDir
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $manifest = [ordered]@{
        sessionId = $Evidence.sessionId
        checkpointDir = $dir
        assistProfile = $Evidence.assistProfile
        launchIntent = $Evidence.launchIntent
        targetSettlement = $Evidence.targetSettlement
        startedAtUtc = $Evidence.startedAtUtc
        endedAtUtc = $Summary.endedAtUtc
        assistLoopStarted = $Evidence.assistLoopStarted
        assistLoopStartedWithoutHotkey = $Evidence.assistLoopStartedWithoutHotkey
        iterationCount = $Evidence.iterationCount
    }
    if ($Evidence.certProfile) { $manifest.certProfile = [string]$Evidence.certProfile }
    if ($null -ne $Evidence.tradeIterationTarget) { $manifest.tradeIterationTarget = [int]$Evidence.tradeIterationTarget }
    if ($null -ne $Evidence.tradeIterationCount) { $manifest.tradeIterationCount = [int]$Evidence.tradeIterationCount }

    if (Get-Command Save-Pr11JsonArtifact -ErrorAction SilentlyContinue) {
        Save-Pr11JsonArtifact -Object $manifest -Path (Join-Path $dir 'session-manifest.json') | Out-Null
        Save-Pr11JsonArtifact -Object @($Evidence.timeline.ToArray()) -Path (Join-Path $dir 'assist-loop-timeline.json') | Out-Null
        Save-Pr11JsonArtifact -Object $Summary -Path (Join-Path $dir 'assist-loop-summary.json') | Out-Null
        if ($Summary.campaignLoopSummary) {
            Save-Pr11JsonArtifact -Object $Summary.campaignLoopSummary -Path (Join-Path $dir 'campaign-loop-summary.json') | Out-Null
        }
    } else {
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $dir 'session-manifest.json') -Encoding UTF8
        @($Evidence.timeline.ToArray()) | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $dir 'assist-loop-timeline.json') -Encoding UTF8
        $Summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $dir 'assist-loop-summary.json') -Encoding UTF8
        if ($Summary.campaignLoopSummary) {
            $Summary.campaignLoopSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $dir 'campaign-loop-summary.json') -Encoding UTF8
        }
    }

    Write-AssistSessionJsonlFile -List $Evidence.stateSnapshots -Path (Join-Path $dir 'state-snapshots.jsonl') | Out-Null
    Write-AssistSessionJsonlFile -List $Evidence.commandTimeline -Path (Join-Path $dir 'command-timeline.jsonl') | Out-Null
    Write-AssistSessionJsonlFile -List $Evidence.toggleEvents -Path (Join-Path $dir 'toggle-events.jsonl') | Out-Null
    Write-AssistSessionJsonlFile -List $Evidence.safetyDecisions -Path (Join-Path $dir 'safety-decisions.jsonl') | Out-Null
    Write-AssistSessionJsonlFile -List $Evidence.travelDecisions -Path (Join-Path $dir 'travel-decisions.jsonl') | Out-Null
    Write-AssistSessionJsonlFile -List $Evidence.trainingDecisions -Path (Join-Path $dir 'training-decisions.jsonl') | Out-Null
    if (Get-Command Write-AutomationCheckpointEventsFile -ErrorAction SilentlyContinue) {
        $events = @($Evidence.checkpointEvents.ToArray())
        if (Get-Command Merge-AutomationCheckpointEvents -ErrorAction SilentlyContinue) {
            $events = Merge-AutomationCheckpointEvents -RunnerEvents $events -ModEventPaths (Get-AutomationModEventPaths -BannerlordRoot $BannerlordRoot)
        }
        Write-AutomationCheckpointEventsFile -Events $events -Path (Join-Path $dir 'checkpoint-events.jsonl') | Out-Null
    } else {
        Write-AssistSessionJsonlFile -List $Evidence.checkpointEvents -Path (Join-Path $dir 'checkpoint-events.jsonl') | Out-Null
    }

    if (Get-Command Copy-TbgLifecycleArtifacts -ErrorAction SilentlyContinue) {
        Copy-TbgLifecycleArtifacts -BannerlordRoot $BannerlordRoot -CheckpointDir $dir | Out-Null
    }
    if (Get-Command Copy-Pr11EvidenceArtifact -ErrorAction SilentlyContinue) {
        Copy-Pr11EvidenceArtifact -SourcePath $StatusPath -CheckpointDir $dir -DestName 'BlacksmithGuild_Status.json' | Out-Null
        Copy-Pr11EvidenceArtifact -SourcePath $RuntimeLifecyclePath -CheckpointDir $dir -DestName 'BlacksmithGuild_RuntimeLifecycle.json' | Out-Null
    }

    $runtimeLcPath = Join-Path $dir 'BlacksmithGuild_RuntimeLifecycle.json'
    if (Test-Path -LiteralPath $runtimeLcPath) {
        Copy-Item -LiteralPath $runtimeLcPath -Destination (Join-Path $dir 'runtime-lifecycle.json') -Force
    }

    # Economic-loop cert profile: harvest boundary/trade streams and emit the offline cert verdict.
    $isEconomicLoop = ([string]$Evidence.certProfile -eq 'economic_loop') -or
        ($Evidence.tradeIterations -and $Evidence.tradeIterations.Count -gt 0) -or
        ($Evidence.boundaries -and $Evidence.boundaries.Count -gt 0)
    if ($isEconomicLoop -and (Get-Command Save-EconomicLoopCertEvidence -ErrorAction SilentlyContinue)) {
        $target = if ($null -ne $Evidence.tradeIterationTarget) { [int]$Evidence.tradeIterationTarget } else { 10 }
        Save-EconomicLoopCertEvidence -Evidence $Evidence -BannerlordRoot $BannerlordRoot -TradeIterationTarget $target | Out-Null
    }

    if ($Summary.travelExecuted -eq $true) {
        if (-not (Get-Command Get-AssistiveTravelExecutionJsonPath -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')
        }
        if (Get-Command Get-AssistiveTravelExecutionJsonPath -ErrorAction SilentlyContinue) {
            $execSrc = Get-AssistiveTravelExecutionJsonPath -BannerlordRoot $BannerlordRoot
            if ($execSrc -and (Test-Path -LiteralPath $execSrc)) {
                if (Get-Command Copy-Pr11EvidenceArtifact -ErrorAction SilentlyContinue) {
                    Copy-Pr11EvidenceArtifact -SourcePath $execSrc -CheckpointDir $dir `
                        -DestName 'BlacksmithGuild_AssistiveTravelExecution.json' | Out-Null
                } else {
                    Copy-Item -LiteralPath $execSrc `
                        -Destination (Join-Path $dir 'BlacksmithGuild_AssistiveTravelExecution.json') -Force
                }
            }
        }
    }

    return $dir
}
