# Segmented full-campaign handoff cert orchestrator.
# Runs ONE segment per invocation by default and stops on the first named failure.
# Campaign attach/load may exceed 30s; every later live segment budgets 30s.
param(
    [ValidateSet('attach', 'movement', 'arrival', 'handoff', 'trade', 'horse', 'provision', 'manpower')]
    [string]$StartSegment = 'attach',
    [ValidateSet('one', 'until_fail', 'all')]
    [string]$Mode = 'one',
    [switch]$SkipBuild,
    [switch]$AllowFocusSteal,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'full-campaign-handoff-cert.ps1')

$order = @(Get-FullCampaignHandoffSegmentOrder)
$startIdx = [Array]::IndexOf($order, $StartSegment)
if ($startIdx -lt 0) { throw "Unknown start segment: $StartSegment" }

$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$outDir = Join-Path $repoRoot "artifacts\latest\full-campaign-handoff-segments\$runId"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$results = New-Object System.Collections.Generic.List[object]
$segmentsToRun = @($order[$startIdx])
if ($Mode -in @('until_fail', 'all')) {
    $segmentsToRun = @($order[$startIdx..($order.Count - 1)])
}

Write-Host "Full-campaign segmented cert runId=$runId mode=$Mode start=$StartSegment"
Write-Host "Segments: $($segmentsToRun -join ' -> ')"

foreach ($segment in $segmentsToRun) {
    $budget = Get-FullCampaignHandoffSegmentBudget -CertSegment $segment
    Write-Host ""
    Write-Host "=== SEGMENT $segment (budget $($budget.maxRuntimeSec)s) ==="
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $args = @(
        '-NoProfile', '-File', (Join-Path $PSScriptRoot 'run-autonomous-assist-session.ps1'),
        '-CertProfile', 'full_campaign_handoff',
        '-CertSegment', $segment,
        '-TradeIterationTarget', '1',
        '-HorseAcquisitionTarget', '1',
        '-ProvisionAcquisitionTarget', '1',
        '-ManpowerAcquisitionTarget', '1',
        '-StopOnUnsafeState'
    )
    if ($AllowFocusSteal) { $args += '-AllowFocusSteal' }
    if ($DryRun) {
        $args += @('-DryRun', '-SkipBuild', '-SkipLaunch')
    } else {
        if ($SkipBuild) { $args += '-SkipBuild' }
        if ($segment -eq 'attach') {
            $args += @('-AttachWaitSec', ([string]$budget.attachWaitSec))
        } else {
            $args += '-SkipLaunch'
        }
    }

    & pwsh @args
    $exit = $LASTEXITCODE
    $sw.Stop()
    $row = [ordered]@{
        schema = 'tbg.full-campaign-handoff.segment-result.v1'
        runId = $runId
        segment = $segment
        exitCode = $exit
        durationMs = [int]$sw.ElapsedMilliseconds
        budgetSec = [int]$budget.maxRuntimeSec
        successStopReason = $budget.successStopReason
        pass = ($exit -eq 0)
        fullChainPass = $false
        atUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    $results.Add([pscustomobject]$row) | Out-Null
    $row | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir "$segment.result.json") -Encoding UTF8
    Write-Host ("SEGMENT_RESULT segment={0} pass={1} exit={2} duration_ms={3} budget_sec={4}" -f `
        $segment, $row.pass, $exit, $row.durationMs, $budget.maxRuntimeSec)

    if ($Mode -eq 'one') { break }
    if ($Mode -eq 'until_fail' -and -not $row.pass) {
        Write-Host "Stopping segmented cert at first failure class owner segment=$segment"
        break
    }
}

$summary = [ordered]@{
    schema = 'tbg.full-campaign-handoff.segment-run.v1'
    runId = $runId
    mode = $Mode
    startSegment = $StartSegment
    results = @($results.ToArray())
    stoppedSegment = $(if ($results.Count -gt 0) { $results[-1].segment } else { $null })
    anyFail = @($results | Where-Object { -not $_.pass }).Count -gt 0
    fullChainPass = $false
    note = 'Segment PASS is not live-runtime-cert. Full chain requires every segment PASS with distinct evidence.'
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outDir 'segment-run.summary.json') -Encoding UTF8
Write-Host ""
Write-Host "Wrote $outDir\segment-run.summary.json"
if ($summary.anyFail) { exit 2 }
exit 0
