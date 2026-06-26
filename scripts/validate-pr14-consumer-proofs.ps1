# PR #14 consumer proof validation — offline fixtures + optional live session probe.
param(
    [switch]$Live,
    [string]$EvidenceDir
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
. (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')
. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')

$proofs = New-Object System.Collections.Generic.List[object]
function Add-Proof {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $proofs.Add([pscustomobject]@{ proof = $Name; pass = $Pass; detail = $Detail }) | Out-Null
    $color = if ($Pass) { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1}: {2}" -f $(if ($Pass) { 'PASS' } else { 'FAIL' }), $Name, $Detail) -ForegroundColor $color
}

$tmpRoot = Join-Path $env:TEMP "pr14-consumer-proof-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

function Write-SimulatedLiveArtifacts {
    param([string]$Root)
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $status = [ordered]@{
        updatedAt = $now
        stateMachine = [ordered]@{
            schemaVersion = 1
            updatedAtUtc = $now
            heartbeatUtc = $now
            gameplaySurface = 'settlement_menu'
            gameLifecycle = 'campaign_loaded'
            safeToExecuteTravel = $true
            safeToExecuteSmithing = $false
            safeToExecuteTrade = $false
            canAcceptAssistiveCommand = $true
            blockReason = $null
            canPollFileInbox = $true
        }
        session = [ordered]@{
            canPollFileInbox = $true
            inGameAssistReady = $true
            canAcceptAssistiveCommand = $true
        }
    }
    $statusPath = Join-Path $Root 'BlacksmithGuild_Status.json'
    ($status | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $statusPath -Encoding UTF8

    $runtime = [ordered]@{
        schemaVersion = 1
        lastHeartbeatUtc = $now
        lastCommandName = $null
        lastCommandStartedAtUtc = $null
        lastCommandFinishedAtUtc = $null
        lastCommandResult = $null
        gracefulShutdownObserved = $false
    }
    $runtimePath = Join-Path $Root 'BlacksmithGuild_RuntimeLifecycle.json'
    ($runtime | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $runtimePath -Encoding UTF8
    return @{ StatusPath = $statusPath; RuntimePath = $runtimePath }
}

# --- Simulated live session (PR #13 producer output present) ---
$sim = Write-SimulatedLiveArtifacts -Root $tmpRoot
$simReady = Get-Pr11AssistiveReadiness -StatusPath $sim.StatusPath -BannerlordRoot $tmpRoot
Add-Proof -Name 'stateMachineConsumed' -Pass $simReady.stateMachine.hasStateMachine `
    -Detail "hasStateMachine=$($simReady.stateMachine.hasStateMachine) surface=$($simReady.stateMachine.gameplaySurface)"
Add-Proof -Name 'runtimeLifecycleConsumed' -Pass $simReady.runtimeLifecycle.parseOk `
    -Detail "parseOk=$($simReady.runtimeLifecycle.parseOk) heartbeat=$($simReady.runtimeLifecycle.lastHeartbeatUtc)"
Add-Proof -Name 'readinessConfidence_not_legacy_low' -Pass ($simReady.confidence -eq 'state_machine') `
    -Detail "confidence=$($simReady.confidence)"

$simGate = Test-Pr11TravelExecuteAllowed -Readiness $simReady
Add-Proof -Name 'travel_gate_permits_settlement_menu' -Pass $simGate.allowed `
    -Detail "allowed=$($simGate.allowed) reason=$($simGate.reason)"

# Stale heartbeat blocks travel
$staleHb = (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o')
$staleRuntimePath = Join-Path $tmpRoot 'BlacksmithGuild_RuntimeLifecycle.stale.json'
(@{
    schemaVersion = 1
    lastHeartbeatUtc = $staleHb
    gracefulShutdownObserved = $false
} | ConvertTo-Json) | Set-Content -LiteralPath $staleRuntimePath -Encoding UTF8
$staleReady = Get-Pr11AssistiveReadiness -StatusPath $sim.StatusPath -BannerlordRoot $tmpRoot
$staleReady.runtimeLifecycle = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $staleRuntimePath
$staleReady.heartbeatFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $staleReady.runtimeLifecycle
$staleGate = Test-Pr11TravelExecuteAllowed -Readiness $staleReady
Add-Proof -Name 'travel_gate_blocks_stale_heartbeat' -Pass (-not $staleGate.allowed -and $staleGate.reason -eq 'runtime_heartbeat_stale') `
    -Detail "allowed=$($staleGate.allowed) reason=$($staleGate.reason)"

Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue

# --- Full-run evidence folder validation (FreshTestLaunch cycle-result) ---
if ($EvidenceDir) {
    if (-not (Test-Path -LiteralPath $EvidenceDir)) { throw "EvidenceDir not found: $EvidenceDir" }
    $cyclePath = Join-Path $EvidenceDir 'cycle-result.json'
    if (-not (Test-Path -LiteralPath $cyclePath)) { throw "cycle-result.json missing in $EvidenceDir" }
    $cycle = Get-Content -LiteralPath $cyclePath -Raw | ConvertFrom-Json

    Add-Proof -Name 'evidence_stateMachineConsumed' -Pass ($cycle.stateMachineConsumed -eq $true) `
        -Detail "stateMachineConsumed=$($cycle.stateMachineConsumed)"
    Add-Proof -Name 'evidence_runtimeLifecycleConsumed' -Pass ($cycle.runtimeLifecycleConsumed -eq $true) `
        -Detail "runtimeLifecycleConsumed=$($cycle.runtimeLifecycleConsumed)"
    Add-Proof -Name 'evidence_readinessConfidence' -Pass ($cycle.readinessConfidence -eq 'state_machine') `
        -Detail "readinessConfidence=$($cycle.readinessConfidence)"
    Add-Proof -Name 'evidence_travelGateReason' -Pass ($cycle.travelGateReason -eq 'state_machine_travel_ready') `
        -Detail "travelGateReason=$($cycle.travelGateReason) allowed=$($cycle.travelGateAllowed)"
    Add-Proof -Name 'evidence_passFail' -Pass ($cycle.passFail -eq 'PASS') `
        -Detail "passFail=$($cycle.passFail) failureClass=$($cycle.failureClass)"

    $statusPath = Join-Path $EvidenceDir 'BlacksmithGuild_Status.json'
    if (Test-Path -LiteralPath $statusPath) {
        $st = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        if ($st.stateMachine) {
            $smPath = Join-Path $EvidenceDir 'status-stateMachine.json'
            ($st.stateMachine | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $smPath -Encoding UTF8
            $surface = [string]$st.stateMachine.gameplaySurface
            $surfaceOk = $surface -in @('settlement_menu', 'campaign_map')
            Add-Proof -Name 'evidence_gameplaySurface' -Pass $surfaceOk `
                -Detail "gameplaySurface=$surface safeToExecuteTravel=$($st.stateMachine.safeToExecuteTravel)"
            Add-Proof -Name 'evidence_canAcceptAssistiveCommand' -Pass ($st.stateMachine.canAcceptAssistiveCommand -eq $true) `
                -Detail "canAcceptAssistiveCommand=$($st.stateMachine.canAcceptAssistiveCommand)"
        } else {
            Add-Proof -Name 'evidence_gameplaySurface' -Pass $false -Detail 'stateMachine block missing from harvested Status.json'
        }
    }

    $runtimePath = Join-Path $EvidenceDir 'BlacksmithGuild_RuntimeLifecycle.json'
    if (Test-Path -LiteralPath $runtimePath) {
        $runtime = Read-Pr11RuntimeLifecycle -BannerlordRoot $EvidenceDir -Path $runtimePath
        $hbFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $runtime
        Add-Proof -Name 'evidence_runtimeHeartbeatRecorded' -Pass $runtime.parseOk `
            -Detail "heartbeat=$($runtime.lastHeartbeatUtc) freshAtHarvest=$hbFresh"
    }

    $execPath = Join-Path $EvidenceDir 'BlacksmithGuild_AssistiveTravelExecution.json'
    if (Test-Path -LiteralPath $execPath) {
        try {
            $exec = Get-Content -LiteralPath $execPath -Raw | ConvertFrom-Json
            $execPass = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $exec
            Add-Proof -Name 'evidence_executeProof' -Pass $execPass.pass `
                -Detail "travelCommandMode=$($exec.travelCommandMode) actualExecutionObserved=$($exec.actualExecutionObserved)"
        } catch {
            Add-Proof -Name 'evidence_executeProof' -Pass $false -Detail $_.Exception.Message
        }
    }

    foreach ($required in @('process-lifecycle.json', 'wait-timeline.json', 'cert-run-output.txt')) {
        $p = Join-Path $EvidenceDir $required
        Add-Proof -Name "evidence_has_$required" -Pass (Test-Path -LiteralPath $p) -Detail $p
    }
}

# --- Optional live session probe (real Bannerlord artifacts) ---
if ($Live) {
    $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
    $statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
    $runtimePath = Get-RuntimeLifecycleJsonPath -BannerlordRoot $bannerlordRoot
    $gameRunning = [bool](Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)

    $liveReady = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
    Add-Proof -Name 'live_stateMachineConsumed' -Pass $liveReady.stateMachine.hasStateMachine `
        -Detail "gameRunning=$gameRunning path=$statusPath"
    Add-Proof -Name 'live_runtimeLifecycleConsumed' -Pass $liveReady.runtimeLifecycle.parseOk `
        -Detail "path=$runtimePath"
    Add-Proof -Name 'live_readinessConfidence_not_legacy_low' -Pass ($liveReady.confidence -eq 'state_machine') `
        -Detail "confidence=$($liveReady.confidence) (requires PR #13 DLL + in-game session)"

    Write-Host ''
    Write-Host 'Running PR11 dry run against live artifacts...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run-pr11-town-travel-launch-attach-execute.ps1') -DryRun -SkipBuild
    if ($LASTEXITCODE -ne 0) { throw "PR11 dry run failed exit=$LASTEXITCODE" }

    $latest = Get-ChildItem -Path (Join-Path $repoRoot 'docs\evidence\live-cert') -Filter '*-pr11-launch-attach-execute' -Directory |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        $cyclePath = Join-Path $latest.FullName 'cycle-result.json'
        if (Test-Path -LiteralPath $cyclePath) {
            $cycle = Get-Content -LiteralPath $cyclePath -Raw | ConvertFrom-Json
            Add-Proof -Name 'live_dryrun_stateMachineConsumed' -Pass ($cycle.stateMachineConsumed -eq $true) `
                -Detail "cycle-result stateMachineConsumed=$($cycle.stateMachineConsumed)"
            Add-Proof -Name 'live_dryrun_runtimeLifecycleConsumed' -Pass ($cycle.runtimeLifecycleConsumed -eq $true) `
                -Detail "runtimeLifecycleConsumed=$($cycle.runtimeLifecycleConsumed)"
            Add-Proof -Name 'live_dryrun_confidence' -Pass ($cycle.readinessConfidence -ne 'legacy_low') `
                -Detail "readinessConfidence=$($cycle.readinessConfidence)"
        }
    }
}

Write-Host ''
$failed = @($proofs | Where-Object { -not $_.pass })
if ($failed.Count -gt 0) {
    Write-Host "PR #14 consumer proofs: FAIL ($($failed.Count) proof(s))" -ForegroundColor Red
    exit 1
}
Write-Host "PR #14 consumer proofs: PASS ($($proofs.Count) proof(s))" -ForegroundColor Green
exit 0
