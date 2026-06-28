# Local reboot iteration coordinator around run-autonomous-assist-session.ps1.
param(
    [int]$MaxIterations = 2,
    [int]$RepeatThreshold = 2,
    [int]$NormalActionTimeoutSec = 30,
    [int]$LongTravelTimeoutSec = 180,
    [int]$LargeSmithingTimeoutSec = 300,
    [int]$MassTradeTimeoutSec = 300,
    [switch]$AllowFocusSteal,
    [switch]$SkipBuild,
    [ValidateSet('play','continue')]
    [string]$LaunchIntent = 'continue',
    [switch]$DryRun,
    [ValidateSet('normal','long_distance_travel','large_smithing','mass_trade')]
    [string]$ActionTimeoutClass = 'normal'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'reboot-context-classifier.ps1')

if ($MaxIterations -lt 1) { throw 'MaxIterations must be >= 1' }
if ($RepeatThreshold -lt 2) { throw 'RepeatThreshold must be >= 2' }
if ($NormalActionTimeoutSec -gt 30) { throw 'NormalActionTimeoutSec must not exceed 30 seconds' }

$sessionId = 'reboot' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '-reboot-session'
$rebootDir = Join-Path $repoRoot (Join-Path 'docs\evidence' $sessionId)
New-Item -ItemType Directory -Force -Path $rebootDir | Out-Null
$commandsRun = New-Object System.Collections.Generic.List[string]
$iterationRecords = New-Object System.Collections.Generic.List[object]
$executeTimeout = Get-RebootActionTimeoutSec -ActionClass $ActionTimeoutClass `
    -NormalActionTimeoutSec $NormalActionTimeoutSec -LongTravelTimeoutSec $LongTravelTimeoutSec `
    -LargeSmithingTimeoutSec $LargeSmithingTimeoutSec -MassTradeTimeoutSec $MassTradeTimeoutSec

function Get-LatestAutonomousAssistEvidenceDir {
    param([datetime]$SinceUtc)
    $root = Join-Path $repoRoot 'docs\evidence\live-cert'
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    return Get-ChildItem -LiteralPath $root -Directory -Filter '*-autonomous-assist-session' |
        Where-Object { $_.LastWriteTimeUtc -ge $SinceUtc.AddMinutes(-2) } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
}

function New-RebootMissingEvidenceContext {
    param([string]$Reason)
    $ctx = [ordered]@{
        schemaVersion = 1; failureClass = $Reason; stopReason = $Reason; visibleMechanicsProven = $false
        proofMode = 'none'; surface = $null; plannedBranch = $null; target = $null; targetSource = $null
        commandSent = $null; commandAcknowledged = $false; travelClockRunning = $false; movementIntentSet = $false
        partyMovedDistanceBucket = 'zero'; partyMovementObserved = $false; operatorInterruptionObserved = $false
        operatorInterruptionReason = $null; foregroundLoss = $false; handoffMissingTarget = $false
        staleEvidence = $true; safeIdleClass = $null; consecutiveSafeIdleCycles = '0'; lastMeaningfulCheckpoint = $null
        likelyOwner = 'evidence/staleness'; likelyFiles = @(Get-RebootLikelyFiles -Owner 'evidence/staleness')
    }
    return [pscustomobject]$ctx
}

Write-Host 'The Blacksmith Guild - Forge Reboot' -ForegroundColor Cyan
Write-Host "Evidence: $rebootDir"
Write-Host "Normal action timeout: ${NormalActionTimeoutSec}s; action class=$ActionTimeoutClass execute timeout=${executeTimeout}s"

$previous = $null
$previousEvidence = $null
$repeatCount = 1
$stableGap = $false
$latestContext = $null
$latestEvidence = $null

for ($i = 1; $i -le $MaxIterations; $i++) {
    $runStartedUtc = (Get-Date).ToUniversalTime()
    $runnerArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'run-autonomous-assist-session.ps1'),
        '-LaunchIntent',$LaunchIntent,'-ProbeTimeoutSec',$NormalActionTimeoutSec,'-ExecuteTimeoutSec',$executeTimeout)
    if ($AllowFocusSteal) { $runnerArgs += '-AllowFocusSteal' }
    if ($SkipBuild -or $DryRun) { $runnerArgs += '-SkipBuild' }
    if ($DryRun) { $runnerArgs += '-DryRun' }
    $commandLine = 'powershell ' + ($runnerArgs -join ' ')
    $commandsRun.Add($commandLine) | Out-Null
    Write-Host "Iteration ${i}/${MaxIterations}: $commandLine" -ForegroundColor DarkCyan
    $output = & powershell @runnerArgs 2>&1
    $runnerExit = $LASTEXITCODE
    $outputPath = Join-Path $rebootDir ("iteration-{0}-runner-output.txt" -f $i)
    Set-Content -LiteralPath $outputPath -Value @($output) -Encoding UTF8
    $evidenceDirInfo = Get-LatestAutonomousAssistEvidenceDir -SinceUtc $runStartedUtc
    $evidencePath = if ($evidenceDirInfo) { $evidenceDirInfo.FullName } else { $null }
    $context = if ($evidencePath) { New-RebootNormalizedContext -EvidencePath $evidencePath } else { New-RebootMissingEvidenceContext -Reason 'runner_evidence_missing' }
    $latestContext = $context
    $latestEvidence = $evidencePath
    $matchesPrevious = Test-RebootContextRepeat -A $previous -B $context
    $repeatCount = if ($matchesPrevious) { $repeatCount + 1 } else { 1 }
    $iterationRecords.Add([ordered]@{ iteration = $i; runnerExit = $runnerExit; evidencePath = $evidencePath; outputPath = $outputPath; repeatCount = $repeatCount; normalizedContext = $context }) | Out-Null
    Write-RebootJson -Object @($iterationRecords.ToArray()) -Path (Join-Path $rebootDir 'reboot-iterations.json') | Out-Null
    if ($matchesPrevious -and $repeatCount -ge $RepeatThreshold) {
        $stableGap = $true
        Write-RebootStableGapHandoff -Context $context -EvidenceA $previousEvidence -EvidenceB $evidencePath `
            -OutputDir $rebootDir -CommandsRun @($commandsRun.ToArray()) -ValidationState 'local_reboot_iterations_completed' | Out-Null
        break
    }
    $previous = $context
    $previousEvidence = $evidencePath
}

$classification = if ($stableGap) { 'stable_gap' } elseif ($DryRun) { 'dry_run_no_repeat' } else { 'max_iterations_no_repeat' }
$summary = [ordered]@{
    iterationsRun = $iterationRecords.Count
    finalClassification = $classification
    repeatedContext = [bool]$stableGap
    latestEvidencePath = $latestEvidence
    latestNormalizedContext = $latestContext
    nextLocalAction = if ($stableGap) { 'open stable-gap-handoff.md and patch the named owner seam' } else { 'rerun ForgeReboot.cmd or inspect latest evidence if user-visible behavior surprised you' }
    nextPatchOwner = if ($latestContext) { $latestContext.likelyOwner } else { 'unknown' }
    userActionNeeded = $false
    evidenceA = if ($iterationRecords.Count -ge 2) { $iterationRecords[$iterationRecords.Count - 2].evidencePath } else { $null }
    evidenceB = $latestEvidence
    recommendedPatchTarget = if ($latestContext) { (@($latestContext.likelyFiles) -join ', ') } else { 'unknown' }
}
Write-RebootJson -Object $summary -Path (Join-Path $rebootDir 'reboot-summary.json') | Out-Null
Write-RebootSummaryMarkdown -Summary ([pscustomobject]$summary) -Path (Join-Path $rebootDir 'reboot-summary.md') | Out-Null
Write-Host "Reboot classification: $classification"
Write-Host "Summary: $(Join-Path $rebootDir 'reboot-summary.md')"
if ($stableGap) { exit 2 }
exit 0