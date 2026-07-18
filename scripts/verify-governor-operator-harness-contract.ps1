# Offline contract verifier for the governor operator smoke harness.
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
    if ($text -notlike "*$Needle*") {
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
    if ($text -like "*$Needle*") {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath must not contain '$Needle'$suffix") | Out-Null
    }
}

foreach ($file in @(
    'scripts\governor-operator-common.ps1',
    'scripts\ensure-dev-save.ps1',
    'scripts\ensure-governor-dev-save-operator.ps1',
    'scripts\run-governor-disposable-smoke.ps1',
    'scripts\invoke-forge-launch-operator.ps1',
    'scripts\forge-stop.ps1',
    'docs\operator\governor-test-harness.md',
    'Run-Governor-Disposable-Smoke.cmd',
    'Run-Governor-Disposable-Smoke-SkipLaunch.cmd',
    'Run-Governor-Ensure-DevSave.cmd'
)) {
    Read-RepoText -RelativePath $file | Out-Null
}

Assert-Contains '.gitignore' '.local/' 'operator outputs must remain local-only'
Assert-Contains '.gitignore' 'BlacksmithGuild_CampaignGovernorDecision.json' 'runtime decision JSON must not be committed from roots'

foreach ($classification in @('PASS', 'FAIL', 'BLOCKED', 'ENVIRONMENT BLOCKED', 'USER CANCELLED')) {
    Assert-Contains 'scripts\governor-operator-common.ps1' $classification 'classification vocabulary'
}

Assert-Contains 'scripts\governor-operator-common.ps1' 'Get-GovernorStopSentinelPath' 'stop sentinel helper'
Assert-Contains 'scripts\governor-operator-common.ps1' 'Assert-GovernorDecisionContract' 'decision JSON validator'
Assert-Contains 'scripts\governor-operator-common.ps1' 'proposedActivity' 'nested activity contract'
Assert-Contains 'scripts\governor-operator-common.ps1' 'latestActivityResult' 'nested result contract'
Assert-Contains 'scripts\governor-operator-common.ps1' 'mutationApplied' 'no-mutation smoke guard'

Assert-Contains 'scripts\run-governor-disposable-smoke.ps1' 'New-GovernorOperatorSessionDir' 'local session output'
Assert-NotContains 'scripts\run-governor-disposable-smoke.ps1' 'docs\evidence\live-cert' 'smoke must not write live-cert evidence'
Assert-Contains 'scripts\run-governor-disposable-smoke.ps1' 'Assert-GovernorDecisionContract' 'decision JSON must be validated'
Assert-Contains 'scripts\run-governor-disposable-smoke.ps1' "[Alias('SkipBuild')]" 'backward-compatible SkipBuild alias'

Assert-Contains 'scripts\governor-operator-common.ps1' 'BlacksmithGuild_Disposable_*.sav' 'approved disposable save pattern'
Assert-Contains 'scripts\governor-operator-common.ps1' 'Get-GovernorDisposableSavePolicy' 'tracked disposable-save policy loader'
Assert-Contains 'scripts\governor-operator-common.ps1' 'Get-GovernorDisposableSaveOperatorAuthority' 'machine-local operator authority loader'
Assert-Contains 'scripts\governor-operator-common.ps1' 'Set-GovernorActiveDisposableSavePin' 'active disposable-save pin writer'
Assert-Contains 'scripts\governor-operator-common.ps1' 'machine-local operator year-floor' 'year-floor must stay machine-local'
Assert-Contains '.tbg\harness\policies\disposable-save.policy.json' '"yearFloorEnabled": false' 'shipped policy must not enable year-floor'
Assert-Contains '.tbg\harness\policies\disposable-save.policy.json' 'treatCalendarYearAsDisposable": false' 'shipped policy must reject calendar-year disposability'
Assert-Contains 'scripts\ensure-dev-save.ps1' 'Read-GovernorOperatorChoice' 'operator no-save menu'
Assert-Contains 'scripts\ensure-dev-save.ps1' 'invoke-forge-launch-operator.ps1' 'operator launch wrapper'
Assert-Contains 'scripts\ensure-dev-save.ps1' 'Assert-GovernorNotStopped' 'stop polling during waits'
Assert-Contains 'Run-Governor-Ensure-DevSave.cmd' 'ensure-governor-dev-save-operator.ps1' 'cmd wrapper must call file wrapper'
Assert-NotContains 'Run-Governor-Ensure-DevSave.cmd' '-Command' 'avoid inline PowerShell variables in cmd wrapper'
foreach ($cmdWrapper in @(
    'Run-Governor-Disposable-Smoke.cmd',
    'Run-Governor-Disposable-Smoke-SkipLaunch.cmd',
    'Run-Governor-Ensure-DevSave.cmd'
)) {
    Assert-Contains $cmdWrapper 'set TBG_EXIT=%ERRORLEVEL%' 'wrapper must preserve PowerShell exit code before pause'
    Assert-Contains $cmdWrapper 'exit /b %TBG_EXIT%' 'wrapper must return PowerShell exit code after pause'
}

Assert-Contains 'scripts\invoke-forge-launch-operator.ps1' 'TBG_OPERATOR_INTERACTIVE_FOCUS' 'interactive focus env gate'
Assert-Contains 'scripts\invoke-forge-launch-operator.ps1' '-LaunchIntent $LaunchIntent' 'forge launch must bind LaunchIntent by name'
Assert-NotContains 'scripts\invoke-forge-launch-operator.ps1' "@('-Launch', '-LaunchIntent', `$LaunchIntent)" 'avoid positional array splatting into forge.ps1'
Assert-Contains 'scripts\launcher-auto-nav.ps1' 'Invoke-OperatorInteractiveFocusPrompt' 'focus prompt hook'
Assert-Contains 'scripts\launcher-auto-nav.ps1' 'guarded_click_denied' 'focus prompt trigger reason'

# Launch-setup mode must reach launcher-auto-nav so guarded PLAY/CONTINUE clicks are permitted.
Assert-Contains 'scripts\install-mod.ps1' '-LaunchSetup' 'install-mod must request launch-setup mode'
# Existing-launcher reuse: an already-running launcher is the target, not a fatal blocker.
Assert-Contains 'scripts\open-bannerlord-launcher.ps1' 'existing launcher detected; reusing' 'reuse existing launcher during launch setup'
Assert-Contains 'scripts\open-bannerlord-launcher.ps1' 'Forge Stop approval' 'running game process still requires Forge Stop approval'
# F7 guard must keep blocking launcher clicks in plain assistive mode.
Assert-Contains 'scripts\f7-external-state-classifier.ps1' 'click_launcher_play' 'plain assistive must not permit PLAY click'

Assert-Contains 'scripts\forge-stop.ps1' 'Write-GovernorStopSentinel' 'soft stop sentinel'
Assert-Contains 'scripts\forge-stop.ps1' 'PauseCampaignGovernorAutomation' 'governor pause command'
Assert-Contains 'scripts\forge-stop.ps1' 'ForceKill' 'explicit emergency mode'
Assert-Contains 'ForgeStop.cmd' 'Soft stop, Force kill, or Cancel' 'operator choice required'

Assert-Contains 'src\BlacksmithGuild\DevTools\QuickStart\DevSaveService.cs' 'IsCampaignSessionReady' 'dev save requires campaign readiness'
Assert-Contains 'src\BlacksmithGuild\DevTools\QuickStart\DevSaveService.cs' 'DevSaveResolver.DevSavePrefix' 'fixed disposable prefix'
Assert-Contains 'src\BlacksmithGuild\DevTools\QuickStart\DevSaveService.cs' '[TBG DEVSAVE]' 'intent/result logging'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: governor operator harness contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: governor operator harness contract verified.' -ForegroundColor Green
exit 0