# Static launcher-to-campaign event-continuity doctrine validator. No process, launcher, game, input, save, deployment, or network mutation.
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputPath = 'artifacts/latest/launcher-to-campaign-continuity/launcher-to-campaign-continuity.result.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot $OutputPath
}

$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Add-Pass([string]$Message) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
function Add-Failure([string]$Message) { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
function Get-Text([string]$RelativePath) {
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Failure "missing file $RelativePath"; return $null }
    Get-Content -LiteralPath $path -Raw -Encoding UTF8
}
function Get-Json([string]$RelativePath) {
    $raw = Get-Text $RelativePath
    if ($null -eq $raw) { return $null }
    try { $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { Add-Failure "invalid JSON $RelativePath: $($_.Exception.Message)"; $null }
}
function Require-Match([string]$Label, [AllowNull()][string]$Text, [string]$Pattern) {
    if ($null -eq $Text) { return }
    if ($Text -match $Pattern) { Add-Pass $Label } else { Add-Failure "$Label missing $Pattern" }
}
function Require-Values([string]$Label, [object[]]$Actual, [string[]]$Expected) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    $missing = @($Expected | Where-Object { $values -notcontains $_ })
    if ($missing.Count -eq 0) { Add-Pass $Label } else { Add-Failure "$Label missing $($missing -join ', ')" }
}
function Require-True([string]$Label, $Value) {
    if ([bool]$Value) { Add-Pass $Label } else { Add-Failure $Label }
}
function Require-Equal([string]$Label, $Actual, $Expected) {
    if ([string]$Actual -eq [string]$Expected) { Add-Pass $Label } else { Add-Failure "$Label expected '$Expected' got '$Actual'" }
}

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
Require-Match 'doctrine defines rock gate' $doctrine 'campaignReady:true[\s\S]*canPollFileInbox:true[\s\S]*60-second'
Require-Match 'doctrine trigger grants no gameplay authority' $doctrine 'readiness cascade grants no gameplay authority'
Require-Match 'AGENTS defines continuity bridge' $agents 'window observer may retire only after a same-run runtime-observer attachment'
Require-Match 'AGENTS defines campaign readiness gate' $agents 'campaignReady:true, canPollFileInbox:true, and a fresh 60-second stable map-ready interval'
Require-Match 'AGENTS rejects trigger authority promotion' $agents 'readiness cascade grants no gameplay authority'
Require-Match 'codebase map indexes continuity contract' $codebaseMap 'launcher-to-campaign-event-continuity\.contract\.json'
Require-Match 'launcher skill reads continuity contract' $launcherSkill 'launcher-to-campaign-event-continuity\.contract\.json'
Require-Match 'launcher skill requires overlap handoff' $launcherSkill 'runtime observer attachment acknowledgement'
Require-Match 'route skill reads continuity contract' $routeSkill 'launcher-to-campaign-event-continuity\.contract\.json'
Require-Match 'route skill requires campaign ready event' $routeSkill 'campaign\.automation\.ready'

if ($policy) {
    Require-Values 'policy contains HD-015' @($policy.rules | ForEach-Object { $_.id }) @('HD-015')
    Require-Values 'policy continuity shared fields' @($policy.launcherToCampaignContinuity.sharedIdentityFields) @(
        'runId','correlationId','launchPath','launcherPidOrNull','launcherHwndOrNull','gamePidOrNull','gameHwndOrNull','gameSessionIdOrNull'
    )
    Require-Values 'policy continuity required events' @($policy.launcherToCampaignContinuity.requiredEvents) @(
        'observer.window.started','observer.runtime.started','launch.handoff.verified_or_blocked','runtime.observer.attached_or_blocked',
        'game.runtime.lifecycle.observed','campaign.map.transition_observed','campaign.map.ready_observed','campaign.readiness.stable_or_blocked',
        'campaign.command_poll.ready_or_blocked','campaign.automation.ready_or_blocked','campaign.readiness.cascade_published_or_blocked'
    )
    Require-True 'policy overlap required' $policy.launcherToCampaignContinuity.observerOverlapRequired
    Require-True 'policy same run required' $policy.launcherToCampaignContinuity.sameRunIdRequired
    Require-True 'policy same correlation required' $policy.launcherToCampaignContinuity.sameCorrelationIdRequired
    Require-True 'policy window retire gated' $policy.launcherToCampaignContinuity.windowObserverRetiresAfterRuntimeAttachment
    Require-True 'policy launcher handoff not readiness' $policy.launcherToCampaignContinuity.launcherHandoffIsNotCampaignReadiness
    Require-True 'policy MapTransition not readiness' $policy.launcherToCampaignContinuity.mapTransitionIsNotCampaignReadiness
    Require-True 'policy trigger no gameplay authority' $policy.launcherToCampaignContinuity.readinessCascadeGrantsGameplayAuthority -eq $false
    Require-Equal 'policy stability window' $policy.launcherToCampaignContinuity.stabilityWindowSeconds 60
}

if ($contract) {
    Require-Equal 'workflow contract id' $contract.id 'launcher-to-campaign-event-continuity'
    Require-Equal 'workflow schema version' $contract.schemaVersion 'TbgWorkflowContract.v1'
    Require-Values 'workflow shared identity fields' @($contract.sharedIdentityFields) @('runId','correlationId','launchPath','gamePidOrNull','gameHwndOrNull','gameSessionIdOrNull')
    Require-True 'workflow window observer active first' $contract.observerLeaseContinuity.windowObserverActiveBeforeFirstActuation
    Require-True 'workflow runtime observer active first' $contract.observerLeaseContinuity.runtimeObserverActiveBeforeFirstActuation
    Require-True 'workflow observer overlap' $contract.observerLeaseContinuity.overlapRequiredAcrossFinalLauncherHandoff
    Require-True 'workflow runtime ack before window retire' $contract.observerLeaseContinuity.windowObserverMayRetireOnlyAfterRuntimeAttachmentAck
    Require-True 'workflow same-process hosting allowed' $contract.observerLeaseContinuity.sameProcessGameHostingAllowed
    Require-True 'workflow handoff requires runtime ack' $contract.launcherHandoffGate.requiresRuntimeObserverAttachmentAck
    Require-True 'workflow handoff not readiness' $contract.launcherHandoffGate.launcherHandoffIsNotCampaignReadiness
    Require-Values 'workflow campaign readiness signals' @($contract.campaignReadinessGate.requiredSignals) @(
        'sessionReady:true','mapReady:true','campaignReady:true','canPollFileInbox:true','runtimeObserverHealthy:true','gameProcessAlive:true','stabilityWindowComplete:true'
    )
    Require-Equal 'workflow stability window' $contract.campaignReadinessGate.stabilityWindowSeconds 60
    Require-Equal 'workflow ready event' $contract.campaignReadinessGate.readyEvent 'campaign.automation.ready'
    if ($contract.campaignReadinessGate.readyEventGrantsGameplayAuthority -eq $false) { Add-Pass 'workflow ready event grants no gameplay authority' } else { Add-Failure 'workflow ready event grants no gameplay authority' }
    Require-Values 'workflow required artifacts' @($contract.requiredArtifacts) @(
        '.local/tbg-runtime-observer/<runId>/handoff-context.json',
        '.local/tbg-runtime-observer/<runId>/campaign-readiness.json',
        '.local/tbg-runtime-observer/<runId>/campaign-readiness-cascade.json'
    )
}

if ($runtimeContract) {
    Require-Equal 'runtime continuity specialization path' $runtimeContract.continuitySpecialization.contract '.tbg/workflows/launcher-to-campaign-event-continuity.contract.json'
    Require-True 'runtime observer preserves run id' $runtimeContract.continuitySpecialization.preserveRunIdAcrossLauncherAndGame
    Require-True 'runtime observer preserves correlation id' $runtimeContract.continuitySpecialization.preserveCorrelationIdAcrossLauncherAndGame
    Require-True 'runtime observer requires overlap' $runtimeContract.continuitySpecialization.requireWindowAndRuntimeObserverOverlap
    Require-True 'runtime observer gates campaign cascade' $runtimeContract.continuitySpecialization.campaignCascadeRequiresStableReadinessGate
}

if ($manifest) {
    Require-Equal 'manifest continuity contract' $manifest.paths.launcherToCampaignContinuityContract '.tbg/workflows/launcher-to-campaign-event-continuity.contract.json'
    Require-Equal 'manifest continuity fixture' $manifest.paths.launcherToCampaignContinuityFixture '.tbg/harness/fixtures/event-continuity/launcher-to-campaign-continuity.fixture.json'
    Require-Equal 'manifest continuity validator' $manifest.paths.launcherToCampaignContinuityValidator 'scripts/tbg/Test-TbgLauncherToCampaignContinuity.ps1'
    Require-Equal 'manifest continuity output' $manifest.paths.launcherToCampaignContinuityOutput 'artifacts/latest/launcher-to-campaign-continuity'
}

foreach ($triggerInfo in @(
    @{ label='launcher handoff trigger'; value=$handoffTrigger; id='launcher-handoff-runtime-attach'; event='launch.handoff.verified'; operation='attach-or-confirm-runtime-observer' },
    @{ label='runtime attachment trigger'; value=$attachmentTrigger; id='runtime-observer-attachment'; event='runtime.observer.attached'; operation='complete-window-observer-transfer' },
    @{ label='campaign readiness trigger'; value=$campaignTrigger; id='campaign-readiness-cascade'; event='campaign.automation.ready'; operation='publish-campaign-readiness-cascade' }
)) {
    $trigger = $triggerInfo.value
    if ($trigger) {
        Require-Equal "$($triggerInfo.label) schema" $trigger.schema 'tbg.one-click-test.trigger.v1'
        Require-Equal "$($triggerInfo.label) id" $trigger.triggerId $triggerInfo.id
        Require-Values "$($triggerInfo.label) event" @($trigger.eventMatch.eventTypes) @($triggerInfo.event)
        Require-Equal "$($triggerInfo.label) operation" $trigger.downstreamOperation $triggerInfo.operation
        Require-Equal "$($triggerInfo.label) authority" $trigger.mutationAuthority 'read_only'
    }
}
if ($campaignTrigger) {
    Require-Match 'campaign trigger states no gameplay authority' ([string]$campaignTrigger.description) 'grants no gameplay authority'
    Require-Match 'campaign trigger requires 60 second stability' ([string]$campaignTrigger.requiredFreshness) '60-second'
}

if ($fixture) {
    Require-Equal 'fixture schema' $fixture.schema 'TbgLauncherToCampaignContinuityFixture.v1'
    Require-Equal 'fixture stability window' $fixture.stabilityWindowSeconds 60
    $caseIds = @($fixture.cases | ForEach-Object { [string]$_.id })
    Require-Values 'fixture cases' $caseIds @(
        'valid_overlap_to_campaign_cascade','window_observer_retires_before_runtime_attach','runtime_attach_uses_new_correlation',
        'map_transition_is_not_campaign_ready','map_ready_without_campaign_ready_blocks','campaign_ready_without_command_poll_blocks',
        'stability_window_too_short_blocks','observer_gap_blocks_readiness_release','readiness_trigger_never_grants_gameplay_authority'
    )
    $valid = @($fixture.cases | Where-Object { $_.id -eq 'valid_overlap_to_campaign_cascade' })[0]
    Require-Equal 'fixture valid terminal state' $valid.expectedTerminalState 'PASS_CONTINUOUS_CAMPAIGN_READINESS_CASCADE'
    $authorityCase = @($fixture.cases | Where-Object { $_.id -eq 'readiness_trigger_never_grants_gameplay_authority' })[0]
    Require-Equal 'fixture authority escalation blocks' $authorityCase.expectedTerminalState 'BLOCKED_TRIGGER_AUTHORITY_ESCALATION'
}

if ($catalog) {
    Require-Equal 'catalog schema' $catalog.schema 'tbg.one-click-test.catalog-entry.v1'
    Require-Equal 'catalog test id' $catalog.testId 'core.launcher-to-campaign-continuity'
    Require-Equal 'catalog source path' $catalog.sourcePath 'scripts/tbg/Test-TbgLauncherToCampaignContinuity.ps1'
    Require-Values 'catalog default profiles' @($catalog.defaultProfileMembership) @('default-static','operator-observe')
    Require-Equal 'catalog mutation class' $catalog.mutationClass 'none'
}

$result = [ordered]@{
    schema = 'TbgLauncherToCampaignContinuityValidation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    pass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    proofLevel = 'static_test'
    proofCeiling = 'static_test'
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
[IO.File]::WriteAllText($OutputPath, ($result | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "Launcher-to-campaign continuity doctrine: FAIL ($($failures.Count))" -ForegroundColor Red
    exit 1
}
Write-Host "Launcher-to-campaign continuity doctrine: PASS ($passes checks)" -ForegroundColor Green
exit 0
