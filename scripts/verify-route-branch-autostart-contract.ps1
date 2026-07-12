Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$servicePath = Join-Path $repoRoot 'src\BlacksmithGuild\MapTrade\MapTradeAutonomousService.cs'
$service = Get-Content -LiteralPath $servicePath -Raw

function Assert-Pattern {
    param(
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($service -notmatch $Pattern) {
        throw "Route branch autostart contract missing: $Label"
    }
}

Assert-Pattern -Label 'automatic tick requires MapTrade Automation mode' -Pattern @'
(?s)OnCampaignTick\s*\(\s*\).*?EngineToggleAuthority\.IsAutomationEnabled\(EngineToggleKey\.MapTrade\).*?TryStartFromRecursiveBranchState\(\)
'@

Assert-Pattern -Label 'idle branch state reads are elapsed-time throttled' -Pattern @'
(?s)RuntimeCadenceGate\.TryEnter\(\s*BranchPollCadenceWorker,\s*DevToolsConfig\.MapTradeBranchStatePollIntervalMs,\s*hardMinimumMs:\s*1000\)
'@

Assert-Pattern -Label 'active route monitoring is elapsed-time throttled' -Pattern @'
(?s)RuntimeCadenceGate\.TryEnter\(\s*ActiveMonitorCadenceWorker,\s*DevToolsConfig\.MapTradeActiveMonitorIntervalMs,\s*hardMinimumMs:\s*100\)
'@

Assert-Pattern -Label 'successful autostart records the same-tick return checkpoint' -Pattern @'
(?s)TryStartFromRecursiveBranchState\(\)\)\s*\{.*?MarkAutoStartTickReturn\(\);\s*return;
'@

Assert-Pattern -Label 'identical blocked branch evidence is suppressed' -Pattern @'
(?s)string\.Equals\(_lastBranchBlockEvidenceKey,\s*evidenceKey,\s*StringComparison\.Ordinal\).*?return;
'@

Assert-Pattern -Label 'successful autostart returns before cached map-menu hold' -Pattern @'
(?s)EngineToggleAuthority\.IsAutomationEnabled\(EngineToggleKey\.MapTrade\)\s*&&\s*TryStartFromRecursiveBranchState\(\)\)\s*\{.*?MarkAutoStartTickReturn\(\);\s*return;\s*\}.*?if\s*\(GameSessionState\.IsMapMenuOpen\)\s*\{.*?MapTradeVisibleMovementDriver\.Hold\(\);
'@

Assert-Pattern -Label 'explicit route command remains available outside Manual mode' -Pattern @'
(?s)StartRouteNow\s*\(.*?EngineToggleAuthority\.IsEngineEnabled\(EngineToggleKey\.MapTrade\)
'@

Assert-Pattern -Label 'failed branch start remains retryable' -Pattern @'
(?s)if\s*\(!StartBranchRouteNow\(targetSettlement,\s*BranchRouteSource\)\)\s*\{\s*return false;\s*\}\s*_lastBranchAutoStartKey\s*=\s*key;
'@

Write-Host 'Route branch autostart contract: PASS'
