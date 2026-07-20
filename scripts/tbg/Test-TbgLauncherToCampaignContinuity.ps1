# Static launcher-to-campaign event-continuity doctrine validator. No process, launcher, game, input, save, deployment, or network mutation.
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputPath = 'artifacts/latest/launcher-to-campaign-continuity/launcher-to-campaign-continuity.result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
if (-not [IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $RepoRoot $OutputPath }

$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Add-Pass([string]$Message) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
function Add-Failure([string]$Message) { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
function Get-Text([string]$RelativePath) {
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "missing file $RelativePath"; return $null }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}
function Get-Json([string]$RelativePath) {
    $raw = Get-Text $RelativePath
    if ($null -eq $raw) { return $null }
    try { return $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { Add-Failure "invalid JSON ${RelativePath}: $($_.Exception.Message)"; return $null }
}
function Get-Value($Object, [string[]]$Path) {
    $current = $Object
    foreach ($segment in $Path) {
        if ($null -eq $current) { return $null }
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) { return $null }
        $current = $property.Value
    }
    return $current
}
function Require-Match([string]$Label, [AllowNull()][string]$Text, [string]$Pattern) {
    if ($null -ne $Text -and $Text -match $Pattern) { Add-Pass $Label } else { Add-Failure "$Label missing $Pattern" }
}
function Require-Values([string]$Label, [object[]]$Actual, [string[]]$Expected) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    $missing = @($Expected | Where-Object { $values -notcontains $_ })
    if ($missing.Count -eq 0) { Add-Pass $Label } else { Add-Failure "$Label missing $($missing -join ', ')" }
}
function Require-True([string]$Label, $Value) {
    if ($Value -eq $true) { Add-Pass $Label } else { Add-Failure $Label }
}
function Require-False([string]$Label, $Value) {
    if ($Value -eq $false) { Add-Pass $Label } else { Add-Failure $Label }
}
function Require-Equal([string]$Label, $Actual, $Expected) {
    if ([string]$Actual -eq [string]$Expected) { Add-Pass $Label } else { Add-Failure "$Label expected '$Expected' got '$Actual'" }
}
function Write-Result {
    $result = [ordered]@{
        schema = 'TbgLauncherToCampaignContinuityValidation.v1'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        pass = ($script:failures.Count -eq 0)
        passCount = $script:passes
        failureCount = $script:failures.Count
        failures = @($script:failures)
        proofLevel = 'static_test'
        proofCeiling = 'static_test'
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
    [IO.File]::WriteAllText($OutputPath, ($result | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
}

try {
    $doctrine = Get-Text 'docs/harness-doctrine.md'
    $agents = Get-Text 'AGENTS.md'
    $codebaseMap = Get-Text 'CODEBASE_MAP.md'
    $launcherSkill = Get-Text '.tbg/skills/launcher-lifecycle/SKILL.md'
    $routeSkill = Get-Text '.tbg/skills/route-visible-trade/SKILL.md'
    $policy = Get-Json '.tbg/harness/policies/harness-doctrine.policy.json'
    $contract = Get-Json '.tbg/workflows/launcher-to-campaign-event-continuity.contract.json'
    $runtimeContract = Get-Json '.tbg/workflows/runtime-event-observation.contract.json'
    $manifest = Get-Json '.tbg/harness/manifest.json'
    $fixture = Get-Json '.tbg/harness/fixtures/event-continuity/launcher-to-campaign-continuity.fixture.json'
    $handoffTrigger = Get-Json '.tbg/harness/triggers.d/launcher-handoff-runtime-attach.trigger.json'
    $attachmentTrigger = Get-Json '.tbg/harness/triggers.d/runtime-observer-attachment.trigger.json'
    $campaignTrigger = Get-Json '.tbg/harness/triggers.d/campaign-readiness-cascade.trigger.json'
    $catalog = Get-Json '.tbg/harness/test-catalog.d/core/launcher-to-campaign-continuity.test.json'

    Require-Match 'doctrine defines cross-boundary continuity' $doctrine 'Cross-boundary observer continuity and campaign readiness cascade'
    Require-Match 'doctrine requires observer overlap' $doctrine 'window observer and external runtime observer must overlap'
    Require-Match 'doctrine gates window observer retirement' $doctrine 'window observer may retire only after'
    Require-Match 'doctrine separates launcher handoff' $doctrine 'Launcher handoff is not campaign readiness'
    Require-Match 'doctrine separates MapTransition' $doctrine 'MapTransition is not MapReady or campaign readiness'
    Require-Match 'doctrine defines campaign readiness gate' $doctrine 'campaignReady:true[\s\S]*canPollFileInbox:true[\s\S]*60-second'
    Require-Match 'doctrine trigger grants no gameplay authority' $doctrine 'readiness cascade grants no gameplay authority'
    Require-Match 'AGENTS defines continuity bridge' $agents 'window observer may retire only after a same-run runtime-observer attachment'
    Require-Match 'AGENTS defines campaign readiness gate' $agents 'campaignReady:true, canPollFileInbox:true, and a fresh 60-second stable map-ready interval'
    Require-Match 'AGENTS rejects trigger authority promotion' $agents 'readiness cascade grants no gameplay authority'
    Require-Match 'codebase map indexes continuity contract' $codebaseMap 'launcher-to-campaign-event-continuity\.contract\.json'
    Require-Match 'launcher skill reads continuity contract' $launcherSkill 'launcher-to-campaign-event-continuity\.contract\.json'
    Require-Match 'launcher skill requires overlap handoff' $launcherSkill 'runtime observer attachment acknowledgement'
    Require-Match 'route skill reads continuity contract' $routeSkill 'launcher-to-campaign-event-continuity\.contract\.json'
    Require-Match 'route skill requires campaign ready event' $routeSkill 'campaign\.automation\.ready'

    Require-Values 'policy contains HD-015' @(Get-Value $policy @('rules') | ForEach-Object { Get-Value $_ @('id') }) @('HD-015')
    $policyContinuity = Get-Value $policy @('launcherToCampaignContinuity')
    Require-Values 'policy continuity shared fields' @(Get-Value $policyContinuity @('sharedIdentityFields')) @('runId','correlationId','launchPath','launcherPidOrNull','launcherHwndOrNull','gamePidOrNull','gameHwndOrNull','gameSessionIdOrNull')
    Require-Values 'policy continuity required events' @(Get-Value $policyContinuity @('requiredEvents')) @('observer.window.started','observer.runtime.started','launch.handoff.verified_or_blocked','runtime.observer.attached_or_blocked','game.runtime.lifecycle.observed','campaign.map.transition_observed','campaign.map.ready_observed','campaign.readiness.stable_or_blocked','campaign.command_poll.ready_or_blocked','campaign.automation.ready_or_blocked','campaign.readiness.cascade_published_or_blocked')
    Require-True 'policy overlap required' (Get-Value $policyContinuity @('observerOverlapRequired'))
    Require-True 'policy same run required' (Get-Value $policyContinuity @('sameRunIdRequired'))
    Require-True 'policy same correlation required' (Get-Value $policyContinuity @('sameCorrelationIdRequired'))
    Require-True 'policy window retire gated' (Get-Value $policyContinuity @('windowObserverRetiresAfterRuntimeAttachment'))
    Require-True 'policy launcher handoff not readiness' (Get-Value $policyContinuity @('launcherHandoffIsNotCampaignReadiness'))
    Require-True 'policy MapTransition not readiness' (Get-Value $policyContinuity @('mapTransitionIsNotCampaignReadiness'))
    Require-False 'policy trigger no gameplay authority' (Get-Value $policyContinuity @('readinessCascadeGrantsGameplayAuthority'))
    Require-Equal 'policy stability window' (Get-Value $policyContinuity @('stabilityWindowSeconds')) 60

    Require-Equal 'workflow contract id' (Get-Value $contract @('id')) 'launcher-to-campaign-event-continuity'
    Require-Equal 'workflow schema version' (Get-Value $contract @('schemaVersion')) 'TbgWorkflowContract.v1'
    Require-Values 'workflow shared identity fields' @(Get-Value $contract @('sharedIdentityFields')) @('runId','correlationId','launchPath','gamePidOrNull','gameHwndOrNull','gameSessionIdOrNull')
    $lease = Get-Value $contract @('observerLeaseContinuity')
    Require-True 'workflow window observer active first' (Get-Value $lease @('windowObserverActiveBeforeFirstActuation'))
    Require-True 'workflow runtime observer active first' (Get-Value $lease @('runtimeObserverActiveBeforeFirstActuation'))
    Require-True 'workflow observer overlap' (Get-Value $lease @('overlapRequiredAcrossFinalLauncherHandoff'))
    Require-True 'workflow runtime ack before window retire' (Get-Value $lease @('windowObserverMayRetireOnlyAfterRuntimeAttachmentAck'))
    Require-True 'workflow same-process hosting allowed' (Get-Value $lease @('sameProcessGameHostingAllowed'))
    $handoffGate = Get-Value $contract @('launcherHandoffGate')
    Require-True 'workflow handoff requires runtime ack' (Get-Value $handoffGate @('requiresRuntimeObserverAttachmentAck'))
    Require-True 'workflow handoff not readiness' (Get-Value $handoffGate @('launcherHandoffIsNotCampaignReadiness'))
    $readinessGate = Get-Value $contract @('campaignReadinessGate')
    Require-Values 'workflow campaign readiness signals' @(Get-Value $readinessGate @('requiredSignals')) @('sessionReady:true','mapReady:true','campaignReady:true','canPollFileInbox:true','runtimeObserverHealthy:true','gameProcessAlive:true','stabilityWindowComplete:true')
    Require-Equal 'workflow stability window' (Get-Value $readinessGate @('stabilityWindowSeconds')) 60
    Require-Equal 'workflow ready event' (Get-Value $readinessGate @('readyEvent')) 'campaign.automation.ready'
    Require-False 'workflow ready event grants no gameplay authority' (Get-Value $readinessGate @('readyEventGrantsGameplayAuthority'))
    Require-Values 'workflow required artifacts' @(Get-Value $contract @('requiredArtifacts')) @('.local/tbg-runtime-observer/<runId>/handoff-context.json','.local/tbg-runtime-observer/<runId>/campaign-readiness.json','.local/tbg-runtime-observer/<runId>/campaign-readiness-cascade.json')

    $runtimeSpecialization = Get-Value $runtimeContract @('continuitySpecialization')
    Require-Equal 'runtime continuity specialization path' (Get-Value $runtimeSpecialization @('contract')) '.tbg/workflows/launcher-to-campaign-event-continuity.contract.json'
    Require-True 'runtime observer preserves run id' (Get-Value $runtimeSpecialization @('preserveRunIdAcrossLauncherAndGame'))
    Require-True 'runtime observer preserves correlation id' (Get-Value $runtimeSpecialization @('preserveCorrelationIdAcrossLauncherAndGame'))
    Require-True 'runtime observer requires overlap' (Get-Value $runtimeSpecialization @('requireWindowAndRuntimeObserverOverlap'))
    Require-True 'runtime observer gates campaign cascade' (Get-Value $runtimeSpecialization @('campaignCascadeRequiresStableReadinessGate'))
    Require-Values 'runtime continuity additional artifacts' @(Get-Value $runtimeSpecialization @('additionalArtifacts')) @('handoff-context.json','campaign-readiness.json','campaign-readiness-cascade.json')

    $manifestPaths = Get-Value $manifest @('paths')
    Require-Equal 'manifest continuity contract' (Get-Value $manifestPaths @('launcherToCampaignContinuityContract')) '.tbg/workflows/launcher-to-campaign-event-continuity.contract.json'
    Require-Equal 'manifest continuity fixture' (Get-Value $manifestPaths @('launcherToCampaignContinuityFixture')) '.tbg/harness/fixtures/event-continuity/launcher-to-campaign-continuity.fixture.json'
    Require-Equal 'manifest continuity validator' (Get-Value $manifestPaths @('launcherToCampaignContinuityValidator')) 'scripts/tbg/Test-TbgLauncherToCampaignContinuity.ps1'
    Require-Equal 'manifest continuity output' (Get-Value $manifestPaths @('launcherToCampaignContinuityOutput')) 'artifacts/latest/launcher-to-campaign-continuity'

    foreach ($item in @(
        @{ Label='launcher handoff trigger'; Object=$handoffTrigger; Id='launcher-handoff-runtime-attach'; Event='launch.handoff.verified'; Operation='attach-or-confirm-runtime-observer' },
        @{ Label='runtime attachment trigger'; Object=$attachmentTrigger; Id='runtime-observer-attachment'; Event='runtime.observer.attached'; Operation='complete-window-observer-transfer' },
        @{ Label='campaign readiness trigger'; Object=$campaignTrigger; Id='campaign-readiness-cascade'; Event='campaign.automation.ready'; Operation='publish-campaign-readiness-cascade' }
    )) {
        Require-Equal "$($item.Label) schema" (Get-Value $item.Object @('schema')) 'tbg.one-click-test.trigger.v1'
        Require-Equal "$($item.Label) id" (Get-Value $item.Object @('triggerId')) $item.Id
        Require-Values "$($item.Label) event" @(Get-Value $item.Object @('eventMatch','eventTypes')) @($item.Event)
        Require-Equal "$($item.Label) operation" (Get-Value $item.Object @('downstreamOperation')) $item.Operation
        Require-Equal "$($item.Label) authority" (Get-Value $item.Object @('mutationAuthority')) 'read_only'
    }
    Require-Match 'campaign trigger states no gameplay authority' ([string](Get-Value $campaignTrigger @('description'))) 'grants no gameplay authority'
    Require-Match 'campaign trigger requires 60 second stability' ([string](Get-Value $campaignTrigger @('requiredFreshness'))) '60-second'

    Require-Equal 'fixture schema' (Get-Value $fixture @('schema')) 'TbgLauncherToCampaignContinuityFixture.v1'
    Require-Equal 'fixture stability window' (Get-Value $fixture @('stabilityWindowSeconds')) 60
    $cases = @(Get-Value $fixture @('cases'))
    $caseIds = @($cases | ForEach-Object { [string](Get-Value $_ @('id')) })
    Require-Values 'fixture cases' $caseIds @('valid_overlap_to_campaign_cascade','window_observer_retires_before_runtime_attach','runtime_attach_uses_new_correlation','map_transition_is_not_campaign_ready','map_ready_without_campaign_ready_blocks','campaign_ready_without_command_poll_blocks','stability_window_too_short_blocks','observer_gap_blocks_readiness_release','readiness_trigger_never_grants_gameplay_authority')
    $validCase = @($cases | Where-Object { (Get-Value $_ @('id')) -eq 'valid_overlap_to_campaign_cascade' } | Select-Object -First 1)
    Require-Equal 'fixture valid terminal state' (Get-Value $validCase @('expectedTerminalState')) 'PASS_CONTINUOUS_CAMPAIGN_READINESS_CASCADE'
    $authorityCase = @($cases | Where-Object { (Get-Value $_ @('id')) -eq 'readiness_trigger_never_grants_gameplay_authority' } | Select-Object -First 1)
    Require-Equal 'fixture authority escalation blocks' (Get-Value $authorityCase @('expectedTerminalState')) 'BLOCKED_TRIGGER_AUTHORITY_ESCALATION'

    Require-Equal 'catalog schema' (Get-Value $catalog @('schema')) 'tbg.one-click-test.catalog-entry.v1'
    Require-Equal 'catalog test id' (Get-Value $catalog @('testId')) 'core.launcher-to-campaign-continuity'
    Require-Equal 'catalog source path' (Get-Value $catalog @('sourcePath')) 'scripts/tbg/Test-TbgLauncherToCampaignContinuity.ps1'
    Require-Values 'catalog default profiles' @(Get-Value $catalog @('defaultProfileMembership')) @('default-static','operator-observe')
    Require-Equal 'catalog mutation class' (Get-Value $catalog @('mutationClass')) 'none'
}
catch {
    Add-Failure "unexpected validator exception: $($_.Exception.Message)"
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) { Add-Failure ([string]$_.InvocationInfo.PositionMessage) }
}
finally {
    Write-Result
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "Launcher-to-campaign continuity doctrine: FAIL ($($failures.Count))" -ForegroundColor Red
    exit 1
}
Write-Host "Launcher-to-campaign continuity doctrine: PASS ($passes checks)" -ForegroundColor Green
exit 0
