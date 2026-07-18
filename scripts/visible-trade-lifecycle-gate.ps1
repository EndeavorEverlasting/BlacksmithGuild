# Read-only classifier for P19 window-lifecycle artifacts consumed by the visible-trade coordinator.
# Never clicks, launches, focuses, OCRs, or invents alternate lifecycle shapes.

Set-StrictMode -Version Latest

function Get-TbgVisibleTradeLifecycleArtifactPaths {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $latestRoot = Join-Path $RepoRoot 'artifacts\latest\window-lifecycle'
    return [ordered]@{
        latestRoot = $latestRoot
        runContext = Join-Path $latestRoot 'window-lifecycle.run-context.json'
        artifactRegistry = Join-Path $latestRoot 'window-lifecycle.artifact-registry.json'
        events = Join-Path $latestRoot 'window-lifecycle.events.jsonl'
        state = Join-Path $latestRoot 'window-lifecycle.state.json'
        result = Join-Path $latestRoot 'window-lifecycle.result.json'
        report = Join-Path $latestRoot 'window-lifecycle.report.md'
        handoff = Join-Path $latestRoot 'window-lifecycle.handoff.md'
    }
}

function Read-TbgVisibleTradeLifecycleJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
}

function Get-TbgVisibleTradeLifecycleWindows {
    param([AllowNull()][object]$State)

    if ($null -eq $State) { return @() }
    $windows = @()
    if ($State.PSObject.Properties.Name -contains 'windows' -and $null -ne $State.windows) {
        $windows = @($State.windows)
    }
    elseif ($State.PSObject.Properties.Name -contains 'state' -and $null -ne $State.state) {
        $nested = $State.state
        if ($nested.PSObject.Properties.Name -contains 'windows' -and $null -ne $nested.windows) {
            $windows = @($nested.windows)
        }
    }
    return @($windows)
}

function Test-TbgVisibleTradeLifecycleFreshness {
    param(
        [Parameter(Mandatory = $true)][string[]]$Paths,
        [int]$MaxAgeHours = 24
    )

    $now = [DateTime]::UtcNow
    $missing = New-Object System.Collections.Generic.List[string]
    $stale = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $missing.Add($path) | Out-Null
            continue
        }
        $item = Get-Item -LiteralPath $path
        if (($now - $item.LastWriteTimeUtc).TotalHours -gt $MaxAgeHours) {
            $stale.Add($path) | Out-Null
        }
    }
    return [pscustomobject]@{
        missing = @($missing)
        stale = @($stale)
        fresh = ($missing.Count -eq 0 -and $stale.Count -eq 0)
    }
}

function Resolve-TbgVisibleTradeLifecycleGate {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$ExpectedCorrelationId = '',
        [int]$MaxAgeHours = 24,
        [switch]$RequireFresh
    )

    $paths = Get-TbgVisibleTradeLifecycleArtifactPaths -RepoRoot $RepoRoot
    $required = @([string]$paths.state, [string]$paths.result)
    $freshness = Test-TbgVisibleTradeLifecycleFreshness -Paths $required -MaxAgeHours $MaxAgeHours

    $packet = [ordered]@{
        schema = 'TbgVisibleTradeLifecycleGate.v1'
        artifactPaths = $paths
        actionAuthority = 'none'
        parserProofLevel = 'artifact_inspection'
        freshnessVerified = [bool]$freshness.fresh
        missingArtifacts = @($freshness.missing)
        staleArtifacts = @($freshness.stale)
        correlationMatched = $null
        quarantined = $false
        actionDispatched = $false
        modalTransitionObserved = $false
        hostHandoffObserved = $false
        highestLifecycleProof = 'none'
        gate = 'missing'
        terminalState = 'BLOCKED_WINDOW_LIFECYCLE_REQUIRED_ARTIFACTS_MISSING'
        sentence = 'Required window-lifecycle state/result artifacts are missing.'
    }

    if ($freshness.missing.Count -gt 0) {
        return [pscustomobject]$packet
    }

    try {
        $state = Read-TbgVisibleTradeLifecycleJson -Path $paths.state
        $result = Read-TbgVisibleTradeLifecycleJson -Path $paths.result
    }
    catch {
        $packet.gate = 'parse_error'
        $packet.terminalState = 'FAIL_WINDOW_LIFECYCLE_PARSE_ERROR'
        $packet.sentence = "Window-lifecycle artifacts could not be parsed: $($_.Exception.Message)"
        return [pscustomobject]$packet
    }

    if ($RequireFresh -and $freshness.stale.Count -gt 0) {
        $packet.gate = 'stale'
        $packet.terminalState = 'BLOCKED_WINDOW_LIFECYCLE_STALE'
        $packet.sentence = 'Window-lifecycle artifacts exist but are stale for the current proof run.'
        return [pscustomobject]$packet
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedCorrelationId)) {
        $runContext = $null
        try { $runContext = Read-TbgVisibleTradeLifecycleJson -Path $paths.runContext } catch { $runContext = $null }
        $resultCorrelation = if ($null -ne $result -and $result.PSObject.Properties.Name -contains 'correlationId') { [string]$result.correlationId } else { '' }
        $contextCorrelation = if ($null -ne $runContext -and $runContext.PSObject.Properties.Name -contains 'correlationId') { [string]$runContext.correlationId } else { '' }
        $packet.correlationMatched = (
            $resultCorrelation -eq $ExpectedCorrelationId -or
            $contextCorrelation -eq $ExpectedCorrelationId
        )
        if (-not [bool]$packet.correlationMatched) {
            $packet.gate = 'correlation_mismatch'
            $packet.terminalState = 'FAIL_WINDOW_LIFECYCLE_CORRELATION_MISMATCH'
            $packet.sentence = 'Window-lifecycle correlation does not match the visible-trade run correlation.'
            return [pscustomobject]$packet
        }
    }

    $windows = @(Get-TbgVisibleTradeLifecycleWindows -State $state)
    $proofRank = @{
        none = 0
        observation = 1
        identity = 2
        action_authority = 3
        action_dispatch = 4
        terminal_observation = 5
        quarantine = 0
    }
    $highestRank = 0
    $highestProof = 'none'
    $hasDisappearedAfterDispatch = $false
    $hasHostHandoff = $false
    $hasQuarantine = $false

    foreach ($window in $windows) {
        $phase = [string]$(if ($window.PSObject.Properties.Name -contains 'phase') { $window.phase } else { '' })
        $identity = [string]$(if ($window.PSObject.Properties.Name -contains 'identityId') { $window.identityId } else { '' })
        $proofLevel = [string]$(if ($window.PSObject.Properties.Name -contains 'proofLevel') { $window.proofLevel } else { 'none' })
        $rank = $(if ($proofRank.ContainsKey($proofLevel)) { [int]$proofRank[$proofLevel] } else { 0 })
        if ($rank -gt $highestRank) {
            $highestRank = $rank
            $highestProof = $proofLevel
        }
        if ($phase -eq 'unknown_quarantined' -or $proofLevel -eq 'quarantine') {
            $hasQuarantine = $true
        }
        if ($phase -eq 'action_dispatched' -or $proofLevel -eq 'action_dispatch') {
            $packet.actionDispatched = $true
        }
        if ($phase -eq 'disappeared' -and $packet.actionDispatched) {
            $hasDisappearedAfterDispatch = $true
        }
        if ($phase -eq 'terminal_observation' -or $proofLevel -eq 'terminal_observation' -or $identity -eq 'bannerlord.singleplayer-host') {
            $hasHostHandoff = $true
        }
    }

    $packet.highestLifecycleProof = $highestProof
    $packet.quarantined = $hasQuarantine
    $packet.modalTransitionObserved = [bool]($packet.actionDispatched -and $hasDisappearedAfterDispatch)
    $packet.hostHandoffObserved = $hasHostHandoff

    if ($hasQuarantine) {
        $packet.gate = 'quarantined'
        $packet.terminalState = 'BLOCKED_WINDOW_LIFECYCLE_QUARANTINED'
        $packet.sentence = 'Window-lifecycle evidence is quarantined for an unknown window; no click or launch authority is granted.'
        return [pscustomobject]$packet
    }

    if ($hasHostHandoff) {
        $packet.gate = 'host_handoff'
        $packet.terminalState = 'READY_WINDOW_LIFECYCLE_HOST_HANDOFF'
        $packet.sentence = 'Window-lifecycle evidence shows Singleplayer host handoff observation without promoting campaign readiness.'
        return [pscustomobject]$packet
    }

    if ($packet.modalTransitionObserved) {
        $packet.gate = 'modal_transition'
        $packet.terminalState = 'READY_WINDOW_LIFECYCLE_MODAL_TRANSITION'
        $packet.sentence = 'Window-lifecycle evidence shows a correlated modal transition after action dispatch, but not host handoff.'
        return [pscustomobject]$packet
    }

    if ($packet.actionDispatched) {
        $packet.gate = 'action_dispatch_only'
        $packet.terminalState = 'FAIL_MODAL_TRANSITION_NOT_OBSERVED'
        $packet.sentence = 'Action dispatch was observed without a correlated modal successor or host handoff.'
        return [pscustomobject]$packet
    }

    $packet.gate = 'insufficient'
    $packet.terminalState = 'FAIL_WINDOW_LIFECYCLE_GATE'
    $packet.sentence = 'Window-lifecycle artifacts are present but do not yet prove modal transition or host handoff.'
    return [pscustomobject]$packet
}
