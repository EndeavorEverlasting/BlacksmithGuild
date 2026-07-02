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
    @{ file = $contextHelper; text = 'Ensure-TbgLauncherWindowContext' },
    @{ file = $contextHelper; text = 'TbgLauncherWindowContext.v1' },
    @{ file = $contextHelper; text = 'window-snapshot-S1-pre-launch.json' },
    @{ file = $contextHelper; text = 'launcher-window-context.json' },
    @{ file = $contextHelper; text = 'launcherProcessId' },
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

Assert-Contains $operatorDoc 'This is currently a documented factoring plan, not a completed implementation refactor.' 'operator doc must not overclaim'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher window context contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher window context doctrine and first implementation slice verified.' -ForegroundColor Green
exit 0
