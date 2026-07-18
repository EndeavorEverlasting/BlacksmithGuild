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

function Resolve-TbgPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Add-TbgFailure {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[string]]$Failures,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $Failures.Add($Message) | Out-Null
}

function Read-TbgJson {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Resolve-TbgPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required JSON file is missing: $RelativePath"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Resolve-TbgFixtureStatus {
    param([Parameter(Mandatory = $true)]$Fixture)

    if ([bool]$Fixture.checkpointClaimedAsCompletion) {
        return 'FAIL_CHECKPOINT_OVERCLAIM'
    }

    if ([bool]$Fixture.resumedWork -and -not [bool]$Fixture.smallestPendingValidationFirst) {
        return 'FAIL_RESUME_SCOPE_EXPANSION'
    }

    $expansionStarted = [bool]$Fixture.broadValidationStarted -or
        [bool]$Fixture.refactoringExpansionStarted -or
        [bool]$Fixture.agentOrEnvironmentSwitchPlanned
    $checkpointType = [string]$Fixture.checkpointType

    if ([bool]$Fixture.coherentTrackedChange -and $expansionStarted -and [string]::IsNullOrWhiteSpace($checkpointType)) {
        return 'FAIL_CHECKPOINT_MISSING'
    }

    if ([bool]$Fixture.hasOwnedUntrackedFiles -and
        -not [string]::IsNullOrWhiteSpace($checkpointType) -and
        -not [bool]$Fixture.checkpointIncludesOwnedUntrackedFiles) {
        return 'FAIL_UNTRACKED_NOT_PRESERVED'
    }

    return 'PASS_CHECKPOINT_DISCIPLINE'
}

$failures = New-Object System.Collections.Generic.List[string]
$contractRelative = '.tbg/workflows/checkpoint-discipline.contract.json'
$fixturesRelative = '.tbg/harness/fixtures/checkpoint-discipline.fixtures.json'
$agentsRelative = 'AGENTS.md'
$skillRelative = '.tbg/skills/agent-skill-factoring/SKILL.md'
$docRelative = 'docs/architecture/checkpointed-harness-discipline.md'
$requiredFiles = @($contractRelative, $fixturesRelative, $agentsRelative, $skillRelative, $docRelative)

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Resolve-TbgPath $relativePath) -PathType Leaf)) {
        Add-TbgFailure -Failures $failures -Message "Required checkpoint discipline surface is missing: $relativePath"
    }
}

$contract = $null
$fixtures = $null
if ($failures.Count -eq 0) {
    try {
        $contract = Read-TbgJson $contractRelative
        $fixtures = Read-TbgJson $fixturesRelative
    }
    catch {
        Add-TbgFailure -Failures $failures -Message $_.Exception.Message
    }
}

if ($null -ne $contract) {
    if ([string]$contract.schema -ne 'TbgCheckpointDisciplineContract.v1') {
        Add-TbgFailure -Failures $failures -Message 'Checkpoint contract schema is not TbgCheckpointDisciplineContract.v1.'
    }
    if ([string]$contract.validator -ne 'scripts/tbg/Test-TbgCheckpointDiscipline.ps1') {
        Add-TbgFailure -Failures $failures -Message 'Checkpoint contract does not name its deterministic validator.'
    }
    if ([string]$contract.fixtures -ne $fixturesRelative) {
        Add-TbgFailure -Failures $failures -Message 'Checkpoint contract does not name the canonical fixture path.'
    }

    $requiredDeclaration = @(
        'repo', 'branchOrWorktree', 'prOrSprint', 'lane', 'ownedScope',
        'forbiddenScope', 'expectedArtifacts', 'validationOrder'
    )
    foreach ($field in $requiredDeclaration) {
        if (@($contract.requiredDeclaration) -notcontains $field) {
            Add-TbgFailure -Failures $failures -Message "Checkpoint contract is missing required declaration field '$field'."
        }
    }

    foreach ($repository in @('EndeavorEverlasting/AgentSwitchboard', 'EndeavorEverlasting/SysAdminSuite')) {
        if (@($contract.sourceDoctrine | ForEach-Object { [string]$_.repository }) -notcontains $repository) {
            Add-TbgFailure -Failures $failures -Message "Checkpoint contract does not retain source doctrine provenance for '$repository'."
        }
    }

    foreach ($status in @(
        'PASS_CHECKPOINT_DISCIPLINE',
        'FAIL_CHECKPOINT_MISSING',
        'FAIL_UNTRACKED_NOT_PRESERVED',
        'FAIL_RESUME_SCOPE_EXPANSION',
        'FAIL_CHECKPOINT_OVERCLAIM'
    )) {
        if (@($contract.terminalStates) -notcontains $status) {
            Add-TbgFailure -Failures $failures -Message "Checkpoint contract is missing terminal state '$status'."
        }
    }
}

$agentsText = ''
$skillText = ''
$docText = ''
if (Test-Path -LiteralPath (Resolve-TbgPath $agentsRelative)) {
    $agentsText = Get-Content -LiteralPath (Resolve-TbgPath $agentsRelative) -Raw
    $agentLineCount = @($agentsText -split "`r?`n").Count
    if ($agentLineCount -gt 110) {
        Add-TbgFailure -Failures $failures -Message "AGENTS.md has $agentLineCount lines; the compact root ceiling is 110."
    }
    foreach ($needle in @(
        'Checkpoint coherent tracked progress before broad validation',
        'Include owned untracked files; a checkpoint proves preservation only.',
        'may route work, but it does not grant destructive',
        'any user-specified validation order'
    )) {
        if (-not $agentsText.Contains($needle)) {
            Add-TbgFailure -Failures $failures -Message "AGENTS.md is missing checkpoint doctrine: $needle"
        }
    }
}
else {
    $agentLineCount = 0
}

if (Test-Path -LiteralPath (Resolve-TbgPath $skillRelative)) {
    $skillText = Get-Content -LiteralPath (Resolve-TbgPath $skillRelative) -Raw
    foreach ($needle in @(
        '## Planning a refactoring',
        'every owned untracked file',
        'smallest failing or pending validation first',
        'A checkpoint proves preservation only.'
    )) {
        if (-not $skillText.Contains($needle)) {
            Add-TbgFailure -Failures $failures -Message "The agent-skill-factoring skill is missing refactoring doctrine: $needle"
        }
    }
}

if (Test-Path -LiteralPath (Resolve-TbgPath $docRelative)) {
    $docText = Get-Content -LiteralPath (Resolve-TbgPath $docRelative) -Raw
    foreach ($needle in @(
        'request',
        'preservation checkpoint',
        'A plain `git diff` patch is incomplete whenever owned untracked files exist.',
        'BlacksmithGuild retains its own runtime, save-safety, evidence, and proof authority.'
    )) {
        if (-not $docText.Contains($needle)) {
            Add-TbgFailure -Failures $failures -Message "The checkpoint architecture document is missing: $needle"
        }
    }
}

$fixtureResults = @()
if ($null -ne $fixtures) {
    if ([string]$fixtures.schema -ne 'TbgCheckpointDisciplineFixtures.v1') {
        Add-TbgFailure -Failures $failures -Message 'Checkpoint fixture schema is not TbgCheckpointDisciplineFixtures.v1.'
    }
    if (@($fixtures.cases).Count -lt 7) {
        Add-TbgFailure -Failures $failures -Message 'Checkpoint fixtures must contain at least seven positive and negative cases.'
    }

    foreach ($fixture in @($fixtures.cases)) {
        $actualStatus = Resolve-TbgFixtureStatus -Fixture $fixture
        $expectedStatus = [string]$fixture.expectedStatus
        $fixtureResults += [ordered]@{
            name = [string]$fixture.name
            expectedStatus = $expectedStatus
            actualStatus = $actualStatus
            passed = ($actualStatus -eq $expectedStatus)
        }
        if ($actualStatus -ne $expectedStatus) {
            Add-TbgFailure -Failures $failures -Message "Fixture '$($fixture.name)' expected '$expectedStatus' but resolved '$actualStatus'."
        }
    }
}

$outputPath = if ([IO.Path]::IsPathRooted($OutputRoot)) {
    [IO.Path]::GetFullPath($OutputRoot)
}
else {
    Resolve-TbgPath $OutputRoot
}
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$status = if ($failures.Count -eq 0) { 'PASS_CHECKPOINT_DISCIPLINE' } else { 'FAIL_CHECKPOINT_DISCIPLINE' }
$result = [ordered]@{
    schema = 'TbgCheckpointDisciplineResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    contractPath = $contractRelative
    fixturesPath = $fixturesRelative
    agentLineCount = $agentLineCount
    fixtureCount = @($fixtureResults).Count
    fixtures = @($fixtureResults)
    failures = @($failures)
    proofLevel = 'static test'
    allowedClaims = @(
        'The checkpoint and refactoring doctrine is present in root, skill, contract, documentation, and fixtures.',
        'The negative untracked-file and interrupted-resume cases are deterministically classified.'
    )
    forbiddenClaims = @(
        'No build, launcher, command ACK, gameplay behavior, deployment, or live runtime proof is established.'
    )
}
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outputPath 'checkpoint-discipline.result.json') -Encoding UTF8

$report = @(
    '# TBG Checkpoint Discipline Validation',
    '',
    "Status: **$status**",
    '',
    "- Root AGENTS.md lines: $agentLineCount",
    "- Fixture cases: $(@($fixtureResults).Count)",
    "- Failures: $($failures.Count)",
    '- Proof level: static test',
    ''
)
if ($failures.Count -gt 0) {
    $report += '## Failures'
    $report += ''
    foreach ($failure in $failures) {
        $report += "- $failure"
    }
    $report += ''
}
$report += 'This validator does not prove build, launcher, command acknowledgement, gameplay behavior, deployment, or live runtime behavior.'
$report -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'checkpoint-discipline.report.md') -Encoding UTF8

Write-Host "Checkpoint discipline validation: $status"
Write-Host "Fixtures: $(@($fixtureResults).Count); AGENTS.md lines: $agentLineCount; failures: $($failures.Count)."

if ($failures.Count -gt 0) {
    exit 1
}
