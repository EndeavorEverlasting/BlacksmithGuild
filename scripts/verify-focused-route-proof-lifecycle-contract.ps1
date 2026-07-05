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
$script = 'scripts\start-bannerlord-focus-keeper.ps1'

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
Need $doc 'Movement proof still requires fresh route cert, position/checkpoint, and time evidence after the route execution window.'

Need $script 'TbgBannerlordFocusLease.v1'
Need $script "[ValidateSet('Observe', 'SyntheticFocusPulse', 'ForegroundLease')]"
Need $script 'SyntheticFocusPulse'
Need $script 'ForegroundLease'
Need $script 'GetForegroundWindow'
Need $script 'SetForegroundWindow'
Need $script 'PostMessage'
Need $script 'WM_ACTIVATEAPP'
Need $script 'WM_SETFOCUS'
Need $script 'SendUnpausePulse'
Need $script 'BlacksmithGuild_FocusLease.json'
Need $script 'focus_attempted_not_proven'
Need $script 'focus_lease_contested'
Need $script 'Movement proof still requires fresh route cert, position/checkpoint, and time evidence after the route execution window.'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: focused route proof lifecycle contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: focused route proof lifecycle contract verified.' -ForegroundColor Green
