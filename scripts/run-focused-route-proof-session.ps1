# Focus-owned route proof wrapper.
# Starts the Bannerlord focus keeper beside the existing autonomous assist runner.
$ErrorActionPreference = 'Stop'

param(
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',

    [string]$AssistProfile = 'training-map',

    [ValidateSet('default', 'economic_loop')]
    [string]$CertProfile = 'default',

    [int]$TradeIterationTarget = 10,

    [string]$TargetSettlement = $null,

    [int]$MaxRuntimeMinutes = 30,

    [int]$AttachWaitSec = 600,

    [int]$PollIntervalSec = 5,

    [int]$TravelCommandCooldownSec = 45,

    [int]$ProbeTimeoutSec = 45,

    [int]$ExecuteTimeoutSec = 120,

    [int]$ForegroundLossStopSec = 8,

    [switch]$SkipBuild,

    [switch]$SkipLaunch,

    [switch]$DryRun,

    [switch]$AllowFocusSteal,

    [ValidateSet('Observe', 'SyntheticFocusPulse', 'ForegroundLease')]
    [string]$FocusKeeperMode = 'SyntheticFocusPulse',

    [int]$FocusKeeperDurationSeconds = 180,

    [int]$FocusKeeperPulseMilliseconds = 500,

    [int]$FocusKeeperWaitForWindowSeconds = 720,

    [switch]$SendUnpausePulse,

    [ValidateSet('Space', 'D1', 'D2', 'D3')]
    [string]$UnpauseKey = 'D3',

    [switch]$StopBeforeLaunch,

    [switch]$FailOnFocusKeeperNoWindow,

    [switch]$FailOnLostForeground
)

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$sessionId = 'focused-route-proof-' + (Get-Date).ToString('yyyyMMdd-HHmmss')
$artifactDir = Join-Path $repoRoot (Join-Path 'docs\evidence\focused-route-proof' $sessionId)
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$focusLeasePath = Join-Path $artifactDir 'BlacksmithGuild_FocusLease.json'
$runnerOutputPath = Join-Path $artifactDir 'runner-output.txt'
$summaryPath = Join-Path $artifactDir 'focused-route-proof-summary.json'

function Write-FocusedRouteJson {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

Write-Host 'The Blacksmith Guild - Focused Route Proof Session' -ForegroundColor Cyan
Write-Host "Artifact dir: $artifactDir"
Write-Host "Focus keeper mode: $FocusKeeperMode"
Write-Host "LaunchIntent: $LaunchIntent"

if ($StopBeforeLaunch) {
    Write-Host 'StopBeforeLaunch requested. Calling ForgeStop.cmd soft before launch.' -ForegroundColor Yellow
    $env:FORGE_NO_PAUSE = '1'
    & (Join-Path $repoRoot 'ForgeStop.cmd') soft
    $stopExit = $LASTEXITCODE
    if ($stopExit -ne 0) {
        throw "ForgeStop.cmd soft failed with exit code $stopExit"
    }
}

$focusArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'start-bannerlord-focus-keeper.ps1'),
    '-Mode', $FocusKeeperMode,
    '-DurationSeconds', $FocusKeeperDurationSeconds,
    '-PulseMilliseconds', $FocusKeeperPulseMilliseconds,
    '-WaitForWindowSeconds', $FocusKeeperWaitForWindowSeconds,
    '-BannerlordRoot', $bannerlordRoot,
    '-OutputPath', $focusLeasePath
)
if ($SendUnpausePulse) { $focusArgs += @('-SendUnpausePulse', '-UnpauseKey', $UnpauseKey) }
if ($FailOnFocusKeeperNoWindow) { $focusArgs += '-FailOnNoWindow' }
if ($FailOnLostForeground) { $focusArgs += '-FailOnLostForeground' }

$focusCommand = 'powershell ' + ($focusArgs -join ' ')
Write-Host "Starting focus keeper: $focusCommand" -ForegroundColor DarkCyan
$focusKeeper = Start-Process -FilePath 'powershell' -ArgumentList $focusArgs -PassThru -WindowStyle Hidden

$runnerArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'run-autonomous-assist-session.ps1'),
    '-LaunchIntent', $LaunchIntent,
    '-AssistProfile', $AssistProfile,
    '-CertProfile', $CertProfile,
    '-TradeIterationTarget', $TradeIterationTarget,
    '-MaxRuntimeMinutes', $MaxRuntimeMinutes,
    '-AttachWaitSec', $AttachWaitSec,
    '-PollIntervalSec', $PollIntervalSec,
    '-TravelCommandCooldownSec', $TravelCommandCooldownSec,
    '-ProbeTimeoutSec', $ProbeTimeoutSec,
    '-ExecuteTimeoutSec', $ExecuteTimeoutSec,
    '-ForegroundLossStopSec', $ForegroundLossStopSec
)
if (-not [string]::IsNullOrWhiteSpace($TargetSettlement)) { $runnerArgs += @('-TargetSettlement', $TargetSettlement) }
if ($SkipBuild) { $runnerArgs += '-SkipBuild' }
if ($SkipLaunch) { $runnerArgs += '-SkipLaunch' }
if ($DryRun) { $runnerArgs += '-DryRun' }
if ($AllowFocusSteal) { $runnerArgs += '-AllowFocusSteal' }

$runnerCommand = 'powershell ' + ($runnerArgs -join ' ')
Write-Host "Starting autonomous assist runner: $runnerCommand" -ForegroundColor DarkCyan
$runnerOutput = & powershell @runnerArgs 2>&1
$runnerExit = $LASTEXITCODE
Set-Content -LiteralPath $runnerOutputPath -Value @($runnerOutput) -Encoding UTF8

$focusExit = $null
if ($focusKeeper -and -not $focusKeeper.HasExited) {
    $graceMs = [Math]::Min(15000, [Math]::Max(1000, $FocusKeeperPulseMilliseconds * 4))
    $exited = $focusKeeper.WaitForExit($graceMs)
    if (-not $exited) {
        Write-Host 'Stopping focus keeper after runner completed.' -ForegroundColor Yellow
        try { Stop-Process -Id $focusKeeper.Id -Force -ErrorAction Stop } catch { }
    }
}
try { if ($focusKeeper) { $focusExit = $focusKeeper.ExitCode } } catch { $focusExit = $null }

$focusLease = $null
if (Test-Path -LiteralPath $focusLeasePath) {
    try { $focusLease = Get-Content -LiteralPath $focusLeasePath -Raw | ConvertFrom-Json } catch { $focusLease = $null }
}

$summary = [ordered]@{
    schema = 'TbgFocusedRouteProofSession.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    sessionId = $sessionId
    branch = (git branch --show-current).Trim()
    headSha = (git rev-parse HEAD).Trim()
    artifactDir = $artifactDir
    bannerlordRoot = $bannerlordRoot
    launchIntent = $LaunchIntent
    assistProfile = $AssistProfile
    certProfile = $CertProfile
    targetSettlement = $TargetSettlement
    focusKeeperMode = $FocusKeeperMode
    focusKeeperDurationSeconds = $FocusKeeperDurationSeconds
    focusKeeperWaitForWindowSeconds = $FocusKeeperWaitForWindowSeconds
    focusLeasePath = $focusLeasePath
    focusLeaseClassification = if ($focusLease) { [string]$focusLease.classification } else { 'missing_focus_lease_artifact' }
    focusLeaseBlocking = if ($focusLease) { [bool]$focusLease.blocking } else { $true }
    runnerOutputPath = $runnerOutputPath
    runnerExitCode = $runnerExit
    focusKeeperExitCode = $focusExit
    stopBeforeLaunch = [bool]$StopBeforeLaunch
    forgeStopUsed = [bool]$StopBeforeLaunch
    proofBoundary = @(
        'This wrapper wires focus keeping into the existing autonomous assist runner.',
        'It does not claim route movement by itself.',
        'Movement proof still requires fresh route cert, position/checkpoint, and time evidence.'
    )
}
Write-FocusedRouteJson -Object ([pscustomobject]$summary) -Path $summaryPath

Write-Host "Focused route proof summary: $summaryPath" -ForegroundColor Green
Write-Host "Runner exit code: $runnerExit"
Write-Host "Focus keeper classification: $($summary.focusLeaseClassification)"

if ($runnerExit -ne 0) { exit $runnerExit }
if ($FailOnFocusKeeperNoWindow -and -not $focusLease) { exit 2 }
if ($FailOnLostForeground -and $focusLease -and [int]$focusLease.lostForegroundSamples -gt 0) { exit 3 }
exit 0
