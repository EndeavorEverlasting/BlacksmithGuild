# Offline documentation and first implementation-slice contract for launcher PID/window context factoring.
# This verifies that the factoring plan exists and that the shared context helper is present.
# It does not claim the full launch-adjacent migration or live runtime proof is complete.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath must not contain '$Needle'$suffix") | Out-Null
    }
}

$handoffDoc = 'docs\handoff\launcher-window-context-factoring.md'
$durationLogDoc = 'docs\handoff\launcher-duration-and-log-evidence-doctrine.md'
$durationSweepDoc = 'docs\handoff\duration-entrypoint-sweep.md'
$operatorDoc = 'docs\operator\governor-test-harness.md'
$contextHelper = 'scripts\launcher-window-context.ps1'
$frozenNav = 'scripts\launcher-frozen-context-nav.ps1'
$durationPolicy = 'scripts\test-duration-policy.ps1'

Assert-Contains $handoffDoc '# Launcher Window Context Factoring' 'canonical handoff doc must exist'
Assert-Contains $durationLogDoc '# Launcher Duration and Log Evidence Doctrine' 'launcher duration/log doctrine must exist'
Assert-Contains $durationSweepDoc '# Duration Entrypoint Sweep' 'duration entrypoint sweep doctrine must exist'
Assert-Contains $operatorDoc '## Launcher Window Context doctrine' 'operator doc must surface doctrine'
Assert-Contains $operatorDoc 'docs/handoff/launcher-window-context-factoring.md' 'operator doc must link detailed plan'
Assert-Contains $operatorDoc 'verify-launcher-window-context-contract.ps1' 'operator doc must list verifier'

foreach ($needle in @(
    'S1 baseline process/window snapshot',
    'S2 post-launch/request snapshot',
    'compare S1/S2',
    'bind preferred hwnd/pid',
    'TbgLauncherWindowContext',
    'Ensure-TbgLauncherWindowContext',
    'Existing launcher reuse is valid, but it must still refresh/write context.',
    'No launch-adjacent script may call launcher-auto-nav.ps1 without a fresh or intentionally reused LauncherWindowContext.',
    'No click path may use heuristic title/size window selection while a valid LauncherWindowContext exists.',
    'Forge and ForgeContinue must take a snapshot of the relevant launcher/game-family PIDs just before opening any game component',
    'candidate set = S2 - S1',
    'Once a launcher hwnd/pid is selected for the click phase, that selection is frozen',
    'No repeated S1/S2 reselection is allowed after launcher target selection unless the selected hwnd/pid is explicitly invalidated.',
    'No spawned game window may be promoted back into launcher click selection after continue_clicked_or_play_clicked.',
    'Bound PID/window context first. Global PID search second. Coordinate/title/size fallback last, logged, and only with a reason.',
    'game_spawned -> post_handoff_watch',
    'Post-handoff watch must emit readiness, blocked, or post_handoff_idle_unactionable classification.',
    'A loaded game with no handoff, no activity, and no message-log command guidance is unfinished product behavior, not PASS.',
    'post_handoff_idle_unactionable',
    'hotkeys_ready',
    'assistive_commands_ready',
    'operator guidance shown yes/no',
    'No fallback may be silent.',
    'PID-global UIA is a fallback only after bound hwnd/pid context fails or is unavailable',
    'Coordinate fallback is a fallback only after bound hwnd/pid context fails or is unavailable',
    'Focus helpers must not bypass context silently.',
    'It does not claim the full refactor is complete.',
    'Runtime proof is not part of this documentation sprint.'
)) {
    Assert-Contains $handoffDoc $needle 'required doctrine text'
}

foreach ($needle in @(
    'Launcher logs are live state. They are not decoration.',
    'Operator action is evidence.',
    'If the user clicks Play or Continue and the game transitions forward, that is a valid handoff signal, not automation failure.',
    'Thirty seconds is the default launcher/test budget.',
    'This rule applies everywhere unless a specific path is explicitly declared as a long-run path with a reason.',
    'Front-door wrappers must not pass a long timeout to launcher navigation',
    'AllowLongRun is present',
    'LongRunReason is present',
    'Forge.cmd',
    'ForgeContinue.cmd',
    'Run-LauncherNavNow.cmd',
    'Run-LauncherNavPlay.cmd',
    '-TimeoutSec 120',
    '-TimeoutSec 300',
    '-TimeoutSec 600',
    '-AttachWaitSec 600',
    '-MaxRuntimeMinutes 30',
    'The overall launch budget is not a per-click budget.',
    'A PLAY/CONTINUE click gets a short verification window.',
    'operator_or_external_handoff_detected',
    'game_spawned_before_script_click',
    'game_spawned_during_click_phase',
    'CLICK_VERIFY_POLICY',
    'CLICK_VERIFY_STARTED',
    'CLICK_VERIFY_RESULT',
    'Launch.log',
    'BlacksmithGuild_Phase1.log',
    'BlacksmithGuild_Status.json',
    'RuntimeLifecycle.json',
    'ForgeStatus.json',
    'BlacksmithGuild_CommandAck.json',
    'ExternalStateTimeline.json',
    'game_spawned != hotkeys_ready',
    'loaded_game != controlled_runtime',
    'The verifier must also check that `Forge.cmd`, `ForgeContinue.cmd`, and other launcher-adjacent entry points do not override the default with a long timeout.',
    'The verifier must require doctrine for operator activity as valid workflow evidence.'
)) {
    Assert-Contains $durationLogDoc $needle 'launcher duration/log doctrine text'
}

foreach ($needle in @(
    'Check the callee.',
    'Check the caller.',
    'Check the wrapper.',
    'Check the runner.',
    'Thirty seconds is the default budget for tests, verifiers, smoke runs, CMD wrappers, launch wrappers, and observation harnesses.',
    'Forge.cmd',
    'ForgeContinue.cmd',
    'LaunchForgeContinue.cmd',
    'Run-LauncherNavNow.cmd',
    'Run-LauncherNavPlay.cmd',
    'forge.ps1',
    'scripts/install-mod.ps1',
    'scripts/open-bannerlord-launcher.ps1',
    'scripts/launcher-window-context.ps1',
    'scripts/launcher-frozen-context-nav.ps1',
    'scripts/launcher-auto-nav.ps1',
    'scripts/invoke-forge-launch-operator.ps1',
    'scripts/run-autonomous-assist-session.ps1',
    'scripts/autonomous-assist-session.ps1',
    'scripts/run-pr11-town-travel-launch-attach-execute.ps1',
    'scripts/ensure-dev-save.ps1',
    'scripts/run-live-assistive-cert.ps1',
    'scripts/run-stage-b-smithing-advisory-cert.ps1',
    'scripts/run-stage-c-charcoal-cert.ps1',
    'scripts/run-town-to-town-trade-assist-cert.ps1',
    'scripts/run-tavern-hero-intel-cert.ps1',
    'scripts/run-weapon-smelt-cert.ps1',
    'scripts/run-character-build-catalog.ps1',
    'scripts/test-local-iteration-contract-stubs.ps1',
    '-BootstrapAttachWaitSec 1200',
    'Evidence-first replacement candidates',
    'Operator activity is not interference by default.',
    'Does the verifier cover this caller, not just the callee?'
)) {
    Assert-Contains $durationSweepDoc $needle 'duration entrypoint sweep doctrine text'
}

foreach ($entryPoint in @(
    'scripts/open-bannerlord-launcher.ps1',
    'scripts/install-mod.ps1',
    'scripts/run-autonomous-assist-session.ps1',
    'scripts/run-pr11-town-travel-launch-attach-execute.ps1',
    'scripts/run-governor-disposable-smoke.ps1',
    'scripts/ensure-dev-save.ps1',
    'scripts/launcher-auto-nav.ps1',
    'scripts/autonomous-assist-session.ps1'
)) {
    Assert-Contains $handoffDoc $entryPoint 'entry point must be listed for migration'
}

foreach ($sourceCheck in @(
    @{ file = $durationPolicy; text = 'Resolve-TbgTestDurationBudget' },
    @{ file = $durationPolicy; text = '$Script:TbgTestDurationDefaultBudgetSec = 30' },
    @{ file = $durationPolicy; text = 'Get-Content -LiteralPath $PolicyPath -Raw -Encoding UTF8' },
    @{ file = $contextHelper; text = 'Ensure-TbgLauncherWindowContext' },
    @{ file = $contextHelper; text = 'TbgLauncherWindowContext.v1' },
    @{ file = $contextHelper; text = 'window-snapshot-S1-pre-launch.json' },
    @{ file = $contextHelper; text = 'launcher-window-context.json' },
    @{ file = $contextHelper; text = 'launcherProcessId' },
    @{ file = $contextHelper; text = 'Get-Content -LiteralPath $Path -Raw -Encoding UTF8' },
    @{ file = $contextHelper; text = 'Set-Content -LiteralPath $Path -Encoding UTF8' },
    @{ file = $contextHelper; text = 'Resolve-TbgTestDurationBudget' },
    @{ file = $contextHelper; text = 'Write-TbgTestDurationBudget' },
    @{ file = $contextHelper; text = 'New-TbgTestDurationDeadline' },
    @{ file = $contextHelper; text = 'Test-TbgTestDurationExpired' },
    @{ file = $contextHelper; text = 'Start-Process -FilePath $launcherExe -WorkingDirectory (Split-Path -Parent $launcherExe) -PassThru' },
    @{ file = $contextHelper; text = 'Get-Process -Id $startedLauncher.Id -ErrorAction SilentlyContinue' },
    @{ file = $contextHelper; text = 'Launcher was started, but no launcher process could be bound for context.' },
    @{ file = $frozenNav; text = '$operationMode = if ($LaunchSetup) { ''launcher_setup'' } else { ''frozen_navigation'' }' },
    @{ file = $frozenNav; text = 'launcher-frozen-context-nav.ps1:$operationMode' },
    @{ file = $frozenNav; text = 'MODE operationMode={0} launchSetup={1} runtimeProofClaim={2} behavior=launcher_context_navigation_only' },
    @{ file = $frozenNav; text = 'Assert-FrozenLauncherContextIntent' },
    @{ file = $frozenNav; text = 'LaunchSetup context missing launchIntent; refusing launcher setup navigation without explicit intent.' },
    @{ file = $frozenNav; text = 'LaunchSetup context intent mismatch' },
    @{ file = $frozenNav; text = 'launcher_setup_handoff_observed' },
    @{ file = $frozenNav; text = 'runtimeProofClaim=false' },
    @{ file = $frozenNav; text = 'selectionFrozen=true' },
    @{ file = $frozenNav; text = 'rescoring=disabled' },
    @{ file = $frozenNav; text = 'post_handoff_idle_unactionable' },
    @{ file = $frozenNav; text = 'operator_action_required' },
    @{ file = $frozenNav; text = 'launcher context has no hwnd to freeze' },
    @{ file = $frozenNav; text = 'Get-Content -LiteralPath $LauncherContextPath -Raw -Encoding UTF8' },
    @{ file = $frozenNav; text = 'Resolve-TbgTestDurationBudget @durationArgs' },
    @{ file = $frozenNav; text = 'New-TbgTestDurationDeadline -Budget $durationBudget' },
    @{ file = $frozenNav; text = 'Test-TbgTestDurationExpired -Deadline $overallDeadline' },
    @{ file = $frozenNav; text = 'Emit-PostHandoffReadiness -Deadline $overallDeadline' },
    @{ file = $frozenNav; text = '$useRealInput = ($foregroundMatches -or $AllowFocusSteal -or -not $RespectUserForeground)' },
    @{ file = $frozenNav; text = 'if ($useRealInput)' },
    @{ file = $frozenNav; text = 'method=real-input dispatched' },
    @{ file = $frozenNav; text = 'method=hwnd SendMessage dispatched hwnd={1} reason=real_input_not_viable' },
    @{ file = 'forge.ps1'; text = 'LaunchIntent is required when -Launch is used.' },
    @{ file = 'Forge.cmd'; text = '-LaunchIntent play' },
    @{ file = 'Forge.cmd'; text = 'launcher-frozen-context-nav.ps1' },
    @{ file = 'Forge.cmd'; text = '-LaunchManual' },
    @{ file = 'ForgeContinue.cmd'; text = '-LaunchIntent continue' },
    @{ file = 'ForgeContinue.cmd'; text = 'launcher-frozen-context-nav.ps1' },
    @{ file = 'ForgeContinue.cmd'; text = '-LaunchManual' },
    @{ file = 'LaunchForgeContinue.cmd'; text = '-LaunchIntent continue' },
    @{ file = 'scripts\install-mod.ps1'; text = 'LaunchIntent is required when -Launch is used.' },
    @{ file = 'scripts\install-mod.ps1'; text = 'launcher-frozen-context-nav.ps1' },
    @{ file = 'scripts\install-mod.ps1'; text = 'classification=hotkeys_ready' },
    @{ file = 'scripts\open-bannerlord-launcher.ps1'; text = '[Parameter(Mandatory = $true)]' },
    @{ file = 'scripts\open-bannerlord-launcher.ps1'; text = 'Ensure-TbgLauncherWindowContext' },
    @{ file = 'scripts\install-mod.ps1'; text = '-LaunchIntent $LaunchIntent' },
    @{ file = 'scripts\launcher-auto-nav.ps1'; text = 'SetPreferredLauncherWindow' },
    @{ file = 'scripts\launcher-auto-nav.ps1'; text = 'GetBestLauncherWindowForCoords' },
    @{ file = 'scripts\run-autonomous-assist-session.ps1'; text = 'launcher-auto-nav.ps1' },
    @{ file = 'scripts\run-pr11-town-travel-launch-attach-execute.ps1'; text = 'launcher-auto-nav.ps1' }
)) {
    Assert-Contains $sourceCheck.file $sourceCheck.text 'current source fact must remain discoverable'
}

Assert-NotContains $contextHelper '$pid =' 'PowerShell $PID is an automatic read-only variable; local launcher process id must use a non-colliding name'
Assert-NotContains $contextHelper 'processId = $pid' 'context must not read from a PID-colliding local variable'
Assert-NotContains $contextHelper 'elseif ($pid -ne 0)' 'score logic must not read from a PID-colliding local variable'
Assert-NotContains $contextHelper 'Start-Sleep -Seconds 2' 'fresh launcher binding must use bounded polling, not a fixed sleep'
Assert-NotContains $frozenNav '[int]$TimeoutSec = 120' 'frozen nav must default to shared bounded policy, not 120 seconds'
Assert-NotContains $frozenNav '[int]$WaitSec = 20' 'click verification must use shared/bounded policy, not legacy fixed wait'
Assert-NotContains $frozenNav 'param([int]$WaitSec = 90)' 'post-handoff readiness must use shared overall deadline'
Assert-NotContains $frozenNav '.AddSeconds($WaitSec)' 'frozen nav waits must not create independent fixed deadlines'
Assert-NotContains $frozenNav 'MODE LaunchSetup=true' 'LaunchSetup must be a real operation mode, not a bare log marker'
Assert-NotContains $frozenNav 'frozen real-input skipped reason=RespectUserForeground target_not_foreground' 'frozen click methods must be mutually exclusive, not layered after SendMessage'
Assert-NotContains $frozenNav 'Wait-FrozenGameSpawnOrInvalidation -Hwnd $targetHwnd -ExpectedPid $targetPid -Deadline $overallDeadline' 'one click verification must not be allowed to consume the whole launcher budget'
Assert-NotContains 'scripts\install-mod.ps1' '-TimeoutSec 120' 'install-mod must not hardcode a long frozen-nav budget'
Assert-NotContains 'Forge.cmd' '-TimeoutSec 120' 'Forge front door must not bypass the shared 30-second launcher policy'
Assert-NotContains 'ForgeContinue.cmd' '-TimeoutSec 120' 'ForgeContinue front door must not bypass the shared 30-second launcher policy'
Assert-NotContains 'Forge.cmd' '-TimeoutSec 300' 'Forge front door must not hide a long launcher wait'
Assert-NotContains 'ForgeContinue.cmd' '-TimeoutSec 300' 'ForgeContinue front door must not hide a long launcher wait'
Assert-NotContains 'Forge.cmd' '-TimeoutSec 600' 'Forge front door must not hide a long launcher wait'
Assert-NotContains 'ForgeContinue.cmd' '-TimeoutSec 600' 'ForgeContinue front door must not hide a long launcher wait'
Assert-NotContains 'forge.ps1' "[string]`$LaunchIntent = 'play'" 'root forge launch intent must be explicit'
Assert-NotContains 'scripts\install-mod.ps1' "[string]`$LaunchIntent = 'play'" 'installer launch intent must be explicit'
Assert-NotContains 'scripts\open-bannerlord-launcher.ps1' "[string]`$LaunchIntent = 'play'" 'launcher context wrapper launch intent must be explicit'
Assert-NotContains 'Forge.cmd' 'launcher-auto-nav.ps1' 'Forge front door must not call the legacy rescoring loop'
Assert-NotContains 'ForgeContinue.cmd' 'launcher-auto-nav.ps1' 'ForgeContinue front door must not call the legacy rescoring loop'
Assert-NotContains 'scripts\install-mod.ps1' 'launcher-auto-nav.ps1' 'raw forge.ps1 -Launch must not reach the legacy rescoring loop through install-mod.ps1'

Assert-Contains $operatorDoc 'This is currently a documented factoring plan, not a completed implementation refactor.' 'operator doc must not overclaim'

$safeModeDoctrineVerifier = Join-Path $PSScriptRoot 'verify-launcher-safe-mode-doctrine.ps1'
if (-not (Test-Path -LiteralPath $safeModeDoctrineVerifier)) {
    $failures.Add('missing Safe Mode doctrine verifier: scripts\verify-launcher-safe-mode-doctrine.ps1') | Out-Null
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $safeModeDoctrineVerifier
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('launcher Safe Mode doctrine verifier failed') | Out-Null
    }
}
if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher window context contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher window context doctrine and first implementation slice verified.' -ForegroundColor Green
exit 0
