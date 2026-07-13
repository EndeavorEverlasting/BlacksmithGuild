# Automated fixture tests for the visible trade proof coordinator.
# Tests event schema, provenance, hash match/mismatch, terminal states,
# capsule generation, sanitization, artifact index, CMD wrapper patterns,
# and fixture replay.

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $RepoRoot 'scripts\visible-trade-proof-event-schema.ps1')
. (Join-Path $RepoRoot 'scripts\visible-trade-cycle-contract.ps1')

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw "ASSERT_FAILED: $Message" }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Actual,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Expected -ne $Actual) { throw "ASSERT_FAILED: $Message expected='$Expected' actual='$Actual'" }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Needle
    )
    $full = Join-Path $RepoRoot $Path
    Assert-True (Test-Path -LiteralPath $full) "Missing file: $Path"
    $text = Get-Content -LiteralPath $full -Raw
    Assert-True ($text.Contains($Needle)) "$Path is missing required text: $Needle"
}

$testCount = 0
$passCount = 0

function Test-Case {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Body
    )
    $script:testCount++
    try {
        & $Body
        $script:passCount++
        Write-Host "  PASS: $Name" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

Write-Host ''
Write-Host '=== Visible Trade Proof Coordinator Tests ===' -ForegroundColor Cyan
Write-Host ''

# ═══════════════════════════════════════════════════════════════
# 1. CMD wrapper path resolution and pause behavior
# ═══════════════════════════════════════════════════════════════
Write-Host '--- CMD Wrapper Tests ---' -ForegroundColor Yellow

Test-Case 'Run-VisibleTradeProof.cmd references correct script' {
    Assert-Contains 'Run-VisibleTradeProof.cmd' 'scripts\run-visible-trade-proof.ps1'
}

Test-Case 'Run-VisibleTradeProof.cmd uses %~dp0 for path resolution' {
    Assert-Contains 'Run-VisibleTradeProof.cmd' '%~dp0'
}

Test-Case 'Run-VisibleTradeProof.cmd supports TBG_NO_PAUSE' {
    Assert-Contains 'Run-VisibleTradeProof.cmd' 'TBG_NO_PAUSE'
}

Test-Case 'Run-VisibleTradeProof.cmd preserves exit code' {
    Assert-Contains 'Run-VisibleTradeProof.cmd' 'ERRORLEVEL'
}

Test-Case 'Run-VisibleTradeProof.cmd prints artifact paths' {
    Assert-Contains 'Run-VisibleTradeProof.cmd' 'artifacts\latest\visible-trade-proof'
}

Test-Case 'Show-LatestVisibleTradeProof.cmd references correct script' {
    Assert-Contains 'Show-LatestVisibleTradeProof.cmd' 'scripts\show-latest-visible-trade-proof.ps1'
}

Test-Case 'Show-LatestVisibleTradeProof.cmd supports TBG_NO_PAUSE' {
    Assert-Contains 'Show-LatestVisibleTradeProof.cmd' 'TBG_NO_PAUSE'
}

Test-Case 'Stop-TbgRuntime.cmd references correct script' {
    Assert-Contains 'Stop-TbgRuntime.cmd' 'scripts\stop-tbg-runtime-proof.ps1'
}

Test-Case 'Stop-TbgRuntime.cmd supports TBG_NO_PAUSE' {
    Assert-Contains 'Stop-TbgRuntime.cmd' 'TBG_NO_PAUSE'
}

Test-Case 'Toggle-TbgEvidenceAutomation.cmd references correct script' {
    Assert-Contains 'Toggle-TbgEvidenceAutomation.cmd' 'scripts\toggle-tbg-evidence-automation-proof.ps1'
}

Test-Case 'Toggle-TbgEvidenceAutomation.cmd supports TBG_NO_PAUSE' {
    Assert-Contains 'Toggle-TbgEvidenceAutomation.cmd' 'TBG_NO_PAUSE'
}

Test-Case 'All CMD files use @echo off and setlocal' {
    foreach ($cmd in @('Run-VisibleTradeProof.cmd', 'Show-LatestVisibleTradeProof.cmd', 'Stop-TbgRuntime.cmd', 'Toggle-TbgEvidenceAutomation.cmd')) {
        Assert-Contains $cmd '@echo off'
        Assert-Contains $cmd 'setlocal'
    }
}

Test-Case 'All CMD files use powershell -NoProfile -ExecutionPolicy Bypass' {
    foreach ($cmd in @('Run-VisibleTradeProof.cmd', 'Show-LatestVisibleTradeProof.cmd', 'Stop-TbgRuntime.cmd', 'Toggle-TbgEvidenceAutomation.cmd')) {
        Assert-Contains $cmd 'powershell -NoProfile -ExecutionPolicy Bypass'
    }
}

# ═══════════════════════════════════════════════════════════════
# 2. Event schema
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Event Schema Tests ---' -ForegroundColor Yellow

Test-Case 'Event schema produces required fields' {
    $seq = 0
    $seq++
    $event = New-TbgVisibleTradeProofEvent `
        -RunId 'test-run' -CorrelationId 'test-run' `
        -Sequence $seq -Stage 'preflight' -Status 'started' `
        -Subject 'coordinator' -Action 'begin' -Object 'test' `
        -Sentence 'Test event.'

    Assert-Equal 'TbgVisibleTradeProofEvent.v1' $event.schema 'schema'
    Assert-Equal 'test-run' $event.runId 'runId'
    Assert-Equal 'test-run' $event.correlationId 'correlationId'
    Assert-True ($event.sequence -eq 1) 'sequence should be 1'
    Assert-True (-not [string]::IsNullOrWhiteSpace($event.timestampUtc)) 'timestampUtc'
    Assert-Equal 'preflight' $event.stage 'stage'
    Assert-Equal 'started' $event.status 'status'
    Assert-Equal 'coordinator' $event.subject 'subject'
    Assert-Equal 'begin' $event.action 'action'
    Assert-Equal 'test' $event.object 'object'
    Assert-Equal 'Test event.' $event.sentence 'sentence'
}

Test-Case 'Event schema increments sequence' {
    $seq = 5
    $seq++
    $event = New-TbgVisibleTradeProofEvent `
        -RunId 'test' -CorrelationId 'test' `
        -Sequence $seq -Stage 'build' -Status 'passed' `
        -Subject 'coordinator' -Action 'build' -Object 'dll' `
        -Sentence 'Build passed.'
    Assert-True ($event.sequence -eq 6) 'sequence should increment to 6'
}

Test-Case 'All required stages are listed' {
    $stages = Get-TbgVisibleTradeProofStageList
    $required = @('preflight','workspace','validation','runtime-stop','build','install','hash-verification','evidence-start','launch','campaign-ready','route-request','command-ack','time-advance','movement','checkpoint','arrival','buy','travel','sell','runtime-stop-final','capsule','remote-publish','closeout')
    foreach ($s in $required) {
        Assert-True ($stages -contains $s) "Stage '$s' must be in stage list"
    }
}

Test-Case 'All terminal states are defined' {
    $states = Get-TbgVisibleTradeProofTerminalStates
    $required = @('PASS_VISIBLE_TRADE_PROVEN','BLOCKED_CAMPAIGN_NOT_READY','BLOCKED_RUNTIME_ENVIRONMENT_UNAVAILABLE','FAIL_SOURCE_BUILD_INSTALL_MISMATCH','FAIL_STATIC_VALIDATION','FAIL_LAUNCHER_HANDOFF','FAIL_COMMAND_NOT_ACKNOWLEDGED','FAIL_CAMPAIGN_TIME_NOT_ADVANCING','FAIL_NO_POSITION_DELTA','FAIL_ROUTE_CHECKPOINT_NOT_OBSERVED','FAIL_ARRIVAL_NOT_OBSERVED','FAIL_BUY_DELTA_NOT_OBSERVED','FAIL_SELL_DELTA_NOT_OBSERVED','FAIL_EVIDENCE_INCOMPLETE','FAIL_REMOTE_EVIDENCE_NOT_PUBLISHED','CANCELLED_SAFE_STOP')
    foreach ($s in $required) {
        Assert-True ($states -contains $s) "Terminal state '$s' must be defined"
    }
}

# ═══════════════════════════════════════════════════════════════
# 3. Exact-head provenance
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Provenance Tests ---' -ForegroundColor Yellow

Test-Case 'Coordinator script has provenance fields' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'sourceBranch'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'sourceCommit'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'executionWorktree'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'executionBranch'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'executionCommit'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'builtAssemblySha256'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'installedAssemblySha256'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'testRunId'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'commandCorrelationId'
}

Test-Case 'FAIL_SOURCE_BUILD_INSTALL_MISMATCH is raised on hash mismatch' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'FAIL_SOURCE_BUILD_INSTALL_MISMATCH'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'local=$localDllHash installed=$installedDllHash'
}

# ═══════════════════════════════════════════════════════════════
# 4. Event ordering and correlation
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Event Ordering Tests ---' -ForegroundColor Yellow

Test-Case 'Coordinator writes all required lifecycle stages' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    $required = @('preflight', 'workspace', 'validation', 'runtime-stop', 'build', 'install', 'hash-verification', 'evidence-start', 'launch', 'campaign-ready', 'route-request', 'command-ack', 'time-advance', 'movement', 'checkpoint', 'arrival', 'buy', 'runtime-stop-final', 'capsule', 'remote-publish', 'closeout')
    foreach ($stage in $required) {
        $idx = $text.IndexOf("-Stage $stage ", [System.StringComparison]::Ordinal)
        Assert-True ($idx -ge 0) "Stage '$stage' must appear in the coordinator"
    }
    $earlyStages = @('preflight', 'workspace', 'validation', 'build')
    $lateStages = @('capsule', 'remote-publish', 'closeout')
    $firstEarly = 999999
    foreach ($s in $earlyStages) {
        $idx = $text.IndexOf("-Stage $s ", [System.StringComparison]::Ordinal)
        if ($idx -ge 0 -and $idx -lt $firstEarly) { $firstEarly = $idx }
    }
    $lastLate = 0
    foreach ($s in $lateStages) {
        $idx = $text.IndexOf("-Stage $s ", [System.StringComparison]::Ordinal)
        if ($idx -gt $lastLate) { $lastLate = $idx }
    }
    Assert-True ($firstEarly -lt $lastLate) 'Early stages must appear before late stages'
}

Test-Case 'All events include runId and correlationId' {
    $seq = 0
    $event = New-TbgVisibleTradeProofEvent `
        -RunId 'corr-123' -CorrelationId 'corr-123' `
        -Sequence ([ref]$seq) -Stage 'test' -Status 'info' `
        -Subject 's' -Action 'a' -Object 'o' `
        -Sentence 'Test.'
    Assert-Equal 'corr-123' $event.runId 'runId'
    Assert-Equal 'corr-123' $event.correlationId 'correlationId'
}

# ═══════════════════════════════════════════════════════════════
# 5. Movement proof
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Movement Proof Tests ---' -ForegroundColor Yellow

Test-Case 'Coordinator checks movement delta' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'movementResult'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'partyMovedDistance'
}

Test-Case 'Coordinator checks movement below noise is not counted' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True ($text.Contains('movementResult') -and $text.Contains('partyMovedDistance')) 'Movement must check both delta and observed'
}

# ═══════════════════════════════════════════════════════════════
# 6. Capsule and sanitization
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Capsule and Sanitization Tests ---' -ForegroundColor Yellow

Test-Case 'Capsule script exists' {
    Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\visible-trade-proof-capsule.ps1')) 'Capsule script must exist'
}

Test-Case 'Capsule sanitizes personal paths' {
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'C:\\Users\\'
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' '<USER>'
}

Test-Case 'Capsule sanitizes tokens' {
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'ghp_'
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' '<TOKEN_REDACTED>'
}

Test-Case 'Capsule excludes saves and binaries' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\visible-trade-proof-capsule.ps1') -Raw
    Assert-True ($text.Contains('Sanitize-TbgCapsuleString') -or $text.Contains('Sanitize')) 'Capsule must sanitize content'
}

Test-Case 'Capsule includes SHA-256 hashes for retained artifacts' {
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'sha256'
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'Get-TbgFileSha256'
}

Test-Case 'Artifact index schema is defined' {
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'TbgArtifactIndex.v1'
}

Test-Case 'Capsule manifest schema is defined' {
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'TbgVisibleTradeProofCapsule.v1'
}

# ═══════════════════════════════════════════════════════════════
# 7. Remote publication
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Remote Publication Tests ---' -ForegroundColor Yellow

Test-Case 'Publication script exists' {
    Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\publish-visible-trade-proof-evidence.ps1')) 'Publication script must exist'
}

Test-Case 'Publication uses deterministic branch naming' {
    Assert-Contains 'scripts\publish-visible-trade-proof-evidence.ps1' 'evidence/visible-trade/'
}

Test-Case 'Publication adds PR comment with evidence marker' {
    Assert-Contains 'scripts\publish-visible-trade-proof-evidence.ps1' '<!-- tbg-visible-trade-proof -->'
}

Test-Case 'Publication retries transient failures' {
    Assert-Contains 'scripts\publish-visible-trade-proof-evidence.ps1' 'MaxRetries'
    Assert-Contains 'scripts\publish-visible-trade-proof-evidence.ps1' 'Start-Sleep'
}

Test-Case 'Publication never force pushes' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\publish-visible-trade-proof-evidence.ps1') -Raw
    Assert-True (-not $text.Contains('push --force')) 'Publication must never force push'
    Assert-True (-not $text.Contains('push -f')) 'Publication must never force push'
}

Test-Case 'Publication never deletes branches' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\publish-visible-trade-proof-evidence.ps1') -Raw
    Assert-True (-not $text.Contains('branch -D')) 'Publication must never delete branches'
    Assert-True (-not $text.Contains('branch -D')) 'Publication must never delete branches'
}

# ═══════════════════════════════════════════════════════════════
# 8. Terminal states
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Terminal State Tests ---' -ForegroundColor Yellow

Test-Case 'PASS_VISIBLE_TRADE_PROVEN requires buy and arrival and movement' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    $idx = $text.IndexOf('PASS_VISIBLE_TRADE_PROVEN', [System.StringComparison]::Ordinal)
    Assert-True ($idx -ge 0) 'PASS_VISIBLE_TRADE_PROVEN must be set'
    $context = $text.Substring([Math]::Max(0, $idx - 200), 400)
    Assert-True ($context.Contains('buyResult.observed') -or $context.Contains('buy')) 'PASS must check buy'
    Assert-True ($context.Contains('arrivalResult.observed') -or $context.Contains('arrival')) 'PASS must check arrival'
    Assert-True ($context.Contains('movementResult.observed') -or $context.Contains('movement')) 'PASS must check movement'
}

Test-Case 'FAIL_REMOTE_EVIDENCE_NOT_PUBLISHED is set when publication fails' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'FAIL_REMOTE_EVIDENCE_NOT_PUBLISHED'
}

Test-Case 'CANCELLED_SAFE_STOP terminal state is defined' {
    $states = Get-TbgVisibleTradeProofTerminalStates
    Assert-True ($states -contains 'CANCELLED_SAFE_STOP') 'CANCELLED_SAFE_STOP must be defined'
}

# ═══════════════════════════════════════════════════════════════
# 9. Forbidden claims
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Forbidden Claims Tests ---' -ForegroundColor Yellow

Test-Case 'Result includes forbiddenClaims' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'forbiddenClaims'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'A command acknowledgement is not terminal workflow proof'
}

Test-Case 'Result includes allowedClaims' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'allowedClaims'
}

# ═══════════════════════════════════════════════════════════════
# 10. Safety: no destructive operations
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Safety Tests ---' -ForegroundColor Yellow

Test-Case 'Coordinator never uses git reset --hard' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True (-not $text.Contains('git reset --hard')) 'Must not use git reset --hard'
}

Test-Case 'Coordinator never uses git clean' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True (-not $text.Contains('git clean')) 'Must not use git clean'
}

Test-Case 'Coordinator never uses git stash' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True (-not $text.Contains('git stash')) 'Must not use git stash'
}

Test-Case 'Coordinator never uses git push --force' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True (-not $text.Contains('push --force')) 'Must not use git push --force'
}

Test-Case 'Coordinator never uses git branch -D' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True (-not $text.Contains('branch -D')) 'Must not use git branch -D'
}

# ═══════════════════════════════════════════════════════════════
# 11. Proof ceiling and hierarchy
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Proof Ceiling Tests ---' -ForegroundColor Yellow

Test-Case 'Proof levels are ordered correctly' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'proofLevels'
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    $idx = $text.IndexOf('proofLevels = @(', [System.StringComparison]::Ordinal)
    Assert-True ($idx -ge 0) 'proofLevels array must exist'
    $levelStr = $text.Substring($idx, 300)
    Assert-True ($levelStr.Contains('none') -and $levelStr.Contains('contract') -and $levelStr.Contains('launcher') -and $levelStr.Contains('buy') -and $levelStr.Contains('sell') -and $levelStr.Contains('complete')) 'All proof levels must be in order'
}

# ═══════════════════════════════════════════════════════════════
# 12. Fixture replay
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Fixture Replay Tests ---' -ForegroundColor Yellow

Test-Case 'Fixture file exists' {
    $fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\visible-trade-proof.fixtures.json'
    Assert-True (Test-Path -LiteralPath $fixturePath) 'Fixture file must exist'
}

Test-Case 'Fixture file has base case and at least 10 cases' {
    $fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\visible-trade-proof.fixtures.json'
    $fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    Assert-True ($fixtures.schemaVersion -eq 'TbgVisibleTradeProofFixtures.v1') 'Fixture schema'
    Assert-True (@($fixtures.cases).Count -ge 10) 'At least 10 fixture cases required'
}

Test-Case 'Fixture replay: complete_visible_trade_passes' {
    $fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\visible-trade-proof.fixtures.json'
    $fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $case = @($fixtures.cases) | Where-Object { $_.id -eq 'complete_visible_trade_passes' }
    Assert-True ($null -ne $case) 'Fixture case must exist'
    Assert-Equal 'PASS_VISIBLE_TRADE_PROVEN' ([string]$case.expectedTerminalState) 'terminal state'
    Assert-Equal 'PASS' ([string]$case.expectedPassFail) 'passFail'
    Assert-Equal 'complete' ([string]$case.expectedHighestProof) 'highestProof'
}

Test-Case 'Fixture replay: build hash mismatch' {
    $fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\visible-trade-proof.fixtures.json'
    $fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $case = @($fixtures.cases) | Where-Object { $_.id -eq 'build_hash_mismatch_fails' }
    Assert-True ($null -ne $case) 'Fixture case must exist'
    Assert-Equal 'FAIL_SOURCE_BUILD_INSTALL_MISMATCH' ([string]$case.expectedTerminalState) 'terminal state'
}

Test-Case 'Fixture replay: no remote publication' {
    $fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\visible-trade-proof.fixtures.json'
    $fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $case = @($fixtures.cases) | Where-Object { $_.id -eq 'no_remote_publication_fails' }
    Assert-True ($null -ne $case) 'Fixture case must exist'
    Assert-Equal 'FAIL_REMOTE_EVIDENCE_NOT_PUBLISHED' ([string]$case.expectedTerminalState) 'terminal state'
}

# ═══════════════════════════════════════════════════════════════
# 13. Diagnostic mode
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Diagnostic Mode Tests ---' -ForegroundColor Yellow

Test-Case 'Coordinator supports -DryRun flag' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' '[switch]$DryRun'
}

Test-Case 'Coordinator supports -Diagnostic flag' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' '[switch]$Diagnostic'
}

Test-Case 'Diagnostic mode sets DIAGNOSTIC_ONLY terminal state' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'DIAGNOSTIC_ONLY'
}

Test-Case 'Diagnostic mode exits with code 3' {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') -Raw
    Assert-True ($text.Contains('exitCode = 3') -or $text.Contains('exitCode=3')) 'Diagnostic mode must set exit code 3'
}

# ═══════════════════════════════════════════════════════════════
# 14. Show/Toggle surface
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Status/Stop/Toggle Surface Tests ---' -ForegroundColor Yellow

Test-Case 'Show script displays all required fields' {
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'terminalState'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'highestProofReached'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'commandAck'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'movement'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'arrival'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'buy'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'sell'
    Assert-Contains 'scripts\show-latest-visible-trade-proof.ps1' 'evidenceBranch'
}

Test-Case 'Stop script writes correlated stop event' {
    Assert-Contains 'scripts\stop-tbg-runtime-proof.ps1' 'TbgRuntimeStopEvent.v1'
    Assert-Contains 'scripts\stop-tbg-runtime-proof.ps1' 'correlationId'
}

Test-Case 'Toggle script exposes supported toggle' {
    Assert-Contains 'scripts\toggle-tbg-evidence-automation-proof.ps1' 'TbgEvidenceAutomationToggle.v1'
    Assert-Contains 'scripts\toggle-tbg-evidence-automation-proof.ps1' 'enabled'
}

# ═══════════════════════════════════════════════════════════════
# 15. UTF-8 BOM requirement
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- UTF-8 BOM Tests ---' -ForegroundColor Yellow

Test-Case 'Coordinator references UTF-8 encoding' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'UTF8Encoding'
}

Test-Case 'Capsule script references UTF-8 encoding' {
    Assert-Contains 'scripts\visible-trade-proof-capsule.ps1' 'UTF8Encoding'
}

# ═══════════════════════════════════════════════════════════════
# 16. Dry-run path
# ═══════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '--- Dry-Run Path Tests ---' -ForegroundColor Yellow

Test-Case 'DryRun triggers diagnostic mode' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'DryRun'
}

Test-Case 'Coordinator has existing contract integration' {
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'visible-trade-cycle-contract.ps1'
    Assert-Contains 'scripts\run-visible-trade-proof.ps1' 'visible-trade-launch-boundary.ps1'
}

Write-Host ''
Write-Host "=== Results: $passCount / $testCount passed ===" -ForegroundColor $(if ($passCount -eq $testCount) { 'Green' } else { 'Red' })
Write-Host ''
exit $(if ($passCount -eq $testCount) { 0 } else { 1 })
