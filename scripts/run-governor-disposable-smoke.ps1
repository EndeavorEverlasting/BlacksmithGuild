param(
    [Alias('SkipBuild')]
    [switch]$NoBuild,
    [switch]$NoInstall,
    [switch]$SkipLaunch,
    [switch]$AllowManualDevSaveSetup,
    [int]$BootstrapAttachWaitSec = 1200,
    [int]$ContinueAttachWaitSec = 600,
    [int]$CommandWaitSec = 120,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$allowManualDevSaveSetupRequested = $AllowManualDevSaveSetup.IsPresent

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'ensure-dev-save.ps1') -RepoRoot $RepoRoot
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
$testStartUtc = (Get-Date).ToUniversalTime()
$session = New-GovernorOperatorSessionDir -RepoRoot $RepoRoot -Kind 'governor-smoke'
$evidenceDir = $session.Path
Clear-GovernorStopSentinel -RepoRoot $RepoRoot

function Complete-GovernorSmokeFailure {
    param(
        [string]$Classification,
        [string]$Message
    )
    $summary = [ordered]@{
        classification = $Classification
        pass = $false
        sessionId = $session.SessionId
        testStartUtc = $testStartUtc.ToString('o')
        completedUtc = (Get-Date).ToUniversalTime().ToString('o')
        error = $Message
        evidenceDir = $evidenceDir
    }
    Write-GovernorJsonFile -InputObject $summary -Path (Join-Path $evidenceDir 'governor-smoke-summary.json') -Depth 8
    Write-Host ("GOVERNOR SMOKE {0}: {1}" -f $Classification, $Message) -ForegroundColor Yellow
    Write-Host ("evidence={0}" -f $evidenceDir)
}

trap {
    $message = $_.Exception.Message
    $classification = 'FAIL'
    if ($message -match 'USER CANCELLED') { $classification = 'USER CANCELLED' }
    elseif ($message -match '^BLOCKED| BLOCKED|manual disposable dev save') { $classification = 'BLOCKED' }
    elseif ($message -match 'launcher focus|campaign attach not observed|Bannerlord install not found|timed out') { $classification = 'ENVIRONMENT BLOCKED' }
    Complete-GovernorSmokeFailure -Classification $classification -Message $message
    exit 1
}

if (-not $NoBuild) {
    Write-Host '==> Build + deploy Release'
    $phase1Path = Get-Phase1LogPath -BannerlordRoot $bannerlordRoot
    $statusPathForProcess = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
    if (-not $NoInstall -and (Test-BannerlordGameProcessRunning -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPathForProcess)) {
        Invoke-GovernorForgeStopApproval -RepoRoot $RepoRoot -Reason 'governor smoke deploy requested while Bannerlord was running'
    }
    if ($NoInstall) {
        dotnet build (Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
        if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
    }
    else {
        & (Join-Path $RepoRoot 'forge.ps1') -SkipSaveBackup
        if ($LASTEXITCODE -ne 0) { throw "forge.ps1 build/install failed with exit code $LASTEXITCODE" }
    }
}

$ensureParams = @{
    BannerlordRoot          = $bannerlordRoot
    BootstrapAttachWaitSec  = $BootstrapAttachWaitSec
    ContinueAttachWaitSec   = $ContinueAttachWaitSec
}
if (-not $SkipLaunch) {
    $ensureParams.LaunchIfNeeded = $true
}
$ensureParams.AllowManualDevSaveSetup = $allowManualDevSaveSetupRequested

$ensureResult = Invoke-EnsureDevSave @ensureParams
Write-Host ("Ensure path: bootstrapUsed={0} launchIntent={1}" -f $ensureResult.bootstrapUsed, $ensureResult.launchIntent)

Write-Host '==> Run governor cycle (RunCampaignGovernorCycleNow)'
Assert-GovernorNotStopped -RepoRoot $RepoRoot
Send-ForgeCommand -CommandName 'RunCampaignGovernorCycleNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $CommandWaitSec | Out-Null

Write-Host '==> Inspect governor decision JSON'
$decisionPath = Find-GovernorDecisionPath -BannerlordRoot $bannerlordRoot

if (-not $decisionPath) {
    throw 'BlacksmithGuild_CampaignGovernorDecision.json not found after RunCampaignGovernorCycleNow'
}

Copy-Item -LiteralPath $decisionPath -Destination (Join-Path $evidenceDir 'BlacksmithGuild_CampaignGovernorDecision.json') -Force
$statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
if (Test-Path -LiteralPath $statusPath) {
    Copy-Item -LiteralPath $statusPath -Destination (Join-Path $evidenceDir 'BlacksmithGuild_Status.json') -Force
}

$decision = Get-Content -LiteralPath $decisionPath -Raw | ConvertFrom-Json
Assert-GovernorDecisionContract -Decision $decision -TestStartUtc $testStartUtc -DecisionPath $decisionPath
$summary = [ordered]@{
    classification   = 'PASS'
    pass             = $true
    sessionId        = $session.SessionId
    testStartUtc     = $testStartUtc.ToString('o')
    completedUtc     = (Get-Date).ToUniversalTime().ToString('o')
    bootstrapUsed    = $ensureResult.bootstrapUsed
    devSavePath      = $ensureResult.devSavePath
    decisionPath     = $decisionPath
    cycleId          = $decision.cycleId
    selectedBranch   = $decision.selectedBranch
    selectedReason   = $decision.selectedReason
    source           = $decision.source
    generatedUtc     = $decision.generatedUtc
    allowed          = $decision.allowed
    mutationApplied  = $decision.latestActivityResult.mutationApplied
    evidenceDir      = $evidenceDir
}
Write-GovernorJsonFile -InputObject $summary -Path (Join-Path $evidenceDir 'governor-smoke-summary.json') -Depth 8

Write-Host 'GOVERNOR SMOKE PASS' -ForegroundColor Green
Write-Host ("branch={0} reason={1}" -f $decision.selectedBranch, $decision.selectedReason)
Write-Host ("evidence={0}" -f $evidenceDir)
