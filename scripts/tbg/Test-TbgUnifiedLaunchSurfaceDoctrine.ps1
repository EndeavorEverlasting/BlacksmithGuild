# Static unified launch-path and launch-surface doctrine validator. No product, process, game, save, input, or network mutation.
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputPath = 'artifacts/latest/unified-launch-surface-doctrine/unified-launch-surface-doctrine.result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot $OutputPath
}

$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Add-Pass([string]$Message) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
function Add-Failure([string]$Message) { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
function Get-Text([string]$RelativePath) {
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "missing file $RelativePath"; return $null }
    Get-Content -LiteralPath $path -Raw -Encoding UTF8
}
function Get-Json([string]$RelativePath) {
    $raw = Get-Text $RelativePath
    if ($null -eq $raw) { return $null }
    try { $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { Add-Failure "invalid JSON $RelativePath"; $null }
}
function Require-Match([string]$Label, [AllowNull()][string]$Text, [string]$Pattern) {
    if ($null -eq $Text) { return }
    if ($Text -match $Pattern) { Add-Pass $Label } else { Add-Failure "$Label missing $Pattern" }
}
function Require-Values([string]$Label, [object[]]$Actual, [string[]]$Expected) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    $missing = @($Expected | Where-Object { $values -notcontains $_ })
    if ($missing.Count -eq 0) { Add-Pass $Label } else { Add-Failure "$Label missing $($missing -join ', ')" }
}

$doctrine = Get-Text 'docs/harness-doctrine.md'
$agents = Get-Text 'AGENTS.md'
$skill = Get-Text '.tbg/skills/launcher-lifecycle/SKILL.md'
$policy = Get-Json '.tbg/harness/policies/harness-doctrine.policy.json'
$windowPolicy = Get-Json '.tbg/harness/policies/window-intelligence.policy.json'
$registry = Get-Json '.tbg/harness/window-identities.registry.json'
$workflow = Get-Json '.tbg/workflows/window-metadata-intelligence.contract.json'
$fixture = Get-Json '.tbg/harness/fixtures/window-intelligence/unified-launch-surface-doctrine.fixture.json'

Require-Match 'doctrine defines launch path invariance' $doctrine 'Unified launch path and surface invariance'
Require-Match 'doctrine names all entry paths' $doctrine 'ForgeContinue[\s\S]*Auto Launch Nav[\s\S]*new-game[\s\S]*Steam-mediated'
Require-Match 'doctrine names all launch surfaces' $doctrine 'Play/Continue[\s\S]*calibration[\s\S]*Safe Mode[\s\S]*Caution[\s\S]*Steam'
Require-Match 'doctrine requires observers before actuation' $doctrine 'same run context[\s\S]*window observer[\s\S]*external runtime observer[\s\S]*before the first actuation'
Require-Match 'doctrine records non-action windows' $doctrine 'recorded even when the harness does not interact with it'
Require-Match 'doctrine constrains Steam' $doctrine 'Steam is a correlated launch broker[\s\S]*observation-only'
Require-Match 'doctrine requires per-surface freeze' $doctrine 'frozen independently for that surface operation'
Require-Match 'doctrine requires path parity' $doctrine 'No launch path may bypass'
Require-Match 'AGENTS requires unified launch contract' $agents 'ForgeContinue, Auto Launch Nav, new-game, Steam-mediated, and future launch paths'
Require-Match 'AGENTS requires all launcher surfaces' $agents 'Play/Continue, calibration, Safe Mode, Caution, Steam broker, other launcher windows, and game handoff'
Require-Match 'skill routes all launch paths' $skill 'ForgeContinue[\s\S]*Auto Launch Nav[\s\S]*new-game[\s\S]*Steam-mediated'
Require-Match 'skill requires Steam observation only' $skill 'Steam[\s\S]*observation-only'

if ($policy) {
    Require-Values 'harness policy rule IDs' @($policy.rules | ForEach-Object { $_.id }) @('HD-013','HD-014')
    Require-Values 'harness launch entry paths' @($policy.unifiedLaunchSurfaces.entryPaths) @(
        'forge_continue','auto_launch_nav','new_game_play','steam_mediated','future_registered_path'
    )
    Require-Values 'harness launch surface classes' @($policy.unifiedLaunchSurfaces.requiredSurfaceClasses) @(
        'play_continue_menu','calibration_menu','safe_mode_window','caution_window','steam_broker_window','other_launcher_window','singleplayer_handoff'
    )
    Require-Values 'harness launch events' @($policy.unifiedLaunchSurfaces.requiredEvents) @(
        'launch.path.selected','window.observed','window.identity.resolved_or_quarantined','action.authorized_or_blocked',
        'action.dispatched_or_skipped','transition.verified_or_unverified','launch.handoff_or_blocked'
    )
    foreach ($property in @(
        'sameObserverContractForEveryPath','observersActiveBeforeFirstActuation','recordAllCorrelatedTopLevelWindows',
        'freezeIdentityPerSurfaceOperation','backgroundSafeAndMouseIndependentByDefault','unknownWindowsQuarantined',
        'steamBrokerObservationOnly','freshTransitionRequiredBeforeSuccess','pathSpecificSafetyBypassForbidden'
    )) {
        if ([bool]$policy.unifiedLaunchSurfaces.$property) { Add-Pass "harness policy $property" }
        else { Add-Failure "harness policy $property" }
    }
}

if ($windowPolicy) {
    Require-Values 'window policy entry paths' @($windowPolicy.pathInvariance.entryPaths) @(
        'forge_continue','auto_launch_nav','new_game_play','steam_mediated','future_registered_path'
    )
    Require-Values 'window policy required surfaces' @($windowPolicy.pathInvariance.requiredSurfaceClasses) @(
        'play_continue_menu','calibration_menu','safe_mode_window','caution_window','steam_broker_window','other_launcher_window','singleplayer_handoff'
    )
    if ($windowPolicy.pathInvariance.sameRunContextAndObservers) { Add-Pass 'window policy same run context and observers' } else { Add-Failure 'window policy same run context and observers' }
    if ($windowPolicy.pathInvariance.recordNonInteractiveWindows) { Add-Pass 'window policy records non-interactive windows' } else { Add-Failure 'window policy records non-interactive windows' }
    if ($windowPolicy.steamBrokerRules.observationOnly) { Add-Pass 'window policy Steam observation only' } else { Add-Failure 'window policy Steam observation only' }
    if ($windowPolicy.steamBrokerRules.correlationRequired) { Add-Pass 'window policy Steam correlation required' } else { Add-Failure 'window policy Steam correlation required' }
    if ($windowPolicy.steamBrokerRules.globalSteamEnumerationForbidden) { Add-Pass 'window policy global Steam enumeration rejected' } else { Add-Failure 'window policy global Steam enumeration rejected' }
}

if ($registry) {
    $identityIds = @($registry.identities | ForEach-Object { [string]$_.id })
    Require-Values 'window registry launch identities' $identityIds @(
        'bannerlord.launcher.menu','bannerlord.launcher.calibration','bannerlord.dependency-version-caution',
        'bannerlord.safe-mode','steam.launch-broker','bannerlord.singleplayer-host'
    )
    $calibration = @($registry.identities | Where-Object { $_.id -eq 'bannerlord.launcher.calibration' })[0]
    $steam = @($registry.identities | Where-Object { $_.id -eq 'steam.launch-broker' })[0]
    if ($calibration -and -not [bool]$calibration.actionPolicy.automatic) { Add-Pass 'calibration requires exact action contract' } else { Add-Failure 'calibration requires exact action contract' }
    if ($steam -and [string]$steam.lifecycleRole -eq 'launch_broker_observation') { Add-Pass 'Steam lifecycle role' } else { Add-Failure 'Steam lifecycle role' }
    if ($steam -and -not [bool]$steam.actionPolicy.automatic) { Add-Pass 'Steam automatic action rejected' } else { Add-Failure 'Steam automatic action rejected' }
    if ($steam -and [bool]$steam.match.correlationRequired) { Add-Pass 'Steam identity requires correlation' } else { Add-Failure 'Steam identity requires correlation' }
}

if ($workflow) {
    Require-Values 'workflow launch paths' @($workflow.launchPathInvariance.entryPaths) @(
        'ForgeContinue.cmd','Auto Launch Nav','new-game Play path','Steam-mediated path','future registered launch path'
    )
    Require-Values 'workflow required surfaces' @($workflow.launchPathInvariance.requiredSurfaceClasses) @(
        'play_continue_menu','calibration_menu','safe_mode_window','caution_window','steam_broker_window','other_launcher_window','singleplayer_handoff'
    )
    Require-Values 'workflow required events' @($workflow.launchPathInvariance.requiredEvents) @(
        'launch.path.selected','window.observed','window.identity.resolved_or_quarantined','action.authorized_or_blocked',
        'action.dispatched_or_skipped','transition.verified_or_unverified','launch.handoff_or_blocked'
    )
    if ($workflow.launchPathInvariance.noPathSpecificSafetyBypass) { Add-Pass 'workflow rejects path-specific bypass' } else { Add-Failure 'workflow rejects path-specific bypass' }
    if ($workflow.launchPathInvariance.observersStartBeforeActuation) { Add-Pass 'workflow observer-first launch' } else { Add-Failure 'workflow observer-first launch' }
}

if ($fixture) {
    Require-Values 'fixture entry paths' @($fixture.entryPaths | ForEach-Object { $_.id }) @(
        'forge_continue','auto_launch_nav','new_game_play','steam_mediated'
    )
    Require-Values 'fixture surface classes' @($fixture.requiredSurfaceClasses | ForEach-Object { $_.id }) @(
        'play_continue_menu','calibration_menu','safe_mode_window','caution_window','steam_broker_window','other_launcher_window','singleplayer_handoff'
    )
    Require-Values 'fixture invariant rules' @($fixture.pathInvariantRules) @(
        'same_run_context_and_correlation_contract','observers_active_before_first_actuation','all_correlated_top_level_windows_recorded',
        'identity_frozen_per_surface_operation','background_safe_and_mouse_independent_by_default','unknown_windows_quarantined',
        'steam_observed_but_never_automatically_acted_on','fresh_transition_required_before_success'
    )
    if ($fixture.matrixExpectation.allEntryPathsMustDeclareAllSurfaceClasses) { Add-Pass 'fixture full path-surface matrix' } else { Add-Failure 'fixture full path-surface matrix' }
    if ($fixture.matrixExpectation.missingSurfaceObservationIsUnknownNotAbsent) { Add-Pass 'fixture missing observation is unknown' } else { Add-Failure 'fixture missing observation is unknown' }
    if ($fixture.matrixExpectation.pathSpecificSafetyBypassForbidden) { Add-Pass 'fixture rejects safety bypass' } else { Add-Failure 'fixture rejects safety bypass' }
}

$result = [ordered]@{
    schema = 'TbgUnifiedLaunchSurfaceDoctrineValidation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    pass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    proofLevel = 'static_test'
    proofCeiling = 'static_test'
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
[IO.File]::WriteAllText($OutputPath, ($result | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "Unified launch-surface doctrine: FAIL ($($failures.Count))" -ForegroundColor Red
    exit 1
}
Write-Host "Unified launch-surface doctrine: PASS ($passes checks)" -ForegroundColor Green
exit 0
