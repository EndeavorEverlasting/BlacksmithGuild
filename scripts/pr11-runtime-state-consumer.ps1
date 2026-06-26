# PR #14 consumer for PR #13 runtime outputs: Status.stateMachine + RuntimeLifecycle.json
# Dot-source after bannerlord-paths.ps1 and f7-external-state-classifier.ps1

$script:Pr11TravelAllowedSurfaces = @('settlement_menu', 'campaign_map')
$script:Pr11TravelBlockedSurfaces = @(
    'loading', 'main_menu', 'multiplayer', 'conversation', 'battle', 'tournament', 'arena',
    'hideout', 'blacksmithing', 'trading', 'inventory', 'party', 'character', 'kingdom',
    'clan', 'escape_menu', 'unknown'
)

function Get-RuntimeLifecycleJsonPath {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_RuntimeLifecycle.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_RuntimeLifecycle.json')
}

function Read-Pr11RuntimeLifecycle {
    param([string]$BannerlordRoot, [string]$Path = $null)

    $result = [ordered]@{
        path = $Path
        parseOk = $false
        lastHeartbeatUtc = $null
        lastCommandName = $null
        lastCommandStartedAtUtc = $null
        lastCommandFinishedAtUtc = $null
        lastCommandResult = $null
        gracefulShutdownObserved = $false
        shutdownObservedAtUtc = $null
    }

    if (-not $Path) {
        $Path = Get-RuntimeLifecycleJsonPath -BannerlordRoot $BannerlordRoot
    }
    $result.path = $Path
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]$result
    }

    try {
        $lc = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $result.parseOk = $true
        if ($lc.lastHeartbeatUtc) {
            $result.lastHeartbeatUtc = ConvertTo-Pr11Utc -Value $lc.lastHeartbeatUtc
        }
        $result.lastCommandName = if ($lc.lastCommandName) { [string]$lc.lastCommandName } else { $null }
        $result.lastCommandStartedAtUtc = if ($lc.lastCommandStartedAtUtc) { [string]$lc.lastCommandStartedAtUtc } else { $null }
        $result.lastCommandFinishedAtUtc = if ($lc.lastCommandFinishedAtUtc) { [string]$lc.lastCommandFinishedAtUtc } else { $null }
        $result.lastCommandResult = if ($lc.lastCommandResult) { [string]$lc.lastCommandResult } else { $null }
        $result.gracefulShutdownObserved = ($lc.gracefulShutdownObserved -eq $true)
        $result.shutdownObservedAtUtc = if ($lc.shutdownObservedAtUtc) { [string]$lc.shutdownObservedAtUtc } else { $null }
    } catch { }

    return [pscustomobject]$result
}

function Read-Pr11StateMachineFromStatus {
    param([string]$StatusPath)

    $result = [ordered]@{
        hasStateMachine = $false
        gameplaySurface = $null
        gameLifecycle = $null
        safeToExecuteTravel = $false
        safeToExecuteSmithing = $false
        safeToExecuteTrade = $false
        canAcceptAssistiveCommand = $false
        blockReason = $null
        updatedAtUtc = $null
        heartbeatUtc = $null
    }

    if (-not $StatusPath -or -not (Test-Path -LiteralPath $StatusPath)) {
        return [pscustomobject]$result
    }

    $st = $null
    if (Get-Command Read-F7StatusJsonSafe -ErrorAction SilentlyContinue) {
        $st = Read-F7StatusJsonSafe -StatusPath $StatusPath
    } else {
        try { $st = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json } catch { }
    }
    if (-not $st) { return [pscustomobject]$result }

    if ($st.updatedAt) {
        try {
            $result.updatedAtUtc = [datetime]::Parse([string]$st.updatedAt, $null, `
                [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
        } catch { }
    }

    $sm = $st.stateMachine
    if (-not $sm) { return [pscustomobject]$result }

    $result.hasStateMachine = $true
    $result.gameplaySurface = if ($sm.gameplaySurface) { [string]$sm.gameplaySurface } else { $null }
    $result.gameLifecycle = if ($sm.gameLifecycle) { [string]$sm.gameLifecycle } else { $null }
    $result.safeToExecuteTravel = ($sm.safeToExecuteTravel -eq $true)
    $result.safeToExecuteSmithing = ($sm.safeToExecuteSmithing -eq $true)
    $result.safeToExecuteTrade = ($sm.safeToExecuteTrade -eq $true)
    $result.canAcceptAssistiveCommand = ($sm.canAcceptAssistiveCommand -eq $true)
    $result.blockReason = if ($sm.blockReason) { [string]$sm.blockReason } else { $null }
    if ($sm.updatedAtUtc) {
        $result.updatedAtUtc = ConvertTo-Pr11Utc -Value $sm.updatedAtUtc
    }
    if ($sm.heartbeatUtc) {
        $result.heartbeatUtc = ConvertTo-Pr11Utc -Value $sm.heartbeatUtc
    }

    return [pscustomobject]$result
}

# Converts a value from a JSON field that is a UTC instant by contract (e.g. *Utc) into a true
# UTC [datetime]. ConvertFrom-Json coerces ISO-8601 "...Z" strings into [datetime] objects whose
# Kind is then lost when re-stringified, so a naive Parse(...).ToUniversalTime() double-applies the
# local offset and pushes the timestamp into the future (negative age => never "fresh"). For a
# field that is UTC by contract, an Unspecified-kind wall-clock must be treated AS UTC, not local.
function ConvertTo-Pr11Utc {
    param($Value)

    if ($null -eq $Value) { return $null }

    if ($Value -is [datetime]) {
        switch ($Value.Kind) {
            ([System.DateTimeKind]::Utc) { return $Value }
            ([System.DateTimeKind]::Local) { return $Value.ToUniversalTime() }
            default { return [datetime]::SpecifyKind($Value, [System.DateTimeKind]::Utc) }
        }
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($text, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        switch ($parsed.Kind) {
            ([System.DateTimeKind]::Utc) { return $parsed }
            ([System.DateTimeKind]::Local) { return $parsed.ToUniversalTime() }
            default { return [datetime]::SpecifyKind($parsed, [System.DateTimeKind]::Utc) }
        }
    }

    if ([datetime]::TryParse($text, [Globalization.CultureInfo]::CurrentCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal,
            [ref]$parsed)) {
        return $parsed
    }

    return $null
}

function Test-Pr11UtcFresh {
    param(
        [datetime]$Utc,
        [int]$MaxAgeSec = 30
    )
    if (-not $Utc) { return $false }
    $ageSec = ((Get-Date).ToUniversalTime() - $Utc).TotalSeconds
    return ($ageSec -ge 0 -and $ageSec -le $MaxAgeSec)
}

function Test-Pr11RuntimeHeartbeatFresh {
    param(
        [object]$RuntimeLifecycle,
        [int]$MaxAgeSec = 30
    )
    if (-not $RuntimeLifecycle -or -not $RuntimeLifecycle.parseOk) { return $false }
    if (-not $RuntimeLifecycle.lastHeartbeatUtc) { return $false }
    return Test-Pr11UtcFresh -Utc $RuntimeLifecycle.lastHeartbeatUtc -MaxAgeSec $MaxAgeSec
}

function Resolve-Pr11StatusJsonPath {
    param(
        [string]$BannerlordRoot,
        [string]$StatusPath = $null
    )
    if ($StatusPath -and (Test-Path -LiteralPath $StatusPath)) {
        try {
            $st = Get-Content -LiteralPath $StatusPath -Raw | ConvertFrom-Json
            if ($st.stateMachine) { return $StatusPath }
        } catch { }
    }
    if (-not (Get-Command Get-StatusJsonCandidates -ErrorAction SilentlyContinue)) {
        return $StatusPath
    }
    foreach ($candidate in (Get-StatusJsonCandidates -BannerlordRoot $BannerlordRoot)) {
        try {
            if (-not (Test-Path -LiteralPath $candidate)) { continue }
            $st = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
            if ($st.stateMachine) { return $candidate }
        } catch { }
    }
    if ($StatusPath) { return $StatusPath }
    return Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
}

function Get-Pr11AssistiveReadiness {
    param(
        [string]$StatusPath,
        [string]$BannerlordRoot = $null,
        [int]$StatusFreshSec = 30,
        [int]$HeartbeatFreshSec = 30
    )

    if ($BannerlordRoot) {
        $StatusPath = Resolve-Pr11StatusJsonPath -BannerlordRoot $BannerlordRoot -StatusPath $StatusPath
    }

    $legacy = Get-F7AssistiveReadinessFromStatus -StatusPath $StatusPath
    $stateMachine = Read-Pr11StateMachineFromStatus -StatusPath $StatusPath
    $runtime = $null
    if ($BannerlordRoot) {
        $runtime = Read-Pr11RuntimeLifecycle -BannerlordRoot $BannerlordRoot
    }

    $confidence = if ($stateMachine.hasStateMachine) { 'state_machine' } else { 'legacy_low' }
    $statusFresh = $false
    if ($stateMachine.hasStateMachine -and $stateMachine.updatedAtUtc) {
        $statusFresh = Test-Pr11UtcFresh -Utc $stateMachine.updatedAtUtc -MaxAgeSec $StatusFreshSec
    } elseif ($legacy.updatedAtUtc) {
        $statusFresh = Test-Pr11UtcFresh -Utc $legacy.updatedAtUtc -MaxAgeSec $StatusFreshSec
    } elseif ($legacy.canPollFileInbox -and $legacy.inGameAssistReady) {
        $statusFresh = $true
    }

    $heartbeatFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $runtime -MaxAgeSec $HeartbeatFreshSec

    $readinessSurface = if ($stateMachine.hasStateMachine -and $stateMachine.gameplaySurface) {
        $stateMachine.gameplaySurface
    } else {
        $legacy.readinessSurface
    }

    $canAccept = if ($stateMachine.hasStateMachine) {
        $stateMachine.canAcceptAssistiveCommand
    } else {
        $legacy.canAcceptAssistiveCommand
    }

    return [pscustomobject][ordered]@{
        readinessSurface = $readinessSurface
        settlementMenuOpen = [bool]$legacy.settlementMenuOpen
        campaignMapSurfaceOpen = [bool]$legacy.campaignMapSurfaceOpen
        campaignReady = [bool]$legacy.campaignReady
        canPollFileInbox = [bool]$legacy.canPollFileInbox
        inGameAssistReady = [bool]$legacy.inGameAssistReady
        canAcceptAssistiveCommand = [bool]$canAccept
        townMenuReady = [bool]$legacy.townMenuReady
        openMapReady = [bool]$legacy.openMapReady
        updatedAtUtc = if ($stateMachine.updatedAtUtc) { $stateMachine.updatedAtUtc } else { $legacy.updatedAtUtc }
        statusPath = $StatusPath
        parseOk = [bool]$legacy.parseOk
        stateMachine = $stateMachine
        runtimeLifecycle = $runtime
        confidence = $confidence
        statusFresh = [bool]$statusFresh
        heartbeatFresh = [bool]$heartbeatFresh
        safeToExecuteTravel = [bool]$stateMachine.safeToExecuteTravel
        blockReason = $stateMachine.blockReason
    }
}

function Test-Pr11TravelExecuteAllowed {
    param(
        [object]$Readiness,
        [int]$StatusFreshSec = 30,
        [int]$HeartbeatFreshSec = 30
    )

    $result = [ordered]@{
        allowed = $false
        reason = $null
        confidence = if ($Readiness) { $Readiness.confidence } else { 'none' }
        routeAgent = 'Agent C - External State Classifier / Assistive Runner'
    }

    if (-not $Readiness -or -not $Readiness.parseOk) {
        $result.reason = 'status_unreadable'
        return [pscustomobject]$result
    }

    if (-not $Readiness.statusFresh) {
        $result.reason = 'status_stale'
        return [pscustomobject]$result
    }

    if ($Readiness.runtimeLifecycle -and $Readiness.runtimeLifecycle.parseOk -and -not $Readiness.heartbeatFresh) {
        $result.reason = 'runtime_heartbeat_stale'
        return [pscustomobject]$result
    }

    if ($Readiness.stateMachine.hasStateMachine) {
        $surface = [string]$Readiness.stateMachine.gameplaySurface
        if ($surface -in $script:Pr11TravelBlockedSurfaces) {
            $result.reason = "surface_blocked:$surface"
            $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
            return [pscustomobject]$result
        }
        if ($surface -notin $script:Pr11TravelAllowedSurfaces) {
            $result.reason = "surface_not_travel_eligible:$surface"
            $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
            return [pscustomobject]$result
        }
        if (-not $Readiness.stateMachine.safeToExecuteTravel) {
            $br = $Readiness.stateMachine.blockReason
            $result.reason = if ($br) { "safeToExecuteTravel_false:$br" } else { 'safeToExecuteTravel_false' }
            $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
            return [pscustomobject]$result
        }
        if (-not $Readiness.canAcceptAssistiveCommand) {
            $result.reason = 'canAcceptAssistiveCommand_false'
            $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
            return [pscustomobject]$result
        }
        $result.allowed = $true
        $result.reason = 'state_machine_travel_ready'
        return [pscustomobject]$result
    }

    # Legacy fallback — lower confidence; mirror pre-PR#13 attach readiness
    if (-not $Readiness.canPollFileInbox -or -not $Readiness.inGameAssistReady) {
        $result.reason = 'legacy_inbox_not_ready'
        return [pscustomobject]$result
    }
    if (-not $Readiness.canAcceptAssistiveCommand) {
        $result.reason = 'legacy_canAcceptAssistiveCommand_false'
        return [pscustomobject]$result
    }
    $legacySurface = [string]$Readiness.readinessSurface
    $legacyOk = $legacySurface -in @('settlement_menu', 'map_surface', 'settlement_interior', 'campaign_map')
    if (-not $legacyOk) {
        $result.reason = "legacy_unsupported_surface:$legacySurface"
        $result.routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
        return [pscustomobject]$result
    }

    $result.allowed = $true
    $result.reason = 'legacy_travel_ready'
    $result.confidence = 'legacy_low'
    return [pscustomobject]$result
}

function Test-Pr11ExecutePassBlockedByRuntime {
    param(
        [object]$Readiness,
        [int]$HeartbeatFreshSec = 30
    )
    if (-not $Readiness) { return $false }
    if ($Readiness.runtimeLifecycle -and $Readiness.runtimeLifecycle.parseOk -and -not $Readiness.heartbeatFresh) {
        return $true
    }
    return $false
}
