[CmdletBinding()]
param([string]$RootPath = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RootPath = [IO.Path]::GetFullPath($RootPath)
$failures = [Collections.Generic.List[string]]::new()
$passes = 0

function Assert-Tbg {
    param([bool]$Condition, [string]$Name, [string]$Message = 'contract failed')
    if ($Condition) { $script:passes++; Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { [void]$script:failures.Add("${Name}: $Message"); Write-Host "[FAIL] $Name - $Message" -ForegroundColor Red }
}
function Resolve-TbgPath { param([string]$Path) Join-Path $RootPath ($Path -replace '/', [IO.Path]::DirectorySeparatorChar) }
function Read-TbgJson { param([string]$Path) Get-Content -LiteralPath (Resolve-TbgPath $Path) -Raw | ConvertFrom-Json -Depth 100 }

$required = @(
    'AGENTS.md','CLAUDE.md','CODEBASE_MAP.md','.ai/agent-contract.json',
    'harness/api/agent-capability-manifest.json','harness/api/agent-routing-manifest.json',
    'harness/api/tbg-harness-api.json','harness/api/artifact-types.json','harness/e2e/e2e-profiles.json',
    'harness/workflows/tbg-sprint-capsule.yaml','schemas/harness/tbg-sprint-capsule.schema.json',
    'schemas/harness/tbg-harness-result.schema.json','scripts/Invoke-TbgHarnessE2E.ps1',
    'scripts/New-TbgSprintCapsule.ps1','tests/harness/test_tbg_harness_contracts.py',
    'docs/AI_HARNESS_ENTRYPOINT.md','docs/END_TO_END_TESTING_POSTURE.md','docs/MACHINE_READABLE_HANDOFF.md'
)
foreach ($item in $required) { Assert-Tbg (Test-Path -LiteralPath (Resolve-TbgPath $item) -PathType Leaf) "required/$item" }

foreach ($item in @('scripts/Test-TbgAiHarness.ps1','scripts/Invoke-TbgHarnessE2E.ps1','scripts/New-TbgSprintCapsule.ps1')) {
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile((Resolve-TbgPath $item),[ref]$tokens,[ref]$errors)
    Assert-Tbg ($errors.Count -eq 0) "parse/$item" (($errors | ForEach-Object Message) -join '; ')
}

$manifest = Read-TbgJson 'harness/api/agent-capability-manifest.json'
$routing = Read-TbgJson 'harness/api/agent-routing-manifest.json'
$api = Read-TbgJson 'harness/api/tbg-harness-api.json'
$e2e = Read-TbgJson 'harness/e2e/e2e-profiles.json'
$artifacts = Read-TbgJson 'harness/api/artifact-types.json'
$family = Read-TbgJson '.ai/agent-contract.json'

Assert-Tbg ($manifest.schema_version -eq 'tbg-agent-capability-manifest/v1') 'manifest/version'
Assert-Tbg ($routing.ambiguity_policy -eq 'fail-closed-to-repository-sprint') 'routing/fail-closed'
Assert-Tbg ($e2e.default_profile -eq 'default-static') 'e2e/default-static'
Assert-Tbg ($e2e.posture.end_to_end_default_required -eq $true) 'e2e/default-required'
Assert-Tbg ($e2e.posture.game_mutation_default -eq $false) 'e2e/no-default-mutation'
Assert-Tbg ($artifacts.tracked_runtime_evidence_allowed -eq $false) 'artifacts/runtime-untracked'
Assert-Tbg ($family.canonical_family_root -eq 'EndeavorEverlasting/AgentSwitchboard') 'family/agentswitchboard-root'

$capabilityIds=@($manifest.capabilities | ForEach-Object { [string]$_.id })
$skillIds=@($manifest.skills | ForEach-Object { [string]$_.id })
$operationIds=@($api.operations | ForEach-Object { [string]$_.id })
Assert-Tbg (($capabilityIds | Select-Object -Unique).Count -eq $capabilityIds.Count) 'capabilities/unique'
Assert-Tbg (($skillIds | Select-Object -Unique).Count -eq $skillIds.Count) 'skills/unique'
foreach ($capability in $manifest.capabilities) { Assert-Tbg (Test-Path (Resolve-TbgPath $capability.path) -PathType Leaf) "capability/$($capability.id)" }
foreach ($skill in $manifest.skills) {
    Assert-Tbg (Test-Path (Resolve-TbgPath $skill.path) -PathType Leaf) "skill/$($skill.id)"
    foreach ($dependency in $skill.capability_dependencies) { Assert-Tbg ($capabilityIds -contains [string]$dependency) "skill-dependency/$($skill.id)/$dependency" }
}

$signals=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($route in $routing.routes) {
    foreach ($signal in $route.signals) { Assert-Tbg ($signals.Add([string]$signal)) "signal/$signal" }
    $target=[string]$route.target.id
    if ($route.target.kind -eq 'skill') { Assert-Tbg ($skillIds -contains $target) "route-skill/$target" }
    else { Assert-Tbg ($operationIds -contains $target) "route-operation/$target" }
}

$journeyIds=@($e2e.journeys | ForEach-Object { [string]$_.id })
foreach ($journey in $e2e.journeys) { Assert-Tbg (Test-Path (Resolve-TbgPath $journey.script) -PathType Leaf) "journey/$($journey.id)" }
foreach ($profile in $e2e.profiles) { foreach ($journeyId in $profile.journey_ids) { Assert-Tbg ($journeyIds -contains [string]$journeyId) "profile/$($profile.id)/$journeyId" } }

$agents=Get-Content -LiteralPath (Resolve-TbgPath 'AGENTS.md') -Raw
foreach ($token in @('End-to-end proof is the default merge target','disposable campaign','command ACK','machine-readable handoffs','sprint capsule')) {
    Assert-Tbg ($agents.IndexOf($token,[StringComparison]::OrdinalIgnoreCase) -ge 0) "agents/$token"
}

$scan = ($required | ForEach-Object { Get-Content -LiteralPath (Resolve-TbgPath $_) -Raw }) -join "`n"
foreach ($token in @(('OPENAI_'+'API_KEY'),('ANTHROPIC_'+'API_KEY'),('DEEPSEEK_'+'API_KEY'),('C:\'+'Users\Cheex'),('/home/'+'cheex'))) {
    Assert-Tbg (-not $scan.Contains($token)) "forbidden/$token"
}

Write-Host "`nResult: $passes passed / $($failures.Count) failed"
if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
