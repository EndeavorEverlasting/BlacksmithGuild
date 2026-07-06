# Offline verifier for harness entrypoint focus ownership.
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

$map = 'docs\handoff\harness-entrypoint-focus-map.md'
$rebootCmd = 'ForgeReboot.cmd'
$routeCmd = 'ForgeRouteProof.cmd'
$stopCmd = 'ForgeStop.cmd'
$rebootRunner = 'scripts\run-reboot-iteration.ps1'
$focusedWrapper = 'scripts\run-focused-route-proof-session.ps1'
$focusKeeper = 'scripts\start-bannerlord-focus-keeper.ps1'
$assistRunner = 'scripts\run-autonomous-assist-session.ps1'

Need $map '# Harness Entrypoint Focus Map'
Need $map 'Runtime automation should keep Bannerlord focus-owned by default.'
Need $map 'Get-BannerlordProcessDetection'
Need $map 'ForgeRouteProof.cmd'
Need $map 'ForgeReboot.cmd'
Need $map 'scripts/run-reboot-iteration.ps1'
Need $map 'scripts/run-focused-route-proof-session.ps1'
Need $map 'scripts/start-bannerlord-focus-keeper.ps1'
Need $map 'scripts/run-autonomous-assist-session.ps1'
Need $map 'ForgeStop.cmd soft'
Need $map 'ForgeReboot.cmd -FocusKeeperMode None'
Need $map 'Not an operator route-proof entrypoint by itself'
Need $map 'scripts/verify-harness-entrypoint-focus-map.ps1'

Need $rebootCmd 'scripts\run-reboot-iteration.ps1'

Need $routeCmd 'ForgeReboot.cmd'
Need $routeCmd 'FocusKeeperMode SyntheticFocusPulse'
Need $routeCmd 'ActionTimeoutClass long_distance_travel'
Need $routeCmd 'StopBeforeLaunch'

Need $stopCmd 'scripts\forge-stop.ps1'

Need $rebootRunner "[string]$`FocusKeeperMode = 'SyntheticFocusPulse'"
Need $rebootRunner 'run-focused-route-proof-session.ps1'
Need $rebootRunner 'run-autonomous-assist-session.ps1'
Need $rebootRunner "if ($`FocusKeeperMode -eq 'None')"
Need $rebootRunner 'Get-LatestFocusedRouteProofDir'
Need $rebootRunner 'latestFocusedRouteProofPath'
Need $rebootRunner 'StopBeforeLaunch'

Need $focusedWrapper 'start-bannerlord-focus-keeper.ps1'
Need $focusedWrapper 'run-autonomous-assist-session.ps1'
Need $focusedWrapper '[int]$ForegroundLossStopSec = 7200'
Need $focusedWrapper 'ForgeStop.cmd'
Need $focusedWrapper 'StopBeforeLaunch'
Need $focusedWrapper 'TbgFocusedRouteProofSession.v1'
Need $focusedWrapper 'focused-route-proof-summary.json'
Need $focusedWrapper 'Focused proof mode raises the runner foreground-loss threshold'

Need $focusKeeper 'Get-BannerlordRootFromRepo'
Need $focusKeeper 'Get-BannerlordProcessDetection'
Need $focusKeeper 'Get-Phase1LogPath'
Need $focusKeeper 'Get-StatusJsonPath'
Need $focusKeeper 'Get-CrashContextJsonPath'
Need $focusKeeper 'ProcessIdHint'
Need $focusKeeper 'WindowHandleHint'
Need $focusKeeper 'SyntheticFocusPulse'
Need $focusKeeper 'ForegroundLease'
Need $focusKeeper 'TbgBannerlordFocusLease.v1'

Need $assistRunner 'ForegroundLossStopSec'
Need $assistRunner 'operator_interruption_foreground_lost'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: harness entrypoint focus map has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: harness entrypoint focus map verified.' -ForegroundColor Green
