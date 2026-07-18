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
    if ($contract.remoteEvidence.rawEvidencePolicy -eq 'local_ignored_only') { Pass 'raw evidence local' } else { Fail 'raw evidence local' }
    if ($contract.remoteEvidence.maxExcerptLines -le 80 -and $contract.remoteEvidence.maxCapsuleBytes -le 65536) {
        Pass 'capsule bounds'
    } else { Fail 'capsule bounds' }
    Contains 'forbidden remote evidence' @($contract.remoteEvidence.forbiddenTrackedContent) @(
        'raw_logs','saves','crash_dumps','credentials','tokens','private_configuration','machine_local_junk'
    )
}

if ($schema) {
    if ($schema.title -eq 'TbgRuntimeContextCapsule.v1') { Pass 'capsule schema' } else { Fail 'capsule schema' }
    Contains 'capsule required fields' @($schema.required) @(
        'runId','generatedUtc','repo','branch','commitSha','sprint','lane','runtimeClassification',
        'processes','handoff','failure','evidenceRefs','proofLevel','redaction','nextDecision'
    )
}

Match 'AGENTS contract pointer' $agents 'runtime-context-continuity\.contract\.json'
Match 'AGENTS process protection' $agents 'process presence is context, not zombie proof'
Match 'AGENTS owner protection' $agents 'active human, foreign, or ambiguous session must not be terminated'
Match 'AGENTS remote capsule' $agents 'sanitized bounded runtime-context capsule'
Match 'AGENTS action commitment' $agents 'plan-only closeout is invalid'
Match 'launcher contract pointer' $launcher 'runtime-context-continuity\.contract\.json'
Match 'launcher PID rule' $launcher 'PID delta.*secondary'
Match 'launcher owner protection' $launcher 'active human, foreign, or ambiguous'
Match 'evidence schema pointer' $evidence 'runtime-context-capsule\.schema\.json'
Match 'evidence raw-log boundary' $evidence 'Raw logs.*ignored'
Match 'remote evidence path' $readme 'docs/evidence/runtime-context'
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
