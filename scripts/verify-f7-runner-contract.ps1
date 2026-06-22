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
$pathsPath = Join-Path $PSScriptRoot 'bannerlord-paths.ps1'
$navPath = Join-Path $PSScriptRoot 'launcher-auto-nav.ps1'

foreach ($p in @($gatePath, $bisectPath, $launchLogPath, $harvestPath, $pathsPath, $navPath)) {
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
        'Get-BannerlordProcessDetection', 'gameProcessDetectionMethod', 'gameAliveConfidence', 'process_detection_uncertain'
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
    } else {
        Write-Host 'PASS nav: shared process detection wired' -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $harvestPath) {
    $harvestText = Get-Content -LiteralPath $harvestPath -Raw
    foreach ($needle in @('Copy-F7EvidenceArtifact', 'Get-F7Phase1Markers', 'Invoke-F7EvidenceHarvest', 'Get-F7WindowsCrashEventSummary', 'windowsCrashEventStatus', 'lastPhase1Marker', 'New-F7JsonSafeValue', 'Write-F7ArtifactsSidecar', 'harvestPartial', 'harvest_failed')) {
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

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "F7 runner contract: FAIL ($($failures.Count) issue(s))" -ForegroundColor Red
    exit 1
}

Write-Host 'F7 runner contract: PASS' -ForegroundColor Green
exit 0
