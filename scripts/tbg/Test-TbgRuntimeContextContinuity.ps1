# Static doctrine validator. No process, game, save, command, or network mutation.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0

function Fail([string]$Message) {
    $script:failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}
function Pass([string]$Message) {
    $script:passes++
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Text([string]$RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { Fail "Missing file: $RelativePath"; return $null }
    Get-Content -LiteralPath $path -Raw
}
function Json([string]$RelativePath) {
    $raw = Text $RelativePath
    if ($null -eq $raw) { return $null }
    try { $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { Fail "Invalid JSON: $RelativePath"; $null }
}
function Match([string]$Label, [string]$Value, [string]$Pattern) {
    if ($null -eq $Value) { return }
    if ($Value -match $Pattern) { Pass $Label } else { Fail "$Label missing $Pattern" }
}
function Contains([string]$Label, [object[]]$Actual, [string[]]$Expected) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    $missing = @($Expected | Where-Object { $values -notcontains $_ })
    if ($missing.Count -eq 0) { Pass $Label } else { Fail "$Label missing: $($missing -join ', ')" }
}

$contractPath = '.tbg/workflows/runtime-context-continuity.contract.json'
$schemaPath = '.tbg/harness/schemas/runtime-context-capsule.schema.json'
$fixturePath = '.tbg/harness/fixtures/runtime-context-continuity.fixtures.json'
$contract = Json $contractPath
$schema = Json $schemaPath
$fixtures = Json $fixturePath
$manifest = Json '.tbg/harness/manifest.json'
$agents = Text 'AGENTS.md'
$launcher = Text '.tbg/skills/launcher-lifecycle/SKILL.md'
$evidence = Text '.tbg/skills/runtime-evidence-certification/SKILL.md'
$readme = Text 'docs/evidence/runtime-context/README.md'

if ($contract) {
    if ($contract.schema -eq 'tbg.runtime-context-continuity.contract.v1') { Pass 'contract schema' } else { Fail 'contract schema' }
    Contains 'request context' @($contract.requiredRequestContext) @(
        'repo','branchOrWorktree','prOrSprint','lane','ownedScope','forbiddenScope','expectedArtifacts','validationOrderWhenSpecified'
    )
    $loop = @('request','evidence_review','bounded_decision','repo_or_git_or_github_mutation','artifacts','validation','report','next_decision')
    if ((@($contract.executionLoop) -join '|') -eq ($loop -join '|')) { Pass 'executable loop' } else { Fail 'executable loop' }
    Contains 'action verbs' @($contract.actionCommitment.actionVerbs) @(
        'install','set up','build','execute','repair','configure','upgrade','deploy','merge','release'
    )
    if ($contract.actionCommitment.requireMutation -and $contract.actionCommitment.requireProof) { Pass 'action commitment' } else { Fail 'action commitment' }
    Contains 'process names' @($contract.processIdentity.canonicalProcessNames) @(
        'Bannerlord','Bannerlord.Native','TaleWorlds.MountAndBlade','TaleWorlds.MountAndBlade.Launcher'
    )
    Contains 'classifications' @($contract.processIdentity.classifications) @(
        'absent','active_owned','active_human','active_foreign','stale_or_zombie_proven','ambiguous'
    )
    if ($contract.processIdentity.pidDeltaForbiddenAsPrimaryIdentity) { Pass 'PID delta secondary' } else { Fail 'PID delta secondary' }
    if ($contract.mutationAuthority.processPresenceAloneIsNotZombieProof) { Pass 'presence not zombie proof' } else { Fail 'presence not zombie proof' }
    Contains 'handoff fields' @($contract.handoffContinuity.requiredForEveryEngineHandoff) @(
        'runId','sourceEngine','targetEngine','branch','phase','authority','correlationId','status',
        'failureClassOrNull','evidenceRefs','nextEngineHint','exactHead'
    )
    Contains 'crash pre-state fields' @($contract.crashObservability.requiredBeforeCrashSensitiveOperation) @(
        'runId','commandIdOrNull','correlationId','spanId','parentSpanIdOrNull','operation','startedAtUtc','preState','expectedSignals'
    )
    Contains 'crash return fields' @($contract.crashObservability.requiredWhenControlReturns) @(
        'completedAtUtc','postState','observedSignals','terminalStatus'
    )
    Contains 'negative evidence fields' @($contract.crashObservability.negativeEvidenceRequiredFields) @(
        'expectedSignal','observer','source','windowStartUtc','windowEndUtc','sourceFresh','observationComplete','observed'
    )
    Contains 'causality fields' @($contract.crashObservability.causalityFields) @(
        'observation','inferenceOrNull','hypotheses','provenCauseOrNull','rootCauseEvidenceRefs'
    )
    Contains 'failure classifications' @($contract.crashObservability.failureClassifications) @(
        'log_stalled','process_unobserved','process_exited','managed_exception_confirmed','native_crash_suspected',
        'native_crash_confirmed','hang_confirmed','clean_exit','unknown_failure'
    )
    Contains 'native crash confirmation' @($contract.crashObservability.nativeCrashConfirmationRequires) @(
        'correlated_external_terminal_evidence','correlated_process_identity','correlated_timestamp'
    )
    if ($contract.crashObservability.lastMarkerIsBoundaryNotCause) { Pass 'last marker boundary only' } else { Fail 'last marker boundary only' }
    if ($contract.crashObservability.balancedSpansRequired) { Pass 'balanced spans required' } else { Fail 'balanced spans required' }
    if ($contract.crashObservability.unrelatedDoneCannotCloseActiveSpan) { Pass 'unrelated done rejected' } else { Fail 'unrelated done rejected' }
    if ($contract.crashObservability.postCrashLiveCertRequiresObservabilityPass) { Pass 'post-crash observability gate' } else { Fail 'post-crash observability gate' }
    Match 'reconstruction gate' ([string]$contract.crashObservability.reconstructionGate) 'fresh agent.*reconstruct'
    if ($contract.remoteEvidence.rawEvidencePolicy -eq 'local_ignored_only') { Pass 'raw evidence local' } else { Fail 'raw evidence local' }
    if ($contract.remoteEvidence.maxExcerptLines -le 80 -and $contract.remoteEvidence.maxCapsuleBytes -le 65536) {
        Pass 'capsule bounds'
    } else { Fail 'capsule bounds' }
    Contains 'allowed crash evidence' @($contract.remoteEvidence.allowedTrackedContent) @(
        'pre_and_post_state','expected_observed_and_absent_signals','open_span','external_terminal_evidence',
        'observation_inference_hypotheses_and_proven_cause'
    )
    Contains 'forbidden remote evidence' @($contract.remoteEvidence.forbiddenTrackedContent) @(
        'raw_logs','saves','crash_dumps','credentials','tokens','private_configuration','machine_local_junk'
    )
    Contains 'non-equivalences' @($contract.nonEquivalences) @(
        'last_marker_is_not_root_cause','stale_log_silence_is_not_negative_evidence','process_non_observation_is_not_native_crash_confirmation'
    )
}

if ($schema) {
    if ($schema.title -eq 'TbgRuntimeContextCapsule.v1') { Pass 'capsule schema' } else { Fail 'capsule schema' }
    Contains 'capsule required fields' @($schema.required) @(
        'runId','generatedUtc','repo','branch','commitSha','sprint','lane','runtimeClassification',
        'processes','handoff','failure','evidenceRefs','proofLevel','redaction','nextDecision'
    )
    if ($schema.properties.PSObject.Properties.Name -contains 'crashObservability') { Pass 'capsule crash observability' } else { Fail 'capsule crash observability' }
    if ($schema.properties.failure.properties.PSObject.Properties.Name -contains 'externalTerminalEvidenceRefs') { Pass 'capsule external terminal evidence' } else { Fail 'capsule external terminal evidence' }
    Contains 'capsule crash trace fields' @($schema.properties.crashObservability.required) @(
        'commandId','correlationId','spanId','parentSpanId','operation','startedAtUtc','completedAtUtc','terminalStatus',
        'preState','postState','expectedSignals','observedSignals','negativeEvidence','lastMarkerBoundaryOnly',
        'balancedSpan','unrelatedDoneClosedSpan','causality','reconstructable'
    )
    Contains 'capsule negative evidence fields' @($schema.properties.crashObservability.properties.negativeEvidence.items.required) @(
        'expectedSignal','observer','source','windowStartUtc','windowEndUtc','observerActive','sourceFresh','observationComplete','observed'
    )
    Contains 'capsule causality fields' @($schema.properties.crashObservability.properties.causality.required) @(
        'observation','inference','hypotheses','provenCause','rootCauseEvidenceRefs'
    )
    if (@($schema.allOf).Count -ge 2) { Pass 'capsule crash conditionals' } else { Fail 'capsule crash conditionals' }
}

Match 'AGENTS contract pointer' $agents 'runtime-context-continuity\.contract\.json'
Match 'AGENTS process protection' $agents 'process presence is context, not zombie proof'
Match 'AGENTS owner protection' $agents 'active human, foreign, or ambiguous session must not be terminated'
Match 'AGENTS remote capsule' $agents 'sanitized bounded runtime-context capsule'
Match 'AGENTS crash boundary' $agents 'last marker as a boundary rather than a cause'
Match 'AGENTS action commitment' $agents 'plan-only closeout is invalid'
Match 'launcher contract pointer' $launcher 'runtime-context-continuity\.contract\.json'
Match 'launcher PID rule' $launcher 'PID delta.*secondary'
Match 'launcher owner protection' $launcher 'active human, foreign, or ambiguous'
Match 'evidence schema pointer' $evidence 'runtime-context-capsule\.schema\.json'
Match 'evidence pre-post state' $evidence 'pre-state.*post-state'
Match 'evidence negative evidence' $evidence 'negative evidence'
Match 'evidence root cause boundary' $evidence 'last marker.*boundary.*cause'
Match 'evidence raw-log boundary' $evidence 'Raw logs.*ignored'
Match 'remote evidence path' $readme 'docs/evidence/runtime-context'
Match 'remote evidence reconstruction' $readme 'fresh agent.*reconstruct'
Match 'remote evidence boundary' $readme 'Never commit raw logs'

if ($agents) {
    $lines = @($agents -split "`r?`n").Count
    if ($lines -le 110) { Pass "AGENTS ceiling $lines/110" } else { Fail "AGENTS ceiling $lines/110" }
}

if ($manifest) {
    $expectedPaths = [ordered]@{
        runtimeContextContinuityContract = $contractPath
        runtimeContextCapsuleSchema = $schemaPath
        runtimeContextContinuityFixtures = $fixturePath
        runtimeContextContinuityValidator = 'scripts/tbg/Test-TbgRuntimeContextContinuity.ps1'
        runtimeContextRemoteEvidence = 'docs/evidence/runtime-context'
    }
    foreach ($item in $expectedPaths.GetEnumerator()) {
        if ([string]$manifest.paths.($item.Key) -eq [string]$item.Value) { Pass "manifest $($item.Key)" }
        else { Fail "manifest $($item.Key)" }
    }
}

if ($fixtures) {
    foreach ($case in @($fixtures.cases)) {
        $valid = $true
        if ($case.claimsAction -and -not $case.mutationEvidence) { $valid = $false }
        if ($case.requestedProcessMutation -in @('stop','kill') -and
            $case.runtimeClassification -notin @('active_owned','stale_or_zombie_proven')) { $valid = $false }
        if ($case.remoteEvidence -eq 'raw_log') { $valid = $false }
        if ($null -ne $case.handoffCrashContextComplete -and -not $case.handoffCrashContextComplete) { $valid = $false }

        if ($null -ne $case.crashObserved) {
            if (-not $case.preStateCaptured) { $valid = $false }
            if (-not $case.expectedSignalsDeclared) { $valid = $false }
            if (-not $case.observedSignalsRecorded) { $valid = $false }
            if (-not $case.negativeEvidenceFresh) { $valid = $false }
            if (-not $case.openSpanCorrelated) { $valid = $false }
            if (-not $case.lastMarkerBoundaryOnly) { $valid = $false }
            if (-not $case.causalitySeparated) { $valid = $false }
            if (-not $case.reconstructable) { $valid = $false }
            if ($case.crashObserved -and -not ($case.postStateCaptured -or $case.processLossBoundaryCaptured)) { $valid = $false }
            if (-not $case.crashObserved -and -not $case.postStateCaptured) { $valid = $false }
            if ($case.failureClassification -eq 'native_crash_confirmed' -and -not $case.externalCrashEvidence) { $valid = $false }
        }

        $actual = if ($valid) { 'PASS' } else { 'FAIL' }
        if ($actual -eq $case.expected) { Pass "fixture $($case.id)" } else { Fail "fixture $($case.id)" }
    }
}

# Guard the cleanup file proposed by active runtime work when it exists.
$cleanupPath = Join-Path $repoRoot 'scripts/preflight-cleanup.ps1'
if (Test-Path -LiteralPath $cleanupPath) {
    $cleanup = Get-Content -LiteralPath $cleanupPath -Raw
    $kills = $cleanup -match '\.Kill\s*\(' -or $cleanup -match 'Stop-Process'
    $gated = $cleanup -match 'runtime-context-continuity|Get-TbgRuntimeContext|active_owned|stale_or_zombie_proven'
    if ($kills -and -not $gated) { Fail 'preflight cleanup kills without runtime-context classification' }
    else { Pass 'preflight cleanup continuity gate' }
}

$result = [ordered]@{
    schema = 'tbg.runtime-context-continuity.validation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    pass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    proofLevel = 'static_test'
    proofCeiling = 'static_test'
}
$output = Join-Path $repoRoot 'artifacts/latest/runtime-context-continuity/runtime-context-continuity.result.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
[IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))

Write-Host ''
if ($failures.Count) {
    Write-Host "Runtime context continuity doctrine: FAIL ($($failures.Count))" -ForegroundColor Red
    exit 1
}
Write-Host "Runtime context continuity doctrine: PASS ($passes checks)" -ForegroundColor Green
exit 0
