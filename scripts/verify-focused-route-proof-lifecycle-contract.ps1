# Offline contract verifier for the focused route proof lifecycle.
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

function Need {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle
    )

    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$RelativePath missing '$Needle'") | Out-Null
    }
}

$doc = 'docs\handoff\focused-route-proof-lifecycle.md'
$entrypointMap = 'docs\handoff\harness-entrypoint-focus-map.md'
$focusKeeper = 'scripts\start-bannerlord-focus-keeper.ps1'
$sessionWrapper = 'scripts\run-focused-route-proof-session.ps1'
$rebootRunner = 'scripts\run-reboot-iteration.ps1'
$cmd = 'ForgeRouteProof.cmd'
$entrypointVerifier = 'scripts\verify-harness-entrypoint-focus-map.ps1'

Need $doc '# Focused Route Proof Lifecycle'
Need $doc 'Bannerlord is not a normal background process for this proof.'
Need $doc 'Invalid proof shape'
Need $doc 'Switch to terminal'
Need $doc 'Correct proof shape'
Need $doc 'Acquire a route proof focus lease'
Need $doc 'campaignReady=true'
Need $doc 'timePaused=true'
Need $doc 'route brain selected Quyaz and travel was safe to attempt'
Need $doc 'autonomous route movement occurred'
Need $doc 'scripts/start-bannerlord-focus-keeper.ps1'
Need $doc 'Observe'
Need $doc 'SyntheticFocusPulse'
Need $doc 'ForegroundLease'
Need $doc 'BlacksmithGuild_FocusLease.json'
Need $doc 'scripts/run-focused-route-proof-session.ps1'
Need $doc 'ForgeRouteProof.cmd'
Need $doc 'ForgeStop.cmd soft'
Need $doc 'Movement proof still requires fresh route cert, position/checkpoint, and time evidence after the route execution window.'

Need $entrypointMap '# Harness Entrypoint Focus Map'
Need $entrypointMap 'Runtime automation should keep Bannerlord focus-owned by default.'
Need $entrypointMap 'ForgeReboot.cmd -FocusKeeperMode None'
Need $entrypointMap 'Not an operator route-proof entrypoint by itself'

Need $focusKeeper 'TbgBannerlordFocusLease.v1'
Need $focusKeeper "[ValidateSet('Observe', 'SyntheticFocusPulse', 'ForegroundLease')]"
Need $focusKeeper 'Get-BannerlordProcessDetection'
Need $focusKeeper 'Get-Phase1LogPath'
Need $focusKeeper 'Get-StatusJsonPath'
Need $focusKeeper 'Get-CrashContextJsonPath'
Need $focusKeeper 'ProcessIdHint'
Need $focusKeeper 'WindowHandleHint'
Need $focusKeeper 'WaitForWindowSeconds'
Need $focusKeeper 'targetSource'
Need $focusKeeper 'SyntheticFocusPulse'
Need $focusKeeper 'ForegroundLease'
Need $focusKeeper 'GetForegroundWindow'
Need $focusKeeper 'SetForegroundWindow'
Need $focusKeeper 'PostMessage'
Need $focusKeeper 'WM_ACTIVATEAPP'
Need $focusKeeper 'WM_SETFOCUS'
Need $focusKeeper 'SendUnpausePulse'
Need $focusKeeper 'BlacksmithGuild_FocusLease.json'
Need $focusKeeper 'focus_attempted_not_proven'
Need $focusKeeper 'focus_lease_contested'
Need $focusKeeper 'PID/window selection reuses Get-BannerlordProcessDetection before any window fallback.'
Need $focusKeeper 'Movement proof still requires fresh route cert, position/checkpoint, and time evidence after the route execution window.'

Need $sessionWrapper 'TbgFocusedRouteProofSession.v1'
Need $sessionWrapper 'start-bannerlord-focus-keeper.ps1'
Need $sessionWrapper 'run-autonomous-assist-session.ps1'
Need $sessionWrapper 'Start-Process'
Need $sessionWrapper 'ForgeStop.cmd'
Need $sessionWrapper 'StopBeforeLaunch'
Need $sessionWrapper 'FocusKeeperMode'
Need $sessionWrapper 'FocusKeeperDurationSeconds'
Need $sessionWrapper 'FocusKeeperWaitForWindowSeconds'
Need $sessionWrapper '[int]$ForegroundLossStopSec = 7200'
Need $sessionWrapper 'Focused proof mode raises the runner foreground-loss threshold'
Need $sessionWrapper 'BlacksmithGuild_FocusLease.json'
Need $sessionWrapper 'focused-route-proof-summary.json'

Need $rebootRunner "[string]$`FocusKeeperMode = 'SyntheticFocusPulse'"
Need $rebootRunner 'run-focused-route-proof-session.ps1'
Need $rebootRunner 'Get-LatestFocusedRouteProofDir'
Need $rebootRunner 'latestFocusedRouteProofPath'
Need $rebootRunner 'StopBeforeLaunch'

Need $cmd 'ForgeReboot.cmd'
Need $cmd 'FocusKeeperMode SyntheticFocusPulse'
Need $cmd 'ActionTimeoutClass long_distance_travel'
Need $cmd 'StopBeforeLaunch'

Need $entrypointVerifier '# Offline verifier for harness entrypoint focus ownership.'
Need $entrypointVerifier 'PASS: harness entrypoint focus map verified.'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: focused route proof lifecycle contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: focused route proof lifecycle contract verified.' -ForegroundColor Green
