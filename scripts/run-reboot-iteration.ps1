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
    [string]$CertProfile = $null,
    [switch]$DryRun,
    [ValidateSet('normal','long_distance_travel','large_smithing','mass_trade')]
    [string]$ActionTimeoutClass = 'normal'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'reboot-context-classifier.ps1')
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')
. (Join-Path $PSScriptRoot 'automation-profile.ps1')
$stubSurfaceContractPath = Join-Path $PSScriptRoot 'stub-surface-contract.ps1'
$stubSurfaceContractAvailable = Test-Path -LiteralPath $stubSurfaceContractPath
if ($stubSurfaceContractAvailable) { . $stubSurfaceContractPath }

if ($MaxIterations -lt 1) { throw 'MaxIterations must be >= 1' }
if ($RepeatThreshold -lt 2) { throw 'RepeatThreshold must be >= 2' }
if ($NormalActionTimeoutSec -gt 30) { throw 'NormalActionTimeoutSec must not exceed 30 seconds' }
$certProfileResolution = Resolve-TbgAutomationProfile -ExplicitProfile $CertProfile -RequestedBy 'run-reboot-iteration.ps1'
$CertProfile = [string]$certProfileResolution.profile

$sessionId = 'reboot' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '-reboot-session'
$rebootDir = Join-Path $repoRoot (Join-Path 'docs\evidence' $sessionId)
New-Item -ItemType Directory -Force -Path $rebootDir | Out-Null
$commandsRun = New-Object System.Collections.Generic.List[string]
$iterationRecords = New-Object System.Collections.Generic.List[object]
$operatorStopRequested = $false
$operatorStopReason = $null
$script:RebootOperatorStopRequested = $false
$script:RebootRepoRoot = $repoRoot
$executeTimeout = Get-RebootActionTimeoutSec -ActionClass $ActionTimeoutClass `
    -NormalActionTimeoutSec $NormalActionTimeoutSec -LongTravelTimeoutSec $LongTravelTimeoutSec `
    -LargeSmithingTimeoutSec $LargeSmithingTimeoutSec -MassTradeTimeoutSec $MassTradeTimeoutSec

$stubSurfaceStatusPath = Join-Path $rebootDir 'stub-surface-status.json'
$stubSurfaceStatus = if ($stubSurfaceContractAvailable -and (Get-Command Write-TbgStubSurfaceStatusSummary -ErrorAction SilentlyContinue)) {
    Write-TbgStubSurfaceStatusSummary -RepoRoot $repoRoot -Path $stubSurfaceStatusPath
} else {
    [pscustomobject]@{
        schemaVersion = 1
        contract = 'tbg_stub_surface_status'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        hasIntentionalStubs = $false
        stubCount = 0
        missingStubSurfaceCount = 0
        blockingProductProofStubCount = 0
        status = 'stub_surface_contract_not_loaded'
        note = 'stub-surface-contract.ps1 was not available to this Reboot run'
        entries = @()
    }
}
if (-not (Test-Path -LiteralPath $stubSurfaceStatusPath)) {
    Write-RebootJson -Object $stubSurfaceStatus -Path $stubSurfaceStatusPath | Out-Null
}

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

function Stop-RebootForOperator {
    param([string]$Reason)
    $script:RebootOperatorStopRequested = $true
    $script:operatorStopRequested = $true
    $script:operatorStopReason = $Reason
    try { Write-GovernorStopSentinel -RepoRoot $script:RebootRepoRoot -Reason $Reason | Out-Null } catch { }
}

Clear-GovernorStopSentinel -RepoRoot $repoRoot
$cancelHandler = $null
try {
    $cancelHandler = [System.ConsoleCancelEventHandler]{
        param($cancelSender, $cancelEventArgs)
        $cancelEventArgs.Cancel = $true
        Stop-RebootForOperator -Reason 'operator_stop_ctrl_c'
        Write-Host 'Forge Reboot: Ctrl+C requested, stopping after current child process exits...' -ForegroundColor Yellow
    }
    [Console]::CancelKeyPress += $cancelHandler
} catch { $cancelHandler = $null }

Write-Host 'The Blacksmith Guild - Forge Reboot' -ForegroundColor Cyan
Write-Host "Evidence: $rebootDir"
Write-Host "Automation profile: $CertProfile source=$($certProfileResolution.source) path=$($certProfileResolution.path)"
Write-Host "Normal action timeout: ${NormalActionTimeoutSec}s; action class=$ActionTimeoutClass execute timeout=${executeTimeout}s"
if ($stubSurfaceStatus.hasIntentionalStubs) {
    Write-Host "Stub surfaces: $($stubSurfaceStatus.stubCount) intentional stubs; product-proof blockers=$($stubSurfaceStatus.blockingProductProofStubCount)" -ForegroundColor Yellow
}

$previous = $null
$previousEvidence = $null
$repeatCount = 1
$stableGap = $false
$latestContext = $null
$latestEvidence = $null

for ($i = 1; $i -le $MaxIterations; $i++) {
    if ($script:RebootOperatorStopRequested -or (Test-GovernorStopRequested -RepoRoot $repoRoot)) {
        $operatorStopRequested = $true
        $operatorStopReason = if ($operatorStopReason) { $operatorStopReason } else { 'operator_stop_forge_stop' }
        $latestContext = New-RebootMissingEvidenceContext -Reason $operatorStopReason
        break
    }
    $runStartedUtc = (Get-Date).ToUniversalTime()
    $runnerArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'run-autonomous-assist-session.ps1'),
        '-LaunchIntent',$LaunchIntent,'-CertProfile',$CertProfile,'-ProbeTimeoutSec',$NormalActionTimeoutSec,'-ExecuteTimeoutSec',$executeTimeout)
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
    $iterationRecords.Add([ordered]@{ iteration = $i; runnerExit = $runnerExit; evidencePath = $evidencePath; outputPath = $outputPath; repeatCount = $repeatCount; normalizedContext = $context; stubSurfaceStatus = $stubSurfaceStatus; automationProfile = $CertProfile; automationProfileSource = $certProfileResolution.source }) | Out-Null
    Write-RebootJson -Object @($iterationRecords.ToArray()) -Path (Join-Path $rebootDir 'reboot-iterations.json') | Out-Null
    if ($script:RebootOperatorStopRequested -or (Test-GovernorStopRequested -RepoRoot $repoRoot) -or $context.stopReason -eq 'operator_stop_forge_stop') {
        $operatorStopRequested = $true
        $operatorStopReason = if ($context.stopReason) { [string]$context.stopReason } else { 'operator_stop_forge_stop' }
        break
    }
    if ($matchesPrevious -and $repeatCount -ge $RepeatThreshold) {
        $stableGap = $true
        Write-RebootStableGapHandoff -Context $context -EvidenceA $previousEvidence -EvidenceB $evidencePath `
            -OutputDir $rebootDir -CommandsRun @($commandsRun.ToArray()) -ValidationState 'local_reboot_iterations_completed' | Out-Null
        break
    }
    $previous = $context
    $previousEvidence = $evidencePath
}

if ($cancelHandler) {
    try { [Console]::CancelKeyPress -= $cancelHandler } catch { }
}

$classification = if ($stableGap) { 'stable_gap' } elseif ($operatorStopRequested) { $operatorStopReason } elseif ($DryRun) { 'dry_run_no_repeat' } else { 'max_iterations_no_repeat' }
$summary = [ordered]@{
    iterationsRun = $iterationRecords.Count
    finalClassification = $classification
    repeatedContext = [bool]$stableGap
    operatorStopRequested = [bool]$operatorStopRequested
    operatorStopReason = $operatorStopReason
    automationProfile = $CertProfile
    automationProfileSource = $certProfileResolution.source
    automationProfilePath = $certProfileResolution.path
    latestEvidencePath = $latestEvidence
    latestNormalizedContext = $latestContext
    stubSurfaceStatus = $stubSurfaceStatus
    stubSurfaceStatusPath = $stubSurfaceStatusPath
    hasIntentionalStubs = [bool]$stubSurfaceStatus.hasIntentionalStubs
    productProofBlockedByStubs = [bool]($stubSurfaceStatus.blockingProductProofStubCount -gt 0)
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
if ($operatorStopRequested) { exit 130 }
exit 0
