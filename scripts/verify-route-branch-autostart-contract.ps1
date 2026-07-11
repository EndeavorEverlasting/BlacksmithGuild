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
(?s)OnCampaignTick\s*\(\s*\).*?GameSessionState\.Refresh\(\);.*?EngineToggleAuthority\.IsAutomationEnabled\(EngineToggleKey\.MapTrade\).*?TryStartFromRecursiveBranchState\(\)
'@

Assert-Pattern -Label 'successful autostart returns before cached map-menu hold' -Pattern @'
(?s)EngineToggleAuthority\.IsAutomationEnabled\(EngineToggleKey\.MapTrade\)\s*&&\s*TryStartFromRecursiveBranchState\(\)\)\s*\{\s*//[^\r\n]*\r?\n\s*//[^\r\n]*\r?\n\s*return;\s*\}.*?if\s*\(GameSessionState\.IsMapMenuOpen\)\s*\{\s*MapTradeVisibleMovementDriver\.Hold\(\);
'@

Assert-Pattern -Label 'explicit route command remains available outside Manual mode' -Pattern @'
(?s)StartRouteNow\s*\(.*?EngineToggleAuthority\.IsEngineEnabled\(EngineToggleKey\.MapTrade\)
'@

Assert-Pattern -Label 'failed branch start remains retryable' -Pattern @'
(?s)if\s*\(!StartBranchRouteNow\(targetSettlement,\s*BranchRouteSource\)\)\s*\{\s*return false;\s*\}\s*_lastBranchAutoStartKey\s*=\s*key;
'@

Write-Host 'Route branch autostart contract: PASS'
