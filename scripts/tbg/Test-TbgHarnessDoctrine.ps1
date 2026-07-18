<#
.SYNOPSIS
    Validates that the harness doctrine is installed and enforced in the repository.
.DESCRIPTION
    Checks for:
    - AGENTS.md exists and contains required sections
    - harness-doctrine.md exists with required content
    - harness-doctrine.policy.json exists and is valid JSON
    - At least one Test-*.ps1 validator exists in scripts/tbg/
    - CODEBASE_MAP.md exists
    - .tbg/skills/manifest.json exists
    - .tbg/workflows/ directory contains at least one contract
    - harness manifest references harness doctrine
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputPath = 'artifacts/latest/harness-doctrine'
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $callerDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $RepoRoot = (Resolve-Path (Join-Path $callerDir '..\..')).Path
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$issues = [System.Collections.Generic.List[string]]::new()
$checks = [System.Collections.Generic.List[pscustomobject]]::new()

function Add-TbgIssue {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$List,
        [Parameter(Mandatory)][string]$Message
    )
    $List.Add($Message)
}

function Test-TbgFileExists {
    param([Parameter(Mandatory)][string]$Path)
    return (Test-Path -LiteralPath $Path -PathType Leaf)
}

function Test-TbgDirExists {
    param([Parameter(Mandatory)][string]$Path)
    return (Test-Path -LiteralPath $Path -PathType Container)
}

function Add-TbgCheck {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Detail = ''
    )
    $checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail })
}

# --- Check 1: AGENTS.md exists ---
$agentsPath = Join-Path $RepoRoot 'AGENTS.md'
$agentsExists = Test-TbgFileExists -Path $agentsPath
Add-TbgCheck -Name 'AGENTS.md exists' -Passed $agentsExists
if (-not $agentsExists) {
    Add-TbgIssue -List $issues -Message 'AGENTS.md not found at repo root'
}

# --- Check 2: AGENTS.md contains harness doctrine reference ---
if ($agentsExists) {
    $agentsContent = Get-Content -LiteralPath $agentsPath -Raw
    $hasDoctrineRef = $agentsContent -match 'harness.doctrine|Harness Doctrine|execution loop|action-commitment'
    Add-TbgCheck -Name 'AGENTS.md references harness doctrine' -Passed $hasDoctrineRef -Detail 'Must mention harness doctrine, execution loop, or action-commitment'
    if (-not $hasDoctrineRef) {
        Add-TbgIssue -List $issues -Message 'AGENTS.md does not reference harness doctrine, execution loop, or action-commitment'
    }
}

# --- Check 3: AGENTS.md contains identity declaration fields ---
if ($agentsExists) {
    $agentsContent = Get-Content -LiteralPath $agentsPath -Raw
    $requiredFields = @('repo', 'branch', 'PR', 'lane', 'owned scope', 'forbidden scope', 'expected artifacts', 'validation order')
    $missingFields = @()
    foreach ($field in $requiredFields) {
        if ($agentsContent -notmatch [regex]::Escape($field)) {
            $missingFields += $field
        }
    }
    $hasAllFields = $missingFields.Count -eq 0
    Add-TbgCheck -Name 'AGENTS.md identity fields' -Passed $hasAllFields -Detail "Missing: $($missingFields -join ', ')"
    if (-not $hasAllFields) {
        Add-TbgIssue -List $issues -Message "AGENTS.md missing identity fields: $($missingFields -join ', ')"
    }
}

# --- Check 4: harness-doctrine.md exists ---
$doctrinePath = Join-Path $RepoRoot 'docs\harness-doctrine.md'
$doctrineExists = Test-TbgFileExists -Path $doctrinePath
Add-TbgCheck -Name 'harness-doctrine.md exists' -Passed $doctrineExists
if (-not $doctrineExists) {
    Add-TbgIssue -List $issues -Message 'docs/harness-doctrine.md not found'
}

# --- Check 5: harness-doctrine.md contains required sections ---
if ($doctrineExists) {
    $doctrineContent = Get-Content -LiteralPath $doctrinePath -Raw
    $requiredSections = @('Identity declaration', 'Execution loop', 'Action-commitment', 'Proof levels', 'Completion report')
    $missingSections = @()
    foreach ($section in $requiredSections) {
        if ($doctrineContent -match $section) { continue }
        $missingSections += $section
    }
    $hasAllSections = $missingSections.Count -eq 0
    Add-TbgCheck -Name 'harness-doctrine.md required sections' -Passed $hasAllSections -Detail "Missing: $($missingSections -join ', ')"
    if (-not $hasAllSections) {
        Add-TbgIssue -List $issues -Message "harness-doctrine.md missing sections: $($missingSections -join ', ')"
    }
}

# --- Check 6: harness-doctrine.policy.json exists and is valid JSON ---
$policyPath = Join-Path $RepoRoot '.tbg\harness\policies\harness-doctrine.policy.json'
$policyExists = Test-TbgFileExists -Path $policyPath
Add-TbgCheck -Name 'harness-doctrine.policy.json exists' -Passed $policyExists
if (-not $policyExists) {
    Add-TbgIssue -List $issues -Message '.tbg/harness/policies/harness-doctrine.policy.json not found'
} else {
    try {
        $policyJson = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
        $hasSchema = -not [string]::IsNullOrWhiteSpace($policyJson.schema)
        $hasRules = $null -ne $policyJson.enforcementRules -and @($policyJson.enforcementRules).Count -gt 0
        Add-TbgCheck -Name 'policy.json valid schema' -Passed $hasSchema
        Add-TbgCheck -Name 'policy.json has enforcement rules' -Passed $hasRules -Detail "Rules count: $(if ($policyJson.enforcementRules) { @($policyJson.enforcementRules).Count } else { 0 })"
        if (-not $hasSchema) {
            Add-TbgIssue -List $issues -Message 'policy.json missing schema field'
        }
        if (-not $hasRules) {
            Add-TbgIssue -List $issues -Message 'policy.json missing or empty enforcementRules'
        }
    } catch {
        Add-TbgCheck -Name 'policy.json valid JSON' -Passed $false -Detail $_.Exception.Message
        Add-TbgIssue -List $issues -Message "policy.json is not valid JSON: $($_.Exception.Message)"
    }
}

# --- Check 7: At least one Test-*.ps1 validator exists ---
$validatorDir = Join-Path $RepoRoot 'scripts\tbg'
$validatorsExist = Test-TbgDirExists -Path $validatorDir
if ($validatorsExist) {
    $validators = Get-ChildItem -LiteralPath $validatorDir -Filter 'Test-*.ps1' -File -ErrorAction SilentlyContinue
    $hasValidators = $null -ne $validators -and @($validators).Count -gt 0
    Add-TbgCheck -Name 'Test-*.ps1 validators exist' -Passed $hasValidators -Detail "Count: $(if ($validators) { @($validators).Count } else { 0 })"
    if (-not $hasValidators) {
        Add-TbgIssue -List $issues -Message 'No Test-*.ps1 validators found in scripts/tbg/'
    }
} else {
    Add-TbgCheck -Name 'scripts/tbg/ directory exists' -Passed $false
    Add-TbgIssue -List $issues -Message 'scripts/tbg/ directory not found'
}

# --- Check 8: CODEBASE_MAP.md exists ---
$codebaseMapPath = Join-Path $RepoRoot 'CODEBASE_MAP.md'
$codebaseMapExists = Test-TbgFileExists -Path $codebaseMapPath
Add-TbgCheck -Name 'CODEBASE_MAP.md exists' -Passed $codebaseMapExists
if (-not $codebaseMapExists) {
    Add-TbgIssue -List $issues -Message 'CODEBASE_MAP.md not found'
}

# --- Check 9: .tbg/skills/manifest.json exists ---
$skillsManifestPath = Join-Path $RepoRoot '.tbg\skills\manifest.json'
$skillsManifestExists = Test-TbgFileExists -Path $skillsManifestPath
Add-TbgCheck -Name '.tbg/skills/manifest.json exists' -Passed $skillsManifestExists
if (-not $skillsManifestExists) {
    Add-TbgIssue -List $issues -Message '.tbg/skills/manifest.json not found'
}

# --- Check 10: .tbg/workflows/ contains at least one contract ---
$workflowsDir = Join-Path $RepoRoot '.tbg\workflows'
$workflowsExist = Test-TbgDirExists -Path $workflowsDir
if ($workflowsExist) {
    $contracts = Get-ChildItem -LiteralPath $workflowsDir -Filter '*.contract.json' -File -ErrorAction SilentlyContinue
    $hasContracts = $null -ne $contracts -and @($contracts).Count -gt 0
    Add-TbgCheck -Name '.tbg/workflows/ has contracts' -Passed $hasContracts -Detail "Count: $(if ($contracts) { @($contracts).Count } else { 0 })"
    if (-not $hasContracts) {
        Add-TbgIssue -List $issues -Message 'No .contract.json files found in .tbg/workflows/'
    }
} else {
    Add-TbgCheck -Name '.tbg/workflows/ directory exists' -Passed $false
    Add-TbgIssue -List $issues -Message '.tbg/workflows/ directory not found'
}

# --- Check 11: harness manifest references harness doctrine ---
$manifestPath = Join-Path $RepoRoot '.tbg\harness\manifest.json'
$manifestExists = Test-TbgFileExists -Path $manifestPath
if ($manifestExists) {
    try {
        $manifestJson = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $doctrineArray = @($manifestJson.doctrine)
        $hasHarnessDoctrine = $false
        foreach ($entry in $doctrineArray) {
            if ($entry -match 'harness|prompt.*harness|repo-local AI harness') {
                $hasHarnessDoctrine = $true
                break
            }
        }
        Add-TbgCheck -Name 'manifest.json references harness doctrine' -Passed $hasHarnessDoctrine -Detail "Doctrine entries: $($doctrineArray.Count)"
        if (-not $hasHarnessDoctrine) {
            Add-TbgIssue -List $issues -Message 'manifest.json doctrine array does not reference harness doctrine'
        }
    } catch {
        Add-TbgCheck -Name 'manifest.json parseable' -Passed $false -Detail $_.Exception.Message
        Add-TbgIssue -List $issues -Message "manifest.json parse error: $($_.Exception.Message)"
    }
} else {
    Add-TbgCheck -Name 'manifest.json exists' -Passed $false
    Add-TbgIssue -List $issues -Message '.tbg/harness/manifest.json not found'
}

# --- Build output ---
$passed = @($checks | Where-Object { $_.passed }).Count
$failed = @($checks | Where-Object { -not $_.passed }).Count
$total = @($checks).Count
$verdict = if ($failed -eq 0) { 'PASS' } else { 'FAIL' }

$output = [pscustomobject]@{
    schema = 'tbg.harness-doctrine-check.v1'
    timestamp = [datetime]::UtcNow.ToString('o')
    verdict = $verdict
    passed = $passed
    failed = $failed
    total = $total
    issues = @($issues)
    checks = @($checks)
}

# Write output
$outputDir = Split-Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$output | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$OutputPath.result.json" -Encoding UTF8

# Console output
Write-Host "`n=== Harness Doctrine Validation ===" -ForegroundColor Cyan
Write-Host "Verdict: $verdict" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } else { 'Red' })
Write-Host "Checks: $passed/$total passed, $failed failed`n" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })

foreach ($check in $checks) {
    $icon = if ($check.passed) { '[PASS]' } else { '[FAIL]' }
    $color = if ($check.passed) { 'Green' } else { 'Red' }
    $detail = if (-not [string]::IsNullOrWhiteSpace($check.detail)) { " ($($check.detail))" } else { '' }
    Write-Host "  $icon $($check.name)$detail" -ForegroundColor $color
}

if ($issues.Count -gt 0) {
    Write-Host "`nIssues:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
}

Write-Host "`nOutput: $OutputPath.result.json`n"

if ($verdict -ne 'PASS') {
    exit 1
}
