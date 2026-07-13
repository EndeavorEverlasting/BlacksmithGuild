[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$OutputRoot = 'artifacts/latest/state-envelope'
)

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

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$schemaDir = Resolve-TbgRepoPath '.tbg/harness/schemas'
$capabilitiesPath = Resolve-TbgRepoPath '.tbg/state/capabilities.registry.json'
$constraintsPath = Resolve-TbgRepoPath '.tbg/state/invariant-constraints.registry.json'
$manifestPath = Resolve-TbgRepoPath '.tbg/skills/manifest.json'
$contractPath = Resolve-TbgRepoPath '.tbg/workflows/state-envelope.contract.json'

$requiredSchemas = @(
    'observation.schema.json',
    'evidence-record.schema.json',
    'claim.schema.json',
    'constraint.schema.json',
    'objective.schema.json',
    'work-item.schema.json',
    'capability.schema.json',
    'state-envelope.schema.json',
    'state-view.schema.json',
    'state-object.schema.json'
)

foreach ($s in $requiredSchemas) {
    $p = Join-Path $schemaDir $s
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Add-TbgIssue -List $errors -Message "Required schema '$s' is missing from $schemaDir."
    }
    else {
        try {
            Get-Content -LiteralPath $p -Raw | ConvertFrom-Json | Out-Null
        }
        catch {
            Add-TbgIssue -List $errors -Message "Schema '$s' is not valid JSON: $($_.Exception.Message)"
        }
    }
}

$capabilities = $null
if (Test-Path -LiteralPath $capabilitiesPath -PathType Leaf) {
    try {
        $capabilities = Get-Content -LiteralPath $capabilitiesPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-TbgIssue -List $errors -Message "Capabilities registry is not valid JSON: $($_.Exception.Message)"
    }
}
else {
    Add-TbgIssue -List $errors -Message "Capabilities registry is missing: $capabilitiesPath"
}

$constraints = $null
if (Test-Path -LiteralPath $constraintsPath -PathType Leaf) {
    try {
        $constraints = Get-Content -LiteralPath $constraintsPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-TbgIssue -List $errors -Message "Invariant constraints registry is not valid JSON: $($_.Exception.Message)"
    }
}
else {
    Add-TbgIssue -List $errors -Message "Invariant constraints registry is missing: $constraintsPath"
}

$manifest = $null
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-TbgIssue -List $errors -Message "Skill manifest is not valid JSON: $($_.Exception.Message)"
    }
}

if ($null -ne $capabilities -and $null -ne $manifest) {
    $skillIds = @($manifest.skills | ForEach-Object { [string]$_.id })
    foreach ($cap in @($capabilities.capabilities)) {
        foreach ($provider in @($cap.providedBy)) {
            $skillRef = $provider -replace '^skill:', ''
            if ($skillIds -notcontains $skillRef) {
                Add-TbgIssue -List $errors -Message "Capability '$($cap.id)' references unregistered skill '$skillRef'."
            }
        }
    }
}

if ($null -ne $constraints) {
    foreach ($c in @($constraints.constraints)) {
        if ([string]::IsNullOrWhiteSpace([string]$c.id)) {
            Add-TbgIssue -List $errors -Message 'A constraint has an empty id.'
        }
        if ([string]::IsNullOrWhiteSpace([string]$c.rule)) {
            Add-TbgIssue -List $errors -Message "Constraint '$($c.id)' has an empty rule."
        }
        if ([string]::IsNullOrWhiteSpace([string]$c.authority)) {
            Add-TbgIssue -List $errors -Message "Constraint '$($c.id)' has an empty authority."
        }
        if ('blocking','warning' -notcontains [string]$c.severity) {
            Add-TbgIssue -List $errors -Message "Constraint '$($c.id)' has invalid severity '$($c.severity)'."
        }
    }
}

$contract = $null
if (Test-Path -LiteralPath $contractPath -PathType Leaf) {
    try {
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        if ($contract.schemaVersion -ne 'TbgWorkflowContract.v1') {
            Add-TbgIssue -List $errors -Message "State envelope contract has unexpected schemaVersion '$($contract.schemaVersion)'."
        }
        if ($contract.sprint -ne 'state-envelope-capability-router-v1') {
            Add-TbgIssue -List $errors -Message "State envelope contract has unexpected sprint '$($contract.sprint)'."
        }
    }
    catch {
        Add-TbgIssue -List $errors -Message "State envelope contract is not valid JSON: $($_.Exception.Message)"
    }
}
else {
    Add-TbgIssue -List $errors -Message "State envelope contract is missing: $contractPath"
}

$outputPath = Resolve-TbgRepoPath $OutputRoot
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$status = if ($errors.Count -eq 0) { 'PASS_state_envelope_valid' } else { 'FAIL_state_envelope_invalid' }

$schemaCount = @($requiredSchemas | Where-Object { Test-Path -LiteralPath (Join-Path $schemaDir $_) }).Count
$capCount = if ($null -ne $capabilities) { @($capabilities.capabilities).Count } else { 0 }
$constraintCount = if ($null -ne $constraints) { @($constraints.constraints).Count } else { 0 }

$result = [ordered]@{
    schema = 'TbgStateEnvelopeResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    schemasPath = '.tbg/harness/schemas'
    registriesPath = '.tbg/state'
    schemaCount = $schemaCount
    capabilityCount = $capCount
    constraintCount = $constraintCount
    errors = @($errors)
    warnings = @($warnings)
    proofLevel = 'static test'
    allowedClaims = @(
        'All state object schemas exist and parse.',
        'The capabilities registry references valid skill ids.',
        'The invariant constraints registry contains valid constraints.',
        'The state envelope contract is well-formed.'
    )
    forbiddenClaims = @(
        'No build, launcher, command ACK, behavior, or live runtime proof is established.'
    )
}
$resultJson = $result | ConvertTo-Json -Depth 10
$resultJson | Set-Content -LiteralPath (Join-Path $outputPath 'state-envelope.result.json') -Encoding UTF8

$reportLines = @(
    '# TBG State Envelope Validation',
    '',
    "The state envelope validator finished with status **$status**.",
    '',
    "- Schemas present: $schemaCount / $($requiredSchemas.Count)",
    "- Capabilities registered: $capCount",
    "- Invariant constraints registered: $constraintCount",
    "- Errors: $($errors.Count)",
    "- Warnings: $($warnings.Count)",
    '- Proof level: static test',
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
if ($warnings.Count -gt 0) {
    $reportLines += '## Warnings'
    $reportLines += ''
    foreach ($w in $warnings) {
        $reportLines += "- $w"
    }
    $reportLines += ''
}
$reportLines += 'The validator does not establish build, launcher, command ACK, behavior, movement, trade, or live runtime proof.'
$reportLines -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'state-envelope.report.md') -Encoding UTF8

Write-Host "State envelope validation: $status"
Write-Host "Schemas: $schemaCount/$($requiredSchemas.Count); Capabilities: $capCount; Constraints: $constraintCount; Errors: $($errors.Count)."

if ($errors.Count -gt 0) {
    exit 1
}
