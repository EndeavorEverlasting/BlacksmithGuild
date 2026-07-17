[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = 'artifacts/latest/skill-routing'
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $callerDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $RepoRoot = (Resolve-Path (Join-Path $callerDir '..\..')).Path
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-TbgIssue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$List,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $List.Add($Message)
}

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Test-TbgNonEmptyCollection {
    param($Value)
    return $null -ne $Value -and @($Value).Count -gt 0
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$manifestRelative = '.tbg/skills/manifest.json'
$schemaRelative = '.tbg/harness/schemas/skill-manifest.schema.json'
$agentsRelative = 'AGENTS.md'
$manifestPath = Resolve-TbgRepoPath $manifestRelative
$schemaPath = Resolve-TbgRepoPath $schemaRelative
$agentsPath = Resolve-TbgRepoPath $agentsRelative

foreach ($requiredPath in @($manifestPath, $schemaPath, $agentsPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Add-TbgIssue -List $errors -Message "The required routing file '$requiredPath' is missing."
    }
}

$manifest = $null
$schema = $null
if ($errors.Count -eq 0) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-TbgIssue -List $errors -Message "The skill manifest or its schema could not be parsed as JSON: $($_.Exception.Message)"
    }
}

$allowedProof = @(
    'contract', 'harness', 'windows watcher harness', 'static test', 'build',
    'launcher', 'command ACK', 'behavior observed', 'live runtime'
)
$allowedRisk = @(
    'static', 'local_read_write', 'external_read_only',
    'runtime_read', 'runtime_write', 'destructive'
)
$requiredSkillSections = @(
    '## Use when',
    '## Do not use when',
    '## Read first',
    '## Owned scope',
    '## Forbidden scope',
    '## Done gate'
)
$requiredSkillProperties = @(
    'id', 'path', 'distribution', 'lane', 'match', 'requiresSkills',
    'composesWith', 'exclusiveWith', 'entryContract', 'primaryAuthorities',
    'validators', 'expectedArtifacts', 'proofCeiling', 'riskClass',
    'freshnessSource', 'ownedPaths', 'forbiddenPaths'
)

$skillIds = @()
if ($null -ne $manifest) {
    if ($manifest.schema -ne 'tbg.skills.manifest.v2') {
        Add-TbgIssue -List $errors -Message "The manifest schema must be 'tbg.skills.manifest.v2'."
    }
    if ($manifest.repo -ne 'EndeavorEverlasting/BlacksmithGuild') {
        Add-TbgIssue -List $errors -Message 'The manifest repo identity does not match BlacksmithGuild.'
    }
    if (-not (Test-TbgNonEmptyCollection $manifest.currentStateSources)) {
        Add-TbgIssue -List $errors -Message 'The manifest must declare currentStateSources.'
    }
    if (-not (Test-TbgNonEmptyCollection $manifest.skills)) {
        Add-TbgIssue -List $errors -Message 'The manifest must register at least one skill.'
    }

    foreach ($skill in @($manifest.skills)) {
        foreach ($property in $requiredSkillProperties) {
            if ($skill.PSObject.Properties.Name -notcontains $property) {
                Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' is missing required property '$property'."
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$skill.id)) {
            Add-TbgIssue -List $errors -Message 'A skill has an empty id.'
            continue
        }

        $skillIds += [string]$skill.id
        $skillPath = Resolve-TbgRepoPath ([string]$skill.path)
        $entryContractPath = Resolve-TbgRepoPath ([string]$skill.entryContract)

        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' points to missing file '$($skill.path)'."
        }
        else {
            $skillText = Get-Content -LiteralPath $skillPath -Raw
            foreach ($section in $requiredSkillSections) {
                if ($skillText -notmatch [regex]::Escape($section)) {
                    Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' is missing section '$section'."
                }
            }
            if ($skillText -match 'post-pr41-repo-hygiene-map\.md') {
                Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' still routes through the superseded post-PR41 floor snapshot."
            }
        }

        if (-not (Test-Path -LiteralPath $entryContractPath -PathType Leaf)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' points to missing entry contract '$($skill.entryContract)'."
        }

        foreach ($authority in @($skill.primaryAuthorities)) {
            if ($authority -match '[*?]') {
                continue
            }
            $authorityPath = Resolve-TbgRepoPath ([string]$authority)
            if (-not (Test-Path -LiteralPath $authorityPath)) {
                Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' points to missing authority '$authority'."
            }
        }

        if (-not (Test-TbgNonEmptyCollection $skill.match.intents)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has no intent match signals."
        }
        if (-not (Test-TbgNonEmptyCollection $skill.validators)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has no validators."
        }
        if (-not (Test-TbgNonEmptyCollection $skill.expectedArtifacts)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has no expected artifacts."
        }
        if (-not (Test-TbgNonEmptyCollection $skill.ownedPaths)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has no owned paths."
        }
        if (-not (Test-TbgNonEmptyCollection $skill.forbiddenPaths)) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has no forbidden paths."
        }
        if ($allowedProof -notcontains [string]$skill.proofCeiling) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has unsupported proof ceiling '$($skill.proofCeiling)'."
        }
        if ($allowedRisk -notcontains [string]$skill.riskClass) {
            Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' has unsupported risk class '$($skill.riskClass)'."
        }
    }

    $duplicates = @($skillIds | Group-Object | Where-Object Count -gt 1)
    foreach ($duplicate in $duplicates) {
        Add-TbgIssue -List $errors -Message "Skill id '$($duplicate.Name)' is registered more than once."
    }

    foreach ($skill in @($manifest.skills)) {
        $dependencies = @($skill.requiresSkills) + @($skill.composesWith) + @($skill.exclusiveWith)
        foreach ($dependency in $dependencies) {
            if ($skillIds -notcontains [string]$dependency) {
                Add-TbgIssue -List $errors -Message "Skill '$($skill.id)' references unregistered skill '$dependency'."
            }
        }
    }

    $manifestText = Get-Content -LiteralPath $manifestPath -Raw
    if ($manifestText -match 'post-pr41-repo-hygiene-map\.md') {
        Add-TbgIssue -List $errors -Message 'The manifest still routes through the superseded post-PR41 floor snapshot.'
    }
}

if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
    $agentText = Get-Content -LiteralPath $agentsPath -Raw
    $agentLineCount = @($agentText -split "`r?`n").Count
    if ($agentLineCount -gt 110) {
        Add-TbgIssue -List $errors -Message "AGENTS.md has $agentLineCount lines; the compact root ceiling is 110."
    }
    if ($agentText -match 'Do not merge PR #') {
        Add-TbgIssue -List $errors -Message 'AGENTS.md contains a mutable PR-specific merge restriction.'
    }
    if ($agentText -match '## Current strategic target') {
        Add-TbgIssue -List $errors -Message 'AGENTS.md contains the mutable current strategic target.'
    }
    if ($agentText -notmatch '## Lane router') {
        Add-TbgIssue -List $errors -Message 'AGENTS.md does not contain the concise lane router.'
    }
    if ($agentText -notmatch 'artifacts/latest/tbg-chat-packet\.json') {
        Add-TbgIssue -List $errors -Message 'AGENTS.md does not point to the current chat packet.'
    }
}
else {
    $agentLineCount = 0
}

$outputPath = if ([IO.Path]::IsPathRooted($OutputRoot)) { [IO.Path]::GetFullPath($OutputRoot) } else { Resolve-TbgRepoPath $OutputRoot }
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$status = if ($errors.Count -eq 0) { 'PASS_skill_router_valid' } else { 'FAIL_skill_router_invalid' }
$result = [ordered]@{
    schema = 'TbgSkillRoutingResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    manifestPath = $manifestRelative
    schemaPath = $schemaRelative
    skillCount = @($skillIds).Count
    agentLineCount = $agentLineCount
    errors = @($errors)
    warnings = @($warnings)
    proofLevel = 'static test'
    allowedClaims = @(
        'The skill manifest parses and satisfies the repo routing contract.',
        'Registered skill, contract, and authority paths exist.',
        'The root agent contract remains within the compact line ceiling.'
    )
    forbiddenClaims = @(
        'No build, launcher, command ACK, behavior, movement, trade, or live runtime proof is established.'
    )
}
$resultJson = $result | ConvertTo-Json -Depth 10
$resultJson | Set-Content -LiteralPath (Join-Path $outputPath 'skill-routing.result.json') -Encoding UTF8

$reportLines = @(
    '# TBG Skill Routing Validation',
    '',
    "The skill routing validator finished with status **$status**.",
    '',
    "- The manifest registered $(@($skillIds).Count) skills.",
    "- The root AGENTS.md file contains $agentLineCount lines.",
    "- The validator found $($errors.Count) errors and $($warnings.Count) warnings.",
    '- The highest proof level reached is static test proof.',
    ''
)
if ($errors.Count -gt 0) {
    $reportLines += '## Errors'
    $reportLines += ''
    foreach ($issue in $errors) {
        $reportLines += "- $issue"
    }
    $reportLines += ''
}
$reportLines += 'The validator does not establish build, launcher, command ACK, behavior, movement, trade, or live runtime proof.'
$reportLines -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'skill-routing.report.md') -Encoding UTF8

Write-Host "Skill routing validation: $status"
Write-Host "Skills: $(@($skillIds).Count); AGENTS.md lines: $agentLineCount; errors: $($errors.Count)."

if ($errors.Count -gt 0) {
    exit 1
}
