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
$operatorDoc = 'docs\operator\governor-test-harness.md'
$contextHelper = 'scripts\launcher-window-context.ps1'
$frozenNav = 'scripts\launcher-frozen-context-nav.ps1'
$durationPolicy = 'scripts\test-duration-policy.ps1'

Assert-Contains $handoffDoc '# Launcher Window Context Factoring' 'canonical handoff doc must exist'
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
    @{ file = $frozenNav; text = 'selectionFrozen=true' },
    @{ file = $frozenNav; text = 'rescoring=disabled' },
    @{ file = $frozenNav; text = 'post_handoff_idle_unactionable' },
    @{ file = $frozenNav; text = 'operator_action_required' },
    @{ file = $frozenNav; text = 'launcher context has no hwnd to freeze' },
    @{ file = $frozenNav; text = 'Get-Content -LiteralPath $LauncherContextPath -Raw -Encoding UTF8' },
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
Assert-NotContains 'forge.ps1' "[string]`$LaunchIntent = 'play'" 'root forge launch intent must be explicit'
Assert-NotContains 'scripts\install-mod.ps1' "[string]`$LaunchIntent = 'play'" 'installer launch intent must be explicit'
Assert-NotContains 'scripts\open-bannerlord-launcher.ps1' "[string]`$LaunchIntent = 'play'" 'launcher context wrapper launch intent must be explicit'
Assert-NotContains 'Forge.cmd' 'launcher-auto-nav.ps1' 'Forge front door must not call the legacy rescoring loop'
Assert-NotContains 'ForgeContinue.cmd' 'launcher-auto-nav.ps1' 'ForgeContinue front door must not call the legacy rescoring loop'
Assert-NotContains 'scripts\install-mod.ps1' 'launcher-auto-nav.ps1' 'raw forge.ps1 -Launch must not reach the legacy rescoring loop through install-mod.ps1'

Assert-Contains $operatorDoc 'This is currently a documented factoring plan, not a completed implementation refactor.' 'operator doc must not overclaim'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher window context contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher window context doctrine and first implementation slice verified.' -ForegroundColor Green
exit 0