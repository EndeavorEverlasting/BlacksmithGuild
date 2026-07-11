param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Import-Module (Join-Path $PSScriptRoot 'TbgEffectivePolicy.psm1') -Force

function Get-FixtureProperty {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Assert-True {
    param(
        [bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) { throw $Message }
}

$fixtureRelative = '.tbg/harness/fixtures/english-renderer.fixtures.json'
$fixturePath = Join-Path $repoRoot $fixtureRelative
$schemaPath = Join-Path $repoRoot '.tbg/harness/schemas/effective-policy-context.schema.json'
$policyPath = Join-Path $repoRoot '.tbg/harness/policies/policy-reporting.policy.json'
$workflowPath = Join-Path $repoRoot '.github/workflows/harness-policy-reports.yml'

$catalog = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
$contextSchema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
$reportingPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$forbiddenPatterns = @(Get-FixtureProperty -Object $catalog -Name 'forbiddenPatterns' -Default @())
$cases = @(Get-FixtureProperty -Object $catalog -Name 'cases' -Default @())
Assert-True ($cases.Count -ge 8) 'English renderer fixtures must cover the canonical profile and all required generic row kinds.'

$moduleText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'TbgEffectivePolicy.psm1') -Raw
Assert-True ($moduleText -notmatch 'local-mcp-code-intelligence|project-ai-layer|route-visible-start') 'The renderer/provider must not branch on a specific profile ID.'

$workflowText = Get-Content -LiteralPath $workflowPath -Raw
foreach ($surface in @($reportingPolicy.ciSurfacePaths)) {
    Assert-True ($workflowText.Contains([string]$surface)) "CI workflow is missing policy/report surface: $surface"
}
Assert-True ($workflowText.Contains('Test-TbgEnglishRenderer.ps1')) 'CI workflow must execute the English renderer validator.'

$rendered = New-Object System.Collections.Generic.List[object]
foreach ($case in $cases) {
    $caseId = [string](Get-FixtureProperty -Object $case -Name 'id' -Default '')
    $profileId = [string](Get-FixtureProperty -Object $case -Name 'profileId' -Default '')
    $rowType = [string](Get-FixtureProperty -Object $case -Name 'rowType' -Default 'auto')
    $row = Get-FixtureProperty -Object $case -Name 'row' -Default $null
    Assert-True (-not [string]::IsNullOrWhiteSpace($caseId)) 'Every English renderer fixture needs an id.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($profileId)) "Fixture '$caseId' needs a profileId."

    $context = Get-TbgEffectivePolicyContext -ProfileId $profileId -InputObject $row -RowType $rowType -RepoRoot $repoRoot
    $english = ConvertTo-TbgPolicyEnglish -Context $context
    Assert-True (-not [string]::IsNullOrWhiteSpace($english)) "Fixture '$caseId' rendered empty prose."
    Assert-True ($english -match '[.!?]$') "Fixture '$caseId' did not render a complete sentence."

    foreach ($pattern in $forbiddenPatterns) {
        Assert-True ($english -notmatch [string]$pattern) "Fixture '$caseId' fell back to forbidden output pattern '$pattern': $english"
    }
    foreach ($pattern in @(Get-FixtureProperty -Object $case -Name 'forbiddenPatterns' -Default @())) {
        Assert-True ($english -notmatch [string]$pattern) "Fixture '$caseId' fell back to forbidden output pattern '$pattern': $english"
    }
    foreach ($fragment in @(Get-FixtureProperty -Object $case -Name 'expectedFragments' -Default @())) {
        Assert-True ($english.Contains([string]$fragment)) "Fixture '$caseId' is missing expected prose '$fragment': $english"
    }

    foreach ($requiredName in @($contextSchema.required)) {
        Assert-True ($null -ne $context.PSObject.Properties[[string]$requiredName]) "Fixture '$caseId' context is missing required field '$requiredName'."
    }
    foreach ($sourceFile in @($context.sourceFiles)) {
        Assert-True (Test-Path -LiteralPath (Join-Path $repoRoot $sourceFile) -PathType Leaf) "Fixture '$caseId' resolved a missing source file: $sourceFile"
    }

    $rendered.Add([pscustomobject]@{ id = $caseId; profileId = $profileId; rowType = $rowType; english = $english; context = $context })
}

$routeContract = Get-Content -LiteralPath (Join-Path $repoRoot '.tbg/workflows/route-visible-start.contract.json') -Raw | ConvertFrom-Json
$routeProfile = @($rendered | Where-Object { $_.profileId -eq 'route-visible-start' -and $_.rowType -eq 'profile' } | Select-Object -First 1)
if ($routeProfile.Count -gt 0) {
    Assert-True ($routeProfile[0].context.resultPath -eq $routeContract.resultPath) 'Route resultPath must come from the executable workflow contract.'
    Assert-True ($routeProfile[0].context.requiresInactiveRuntime -eq [bool]$routeContract.requiresInactiveGame) 'Route inactive-runtime policy must come from the executable workflow contract.'
}

$blocked = @($rendered | Where-Object { $_.context.blockedReason -eq 'status file missing' } | Select-Object -First 1)
Assert-True ($blocked.Count -eq 1) 'A blocked route fixture must exercise status-file-missing policy.'
Assert-True (-not [string]::IsNullOrWhiteSpace($blocked[0].context.nextPatchHint)) 'Blocked-result nextPatchHint must be derived from the workflow blocker map.'

$denied = @($rendered | Where-Object { $_.context.decision -eq 'deny' -and $_.context.commandText -eq 'ForgeReboot.cmd' } | Select-Object -First 1)
Assert-True ($denied.Count -eq 1) 'A denied ForgeReboot fixture is required.'
Assert-True ($denied[0].context.requiresForgeStopFirst) 'Denied runtime-affecting commands must retain the ForgeStop-first policy.'

$artifactDir = Join-Path $repoRoot 'artifacts/latest'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$proofPath = Join-Path $artifactDir 'policy-english-renderer.fixtures.md'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Effective policy English renderer fixture proof')
foreach ($item in $rendered) {
    $lines.Add('')
    $lines.Add("## $($item.id)")
    $lines.Add('')
    $lines.Add($item.english)
}
Set-Content -LiteralPath $proofPath -Value $lines -Encoding UTF8

foreach ($item in $rendered) {
    Write-Host "[$($item.id)] $($item.english)"
}
Write-Host "PASS: $($rendered.Count) effective-policy English fixtures rendered without JSON or field-name bullet fallbacks."
