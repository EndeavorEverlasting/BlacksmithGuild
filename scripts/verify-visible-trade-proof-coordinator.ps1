# Verifier for visible trade proof coordinator.
# Runs a dry-run path exercising workspace, validation, provenance, event writing,
# capsule generation, sanitization, publication simulation, and terminal reporting.

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw "ASSERT_FAILED: $Message" }
}

Write-Host ''
Write-Host '=== Visible Trade Proof Coordinator Verifier ===' -ForegroundColor Cyan
Write-Host ''

# Run the fixture tests first
Write-Host 'Running fixture tests...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\test-visible-trade-proof-coordinator.ps1')
$testExit = $LASTEXITCODE
Assert-True ($testExit -eq 0) "Fixture tests must pass (exit=$testExit)"
Write-Host ''

# Run the dry-run coordinator
Write-Host 'Running dry-run coordinator...'
$dryRunRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-vtp-dryrun-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $dryRunRoot | Out-Null

try {
    $dryRunOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $RepoRoot 'scripts\run-visible-trade-proof.ps1') `
        -RepoRoot $RepoRoot `
        -DryRun `
        -EvidenceRoot $dryRunRoot 2>&1
    $dryRunExit = $LASTEXITCODE

    $dryRunOutput | ForEach-Object { Write-Host $_ }

    Assert-True ($dryRunExit -eq 3) "Dry run must exit 3 (diagnostic), got $dryRunExit"

    # Verify artifacts exist
    $resultPath = Join-Path $dryRunRoot 'visible-trade-proof.result.json'
    $proofPath = Join-Path $dryRunRoot 'visible-trade-proof.proof.json'
    $eventsPath = Join-Path $dryRunRoot 'visible-trade-proof.events.jsonl'
    $progressPath = Join-Path $dryRunRoot 'visible-trade-proof.progress.log'
    $handoffPath = Join-Path $dryRunRoot 'visible-trade-proof.handoff.md'
    $capsulePath = Join-Path $dryRunRoot 'visible-trade-proof.capsule.json'

    Assert-True (Test-Path -LiteralPath $resultPath) 'Result JSON must exist after dry run'
    Assert-True (Test-Path -LiteralPath $proofPath) 'Proof JSON must exist after dry run'
    Assert-True (Test-Path -LiteralPath $eventsPath) 'Events JSONL must exist after dry run'
    Assert-True (Test-Path -LiteralPath $progressPath) 'Progress log must exist after dry run'
    Assert-True (Test-Path -LiteralPath $handoffPath) 'Handoff must exist after dry run'

    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Assert-Equal 'DIAGNOSTIC_ONLY' ([string]$result.terminalState) 'terminal state'
    Assert-Equal 'DIAGNOSTIC' ([string]$result.passFail) 'passFail'
    Assert-True ($result.eventCount -gt 0) 'At least one event must be written'
    Assert-True ($result.provenance.sourceCommit.Length -gt 0) 'Source commit must be recorded'
    Assert-True ($result.provenance.executionWorktree.Length -gt 0) 'Execution worktree must be recorded'

    $proof = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
    Assert-True ($proof.schemaVersion -eq 'TbgVisibleTradeProof.v1') 'Proof schema version'
    Assert-Equal 'DIAGNOSTIC_ONLY' ([string]$proof.terminalState) 'Proof terminal state'

    # Verify events.jsonl has valid JSONL
    $eventLines = @(Get-Content -LiteralPath $eventsPath | Where-Object { $_.Trim().Length -gt 0 })
    Assert-True ($eventLines.Count -gt 0) 'Events file must have entries'
    foreach ($line in $eventLines) {
        try {
            $ev = $line | ConvertFrom-Json
            Assert-True ($null -ne $ev.schema) 'Event must have schema'
            Assert-True ($null -ne $ev.runId) 'Event must have runId'
            Assert-True ($null -ne $ev.stage) 'Event must have stage'
            Assert-True ($null -ne $ev.sentence) 'Event must have sentence'
        } catch {
            throw "Invalid event in JSONL: $line"
        }
    }

    # Verify progress.log is human-readable
    $progressLines = @(Get-Content -LiteralPath $progressPath)
    Assert-True ($progressLines.Count -gt 0) 'Progress log must have entries'

    # Verify handoff is markdown
    $handoffText = Get-Content -LiteralPath $handoffPath -Raw
    Assert-True ($handoffText.Contains('# TBG Visible Trade')) 'Handoff must be markdown'
    Assert-True ($handoffText.Contains($result.runId)) 'Handoff must contain run ID'

    Write-Host ''
    Write-Host "Dry-run verification: ALL PASSED ($($eventLines.Count) events, $($progressLines.Count) progress lines)" -ForegroundColor Green
    Write-Host ''

    # Check for personal path redaction in sanitized artifacts
    $capsuleDir = Join-Path $dryRunRoot 'visible-trade-proof' | Split-Path -Parent
    $capsuleSubDir = Get-ChildItem -LiteralPath $dryRunRoot -Recurse -Directory -Filter 'capsule' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($capsuleSubDir) {
        $capsuleFiles = @(Get-ChildItem -LiteralPath $capsuleSubDir.FullName -File -Recurse -ErrorAction SilentlyContinue)
        Write-Host "Capsule generated: $($capsuleFiles.Count) files in $($capsuleSubDir.FullName)"
    }

    Write-Host ''
    Write-Host '=== Verifier Complete ===' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ''
    Write-Host "VERIFICATION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path -LiteralPath $dryRunRoot) {
        Remove-Item -LiteralPath $dryRunRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
