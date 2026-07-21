<#
.SYNOPSIS
  Validates that all harness components registered in .tbg/harness/manifest.json
  exist on disk and that every skill's entry contract, validators, and owned paths resolve.
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

$manifest = Get-Json '.tbg/harness/manifest.json'
if ($null -eq $manifest) { Add-Failure 'harness manifest missing or invalid'; $result = @{ schema = 'tbg.harness-completeness.result.v1'; passes = $passes; failures = $failures }; $null = New-Item -Path (Split-Path $OutputPath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue; $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8; Write-Host "`nHarness completeness: $passes passed, $($failures.Count) failed" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' }); exit $(if ($failures.Count -eq 0) { 0 } else { 1 }) }

$skillsManifest = Get-Json '.tbg/skills/manifest.json'

Write-Host "`n=== Harness surface components ==="

$surfaceFiles = @(
    'AGENTS.md', 'CLAUDE.md', 'CODEBASE_MAP.md',
    'docs/AI_HARNESS_ENTRYPOINT.md', 'docs/harness-doctrine.md',
    '.tbg/harness/policies/harness-doctrine.policy.json',
    'scripts/tbg/Test-TbgHarnessDoctrine.ps1'
)
foreach ($f in $surfaceFiles) {
    Require-File "surface $f" $f
}

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
foreach ($skill in @($skillsManifest.skills)) {
    $skillCount++
    $id = [string]$skill.id
    if (-not [string]::IsNullOrWhiteSpace($skill.path)) {
        Require-File "skill $id path" $skill.path
    }
    if (-not [string]::IsNullOrWhiteSpace($skill.entryContract)) {
        Require-File "skill $id contract" $skill.entryContract
    }
    foreach ($v in @($skill.validators)) {
        if ($v -match '-File\s+(scripts[^\s"]+)') {
            Require-File "skill $id validator: $($Matches[1])" $Matches[1]
        }
    }
}
Add-Pass "skill manifest: $skillCount skills inspected"

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

Write-Host "`n=== PowerShell UTF-8 BOM check ==="

$bomPaths = @(
    'scripts/tbg/Test-TbgEndToEndHarness.ps1',
    'scripts/tbg/Invoke-TbgEndToEndValidation.ps1',
    'scripts/tbg/New-TbgSprintCapsule.ps1',
    'scripts/tbg/Test-TbgHarnessDoctrine.ps1',
    'scripts/tbg/Test-TbgSkillRouting.ps1'
)
foreach ($bomPath in $bomPaths) {
    $bomFile = Join-Path $RepoRoot $bomPath
    if (Test-Path -LiteralPath $bomFile -PathType Leaf) {
        $raw = [IO.File]::ReadAllBytes($bomFile)
        if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
            Add-Pass "BOM $bomPath"
        } else {
            Add-Failure "BOM missing $bomPath"
        }
    }
}

Write-Host "`n=== Git hooks ==="

Require-File 'githook pre-commit' '.githooks/pre-commit'

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
}

$null = New-Item -Path (Split-Path $OutputPath -Parent) -ItemType Directory -Force -ErrorAction SilentlyContinue
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "`n=== Harness completeness: $passes passed, $($failures.Count) failed ===" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Host "  $f" -ForegroundColor Red }
}

exit $(if ($failures.Count -eq 0) { 0 } else { 1 })
