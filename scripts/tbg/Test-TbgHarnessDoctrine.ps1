# Static harness-doctrine validator. No product, process, game, save, or network mutation.
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputPath = 'artifacts/latest/harness-doctrine/harness-doctrine.result.json'
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
    Get-Content -LiteralPath $path -Raw
}
function Get-Json([string]$RelativePath) {
    $raw = Get-Text $RelativePath
    if ($null -eq $raw) { return $null }
    try { $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { Add-Failure "invalid JSON $RelativePath"; $null }
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
function Require-Path([string]$Label, [string]$RelativePath) {
    if (Test-Path -LiteralPath (Join-Path $RepoRoot $RelativePath)) { Add-Pass $Label }
    else { Add-Failure "$Label missing $RelativePath" }
}

$doctrinePath = 'docs/harness-doctrine.md'
$entrypointPath = 'docs/AI_HARNESS_ENTRYPOINT.md'
$generatedOutputPolicyPath = '.gitignore'
$policyPath = '.tbg/harness/policies/harness-doctrine.policy.json'
$runtimePath = '.tbg/workflows/runtime-context-continuity.contract.json'
$runtimeSchemaPath = '.tbg/harness/schemas/runtime-context-capsule.schema.json'
$doctrine = Get-Text $doctrinePath
$entrypoint = Get-Text $entrypointPath
$generatedOutputPolicy = Get-Text $generatedOutputPolicyPath
$agents = Get-Text 'AGENTS.md'
$policy = Get-Json $policyPath
$manifest = Get-Json '.tbg/harness/manifest.json'
$runtime = Get-Json $runtimePath
$runtimeSchema = Get-Json $runtimeSchemaPath

Require-Match 'doctrine defines harness' $doctrine 'A prompt is one artifact inside the harness'
Require-Match 'doctrine defines fresh-agent acceptance' $doctrine 'Fresh-agent acceptance'
Require-Match 'doctrine defines execution loop' $doctrine 'request[\s\S]*evidence review[\s\S]*bounded decision[\s\S]*repo or Git or GitHub mutation[\s\S]*artifacts[\s\S]*validation[\s\S]*report[\s\S]*next decision'
Require-Match 'doctrine defines action commitment' $doctrine 'install, set up, build, execute, repair, configure, upgrade, deploy, merge, or release'
Require-Match 'doctrine defines task override' $doctrine 'task-specific execution contract overrides generic closeout'
Require-Match 'doctrine defines runtime specialization' $doctrine 'runtime-context-continuity\.contract\.json'
Require-Match 'doctrine defines crash observability' $doctrine 'Crash observability and negative evidence'
Require-Match 'doctrine requires pre-post state' $doctrine 'pre-state snapshot[\s\S]*post-state snapshot'
Require-Match 'doctrine constrains negative evidence' $doctrine 'Negative evidence is valid only when'
Require-Match 'doctrine separates causality' $doctrine 'observation:[\s\S]*inference:[\s\S]*hypotheses:[\s\S]*proven cause:'
Require-Match 'doctrine last marker boundary' $doctrine 'last marker is always a boundary, never a cause'
Require-Match 'doctrine external crash evidence' $doctrine 'native_crash_confirmed.*correlated external terminal evidence'
Require-Match 'doctrine reconstruction gate' $doctrine 'fresh agent who was not present must be able to reconstruct'
Require-Match 'entrypoint defines ordered fresh-agent journey' $entrypoint 'AGENTS\.md[\s\S]*harness-doctrine\.md[\s\S]*harness/manifest\.json[\s\S]*\.gitignore[\s\S]*CODEBASE_MAP\.md[\s\S]*skills/manifest\.json[\s\S]*workflow contract[\s\S]*targeted validator[\s\S]*E2E profile[\s\S]*artifact registry[\s\S]*sprint-capsule'
Require-Match 'entrypoint rejects prompt substitution' $entrypoint 'Prompts remain artifacts inside this system; they are not the harness'
$generatedOutputLines = @($generatedOutputPolicy -split "`r?`n")
Require-Values 'generated output boundaries' $generatedOutputLines @('.local/','artifacts/','*.log','*.dmp')
Require-Match 'AGENTS points to doctrine' $agents 'docs/harness-doctrine\.md'
Require-Match 'AGENTS requires action proof' $agents 'plan-only closeout is invalid'
Require-Match 'AGENTS protects existing runtime' $agents 'process presence is context, not zombie proof'
Require-Match 'AGENTS defines crash boundary' $agents 'last marker as a boundary rather than a cause'
if ($agents) {
    $lineCount = @($agents -split "`r?`n").Count
    if ($lineCount -le 110) { Add-Pass "AGENTS ceiling $lineCount/110" }
    else { Add-Failure "AGENTS ceiling $lineCount/110" }
}

if ($policy) {
    if ($policy.schema -eq 'tbg.harness-doctrine.policy.v1') { Add-Pass 'policy schema' } else { Add-Failure 'policy schema' }
    Require-Values 'policy identity fields' @($policy.requiredFields) @(
        'repo','branch_or_worktree','pr_or_sprint','lane','owned_scope','forbidden_scope','expected_artifacts','validation_order_when_specified'
    )
    $expectedLoop = @('request','evidence_review','bounded_decision','repo_or_git_or_github_mutation','artifacts','validation','report','next_decision')
    if ((@($policy.executionLoop) -join '|') -eq ($expectedLoop -join '|')) { Add-Pass 'policy executable loop' }
    else { Add-Failure 'policy executable loop' }
    Require-Values 'policy action verbs' @($policy.actionCommitment.verbs) @(
        'install','set up','build','execute','repair','configure','upgrade','deploy','merge','release'
    )
    if ($policy.actionCommitment.requiresMutation -and $policy.actionCommitment.requiresProof) { Add-Pass 'policy action commitment' }
    else { Add-Failure 'policy action commitment' }
    Require-Values 'policy invalid closeouts' @($policy.invalidCloseouts) @(
        'acknowledgment_only','summary_only','rewritten_prompt_only','plan_only','handoff_only','preflight_only'
    )
    Require-Values 'policy rule IDs' @($policy.rules | ForEach-Object { $_.id }) @('HD-001','HD-002','HD-003','HD-004','HD-005','HD-006','HD-007','HD-008','HD-009','HD-010','HD-011','HD-012')
    Require-Values 'policy crash trace fields' @($policy.crashObservability.requiredTraceFields) @(
        'runId','commandIdOrNull','correlationId','spanId','parentSpanIdOrNull','operation','startedAtUtc',
        'preState','postStateOrNull','expectedSignals','observedSignals','negativeEvidence','terminalStatus'
    )
    Require-Values 'policy negative evidence requirements' @($policy.crashObservability.negativeEvidenceRequires) @(
        'signal_declared_in_advance','observer_identified','source_identified','source_fresh','observation_window_complete','signal_explicitly_absent'
    )
    Require-Values 'policy causality fields' @($policy.crashObservability.causalityFields) @(
        'observation','inferenceOrNull','hypotheses','provenCauseOrNull','rootCauseEvidenceRefs'
    )
    Require-Values 'policy native crash evidence' @($policy.crashObservability.nativeCrashConfirmationRequires) @(
        'correlated_external_terminal_evidence','correlated_process_identity','correlated_timestamp'
    )
    if ($policy.crashObservability.lastMarkerIsBoundaryNotCause) { Add-Pass 'policy last marker boundary' } else { Add-Failure 'policy last marker boundary' }
    if ($policy.crashObservability.balancedSpansRequired) { Add-Pass 'policy balanced spans' } else { Add-Failure 'policy balanced spans' }
    if ($policy.crashObservability.unrelatedDoneCannotCloseActiveSpan) { Add-Pass 'policy unrelated done rejected' } else { Add-Failure 'policy unrelated done rejected' }
    if ($policy.crashObservability.postCrashLiveCertRequiresObservabilityPass) { Add-Pass 'policy post-crash cert gate' } else { Add-Failure 'policy post-crash cert gate' }
    Require-Match 'policy reconstruction gate' ([string]$policy.crashObservability.reconstructionGate) 'fresh agent.*reconstruct'
    foreach ($property in $policy.requiredHarnessComponents.PSObject.Properties) {
        Require-Path "harness component $($property.Name)" ([string]$property.Value)
    }
}

if ($manifest) {
    $expected = [ordered]@{
        codebaseMap = 'CODEBASE_MAP.md'
        aiHarnessEntrypoint = $entrypointPath
        generatedOutputPolicy = $generatedOutputPolicyPath
        harnessDoctrine = $doctrinePath
        harnessDoctrinePolicy = $policyPath
        harnessDoctrineValidator = 'scripts/tbg/Test-TbgHarnessDoctrine.ps1'
        endToEndContract = '.tbg/workflows/end-to-end-validation.contract.json'
        endToEndArtifactTypes = '.tbg/harness/e2e-artifact-types.registry.json'
        sprintCapsuleContract = '.tbg/workflows/tbg-sprint-capsule.contract.json'
        runtimeContextContinuityContract = $runtimePath
        runtimeContextCapsuleSchema = $runtimeSchemaPath
    }
    foreach ($entry in $expected.GetEnumerator()) {
        if ([string]$manifest.paths.($entry.Key) -eq [string]$entry.Value) { Add-Pass "manifest $($entry.Key)" }
        else { Add-Failure "manifest $($entry.Key)" }
    }
}

if ($runtime -and $runtime.schema -eq 'tbg.runtime-context-continuity.contract.v1') { Add-Pass 'runtime continuity contract' }
else { Add-Failure 'runtime continuity contract' }
if ($runtimeSchema -and $runtimeSchema.title -eq 'TbgRuntimeContextCapsule.v1') { Add-Pass 'runtime capsule schema' }
else { Add-Failure 'runtime capsule schema' }
if ($runtime -and $runtime.crashObservability.lastMarkerIsBoundaryNotCause) { Add-Pass 'runtime crash observability contract' }
else { Add-Failure 'runtime crash observability contract' }
if ($runtimeSchema -and ($runtimeSchema.properties.PSObject.Properties.Name -contains 'crashObservability')) { Add-Pass 'runtime crash observability schema' }
else { Add-Failure 'runtime crash observability schema' }

$result = [ordered]@{
    schema = 'tbg.harness-doctrine.validation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    pass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    proofLevel = 'static_test'
    proofCeiling = 'static_test'
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
[IO.File]::WriteAllText($OutputPath, ($result | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "Harness doctrine: FAIL ($($failures.Count))" -ForegroundColor Red
    exit 1
}
Write-Host "Harness doctrine: PASS ($passes checks)" -ForegroundColor Green
exit 0
