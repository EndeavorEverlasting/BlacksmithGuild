# Offline regression: PR #14 consumer for PR #13 stateMachine + RuntimeLifecycle outputs.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
. (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')

$tmpRoot = Join-Path $env:TEMP "pr11-runtime-consumer-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

function New-StatusFixture {
    param(
        [hashtable]$StateMachine = $null,
        [hashtable]$Session = $null
    )
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $obj = [ordered]@{
        updatedAt = $now
        session = if ($Session) { $Session } else { [ordered]@{} }
    }
    if ($StateMachine) {
        if (-not $StateMachine.Contains('updatedAtUtc')) { $StateMachine['updatedAtUtc'] = $now }
        $obj['stateMachine'] = $StateMachine
    }
    return ($obj | ConvertTo-Json -Depth 8)
}

function New-RuntimeFixture {
    param([hashtable]$Fields)
    $base = [ordered]@{
        schemaVersion = 1
        lastHeartbeatUtc = (Get-Date).ToUniversalTime().ToString('o')
        gracefulShutdownObserved = $false
        lastCommandStartedAtUtc = $null
        lastCommandFinishedAtUtc = $null
        lastCommandName = $null
        lastCommandResult = $null
    }
    foreach ($k in $Fields.Keys) { $base[$k] = $Fields[$k] }
    return ($base | ConvertTo-Json -Depth 6)
}

function Test-TravelGate {
    param(
        [string]$Surface,
        [bool]$SafeTravel = $true,
        [bool]$CanAccept = $true,
        [string]$BlockReason = $null,
        [bool]$ExpectAllowed
    )
    $statusPath = Join-Path $tmpRoot "status-$Surface.json"
    New-StatusFixture -StateMachine @{
        gameplaySurface = $Surface
        gameLifecycle = 'campaign_loaded'
        safeToExecuteTravel = $SafeTravel
        safeToExecuteSmithing = ($Surface -eq 'blacksmithing')
        safeToExecuteTrade = ($Surface -eq 'trading')
        canAcceptAssistiveCommand = $CanAccept
        blockReason = $BlockReason
    } | Set-Content -LiteralPath $statusPath -Encoding UTF8

    $runtimePath = Join-Path $tmpRoot "runtime-$Surface.json"
    New-RuntimeFixture @{} | Set-Content -LiteralPath $runtimePath -Encoding UTF8

    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $tmpRoot
    $ready.runtimeLifecycle = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $runtimePath
    $ready.heartbeatFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $ready.runtimeLifecycle
    $gate = Test-Pr11TravelExecuteAllowed -Readiness $ready
    if ($gate.allowed -ne $ExpectAllowed) {
        throw "surface=$Surface expected allowed=$ExpectAllowed got $($gate.allowed) reason=$($gate.reason)"
    }
}

Test-TravelGate -Surface 'settlement_menu' -ExpectAllowed $true
Test-TravelGate -Surface 'campaign_map' -ExpectAllowed $true
Test-TravelGate -Surface 'blacksmithing' -SafeTravel $false -BlockReason 'surface_blocked:blacksmithing' -ExpectAllowed $false
Test-TravelGate -Surface 'trading' -SafeTravel $false -BlockReason 'surface_blocked:trading' -ExpectAllowed $false
Test-TravelGate -Surface 'conversation' -SafeTravel $false -BlockReason 'mission_active:conversation' -ExpectAllowed $false

function New-RecursiveBranchStatusFixture {
    param(
        [hashtable]$RecursiveBranchState,
        [hashtable]$StateMachine = $null
    )
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $obj = [ordered]@{ updatedAt = $now; session = [ordered]@{} }
    if ($StateMachine) {
        if (-not $StateMachine.Contains('updatedAtUtc')) { $StateMachine['updatedAtUtc'] = $now }
        $obj['stateMachine'] = $StateMachine
    }
    if (-not $RecursiveBranchState.Contains('updatedAtUtc')) { $RecursiveBranchState['updatedAtUtc'] = $now }
    $obj['recursiveBranchState'] = $RecursiveBranchState
    return ($obj | ConvertTo-Json -Depth 10)
}

# recursiveBranchState: fresh parse with all eight branch gates
$rbsFreshPath = Join-Path $tmpRoot 'status-rbs-fresh.json'
$branchGates = [ordered]@{
    travel = [ordered]@{ state = 'available'; reason = 'surface_allows_travel' }
    trade = [ordered]@{ state = 'blocked'; reason = 'trade_surface_not_open' }
    smith_refine = [ordered]@{ state = 'blocked'; reason = 'smithing_surface_not_open' }
    rest_wait = [ordered]@{ state = 'available'; reason = 'safe_wait_surface' }
    tavern_scan = [ordered]@{ state = 'blocked'; reason = 'not_at_settlement_surface' }
    companion_roster = [ordered]@{ state = 'unknown'; reason = 'companion_roster_not_scanned' }
    avoid_threat = [ordered]@{ state = 'unknown'; reason = 'threat_state_unknown' }
    observe_only = [ordered]@{ state = 'available'; reason = 'always_safe_fallback' }
}
New-RecursiveBranchStatusFixture -RecursiveBranchState @{
    schemaVersion = 1
    currentTown = 'Ortysia'
    currentSettlementId = 'town_ES3'
    gameplaySurface = 'campaign_map'
    terminal = $false
    nextActionRequired = $true
    nextPlannedBranch = 'observe_only'
    nextActionReason = 'branch_truth_requires_fresh_observation'
    branches = $branchGates
} -StateMachine @{
    gameplaySurface = 'campaign_map'
    gameLifecycle = 'campaign_loaded'
    safeToExecuteTravel = $true
    canAcceptAssistiveCommand = $true
} | Set-Content -LiteralPath $rbsFreshPath -Encoding UTF8

$rbsParsed = Read-Pr11RecursiveBranchStateFromStatus -StatusPath $rbsFreshPath -FreshSec 30
if (-not $rbsParsed.hasRecursiveBranchState) { throw 'fresh recursiveBranchState must parse' }
if (-not $rbsParsed.fresh) { throw 'fresh recursiveBranchState must be fresh' }
if ($rbsParsed.schemaVersion -ne 1) { throw 'recursiveBranchState schemaVersion must parse' }
if ($rbsParsed.nextPlannedBranch -ne 'observe_only') { throw 'nextPlannedBranch must parse' }
if ($rbsParsed.nextActionReason -ne 'branch_truth_requires_fresh_observation') { throw 'nextActionReason must parse' }
foreach ($gateName in @('travel', 'trade', 'smith_refine', 'rest_wait', 'tavern_scan', 'companion_roster', 'avoid_threat', 'observe_only')) {
    if (-not $rbsParsed.branches.ContainsKey($gateName)) { throw "missing branch gate $gateName" }
}

$rbsReady = Get-Pr11AssistiveReadiness -StatusPath $rbsFreshPath -BannerlordRoot $tmpRoot
if (-not $rbsReady.recursiveBranchFresh) { throw 'readiness must surface recursiveBranchFresh=true when fresh' }
if (-not $rbsReady.recursiveBranchState.hasRecursiveBranchState) { throw 'readiness must surface recursiveBranchState' }

# stale recursiveBranchState: hasRecursiveBranchState true, fresh false
$rbsStalePath = Join-Path $tmpRoot 'status-rbs-stale.json'
$staleRbsUtc = (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o')
New-RecursiveBranchStatusFixture -RecursiveBranchState @{
    schemaVersion = 1
    updatedAtUtc = $staleRbsUtc
    nextActionRequired = $true
    nextPlannedBranch = 'travel'
    nextActionReason = 'stale_branch_truth'
    branches = $branchGates
} | Set-Content -LiteralPath $rbsStalePath -Encoding UTF8
$rbsStale = Read-Pr11RecursiveBranchStateFromStatus -StatusPath $rbsStalePath -FreshSec 30
if (-not $rbsStale.hasRecursiveBranchState) { throw 'stale recursiveBranchState must still parse' }
if ($rbsStale.fresh) { throw 'stale recursiveBranchState must not be fresh' }
$staleReady = Get-Pr11AssistiveReadiness -StatusPath $rbsStalePath -BannerlordRoot $tmpRoot
if ($staleReady.recursiveBranchFresh) { throw 'readiness must surface recursiveBranchFresh=false when stale' }

# missing recursiveBranchState block defaults
$rbsMissingPath = Join-Path $tmpRoot 'status-rbs-missing.json'
New-StatusFixture -StateMachine @{
    gameplaySurface = 'campaign_map'
    gameLifecycle = 'campaign_loaded'
    safeToExecuteTravel = $true
    canAcceptAssistiveCommand = $true
} | Set-Content -LiteralPath $rbsMissingPath -Encoding UTF8
$rbsMissing = Read-Pr11RecursiveBranchStateFromStatus -StatusPath $rbsMissingPath -FreshSec 30
if ($rbsMissing.hasRecursiveBranchState) { throw 'missing recursiveBranchState must default hasRecursiveBranchState=false' }
if ($rbsMissing.fresh) { throw 'missing recursiveBranchState must default fresh=false' }

# Legacy fallback without stateMachine
$legacyPath = Join-Path $tmpRoot 'status-legacy.json'
New-StatusFixture -Session @{
    readinessSurface = 'settlement_menu'
    canPollFileInbox = $true
    inGameAssistReady = $true
    canAcceptAssistiveCommand = $true
} | Set-Content -LiteralPath $legacyPath -Encoding UTF8
$legacyReady = Get-Pr11AssistiveReadiness -StatusPath $legacyPath -BannerlordRoot $tmpRoot
if ($legacyReady.confidence -ne 'legacy_low') { throw 'missing stateMachine must use legacy_low confidence' }
$legacyGate = Test-Pr11TravelExecuteAllowed -Readiness $legacyReady
if (-not $legacyGate.allowed) { throw "legacy fallback must allow travel got $($legacyGate.reason)" }
if ($legacyGate.confidence -ne 'legacy_low') { throw 'legacy gate must report legacy_low confidence' }

# Stale heartbeat blocks PASS
$staleRuntimePath = Join-Path $tmpRoot 'runtime-stale.json'
$staleHb = (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o')
New-RuntimeFixture @{ lastHeartbeatUtc = $staleHb } | Set-Content -LiteralPath $staleRuntimePath -Encoding UTF8
$staleRuntime = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $staleRuntimePath
$legacyReady.runtimeLifecycle = $staleRuntime
$legacyReady.heartbeatFresh = $false
if (-not (Test-Pr11ExecutePassBlockedByRuntime -Readiness $legacyReady)) {
    throw 'stale heartbeat must block PASS'
}

# Missing heartbeat is stale, not a runner exception
$missingHeartbeatPath = Join-Path $tmpRoot 'runtime-missing-heartbeat.json'
New-RuntimeFixture @{ lastHeartbeatUtc = $null } | Set-Content -LiteralPath $missingHeartbeatPath -Encoding UTF8
$missingHeartbeatRuntime = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $missingHeartbeatPath
if (Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $missingHeartbeatRuntime) {
    throw 'missing heartbeat must not be fresh'
}

# Termination: graceful shutdown
$gracePath = Join-Path $tmpRoot 'runtime-grace.json'
New-RuntimeFixture @{
    gracefulShutdownObserved = $true
    lastHeartbeatUtc = (Get-Date).ToUniversalTime().ToString('o')
} | Set-Content -LiteralPath $gracePath -Encoding UTF8
$graceRuntime = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $gracePath
$termGrace = Invoke-TbgTerminationClassification -BannerlordRoot $tmpRoot -CyclePhase 'cert' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false }) -RuntimeLifecycle $graceRuntime
if ($termGrace.classification -ne 'clean_shutdown') {
    throw "expected clean_shutdown got $($termGrace.classification)"
}

# Termination: command in flight exit
$inflightPath = Join-Path $tmpRoot 'runtime-inflight.json'
New-RuntimeFixture @{
    lastCommandStartedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    lastCommandFinishedAtUtc = $null
    lastCommandName = 'AssistiveLeaveTownAndTravel'
    lastHeartbeatUtc = (Get-Date).ToUniversalTime().ToString('o')
} | Set-Content -LiteralPath $inflightPath -Encoding UTF8
$inflightRuntime = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $inflightPath
$termInflight = Invoke-TbgTerminationClassification -BannerlordRoot $tmpRoot -CyclePhase 'cert' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false }) -RuntimeLifecycle $inflightRuntime
if ($termInflight.classification -ne 'command_in_flight_exit') {
    throw "expected command_in_flight_exit got $($termInflight.classification)"
}

# Termination: crash_or_unexpected_exit (stale heartbeat, no graceful)
$crashPath = Join-Path $tmpRoot 'runtime-crash.json'
New-RuntimeFixture @{
    gracefulShutdownObserved = $false
    lastHeartbeatUtc = $staleHb
} | Set-Content -LiteralPath $crashPath -Encoding UTF8
$crashRuntime = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $crashPath
$termCrash = Invoke-TbgTerminationClassification -BannerlordRoot $tmpRoot -CyclePhase 'cert' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $false }) -RuntimeLifecycle $crashRuntime
if ($termCrash.classification -ne 'crash_or_unexpected_exit') {
    throw "expected crash_or_unexpected_exit got $($termCrash.classification)"
}

# Termination: status_stale_process_alive + heartbeat stale
$aliveStalePath = Join-Path $tmpRoot 'runtime-alive-stale.json'
New-RuntimeFixture @{ lastHeartbeatUtc = $staleHb } | Set-Content -LiteralPath $aliveStalePath -Encoding UTF8
$aliveStaleRuntime = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $aliveStalePath
$termAlive = Invoke-TbgTerminationClassification -BannerlordRoot $tmpRoot -CyclePhase 'cert' `
    -Detection ([pscustomobject]@{ gameProcessRunning = $true }) -RuntimeLifecycle $aliveStaleRuntime `
    -StatusPath (Join-Path $tmpRoot 'nonexistent-status.json')
if ($termAlive.classification -ne 'status_stale_process_alive') {
    throw "expected status_stale_process_alive got $($termAlive.classification)"
}

# Runner contract strings
$runnerText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-pr11-town-travel-launch-attach-execute.ps1') -Raw
foreach ($needle in @(
    'pr11-runtime-state-consumer.ps1', 'Get-Pr11AssistiveReadiness', 'Test-Pr11TravelExecuteAllowed',
    'BlacksmithGuild_RuntimeLifecycle.json', 'stateMachineConsumed', 'runtimeLifecycleConsumed'
)) {
    if ($runnerText -notmatch [regex]::Escape($needle)) { throw "runner missing consumer hook: $needle" }
}

Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'PASS offline PR11 runtime state consumer regression'
