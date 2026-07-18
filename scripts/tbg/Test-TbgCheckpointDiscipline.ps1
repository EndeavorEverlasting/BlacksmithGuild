[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = 'artifacts/latest/checkpoint-discipline'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function RepoPath([string]$RelativePath) {
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Resolve-FixtureStatus($Case) {
    if ([bool]$Case.checkpointClaimedAsCompletion) { return 'FAIL_CHECKPOINT_OVERCLAIM' }
    if ([bool]$Case.resumedWork -and -not [bool]$Case.smallestPendingValidationFirst) {
        return 'FAIL_RESUME_SCOPE_EXPANSION'
    }

    $expansion = [bool]$Case.broadValidationStarted -or
        [bool]$Case.refactoringExpansionStarted -or
        [bool]$Case.agentOrEnvironmentSwitchPlanned
    $checkpointType = [string]$Case.checkpointType

    if ([bool]$Case.coherentTrackedChange -and $expansion -and [string]::IsNullOrWhiteSpace($checkpointType)) {
        return 'FAIL_CHECKPOINT_MISSING'
    }
    if ([bool]$Case.hasOwnedUntrackedFiles -and
        -not [string]::IsNullOrWhiteSpace($checkpointType) -and
        -not [bool]$Case.checkpointIncludesOwnedUntrackedFiles) {
        return 'FAIL_UNTRACKED_NOT_PRESERVED'
    }
    return 'PASS_CHECKPOINT_DISCIPLINE'
}

$failures = New-Object System.Collections.Generic.List[string]
$contractRel = '.tbg/workflows/checkpoint-discipline.contract.json'
$fixturesRel = '.tbg/harness/fixtures/checkpoint-discipline.fixtures.json'
$agentsRel = 'AGENTS.md'
$skillRel = '.tbg/skills/agent-skill-factoring/SKILL.md'
$docRel = 'docs/architecture/checkpointed-harness-discipline.md'

foreach ($relativePath in @($contractRel, $fixturesRel, $agentsRel, $skillRel, $docRel)) {
    if (-not (Test-Path -LiteralPath (RepoPath $relativePath) -PathType Leaf)) {
        $failures.Add("Missing checkpoint discipline surface: $relativePath") | Out-Null
    }
}

$contract = $null
$fixtures = $null
if ($failures.Count -eq 0) {
    try {
        $contract = Get-Content -LiteralPath (RepoPath $contractRel) -Raw | ConvertFrom-Json
        $fixtures = Get-Content -LiteralPath (RepoPath $fixturesRel) -Raw | ConvertFrom-Json
    }
    catch {
        $failures.Add("Checkpoint JSON parse failed: $($_.Exception.Message)") | Out-Null
    }
}

if ($null -ne $contract) {
    if ([string]$contract.schema -ne 'TbgCheckpointDisciplineContract.v1') {
        $failures.Add('Wrong checkpoint contract schema.') | Out-Null
    }
    foreach ($repository in @('EndeavorEverlasting/AgentSwitchboard', 'EndeavorEverlasting/SysAdminSuite')) {
        if (@($contract.sourceDoctrine | ForEach-Object { [string]$_.repository }) -notcontains $repository) {
            $failures.Add("Missing source doctrine provenance: $repository") | Out-Null
        }
    }
    foreach ($field in @('repo','branchOrWorktree','prOrSprint','lane','ownedScope','forbiddenScope','expectedArtifacts','validationOrder')) {
        if (@($contract.requiredDeclaration) -notcontains $field) {
            $failures.Add("Missing required declaration field: $field") | Out-Null
        }
    }
    foreach ($status in @('PASS_CHECKPOINT_DISCIPLINE','FAIL_CHECKPOINT_MISSING','FAIL_UNTRACKED_NOT_PRESERVED','FAIL_RESUME_SCOPE_EXPANSION','FAIL_CHECKPOINT_OVERCLAIM')) {
        if (@($contract.terminalStates) -notcontains $status) {
            $failures.Add("Missing terminal state: $status") | Out-Null
        }
    }
}

$agentsText = Get-Content -LiteralPath (RepoPath $agentsRel) -Raw
$agentLineCount = @($agentsText -split "`r?`n").Count
if ($agentLineCount -gt 110) {
    $failures.Add("AGENTS.md has $agentLineCount lines; ceiling is 110.") | Out-Null
}
foreach ($needle in @(
    'any user-specified validation order',
    'may route work, but it does not grant destructive',
    'Checkpoint coherent tracked progress before broad validation',
    'Include owned untracked files; a checkpoint proves preservation only.'
)) {
    if (-not $agentsText.Contains($needle)) { $failures.Add("AGENTS.md missing: $needle") | Out-Null }
}

$skillText = Get-Content -LiteralPath (RepoPath $skillRel) -Raw
foreach ($needle in @(
    '## Planning a refactoring',
    'every owned untracked file',
    'smallest failing or pending validation first',
    'A checkpoint proves preservation only.'
)) {
    if (-not $skillText.Contains($needle)) { $failures.Add("Skill missing: $needle") | Out-Null }
}

$docText = Get-Content -LiteralPath (RepoPath $docRel) -Raw
foreach ($needle in @(
    'preservation checkpoint',
    'A plain `git diff` patch is incomplete whenever owned untracked files exist.',
    'BlacksmithGuild retains its own runtime, save-safety, evidence, and proof authority.'
)) {
    if (-not $docText.Contains($needle)) { $failures.Add("Architecture doc missing: $needle") | Out-Null }
}

$fixtureResults = @()
if ($null -ne $fixtures) {
    if ([string]$fixtures.schema -ne 'TbgCheckpointDisciplineFixtures.v1') {
        $failures.Add('Wrong checkpoint fixture schema.') | Out-Null
    }
    if (@($fixtures.cases).Count -lt 7) {
        $failures.Add('At least seven checkpoint fixtures are required.') | Out-Null
    }
    foreach ($case in @($fixtures.cases)) {
        $actual = Resolve-FixtureStatus $case
        $expected = [string]$case.expectedStatus
        $passed = $actual -eq $expected
        $fixtureResults += [ordered]@{ name = [string]$case.name; expected = $expected; actual = $actual; passed = $passed }
        if (-not $passed) {
            $failures.Add("Fixture '$($case.name)' expected '$expected' but resolved '$actual'.") | Out-Null
        }
    }
}

$outputPath = if ([IO.Path]::IsPathRooted($OutputRoot)) { $OutputRoot } else { RepoPath $OutputRoot }
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$status = if ($failures.Count -eq 0) { 'PASS_CHECKPOINT_DISCIPLINE' } else { 'FAIL_CHECKPOINT_DISCIPLINE' }
$result = [ordered]@{
    schema = 'TbgCheckpointDisciplineResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    agentLineCount = $agentLineCount
    fixtureCount = @($fixtureResults).Count
    fixtures = @($fixtureResults)
    failures = @($failures)
    proofLevel = 'static test'
    forbiddenClaims = @('No build, launcher, command ACK, gameplay, deployment, or live runtime proof is established.')
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'checkpoint-discipline.result.json') -Encoding UTF8

$report = @('# TBG Checkpoint Discipline Validation','',"Status: **$status**",'',"- AGENTS.md lines: $agentLineCount","- Fixtures: $(@($fixtureResults).Count)","- Failures: $($failures.Count)",'','Static validation only; no runtime or deployment proof is established.')
$report -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'checkpoint-discipline.report.md') -Encoding UTF8

Write-Host "Checkpoint discipline validation: $status"
Write-Host "Fixtures: $(@($fixtureResults).Count); AGENTS.md lines: $agentLineCount; failures: $($failures.Count)."
if ($failures.Count -gt 0) { exit 1 }
