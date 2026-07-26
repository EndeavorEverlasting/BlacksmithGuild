<#
.SYNOPSIS
  Validates that all harness components registered in .tbg/harness/manifest.json
  exist on disk and that every skill's entry contract, validators, and owned paths resolve.
  Also enforces the weak-agent-safe live-runtime proof admission and save compatibility bundles.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputPath = 'artifacts/latest/harness-completeness/harness-completeness.result.json'
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
function Get-Json([string]$RelativePath) {
    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { return $null }
}
function Require-Path([string]$Label, [string]$RelativePath) {
    $full = Join-Path $RepoRoot $RelativePath
    if (Test-Path -LiteralPath $full) { Add-Pass $Label }
    else { Add-Failure "${Label}: missing $RelativePath" }
}
function Require-File([string]$Label, [string]$RelativePath) {
    $full = Join-Path $RepoRoot $RelativePath
    if (Test-Path -LiteralPath $full -PathType Leaf) { Add-Pass $Label }
    else { Add-Failure "${Label}: file not found $RelativePath" }
}
function Require-Text([string]$Label, [string]$RelativePath, [string]$Needle) {
    $full = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Add-Failure "${Label}: file not found $RelativePath"
        return
    }
    $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8
    if ($text.Contains($Needle)) { Add-Pass $Label }
    else { Add-Failure "${Label}: missing '$Needle' in $RelativePath" }
}

$manifest = Get-Json '.tbg/harness/manifest.json'
if ($null -eq $manifest) {
    Add-Failure 'harness manifest missing or invalid'
    $result = @{ schema = 'tbg.harness-completeness.result.v1'; passes = $passes; failures = $failures }
    $null = New-Item -Path (Split-Path $OutputPath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host "`nHarness completeness: $passes passed, $($failures.Count) failed" -ForegroundColor Red
    exit 1
}

$skillsManifest = Get-Json '.tbg/skills/manifest.json'

Write-Host "`n=== Harness surface components ==="
$surfaceFiles = @(
    'AGENTS.md', 'CLAUDE.md', 'CODEBASE_MAP.md',
    'docs/AI_HARNESS_ENTRYPOINT.md', 'docs/harness-doctrine.md',
    '.tbg/harness/policies/harness-doctrine.policy.json',
    'scripts/tbg/Test-TbgHarnessDoctrine.ps1'
)
foreach ($f in $surfaceFiles) { Require-File "surface $f" $f }

Write-Host "`n=== Manifest path registry ==="
$requiredPaths = @(
    'codebaseMap', 'aiHarnessEntrypoint', 'generatedOutputPolicy',
    'skillsManifest', 'harnessDoctrine', 'harnessDoctrinePolicy',
    'harnessDoctrineValidator', 'endToEndProfiles', 'endToEndContract',
    'endToEndEntrypoint', 'sprintCapsuleContract', 'sprintCapsuleSchema',
    'sprintCapsuleGenerator', 'consumerHandoffRegistry',
    'runtimeContextContinuityContract', 'runtimeContextCapsuleSchema',
    'artifactEngineContract', 'artifactEngineRegistry',
    'windowIdentityRegistry', 'windowIntelligencePolicy', 'windowIntelligenceContract',
    'gameCompatibilityRegistry', 'gameCompatibilityContract',
    'saveCompatibilityRegistry', 'saveCompatibilityContract', 'saveCompatibilityCommand',
    'saveCompatibilityEntrypoint', 'saveCompatibilityValidator',
    'saveCompatibilityArtifactRegistry', 'saveCompatibilityFixtures',
    'saveCompatibilityOperatorReport',
    'stateEnvelopeContract', 'stateEnvelopeValidator',
    'skillRoutingValidator'
)
foreach ($key in $requiredPaths) {
    if ($null -eq $manifest.paths.$key) {
        Add-Failure "manifest.paths.$key missing"
        continue
    }
    Require-File "manifest.$key" $manifest.paths.$key
}

Write-Host "`n=== Skill entry contracts and validators ==="
$skillCount = 0
if ($skillsManifest) {
    foreach ($skill in @($skillsManifest.skills)) {
        $skillCount++
        $id = [string]$skill.id
        if (-not [string]::IsNullOrWhiteSpace($skill.path)) { Require-File "skill $id path" $skill.path }
        if (-not [string]::IsNullOrWhiteSpace($skill.entryContract)) { Require-File "skill $id contract" $skill.entryContract }
        foreach ($v in @($skill.validators)) {
            if ($v -match '-File\s+(scripts[^\s"]+)') { Require-File "skill $id validator: $($Matches[1])" $Matches[1] }
        }
    }
    Add-Pass "skill manifest: $skillCount skills inspected"
} else {
    Add-Failure 'skills manifest missing or invalid'
}

Write-Host "`n=== Workflow contract inventory ==="
$workflowDir = Join-Path $RepoRoot '.tbg/workflows'
if (Test-Path -LiteralPath $workflowDir) {
    $wfCount = 0
    foreach ($wf in Get-ChildItem -LiteralPath $workflowDir -Filter '*.contract.json') {
        $wfCount++
        $rawText = Get-Content -LiteralPath $wf.FullName -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($rawText)) {
            Add-Failure "workflow $($wf.Name) empty"
            continue
        }
        try {
            $content = $rawText | ConvertFrom-Json -ErrorAction Stop
            $wfId = if ($content.id) { [string]$content.id } elseif ($content.workflow) { [string]$content.workflow } elseif ($content.schema) { [string]$content.schema } else { $wf.BaseName }
        } catch {
            $wfId = "$($wf.BaseName) (non-standard JSON)"
        }
        Add-Pass "workflow $wfId"
    }
    Add-Pass "workflow directory: $wfCount contracts"
} else {
    Add-Failure 'workflow directory missing'
}

Write-Host "`n=== Live runtime proof admission bundle ==="
$liveProofFiles = @(
    '.tbg/workflows/live-runtime-proof-admission.contract.json',
    '.tbg/harness/live-runtime-proof-artifacts.registry.json',
    '.tbg/harness/fixtures/live-runtime-proof-admission.fixtures.json',
    '.tbg/harness/test-catalog.d/core/live-runtime-proof-admission.test.json',
    '.tbg/skills/runtime-evidence-certification/SKILL.md',
    'scripts/tbg/Test-TbgLiveRuntimeProofAdmission.ps1',
    'docs/operator/live-runtime-proof-admission.md',
    '.github/workflows/live-runtime-proof-admission.yml'
)
foreach ($f in $liveProofFiles) { Require-File "live proof $f" $f }
Require-Text 'codebase map routes live proof admission' 'CODEBASE_MAP.md' '## Live runtime proof admission'
Require-Text 'runtime skill reads live proof contract' '.tbg/skills/runtime-evidence-certification/SKILL.md' '.tbg/workflows/live-runtime-proof-admission.contract.json'
Require-Text 'operator report forbids proof promotion' 'docs/operator/live-runtime-proof-admission.md' 'Agent prose cannot'

$liveContract = Get-Json '.tbg/workflows/live-runtime-proof-admission.contract.json'
if ($liveContract) {
    if ($liveContract.modes.live_fresh_launch.rejectSkipLaunch -eq $true) { Add-Pass 'live proof contract rejects SkipLaunch' }
    else { Add-Failure 'live proof contract does not reject SkipLaunch' }
    if (@($liveContract.terminalStates) -contains 'PASS_LIVE_RUNTIME') { Add-Pass 'live proof contract has PASS_LIVE_RUNTIME' }
    else { Add-Failure 'live proof contract missing PASS_LIVE_RUNTIME' }
} else {
    Add-Failure 'live proof contract invalid JSON'
}

Write-Host "`n=== Save compatibility bundle ==="
$saveCompatibilityFiles = @(
    '.tbg/state/save-compatibility.registry.json',
    '.tbg/workflows/save-compatibility-classification.contract.json',
    '.tbg/harness/save-compatibility-artifacts.registry.json',
    '.tbg/harness/fixtures/save-compatibility.fixtures.json',
    '.tbg/harness/test-catalog.d/core/save-compatibility.test.json',
    'scripts/tbg/Invoke-TbgSaveCompatibility.ps1',
    'scripts/tbg/Test-TbgSaveCompatibility.ps1',
    'docs/operator/save-compatibility.md',
    '.github/workflows/save-compatibility-harness.yml',
    'ForgeSaveCompatibility.cmd'
)
foreach ($f in $saveCompatibilityFiles) { Require-File "save compatibility $f" $f }
Require-Text 'codebase map routes save compatibility' 'CODEBASE_MAP.md' '## Save compatibility classification'
Require-Text 'harness maturity defines save compatibility split' '.tbg/skills/harness-maturity/SKILL.md' '### Save compatibility split'
Require-Text 'pre-push runs save compatibility' '.githooks/pre-push' 'Test-TbgSaveCompatibility.ps1'

$saveContract = Get-Json '.tbg/workflows/save-compatibility-classification.contract.json'
if ($saveContract) {
    if ([string]$saveContract.proofCeiling -eq 'real-file read-only parsing') { Add-Pass 'save compatibility proof ceiling is read-only parsing' }
    else { Add-Failure 'save compatibility proof ceiling drifted' }
    if ($saveContract.mutatesSaves -eq $false) { Add-Pass 'save compatibility contract forbids save mutation' }
    else { Add-Failure 'save compatibility contract allows save mutation' }
    if (@($saveContract.terminalStates) -contains 'BLOCKED_SAVE_NEWER_THAN_GAME') { Add-Pass 'save compatibility contract blocks newer saves' }
    else { Add-Failure 'save compatibility contract missing newer-save block' }
    if ([string]$saveContract.operatorEntry -eq 'ForgeSaveCompatibility.cmd') { Add-Pass 'save compatibility operator entry is canonical CMD' }
    else { Add-Failure 'save compatibility operator entry is not ForgeSaveCompatibility.cmd' }
} else {
    Add-Failure 'save compatibility contract invalid JSON'
}

$saveFixtures = Get-Json '.tbg/harness/fixtures/save-compatibility.fixtures.json'
if ($saveFixtures) {
    $autosaveFixture = @($saveFixtures.cases | Where-Object { $_.leafName -eq 'saveauto1.sav' } | Select-Object -First 1)
    if ($autosaveFixture.Count -eq 1 -and [string]$autosaveFixture[0].expectedTerminalState -eq 'BLOCKED_SAVE_NEWER_THAN_GAME') { Add-Pass 'save compatibility fixture reproduces newer saveauto1 block' }
    else { Add-Failure 'save compatibility fixture does not reproduce newer saveauto1 block' }
    if ([string]$saveFixtures.operatorObservedReference.gameVersion -eq '1.4.6.115628') { Add-Pass 'save compatibility fixture records operator-observed game version reference' }
    else { Add-Failure 'save compatibility operator reference game version drifted' }
} else {
    Add-Failure 'save compatibility fixtures invalid JSON'
}

Write-Host "`n=== PowerShell UTF-8 BOM check ==="
$bomPaths = @(
    'scripts/tbg/Test-TbgEndToEndHarness.ps1',
    'scripts/tbg/Invoke-TbgEndToEndValidation.ps1',
    'scripts/tbg/New-TbgSprintCapsule.ps1',
    'scripts/tbg/Test-TbgHarnessDoctrine.ps1',
    'scripts/tbg/Test-TbgSkillRouting.ps1',
    'scripts/tbg/Test-TbgLiveRuntimeProofAdmission.ps1',
    'scripts/tbg/Invoke-TbgSaveCompatibility.ps1',
    'scripts/tbg/Test-TbgSaveCompatibility.ps1'
)
foreach ($bomPath in $bomPaths) {
    $bomFile = Join-Path $RepoRoot $bomPath
    if (Test-Path -LiteralPath $bomFile -PathType Leaf) {
        $raw = [IO.File]::ReadAllBytes($bomFile)
        if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) { Add-Pass "BOM $bomPath" }
        else { Add-Failure "BOM missing $bomPath" }
    }
}

Write-Host "`n=== Git hooks ==="
Require-File 'githook pre-commit' '.githooks/pre-commit'
Require-File 'githook pre-push' '.githooks/pre-push'
Require-Text 'pre-push runs live proof admission' '.githooks/pre-push' 'Test-TbgLiveRuntimeProofAdmission.ps1'
Require-Text 'pre-push runs save compatibility validator' '.githooks/pre-push' 'Test-TbgSaveCompatibility.ps1'
Require-Text 'pre-push runs completeness' '.githooks/pre-push' 'Test-TbgHarnessCompleteness.ps1'

Write-Host "`n=== E2E contract files ==="
$e2eFiles = @(
    '.tbg/harness/e2e/profiles.json',
    '.tbg/harness/e2e-artifact-types.registry.json',
    '.tbg/harness/api/operations.json',
    '.tbg/workflows/end-to-end-validation.contract.json',
    '.tbg/workflows/tbg-sprint-capsule.contract.json'
)
foreach ($f in $e2eFiles) { Require-File "e2e $f" $f }

Write-Host "`n=== CI/CD workflows ==="
$githubWorkflows = Join-Path $RepoRoot '.github/workflows'
if (Test-Path -LiteralPath $githubWorkflows) {
    $ciCount = 0
    foreach ($ci in Get-ChildItem -LiteralPath $githubWorkflows -Filter '*.yml') { $ciCount++ }
    Add-Pass "CI/CD: $ciCount GitHub workflows"
} else {
    Add-Failure 'GitHub workflows directory missing'
}

$result = @{
    schema = 'tbg.harness-completeness.result.v1'
    timestamp = [DateTime]::UtcNow.ToString('o')
    repo = [string]$manifest.repo.remote
    passes = $passes
    failures = $failures
    skillsInspected = $skillCount
    liveRuntimeProofAdmission = [ordered]@{
        contract = '.tbg/workflows/live-runtime-proof-admission.contract.json'
        validator = 'scripts/tbg/Test-TbgLiveRuntimeProofAdmission.ps1'
        artifactRegistry = '.tbg/harness/live-runtime-proof-artifacts.registry.json'
        operatorReport = 'docs/operator/live-runtime-proof-admission.md'
        prePushHook = '.githooks/pre-push'
    }
    saveCompatibility = [ordered]@{
        contract = '.tbg/workflows/save-compatibility-classification.contract.json'
        registry = '.tbg/state/save-compatibility.registry.json'
        validator = 'scripts/tbg/Test-TbgSaveCompatibility.ps1'
        entrypoint = 'scripts/tbg/Invoke-TbgSaveCompatibility.ps1'
        operatorEntry = 'ForgeSaveCompatibility.cmd'
        artifactRegistry = '.tbg/harness/save-compatibility-artifacts.registry.json'
        operatorReport = 'docs/operator/save-compatibility.md'
        proofCeiling = 'real-file read-only parsing'
    }
}

$null = New-Item -Path (Split-Path $OutputPath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "`n=== Harness completeness: $passes passed, $($failures.Count) failed ===" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "  $f" -ForegroundColor Red }
}

exit $(if ($failures.Count -eq 0) { 0 } else { 1 })
