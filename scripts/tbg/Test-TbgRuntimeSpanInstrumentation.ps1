[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0

function Assert-Span([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
    else { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
}
function Read-Source([string]$RelativePath) {
    Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw -Encoding UTF8
}

$emitter = Read-Source 'src/BlacksmithGuild/DevTools/Automation/AutomationRuntimeEventEmitter.cs'
$context = Read-Source 'src/BlacksmithGuild/DevTools/Diagnostics/RuntimeSpanContext.cs'
$writer = Read-Source 'src/BlacksmithGuild/DevTools/Diagnostics/RuntimeSpanWriter.cs'
$snapshot = Read-Source 'src/BlacksmithGuild/DevTools/Diagnostics/RuntimeStateSnapshot.cs'
$governor = Read-Source 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs'
$selector = Read-Source 'src/BlacksmithGuild/MapTrade/MapTradeMissionSelector.cs'
$service = Read-Source 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs'
$fixturePath = Join-Path $repoRoot '.tbg/harness/fixtures/runtime-span-instrumentation.fixtures.json'
$fixtures = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json

Assert-Span ($context -match 'RunId' -and $context -match 'SessionId' -and $context -match 'CommandId' -and $context -match 'CorrelationId' -and $context -match 'ParentSpanId') 'correlation context fields'
Assert-Span ($emitter -match 'BeginSpan' -and $emitter -match 'CompleteSpan' -and $emitter -match 'BlockSpan' -and $emitter -match 'FailSpan' -and $emitter -match 'AbandonSpan') 'span lifecycle API'
Assert-Span ($writer -match 'MaximumExceptionText = 512' -and $writer -match 'in_process_span' -and $writer -match 'assemblyIdentity') 'bounded sanitized writer'
Assert-Span ($snapshot -match 'CampaignReady' -and $snapshot -match 'MapMenuOpen' -and $snapshot -match 'MainPartyAvailable' -and $snapshot -match 'CachedMarketScan' -and $snapshot -match 'CandidateCount') 'bounded runtime state snapshot'
Assert-Span (($governor.IndexOf('RuntimeStateSnapshot.Capture(source)') -lt $governor.IndexOf('BuildDecision(source)')) -and $governor -match 'FailSpan' -and $governor -match 'throw;') 'governor captures pre-state and rethrows'
Assert-Span ($selector -match 'MarketScan' -and $selector -match 'PackMissionEvaluation' -and $selector -match 'SmithingInputLookup' -and $selector -match 'SettlementResolution' -and $selector -match 'DistanceEvaluation' -and $selector -match 'CandidateCreation' -and $selector -match 'Fallback' -and $selector -match 'FinalOrdering') 'selector nested operation spans'
Assert-Span ($service -match 'StartRouteNow' -and $service -match 'BeginTravel' -and $service -match 'BlockSpan' -and $service -match 'CompleteSpan') 'route boundaries terminalized'

foreach ($case in @($fixtures.cases)) {
    $open = @{}
    $valid = $true
    foreach ($event in @($case.events)) {
        $spanId = [string]$event.spanId
        if ($event.eventType -eq 'span.started') {
            if ($open.ContainsKey($spanId)) { $valid = $false }
            $open[$spanId] = $true
        } elseif ($event.eventType -match '^span\.(completed|error|blocked|abandoned)$') {
            if ($open.ContainsKey($spanId)) { $open.Remove($spanId) } elseif ($spanId -ne 'unrelated') { $valid = $false }
        }
    }
    Assert-Span ($valid -and $open.Count -eq 0) "fixture $($case.id)"
}

$result = [ordered]@{
    schema = 'tbg.runtime-span-instrumentation.validation.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    pass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    proofLevel = 'static_test'
}
$output = Join-Path $repoRoot 'artifacts/latest/runtime-observer/runtime-span-instrumentation.result.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
[IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { exit 1 }
Write-Host "Runtime span instrumentation: PASS ($passes checks)" -ForegroundColor Green
