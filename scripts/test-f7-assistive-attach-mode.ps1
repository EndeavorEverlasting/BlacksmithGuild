# Offline regression: F7 cert vs assistive attach mode split.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')

# Assistive attach: manual Continue with game running is acceptable.
$attach = Get-F7AssistiveAttachResult -LaunchPath 'continue' -LaunchSelectedBy 'user' -GameProcessRunning $true
if (-not $attach.assistiveAttach) { throw 'Expected assistiveAttach=true' }
if ($attach.targetMismatch) { throw 'Assistive attach must not set targetMismatch' }
if ($attach.contaminated) { throw 'Assistive attach must not set contaminated for user Continue' }
if (-not $attach.manualLaunchObserved) { throw 'Expected manualLaunchObserved=true for user Continue' }

# Cert mode: same inputs must contaminate.
$cert = Get-F7LaunchContaminationResult -CertTarget 'continue' -LaunchPath 'continue' `
    -LaunchSelectedBy 'user' -AutomationContinueSuccess $false
if (-not $cert.contaminated) { throw 'Cert mode must contaminate user Continue' }
if (-not $cert.targetMismatch) { throw 'Cert mode must set targetMismatch for user Continue' }
if ($cert.gameSpawnRejectedReason -ne 'user_handoff_not_eligible_for_continue_cert') {
    throw "Expected user_handoff_not_eligible_for_continue_cert got $($cert.gameSpawnRejectedReason)"
}

# Cert pre-intent still fails (175909 class).
$preIntent = Get-F7PreIntentContaminationResult
if ($preIntent.gameSpawnRejectedReason -ne 'pre_intent_game_spawn') {
    throw 'Pre-intent contamination must remain pre_intent_game_spawn in cert mode'
}

# Unknown window: never click.
if (Test-F7GuardedActionAllowed -Mode 'assistive' -Action 'click_launcher_continue' -ClassifiedState 'UnknownWindowState') {
    throw 'UnknownWindowState must deny click_launcher_continue'
}
if (Test-F7GuardedActionAllowed -Mode 'cert' -Action 'click_launcher_play' -ClassifiedState 'UnknownGameSurface') {
    throw 'UnknownGameSurface must deny click_launcher_play'
}

# Fresh Status surface mapping (mock object).
$mockStatus = [pscustomobject]@{
    readinessSurface = 'settlement_menu'
    settlementMenuOpen = $true
    campaignMapSurfaceOpen = $false
    campaignReady = $true
    session = [pscustomobject]@{ canPollFileInbox = $true; sessionReady = $true }
}
$surface = Resolve-F7GameSurfaceClassifiedState -StatusJson $mockStatus -StatusArtifactState 'fresh'
if ($surface.state -ne 'SettlementTownMenu') {
    throw "Expected SettlementTownMenu got $($surface.state)"
}
if ($surface.runtimeEvidenceStates -notcontains 'ReadinessSurfaceSettlementMenu') {
    throw 'Expected ReadinessSurfaceSettlementMenu runtime evidence'
}

$stale = Resolve-F7GameSurfaceClassifiedState -StatusJson $mockStatus -StatusArtifactState 'stale'
if ($stale.state -ne 'UnknownGameSurface') {
    throw 'Stale Status must not guess in-game surface'
}

# Timeline init + event roundtrip.
$tmpTimeline = Join-Path $env:TEMP "ExternalStateTimeline-test-$PID.json"
if (Test-Path -LiteralPath $tmpTimeline) { Remove-Item -LiteralPath $tmpTimeline -Force }
Initialize-F7ExternalStateTimeline -Mode assistive -OutputPath $tmpTimeline -SessionId 'test-session'
$cls = Invoke-F7ExternalStateClassification -BannerlordRoot (Get-BannerlordRootFromRepo) -Mode assistive `
    -LaunchPath 'continue' -LaunchSelectedBy 'user' -ReasonOverride 'offline regression attach checkpoint'
Add-F7ExternalStateTimelineEvent -Classification $cls -Force | Out-Null
$written = Save-F7ExternalStateTimeline
if (-not (Test-Path -LiteralPath $written)) { throw "Timeline not written: $written" }
$parsed = Get-Content -LiteralPath $written -Raw | ConvertFrom-Json
if ($parsed.mode -ne 'assistive') { throw 'Timeline mode must be assistive' }
if (@($parsed.events).Count -lt 1) { throw 'Timeline must contain at least one event' }
Remove-Item -LiteralPath $tmpTimeline -Force -ErrorAction SilentlyContinue

Write-Host 'PASS offline assistive attach mode regression'
Write-Host "assistiveAttach=$($attach.assistiveAttach) certContaminated=$($cert.contaminated) surface=$($surface.state)"
