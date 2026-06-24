# Agent A: read-only fail-closed contract check for F7 gate runners (no game launch).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Test-PowerShellParses {
    param([string]$Path)
    try {
        $null = [scriptblock]::Create((Get-Content -LiteralPath $Path -Raw))
        Write-Host "PASS parse: $Path" -ForegroundColor Green
        return $true
    } catch {
        Add-Failure "Parse error in $Path : $($_.Exception.Message)"
        return $false
    }
}

$gatePath = Join-Path $PSScriptRoot 'run-f7-gate-continue.ps1'
$bisectPath = Join-Path $PSScriptRoot 'run-agent-a-f7-bisect.ps1'
$launchLogPath = Join-Path $PSScriptRoot 'write-launch-log.ps1'
$harvestPath = Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1'
$launchContractPath = Join-Path $PSScriptRoot 'f7-launch-contract.ps1'
$classifierPath = Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1'
$pathsPath = Join-Path $PSScriptRoot 'bannerlord-paths.ps1'
$navPath = Join-Path $PSScriptRoot 'launcher-auto-nav.ps1'
$forgeStatusPath = Join-Path $PSScriptRoot 'forge-status.ps1'

foreach ($p in @($gatePath, $bisectPath, $launchLogPath, $harvestPath, $launchContractPath, $classifierPath, $pathsPath, $navPath, $forgeStatusPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Add-Failure "Missing required script: $p"
        continue
    }
    $null = Test-PowerShellParses -Path $p
}

if (Test-Path -LiteralPath $gatePath) {
    $gateText = Get-Content -LiteralPath $gatePath -Raw
    $lineCount = (Get-Content -LiteralPath $gatePath).Count

    if ($lineCount -lt 100) {
        Add-Failure "run-f7-gate-continue.ps1 looks like PR #8 stub ($lineCount lines); need real gate runner"
    } else {
        Write-Host "PASS gate size: $lineCount lines" -ForegroundColor Green
    }

    foreach ($needle in @(
        'Invoke-F7NoClickLaunch', 'Save-CheckpointEvidence', 'function Exit-F7Gate', 'Test-F7GateManifestPass',
        'f7-evidence-harvest.ps1', 'Invoke-F7EvidenceHarvest', 'evidenceCompleteness',
        'launchPath', 'launchSelectedBy', 'certTarget', 'targetMismatch',
        'Resolve-F7LaunchPath', 'continueEscalated', 'harvest_failed',
        'Get-BannerlordProcessDetection', 'gameProcessDetectionMethod', 'gameAliveConfidence', 'process_detection_uncertain',
        'contaminated_launch_path', 'f7-launch-contract.ps1', 'readinessJudged', 'targetMismatchReason', 'failureReason',
        'Stop-F7CertProcesses', 'spawnAttribution', 'pre_intent_game_spawn', 'retryCount',
        'Test-F7StrongPreIntentGameSignal', 'Test-F7GameGoneDefinitive', 'fail_game_gone_definitive', 'exeEverSeen',
        'f7-external-state-classifier.ps1', 'Initialize-F7ExternalStateTimeline', 'ExternalStateTimeline',
        'Emit-F7ExternalStateTimelineCheckpoint', 'Save-F7ExternalStateTimeline', 'Test-F7GuardedActionAllowed',
        'fail_settlement_menu_semantic_mismatch', 'Test-F7SettlementMenuReadyObserved', 'Get-F7StatusSurfaceSignals'
    )) {
        if ($gateText -notmatch [regex]::Escape($needle)) {
            Add-Failure "run-f7-gate-continue.ps1 missing: $needle"
        } else {
            Write-Host "PASS gate contains: $needle" -ForegroundColor Green
        }
    }

    if ($gateText -notmatch 'MaxLines\s*=\s*300|phase1MaxLines\s*=\s*300|300') {
        Add-Failure 'run-f7-gate-continue.ps1 / harvest must use Phase1 FAIL tail target 300 lines'
    } else {
        Write-Host 'PASS gate: Phase1 FAIL tail 300 target present' -ForegroundColor Green
    }

    if ($gateText -match 'SkipLaunch') {
        Add-Failure 'run-f7-gate-continue.ps1 must not expose -SkipLaunch (fake-pass risk)'
    } else {
        Write-Host 'PASS gate: no SkipLaunch switch' -ForegroundColor Green
    }

    if ($gateText -notmatch 'FAIL-CLOSED') {
        Add-Failure 'run-f7-gate-continue.ps1 missing FAIL-CLOSED exit 0 guard'
    } else {
        Write-Host 'PASS gate: FAIL-CLOSED guard present' -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $pathsPath) {
    $pathsText = Get-Content -LiteralPath $pathsPath -Raw
    foreach ($needle in @(
        'Get-BannerlordProcessDetection', 'Test-LauncherHostedWindowTitle',
        'Test-LauncherMenuWindowTitle', 'Test-LauncherSingleplayerHostedTitle',
        'Test-F7PreflightCleanState',
        'Get-BannerlordProcessCandidates', 'Test-BannerlordGameProcessRunning'
    )) {
        if ($pathsText -notmatch [regex]::Escape($needle)) {
            Add-Failure "bannerlord-paths.ps1 missing: $needle"
        } else {
            Write-Host "PASS paths contains: $needle" -ForegroundColor Green
        }
    }
}

if (Test-Path -LiteralPath $navPath) {
    $navText = Get-Content -LiteralPath $navPath -Raw
    if ($navText -notmatch 'Get-LaunchNavProcessDetection') {
        Add-Failure 'launcher-auto-nav.ps1 missing Get-LaunchNavProcessDetection'
    } elseif ($navText -notmatch 'contaminated_launch_path|Write-ContaminatedLaunchPath') {
        Add-Failure 'launcher-auto-nav.ps1 missing Continue-cert contamination guard'
    } elseif ($navText -notmatch 'Test-PreIntentGameSpawnAndContaminate|automationContinueIntentDeclared') {
        Add-Failure 'launcher-auto-nav.ps1 missing pre-intent intent barrier'
    } elseif ($navText -notmatch 'Invoke-LauncherSafeModeAndCrashDialogs|safe_mode_visible|ContinueClickVerifySec') {
        Add-Failure 'launcher-auto-nav.ps1 missing Safe Mode early detect / reduced verify timeout'
    } elseif ($navText -notmatch 'Test-NavGuardedLauncherClick|unknown_window_state') {
        Add-Failure 'launcher-auto-nav.ps1 missing guarded click / unknown_window_state hook'
    } elseif ($navText -notmatch 'LauncherSelectionMaxMs|Write-LaunchTimingEvidence|launcher_timing_timeout') {
        Add-Failure 'launcher-auto-nav.ps1 missing launcher selection cap / LAUNCH_TIMING evidence'
    } elseif ($navText -notmatch 'LaunchSetup|assistive_launch_setup') {
        Add-Failure 'launcher-auto-nav.ps1 missing LaunchSetup / assistive_launch_setup'
    } else {
        Write-Host 'PASS nav: shared process detection wired' -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $launchContractPath) {
    $contractText = Get-Content -LiteralPath $launchContractPath -Raw
    foreach ($needle in @('Test-F7StrongPreIntentGameSignal', 'Get-F7PreIntentContaminationResult', 'pre_intent_game_spawn', 'Get-F7AssistiveAttachResult', 'assistiveAttach')) {
        if ($contractText -notmatch [regex]::Escape($needle)) {
            Add-Failure "f7-launch-contract.ps1 missing: $needle"
        } else {
            Write-Host "PASS contract contains: $needle" -ForegroundColor Green
        }
    }
}

if (Test-Path -LiteralPath $classifierPath) {
    $classifierText = Get-Content -LiteralPath $classifierPath -Raw
    foreach ($needle in @(
        'Invoke-F7ExternalStateClassification', 'Get-F7StateActionPolicy', 'Resolve-F7GameSurfaceClassifiedState',
        'Resolve-F7ProcessClassifiedState', 'Add-F7ExternalStateTimelineEvent', 'Test-F7GuardedActionAllowed',
        'Get-F7StatusSurfaceSignals', 'Test-F7SettlementMenuReadyObserved', 'LauncherMenuPlayOnly', 'SafeModeDialog',
        'settlement_menu_ready_observed', 'windowBoundsReason',
        'Test-F7AssistiveSessionAttachable', 'assistive_launch_setup'
    )) {
        if ($classifierText -notmatch [regex]::Escape($needle)) {
            Add-Failure "f7-external-state-classifier.ps1 missing: $needle"
        } else {
            Write-Host "PASS classifier contains: $needle" -ForegroundColor Green
        }
    }
}

if (Test-Path -LiteralPath $harvestPath) {
    $harvestText = Get-Content -LiteralPath $harvestPath -Raw
    foreach ($needle in @('Copy-F7EvidenceArtifact', 'Get-F7Phase1Markers', 'Invoke-F7EvidenceHarvest', 'Invoke-F7AssistiveEvidenceHarvest', 'Get-F7AssistiveEvidenceCompleteness', 'Test-F7AssistiveTownTradeCertPass', 'Get-F7WindowsCrashEventSummary', 'windowsCrashEventStatus', 'lastPhase1Marker', 'New-F7JsonSafeValue', 'Write-F7ArtifactsSidecar', 'harvestPartial', 'harvest_failed', 'Get-F7SafeArtifactFreshnessState', 'externalStateTimelineCopied')) {
        if ($harvestText -notmatch [regex]::Escape($needle)) {
            Add-Failure "f7-evidence-harvest.ps1 missing: $needle"
        } else {
            Write-Host "PASS harvest contains: $needle" -ForegroundColor Green
        }
    }
}

if (Test-Path -LiteralPath $bisectPath) {
    $bisectText = Get-Content -LiteralPath $bisectPath -Raw
    if ($bisectText -match '(?m)^\s*param\([^)]*SkipLaunch' -or $bisectText -match '-SkipLaunch\s') {
        Add-Failure 'run-agent-a-f7-bisect.ps1 must not invoke -SkipLaunch'
    } else {
        Write-Host 'PASS bisect: no SkipLaunch usage' -ForegroundColor Green
    }
    if ($bisectText -notmatch 'FAKE_PASS_REJECTED') {
        Add-Failure 'run-agent-a-f7-bisect.ps1 missing FAKE_PASS_REJECTED guard'
    } else {
        Write-Host 'PASS bisect: FAKE_PASS_REJECTED present' -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $launchLogPath) {
    $logText = Get-Content -LiteralPath $launchLogPath -Raw
    if ($logText -notmatch 'previousErrorActionPreference|WaitOne') {
        Add-Failure 'write-launch-log.ps1 missing scoped ErrorActionPreference or mutex WaitOne'
    } else {
        Write-Host 'PASS write-launch-log: EAP restore + mutex' -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $forgeStatusPath) {
    $forgeStatusText = Get-Content -LiteralPath $forgeStatusPath -Raw
    foreach ($needle in @('Get-LastConsumedForgeInboxSequence', 'Select-String', 'consumed sequence=')) {
        if ($forgeStatusText -notmatch [regex]::Escape($needle)) {
            Add-Failure "forge-status.ps1 missing: $needle"
        } else {
            Write-Host "PASS forge-status contains: $needle" -ForegroundColor Green
        }
    }
} else {
    Add-Failure 'Missing forge-status.ps1'
}

$grepGuard = Join-Path $PSScriptRoot 'verify-log-grep-patterns.ps1'
if (Test-Path -LiteralPath $grepGuard) {
    Write-Host 'Running verify-log-grep-patterns.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $grepGuard
    $grepExit = $LASTEXITCODE
    if ($grepExit -ne 0) {
        Add-Failure "verify-log-grep-patterns.ps1 exited $grepExit"
    }
} else {
    Write-Host 'WARN: verify-log-grep-patterns.ps1 not present (Agent B lane)' -ForegroundColor Yellow
}

$harvestRegression = Join-Path $PSScriptRoot 'test-f7-harvest-150405.ps1'
if (Test-Path -LiteralPath $harvestRegression) {
    Write-Host 'Running test-f7-harvest-150405.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $harvestRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-harvest-150405.ps1 failed (Argument types / enrichment regression)'
    } else {
        Write-Host 'PASS offline harvest regression 150405' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-harvest-150405.ps1 offline harvest regression'
}

$processDetectionRegression = Join-Path $PSScriptRoot 'test-f7-process-detection-154012.ps1'
if (Test-Path -LiteralPath $processDetectionRegression) {
    Write-Host 'Running test-f7-process-detection-154012.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $processDetectionRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-process-detection-154012.ps1 failed (launcher-hosted / timeout note regression)'
    } else {
        Write-Host 'PASS offline process detection regression 154012' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-process-detection-154012.ps1 offline regression'
}

$contaminatedLaunchRegression = Join-Path $PSScriptRoot 'test-f7-contaminated-launch-163921.ps1'
if (Test-Path -LiteralPath $contaminatedLaunchRegression) {
    Write-Host 'Running test-f7-contaminated-launch-163921.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $contaminatedLaunchRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-contaminated-launch-163921.ps1 failed (Continue cert contamination regression)'
    } else {
        Write-Host 'PASS offline contaminated launch regression 163921' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-contaminated-launch-163921.ps1 offline regression'
}

$preIntentRegression = Join-Path $PSScriptRoot 'test-f7-contaminated-launch-175909.ps1'
if (Test-Path -LiteralPath $preIntentRegression) {
    Write-Host 'Running test-f7-contaminated-launch-175909.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $preIntentRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-contaminated-launch-175909.ps1 failed (pre-intent spawn regression)'
    } else {
        Write-Host 'PASS offline pre-intent contaminated launch regression 175909' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-contaminated-launch-175909.ps1 offline regression'
}

$gameGoneRegression = Join-Path $PSScriptRoot 'test-f7-game-gone-202052.ps1'
if (Test-Path -LiteralPath $gameGoneRegression) {
    Write-Host 'Running test-f7-game-gone-202052.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $gameGoneRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-game-gone-202052.ps1 failed (launcher_hosted game_gone regression)'
    } else {
        Write-Host 'PASS offline game-gone regression 202052' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-game-gone-202052.ps1 offline regression'
}

$assistiveRegression = Join-Path $PSScriptRoot 'test-f7-assistive-attach-mode.ps1'
if (Test-Path -LiteralPath $assistiveRegression) {
    Write-Host 'Running test-f7-assistive-attach-mode.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $assistiveRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-assistive-attach-mode.ps1 failed (cert vs assistive attach regression)'
    } else {
        Write-Host 'PASS offline assistive attach mode regression' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-assistive-attach-mode.ps1 offline regression'
}

$launcherTimingRegression = Join-Path $PSScriptRoot 'test-f7-launcher-timing-205925.ps1'
if (Test-Path -LiteralPath $launcherTimingRegression) {
    Write-Host 'Running test-f7-launcher-timing-205925.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $launcherTimingRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-launcher-timing-205925.ps1 failed (launcher cap / LAUNCH_TIMING regression)'
    } else {
        Write-Host 'PASS offline launcher timing regression 205925' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-launcher-timing-205925.ps1 offline regression'
}

$settlementMenuRegression = Join-Path $PSScriptRoot 'test-f7-settlement-menu-fast-fail.ps1'
if (Test-Path -LiteralPath $settlementMenuRegression) {
    Write-Host 'Running test-f7-settlement-menu-fast-fail.ps1 ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $settlementMenuRegression
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'test-f7-settlement-menu-fast-fail.ps1 failed (settlement menu semantic mismatch regression)'
    } else {
        Write-Host 'PASS offline settlement-menu fast-fail regression' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing test-f7-settlement-menu-fast-fail.ps1 offline regression'
}

$townTradeSkeleton = Join-Path $PSScriptRoot 'run-town-to-town-trade-assist-cert.ps1'
if (Test-Path -LiteralPath $townTradeSkeleton) {
    $townText = Get-Content -LiteralPath $townTradeSkeleton -Raw
    foreach ($needle in @('AttachOnly', 'assistive_attach', 'Test-F7AssistiveSessionAttachable', 'Invoke-F7AssistiveEvidenceHarvest')) {
        if ($townText -notmatch [regex]::Escape($needle)) {
            Add-Failure "run-town-to-town-trade-assist-cert.ps1 missing: $needle"
        }
    }
    Write-Host 'Running run-town-to-town-trade-assist-cert.ps1 -WhatIf ...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $townTradeSkeleton -WhatIf
    if ($LASTEXITCODE -ne 0) {
        Add-Failure 'run-town-to-town-trade-assist-cert.ps1 -WhatIf failed'
    } else {
        Write-Host 'PASS assistive town-trade cert parses' -ForegroundColor Green
    }
} else {
    Add-Failure 'Missing run-town-to-town-trade-assist-cert.ps1 assistive skeleton'
}

foreach ($pair in @(
    @{ path = 'test-town-to-town-attach-only.ps1'; label = 'town-to-town attach-only' },
    @{ path = 'test-town-to-town-no-launch-harvest.ps1'; label = 'town-to-town no-launch harvest' },
    @{ path = 'test-assistive-launch-setup-guarded-click.ps1'; label = 'assistive launch setup guarded click' },
    @{ path = 'test-forge-command-sequence-after-prior-ack.ps1'; label = 'forge command sequence after prior ack' }
)) {
    $regPath = Join-Path $PSScriptRoot $pair.path
    if (Test-Path -LiteralPath $regPath) {
        Write-Host "Running $($pair.path) ..." -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File $regPath
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "$($pair.path) failed ($($pair.label))"
        } else {
            Write-Host "PASS $($pair.label)" -ForegroundColor Green
        }
    } else {
        Add-Failure "Missing $($pair.path)"
    }
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "F7 runner contract: FAIL ($($failures.Count) issue(s))" -ForegroundColor Red
    exit 1
}

Write-Host 'F7 runner contract: PASS' -ForegroundColor Green
exit 0
