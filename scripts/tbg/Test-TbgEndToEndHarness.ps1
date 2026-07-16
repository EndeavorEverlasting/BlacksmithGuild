[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutputRoot = '.local/tbg-e2e-runs/contract-validation'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$errors = New-Object 'System.Collections.Generic.List[string]'
$passes = 0
function Add-Check([bool]$Condition,[string]$Name,[string]$Message='contract failed') {
    if ($Condition) { $script:passes++; Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { $script:errors.Add("${Name}: $Message"); Write-Host "[FAIL] $Name - $Message" -ForegroundColor Red }
}
function RepoPath([string]$Relative) { Join-Path $RepoRoot ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar) }
function ReadJson([string]$Relative) { Get-Content -LiteralPath (RepoPath $Relative) -Raw | ConvertFrom-Json }
$required=@(
 'AGENTS.md','CLAUDE.md','CODEBASE_MAP.md','.tbg/harness/manifest.json','.tbg/skills/manifest.json',
 '.tbg/harness/api/operations.json','.tbg/harness/e2e/profiles.json','.tbg/harness/consumer-handoffs.registry.json',
 '.tbg/harness/e2e-artifact-types.registry.json','.tbg/workflows/end-to-end-validation.contract.json',
 '.tbg/workflows/tbg-sprint-capsule.contract.json','.tbg/harness/schemas/e2e-validation-profiles.schema.json',
 '.tbg/harness/schemas/tbg-harness-result.schema.json','.tbg/harness/schemas/tbg-sprint-capsule.schema.json',
 'scripts/tbg/Test-TbgEndToEndHarness.ps1','scripts/tbg/Invoke-TbgEndToEndValidation.ps1',
 'scripts/tbg/New-TbgSprintCapsule.ps1','scripts/tbg/Test-TbgSkillRouting.ps1','tests/harness/test_tbg_end_to_end_harness.py',
 'docs/AI_HARNESS_ENTRYPOINT.md','docs/END_TO_END_TESTING_POSTURE.md','docs/MACHINE_READABLE_HANDOFF.md'
)
foreach($item in $required){Add-Check (Test-Path -LiteralPath (RepoPath $item) -PathType Leaf) "required/$item"}
foreach($item in @('scripts/tbg/Test-TbgEndToEndHarness.ps1','scripts/tbg/Invoke-TbgEndToEndValidation.ps1','scripts/tbg/New-TbgSprintCapsule.ps1')){
 $path=RepoPath $item; $bytes=[IO.File]::ReadAllBytes($path); Add-Check ($bytes.Length -ge 3 -and $bytes[0]-eq 239 -and $bytes[1]-eq 187 -and $bytes[2]-eq 191) "bom/$item"
 $tokens=$null;$parseErrors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors);Add-Check ($parseErrors.Count -eq 0) "parse/$item" (($parseErrors|ForEach-Object Message)-join '; ')
}
$manifest=ReadJson '.tbg/harness/manifest.json';$profiles=ReadJson '.tbg/harness/e2e/profiles.json';$operations=ReadJson '.tbg/harness/api/operations.json';$consumers=ReadJson '.tbg/harness/consumer-handoffs.registry.json';$capsuleSchema=ReadJson '.tbg/harness/schemas/tbg-sprint-capsule.schema.json'
Add-Check ($profiles.schema -eq 'tbg.e2e-profiles.v1') 'profiles/version'
Add-Check ($profiles.defaultProfile -eq 'default-static') 'profiles/default'
Add-Check ($profiles.posture.endToEndDefaultRequired -eq $true) 'profiles/e2e-default'
Add-Check ($profiles.posture.gameMutationDefault -eq $false) 'profiles/no-default-mutation'
$journeyIds=@($profiles.journeys|ForEach-Object{[string]$_.id});foreach($profile in $profiles.profiles){foreach($id in $profile.journeyIds){Add-Check ($journeyIds -contains [string]$id) "profile/$($profile.id)/$id"}}
foreach($journey in $profiles.journeys){if($journey.script){Add-Check (Test-Path -LiteralPath (RepoPath $journey.script) -PathType Leaf) "journey/$($journey.id)"}}
$operationIds=@($operations.operations|ForEach-Object{[string]$_.id});Add-Check (($operationIds|Select-Object -Unique).Count -eq $operationIds.Count) 'operations/unique'
Add-Check (@($consumers.consumers|Where-Object id -eq 'agent-switchboard').Count -eq 1) 'consumer/agentswitchboard'
Add-Check (@($consumers.consumers|Where-Object id -eq 'sysadminsuite').Count -eq 1) 'consumer/sysadminsuite'
foreach($field in @('consumers','proof','git','nextCommand')){Add-Check (@($capsuleSchema.required) -contains $field) "capsule/$field"}
foreach($property in @('endToEndProfiles','endToEndContract','endToEndEntrypoint','sprintCapsuleContract','consumerHandoffRegistry')){Add-Check ($manifest.paths.PSObject.Properties.Name -contains $property) "manifest/$property"}
$agentLines=@((Get-Content (RepoPath 'AGENTS.md'))).Count;Add-Check ($agentLines -le 110) 'agents/compact' "AGENTS.md has $agentLines lines"
$agents=Get-Content (RepoPath 'AGENTS.md') -Raw;foreach($token in @('CODEBASE_MAP.md','end-to-end-validation.contract.json','tbg-sprint-capsule.contract.json','SysAdminSuite')){Add-Check ($agents -match [regex]::Escape($token)) "agents/$token"}
$newFiles=$required|Where-Object{$_ -notin @('.tbg/harness/manifest.json','.tbg/skills/manifest.json','scripts/tbg/Test-TbgSkillRouting.ps1')};$text=($newFiles|ForEach-Object{Get-Content (RepoPath $_) -Raw})-join "`n";foreach($token in @(('OPENAI_'+'API_KEY'),('ANTHROPIC_'+'API_KEY'),('C:\'+'Users\Cheex'),('/home/'+'cheex'))){Add-Check (-not $text.Contains($token)) "forbidden/$token"}
$output=RepoPath $OutputRoot;New-Item -ItemType Directory -Force -Path $output|Out-Null;$status=if($errors.Count){'FAIL'}else{'PASS'}
[ordered]@{schema='tbg.e2e-contract-result.v1';generatedUtc=[DateTime]::UtcNow.ToString('o');status=$status;passes=$passes;errors=@($errors)}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $output 'validation-result.json') -Encoding UTF8
Write-Host "Result: $passes passed / $($errors.Count) failed";if($errors.Count){throw ($errors -join [Environment]::NewLine)}
