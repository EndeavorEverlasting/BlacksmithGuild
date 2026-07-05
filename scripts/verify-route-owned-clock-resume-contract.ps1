# Offline contract verifier for route-owned clock resume.
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
        [Parameter(Mandatory = $true)][string]$Why
    )

    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        $failures.Add("$RelativePath missing '$Needle' ($Why)") | Out-Null
    }
}

$routeDoctrine = 'docs\handoff\route-owned-clock-resume-doctrine.md'
$outcomeDoctrine = 'docs\handoff\campaign-engine-outcome-schema.md'
$orchestratorDoctrine = 'docs\handoff\campaign-orchestrator.md'
$authorityDoctrine = 'docs\handoff\engine-toggle-authority.md'
$durationDoctrine = 'docs\operator\test-duration-doctrine.md'
$mapTradeModels = 'src\BlacksmithGuild\MapTrade\MapTradeModels.cs'
$mapTradeService = 'src\BlacksmithGuild\MapTrade\MapTradeAutonomousService.cs'
$mapTradeEvidenceWriter = 'src\BlacksmithGuild\MapTrade\MapTradeEvidenceWriter.cs'
$devToolsConfig = 'src\BlacksmithGuild\DevTools\DevToolsConfig.cs'
$agentIterationConfig = 'src\BlacksmithGuild\DevTools\AgentIterationConfigService.cs'
$campaignMapReadyOrchestrator = 'src\BlacksmithGuild\DevTools\CampaignMapReadyOrchestrator.cs'

Assert-TextContains -RelativePath $routeDoctrine -Needle 'route assigned is an intent checkpoint' -Why 'route assignment must not be movement proof'
Assert-TextContains -RelativePath $routeDoctrine -Needle 'Movement proof requires clock ownership' -Why 'movement proof requires clock ownership'
Assert-TextContains -RelativePath $routeDoctrine -Needle 'AutoTravelToRecommended can ACK Success and assign a route while campaign time remains stopped' -Why 'known route ACK gap must stay visible'
Assert-TextContains -RelativePath $routeDoctrine -Needle 'route_started' -Why 'route owner terminal handoff must include started classification'
Assert-TextContains -RelativePath $routeDoctrine -Needle 'route_blocked' -Why 'route owner terminal handoff must include blocked classification'
Assert-TextContains -RelativePath $routeDoctrine -Needle 'operator_action_required' -Why 'route owner must hand off when blocked by surface/operator state'

Assert-TextContains -RelativePath $outcomeDoctrine -Needle 'checkpoint_completed' -Why 'route outcomes must separate checkpoint from completion'
Assert-TextContains -RelativePath $outcomeDoctrine -Needle 'operator_action_required' -Why 'route outcomes must support honest blocked states'
Assert-TextContains -RelativePath $outcomeDoctrine -Needle 'terminal_stop' -Why 'route outcomes must support terminal stop classification'

Assert-TextContains -RelativePath $orchestratorDoctrine -Needle 'observe -> decide -> act once -> record evidence -> write outcome -> choose next engine -> stop or hand off' -Why 'route owner must participate in one-action campaign loop'

Assert-TextContains -RelativePath $authorityDoctrine -Needle 'Automation is not runtime proof' -Why 'authority permission must not be confused with route proof'
Assert-TextContains -RelativePath $durationDoctrine -Needle '30 seconds' -Why 'route observation must stay bounded unless explicitly marked long-run'

Assert-TextContains -RelativePath $mapTradeModels -Needle 'public sealed class MapTradeRouteClockEvidence' -Why 'route-clock evidence model must exist'
Assert-TextContains -RelativePath $mapTradeModels -Needle 'public MapTradeRouteClockEvidence RouteClockEvidence { get; set; }' -Why 'map trade cert must carry route-clock evidence'
Assert-TextContains -RelativePath $mapTradeService -Needle 'RouteClockEvidence = new MapTradeRouteClockEvidence' -Why 'BeginTravel must populate route-clock evidence'
Assert-TextContains -RelativePath $mapTradeService -Needle 'RuntimeProofClaim = false' -Why 'route ACK must not claim movement proof'
Assert-TextContains -RelativePath $mapTradeEvidenceWriter -Needle 'routeClockEvidence' -Why 'route-clock evidence must be serialized into cert JSON'
Assert-TextContains -RelativePath $mapTradeEvidenceWriter -Needle 'AppendRouteClockEvidence' -Why 'route-clock evidence serializer must exist'

Assert-TextContains -RelativePath $devToolsConfig -Needle 'public static bool AgentAutoMapTradeRoute = false' -Why 'agent config must expose explicit one-shot map-trade trigger'
Assert-TextContains -RelativePath $agentIterationConfig -Needle 'autoMapTradeRoute' -Why 'AgentIterationConfig must read explicit map-trade route trigger'
Assert-TextContains -RelativePath $campaignMapReadyOrchestrator -Needle 'TryRunAgentAutoMapTradeRouteOnce' -Why 'map-ready orchestrator must own the one-shot map-trade trigger'
Assert-TextContains -RelativePath $campaignMapReadyOrchestrator -Needle 'CampaignSetupStateTracker.UsedDisposableQuickStartPath' -Why 'agent map-trade trigger must preserve disposable bootstrap guard'
Assert-TextContains -RelativePath $campaignMapReadyOrchestrator -Needle 'MapTradeAutonomousService.StartRouteNow("AgentAutoMapTradeRoute")' -Why 'agent map-trade trigger must start the route owner explicitly'

$requiredEvidenceFields = @(
    'commandAck',
    'routeTarget',
    'routeIntent',
    'routeOwner',
    'clockStateBefore',
    'clockResumeAttempted',
    'clockResumeResult',
    'authorityMode',
    'movementObservation',
    'arrivalBlockedIndeterminate',
    'nextOwner',
    'runtimeProofClaim'
)

$routeText = Read-RepoText -RelativePath $routeDoctrine
$outcomeText = Read-RepoText -RelativePath $outcomeDoctrine
$combinedText = "$routeText`n$outcomeText"

foreach ($field in $requiredEvidenceFields) {
    if ($combinedText.IndexOf($field, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        $failures.Add("route-owned clock evidence contract missing field '$field' in doctrine") | Out-Null
    }
}

if ($combinedText.IndexOf('runtimeProofClaim=false', [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -and
    $combinedText.IndexOf('runtimeProofClaim: false', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    $failures.Add("route-owned clock evidence contract must state runtimeProofClaim=false unless movement is observed") | Out-Null
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: route-owned clock resume contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'PASS: route-owned clock resume contract verified.' -ForegroundColor Green
exit 0
