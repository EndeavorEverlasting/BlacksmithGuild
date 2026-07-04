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
$assistive = 'src\BlacksmithGuild\DevTools\Assistive\AssistReadinessEvaluator.cs'
$config = 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs'
$hotkeys = 'src\BlacksmithGuild\DevTools\DevHotkeyHandler.cs'
$doc = 'docs\handoff\engine-toggle-authority.md'
$durationDoc = 'docs\operator\test-duration-doctrine.md'
$durationManifest = 'docs\handoff\test-duration-policy.manifest.json'
$durationAgentNote = 'docs\handoff\test-duration-policy-agent-note.md'
$durationRefactorPlan = 'docs\handoff\test-duration-policy.refactor-plan.md'

Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+enum\s+EngineToggleMode\s*\{' -Label 'public enum EngineToggleMode' -Why 'mode enum must be a declaration'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)public\s+enum\s+EngineToggleMode\s*\{[^}]*\bManual\b[^}]*\bHybrid\b[^}]*\bAutomation\b[^}]*\}' -Label 'EngineToggleMode members Manual/Hybrid/Automation' -Why 'mode members must be enum members'
Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+enum\s+EngineToggleKey\s*\{' -Label 'public enum EngineToggleKey' -Why 'engine key enum must be a declaration'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)public\s+enum\s+EngineToggleKey\s*\{[^}]*\bGovernor\b[^}]*\bMapTrade\b[^}]*\bGuildLoop\b[^}]*\bCohesion\b[^}]*\bHorseMarket\b[^}]*\bSmithing\b[^}]*\bCompanion\b[^}]*\bAssistive\b[^}]*\}' -Label 'EngineToggleKey declared members' -Why 'engine keys must be enum members'
Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+static\s+bool\s+SetGlobalMode\s*\(' -Label 'public static bool SetGlobalMode(' -Why 'global mode setter must be a method declaration'
Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+static\s+bool\s+SetEngineMode\s*\(' -Label 'public static bool SetEngineMode(' -Why 'per-engine setter must be a method declaration'
Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+static\s+bool\s+IsEngineEnabled\s*\(' -Label 'public static bool IsEngineEnabled(' -Why 'engine enabled helper must be a method declaration'
Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+static\s+bool\s+IsAutomationEnabled\s*\(' -Label 'public static bool IsAutomationEnabled(' -Why 'automation helper must be a method declaration'
Assert-TextMatches -RelativePath $authority -Pattern '(?m)^\s*public\s+static\s+bool\s+IsBoundedExecutionAllowed\s*\(' -Label 'public static bool IsBoundedExecutionAllowed(' -Why 'bounded execution helper must be a method declaration'

Assert-TextMatches -RelativePath $config -Pattern '(?m)^\s*public\s+static\s+bool\s+CampaignRuntimeGovernorAutonomousMode\s*=' -Label 'CampaignRuntimeGovernorAutonomousMode declaration' -Why 'governor auto flag must be a real config declaration'
Assert-TextMatches -RelativePath $config -Pattern '(?m)^\s*public\s+static\s+bool\s+CampaignRuntimeGovernorAllowBoundedExecution\s*=' -Label 'CampaignRuntimeGovernorAllowBoundedExecution declaration' -Why 'bounded flag must be a real config declaration'
Assert-TextMatches -RelativePath $config -Pattern '(?m)^\s*public\s+static\s+bool\s+MapTradeAutonomousMode\s*=' -Label 'MapTradeAutonomousMode declaration' -Why 'map-trade flag must be a real config declaration'
Assert-TextMatches -RelativePath $config -Pattern '(?m)^\s*public\s+static\s+bool\s+GuildLoopAutonomousMode\s*=' -Label 'GuildLoopAutonomousMode declaration' -Why 'guild-loop flag must be a real config declaration'
Assert-TextMatches -RelativePath $config -Pattern '(?m)^\s*public\s+static\s+bool\s+AssistiveMode\s*=' -Label 'AssistiveMode declaration' -Why 'assistive flag must be a real config declaration'

Assert-TextMatches -RelativePath $authority -Pattern '(?s)private\s+static\s+void\s+ApplyModeToConfig\s*\(EngineToggleKey\s+engine,\s*EngineToggleMode\s+mode\).*?CampaignRuntimeGovernorAutonomousMode\s*=\s*mode\s*==\s*EngineToggleMode\.Automation.*?CampaignRuntimeGovernorAllowBoundedExecution\s*=\s*mode\s*==\s*EngineToggleMode\.Automation.*?MapTradeAutonomousMode\s*=\s*mode\s*!=\s*EngineToggleMode\.Manual.*?GuildLoopAutonomousMode\s*=\s*mode\s*!=\s*EngineToggleMode\.Manual.*?AssistiveMode\s*=\s*mode\s*!=\s*EngineToggleMode\.Manual' -Label 'ApplyModeToConfig config mappings' -Why 'authority must map real config flags through code, not prose'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)public\s+static\s+bool\s+SetEngineMode\s*\([^)]*\)\s*\{.*?EngineModes\[engine\]\s*=\s*mode;.*?ApplyModeToConfig\(engine,\s*mode\);\s*_globalMode\s*=\s*InferGlobalMode\(\);' -Label 'SetEngineMode aggregate recompute after config apply' -Why 'per-engine/global aggregate state must stay synchronized'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)private\s+static\s+EngineToggleMode\s+InferGlobalMode\s*\(\)\s*\{.*?var\s+allManual\s*=\s*true;.*?var\s+allAutomation\s*=\s*true;.*?return\s+allAutomation\s*\?\s*EngineToggleMode\.Automation\s*:\s*EngineToggleMode\.Hybrid;' -Label 'InferGlobalMode all-manual/all-automation/mixed-hybrid rule' -Why 'mixed Manual+Automation state must infer Hybrid, not Automation'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)EngineModes\[EngineToggleKey\.Cohesion\]\s*=\s*EngineToggleMode\.Manual;.*?EngineModes\[EngineToggleKey\.HorseMarket\]\s*=\s*EngineToggleMode\.Manual;.*?EngineModes\[EngineToggleKey\.Smithing\]\s*=\s*EngineToggleMode\.Manual;.*?EngineModes\[EngineToggleKey\.Companion\]\s*=\s*EngineToggleMode\.Manual;' -Label 'non-config engines initialize manual' -Why 'startup inference must not force Hybrid through engines with no config flag'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)public\s+static\s+bool\s+IsBoundedExecutionAllowed\s*\(EngineToggleKey\s+engine\)\s*\{.*?engine\s*==\s*EngineToggleKey\.Governor.*?GetMode\(EngineToggleKey\.Governor\)\s*==\s*EngineToggleMode\.Automation.*?CampaignRuntimeGovernorAllowBoundedExecution' -Label 'governor-scoped bounded execution code' -Why 'bounded execution must be governor-scoped'
Assert-TextMatches -RelativePath $authority -Pattern '(?s)private\s+static\s+void\s+RequestManualHold\s*\(EngineToggleKey\s+engine,\s*string\s+source\).*?MapTradeAutonomousService\.AbortNow\(\).*?AutonomousGuildLoopService\.AbortNow\(\)' -Label 'manual hold aborts active route engines' -Why 'Manual must request abort/hold for active MapTrade and GuildLoop routes'

Assert-TextContains -RelativePath $hotkeys -Needle 'Ctrl+Alt+T' -Why 'engine cycle hotkey must be documented in code'
Assert-TextMatches -RelativePath $hotkeys -Pattern '(?m)^\s*private\s+static\s+bool\s+TryEngineToggleHotkey\s*\(' -Label 'TryEngineToggleHotkey method declaration' -Why 'hotkey path must be factored'
Assert-TextMatches -RelativePath $hotkeys -Pattern '(?s)TryEngineToggleHotkey\s*\([^)]*\)\s*\{.*?EngineToggleAuthority\.RunCommand\(EngineToggleAuthority\.CycleEngineToggleModeCommand,\s*label\)' -Label 'TryEngineToggleHotkey authority dispatch' -Why 'hotkey must use authority rather than editing raw config'

Assert-TextMatches -RelativePath $assistive -Pattern '(?s)private\s+static\s+bool\s+IsAssistCommandBlocked\s*\(out\s+string\s+reason\)\s*\{.*?EngineToggleAuthority\.IsEngineEnabled\(EngineToggleKey\.Assistive\).*?engine_toggle_manual:Assistive' -Label 'assistive readiness authority gate' -Why 'Manual mode must reject assistive movement/action commands'

Assert-TextContains -RelativePath $doc -Needle '# Engine Toggle Authority' -Why 'handoff doc must exist'
Assert-TextContains -RelativePath $doc -Needle 'Manual -> Hybrid -> Automation -> Manual' -Why 'cycle order must be documented'
Assert-TextContains -RelativePath $doc -Needle 'Higher-order engines must not flip raw booleans directly.' -Why 'higher-order rule must be documented'
Assert-TextContains -RelativePath $doc -Needle 'DevToolsConfig.MapTradeAutonomousMode = true;' -Why 'bad raw-config example must remain visible'
Assert-TextContains -RelativePath $doc -Needle 'Visible mechanics PASS' -Why 'docs must distinguish mode from runtime proof'
Assert-TextContains -RelativePath $doc -Needle 'The next implementation sprint should migrate direct readers to authority calls' -Why 'remaining migration boundary must be explicit'
Assert-TextContains -RelativePath $doc -Needle 'docs/operator/test-duration-doctrine.md' -Why 'engine sprint must link PR26 duration doctrine'
Assert-TextContains -RelativePath $doc -Needle 'docs/handoff/test-duration-policy.manifest.json' -Why 'engine sprint must link PR26 duration manifest'
Assert-TextContains -RelativePath $doc -Needle 'docs/handoff/test-duration-policy-agent-note.md' -Why 'engine sprint must link PR26 agent note'
Assert-TextContains -RelativePath $doc -Needle 'docs/handoff/test-duration-policy.refactor-plan.md' -Why 'engine sprint must link PR26 duration refactor plan'
Assert-TextContains -RelativePath $doc -Needle 'Manual mode must request hold or abort for already-active autonomous routes' -Why 'manual mode must be active runtime control'
Assert-TextContains -RelativePath $doc -Needle 'Manual only when every known engine is Manual' -Why 'aggregate manual inference rule must be documented'
Assert-TextContains -RelativePath $doc -Needle 'Automation only when every known engine is Automation' -Why 'aggregate automation inference rule must be documented'
Assert-TextContains -RelativePath $doc -Needle 'Hybrid for every mixed state' -Why 'mixed aggregate mode must be hybrid'
Assert-TextContains -RelativePath $doc -Needle 'Any per-engine mode change must recompute the aggregate global mode' -Why 'per-engine changes must refresh aggregate state'
Assert-TextContains -RelativePath $doc -Needle 'Bounded execution is a Governor capability' -Why 'bounded execution must be governor-only doctrine'
Assert-TextContains -RelativePath $doc -Needle 'Assistive readiness must read EngineToggleAuthority' -Why 'assistive readiness must obey authority'
Assert-TextContains -RelativePath $doc -Needle 'Automation is not runtime proof' -Why 'automation permission must not overclaim runtime proof'

Assert-TextContains -RelativePath $durationDoc -Needle '# Test Duration Doctrine' -Why 'PR26 duration doctrine must be present after rebase onto main'
Assert-TextContains -RelativePath $durationDoc -Needle 'Thirty seconds is the default test-duration budget' -Why 'PR26 30-second rule must be authoritative'
Assert-TextContains -RelativePath $durationDoc -Needle 'The doctrine is not aspirational. It is a merge expectation.' -Why 'PR26 merge expectation must be preserved'
Assert-TextContains -RelativePath $durationManifest -Needle '"policyId": "test-duration-doctrine"' -Why 'PR26 manifest must name the duration policy'
Assert-TextContains -RelativePath $durationManifest -Needle '"defaultBudgetSec": 30' -Why 'PR26 manifest must preserve 30-second default'
Assert-TextContains -RelativePath $durationAgentNote -Needle 'Default rule:' -Why 'PR26 agent note must be present'
Assert-TextContains -RelativePath $durationRefactorPlan -Needle '# Test Duration Policy Refactor Plan' -Why 'PR26 refactor plan must be present'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: engine toggle authority contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: engine toggle authority contract verified.' -ForegroundColor Green
exit 0