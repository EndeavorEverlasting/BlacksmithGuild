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

function Assert-TextContains {
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

function Assert-TextMatches {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text -notmatch $Pattern) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing $Label$suffix") | Out-Null
    }
}

$authority = 'src\BlacksmithGuild\DevTools\EngineToggleAuthority.cs'
$hotkeys = 'src\BlacksmithGuild\DevTools\DevHotkeyHandler.cs'
$doc = 'docs\handoff\engine-toggle-authority.md'

Assert-TextMatches $authority '(?m)^\s*public\s+enum\s+EngineToggleMode\s*\{' 'public enum EngineToggleMode' 'mode enum must be a declaration'
Assert-TextMatches $authority '(?s)public\s+enum\s+EngineToggleMode\s*\{[^}]*\bManual\b[^}]*\bHybrid\b[^}]*\bAutomation\b[^}]*\}' 'EngineToggleMode members Manual/Hybrid/Automation' 'mode members must be enum members'
Assert-TextMatches $authority '(?m)^\s*public\s+enum\s+EngineToggleKey\s*\{' 'public enum EngineToggleKey' 'engine key enum must be a declaration'
Assert-TextMatches $authority '(?s)public\s+enum\s+EngineToggleKey\s*\{[^}]*\bGovernor\b[^}]*\bMapTrade\b[^}]*\bGuildLoop\b[^}]*\bCohesion\b[^}]*\bHorseMarket\b[^}]*\bSmithing\b[^}]*\bCompanion\b[^}]*\bAssistive\b[^}]*\}' 'EngineToggleKey declared members' 'engine keys must be enum members'
Assert-TextMatches $authority '(?m)^\s*public\s+static\s+bool\s+SetGlobalMode\s*\(' 'public static bool SetGlobalMode(' 'global mode setter must be a method declaration'
Assert-TextMatches $authority '(?m)^\s*public\s+static\s+bool\s+SetEngineMode\s*\(' 'public static bool SetEngineMode(' 'per-engine setter must be a method declaration'
Assert-TextMatches $authority '(?m)^\s*public\s+static\s+bool\s+IsEngineEnabled\s*\(' 'public static bool IsEngineEnabled(' 'engine enabled helper must be a method declaration'
Assert-TextMatches $authority '(?m)^\s*public\s+static\s+bool\s+IsAutomationEnabled\s*\(' 'public static bool IsAutomationEnabled(' 'automation helper must be a method declaration'
Assert-TextMatches $authority '(?m)^\s*public\s+static\s+bool\s+IsBoundedExecutionAllowed\s*\(' 'public static bool IsBoundedExecutionAllowed(' 'bounded execution helper must be a method declaration'
Assert-TextContains $authority 'CampaignRuntimeGovernorAutonomousMode' 'authority must map governor auto flag'
Assert-TextContains $authority 'CampaignRuntimeGovernorAllowBoundedExecution' 'authority must map bounded execution flag'
Assert-TextContains $authority 'MapTradeAutonomousMode' 'authority must map map-trade flag'
Assert-TextContains $authority 'GuildLoopAutonomousMode' 'authority must map guild-loop flag'
Assert-TextContains $authority 'AssistiveMode' 'authority must map assistive flag'
Assert-TextContains $authority '_globalMode = InferGlobalMode();' 'per-engine/global aggregate state must stay recalculable'
Assert-TextContains $authority 'engine == EngineToggleKey.Governor' 'bounded execution must be governor-scoped'

Assert-TextContains $hotkeys 'Ctrl+Alt+T' 'engine cycle hotkey must be documented in code'
Assert-TextMatches $hotkeys '(?m)^\s*private\s+static\s+bool\s+TryEngineToggleHotkey\s*\(' 'TryEngineToggleHotkey method declaration' 'hotkey path must be factored'
Assert-TextContains $hotkeys 'EngineToggleAuthority.RunCommand' 'hotkey must use authority rather than editing raw config'

Assert-TextContains $doc '# Engine Toggle Authority' 'handoff doc must exist'
Assert-TextContains $doc 'Manual -> Hybrid -> Automation -> Manual' 'cycle order must be documented'
Assert-TextContains $doc 'Higher-order engines must not flip raw booleans directly.' 'higher-order rule must be documented'
Assert-TextContains $doc 'DevToolsConfig.MapTradeAutonomousMode = true;' 'bad raw-config example must remain visible'
Assert-TextContains $doc 'Visible mechanics PASS' 'docs must distinguish mode from runtime proof'
Assert-TextContains $doc 'The next implementation sprint should migrate direct readers to authority calls' 'remaining migration boundary must be explicit'
Assert-TextContains $doc 'docs/handoff/test-timeout-contract.md' 'engine sprint must link short-timeout doctrine'
Assert-TextContains $doc 'scripts/verify-test-timeout-contract.ps1' 'engine sprint must link timeout verifier'
Assert-TextContains $doc 'Manual mode must request hold or abort for already-active autonomous routes' 'manual mode must be active runtime control'
Assert-TextContains $doc 'Manual only when every known engine is Manual' 'aggregate manual inference rule must be documented'
Assert-TextContains $doc 'Automation only when every known engine is Automation' 'aggregate automation inference rule must be documented'
Assert-TextContains $doc 'Hybrid for every mixed state' 'mixed aggregate mode must be hybrid'
Assert-TextContains $doc 'Any per-engine mode change must recompute the aggregate global mode' 'per-engine changes must refresh aggregate state'
Assert-TextContains $doc 'Bounded execution is a Governor capability' 'bounded execution must be governor-only doctrine'
Assert-TextContains $doc 'Assistive readiness must read EngineToggleAuthority' 'assistive readiness must obey authority'
Assert-TextContains $doc 'Automation is not runtime proof' 'automation permission must not overclaim runtime proof'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: engine toggle authority contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: engine toggle authority contract verified.' -ForegroundColor Green
exit 0
