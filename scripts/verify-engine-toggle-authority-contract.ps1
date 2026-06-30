# Offline contract verifier for shared engine toggle authority.
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

$authority = 'src\BlacksmithGuild\DevTools\EngineToggleAuthority.cs'
$hotkeys = 'src\BlacksmithGuild\DevTools\DevHotkeyHandler.cs'
$doc = 'docs\handoff\engine-toggle-authority.md'

Assert-Contains $authority 'public enum EngineToggleMode' 'mode enum must exist'
Assert-Contains $authority 'Manual' 'manual mode must exist'
Assert-Contains $authority 'Hybrid' 'hybrid mode must exist'
Assert-Contains $authority 'Automation' 'automation mode must exist'
Assert-Contains $authority 'public enum EngineToggleKey' 'engine key enum must exist'
Assert-Contains $authority 'EngineToggleKey.Governor' 'governor key must be represented'
Assert-Contains $authority 'EngineToggleKey.MapTrade' 'map trade key must be represented'
Assert-Contains $authority 'EngineToggleKey.GuildLoop' 'guild loop key must be represented'
Assert-Contains $authority 'SetGlobalMode' 'global mode setter must exist'
Assert-Contains $authority 'SetEngineMode' 'per-engine setter must exist for higher-order engines'
Assert-Contains $authority 'IsEngineEnabled' 'engine enabled helper must exist'
Assert-Contains $authority 'IsAutomationEnabled' 'automation helper must exist'
Assert-Contains $authority 'IsBoundedExecutionAllowed' 'bounded execution helper must exist'
Assert-Contains $authority 'CampaignRuntimeGovernorAutonomousMode' 'authority must map governor auto flag'
Assert-Contains $authority 'CampaignRuntimeGovernorAllowBoundedExecution' 'authority must map bounded execution flag'
Assert-Contains $authority 'MapTradeAutonomousMode' 'authority must map map-trade flag'
Assert-Contains $authority 'GuildLoopAutonomousMode' 'authority must map guild-loop flag'

Assert-Contains $hotkeys 'Ctrl+Alt+T' 'engine cycle hotkey must be documented in code'
Assert-Contains $hotkeys 'TryEngineToggleHotkey' 'hotkey path must be factored'
Assert-Contains $hotkeys 'EngineToggleAuthority.RunCommand' 'hotkey must use authority rather than editing raw config'

Assert-Contains $doc '# Engine Toggle Authority' 'handoff doc must exist'
Assert-Contains $doc 'Manual -> Hybrid -> Automation -> Manual' 'cycle order must be documented'
Assert-Contains $doc 'Higher-order engines must not flip raw booleans directly.' 'higher-order rule must be documented'
Assert-Contains $doc 'DevToolsConfig.MapTradeAutonomousMode = true;' 'bad raw-config example must remain visible'
Assert-Contains $doc 'Visible mechanics PASS' 'docs must distinguish mode from runtime proof'
Assert-Contains $doc 'The next implementation sprint should migrate direct readers to authority calls' 'remaining migration boundary must be explicit'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: engine toggle authority contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: engine toggle authority contract verified.' -ForegroundColor Green
exit 0
