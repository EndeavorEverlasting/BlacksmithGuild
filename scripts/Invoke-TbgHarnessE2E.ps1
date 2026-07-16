[CmdletBinding()]
param(
    [string]$Profile='default-static', [string]$OutputRoot, [string]$GameFolder,
    [switch]$AllowLiveRuntime, [switch]$AllowDisposableSaveMutation
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if(-not $OutputRoot){$OutputRoot=Join-Path $root ('.local\harness-runs\{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))}
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot); New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$catalog=Get-Content (Join-Path $root 'harness\e2e\e2e-profiles.json') -Raw | ConvertFrom-Json -Depth 50
$selected=@($catalog.profiles | Where-Object id -eq $Profile) | Select-Object -First 1
if(-not $selected){throw "Unknown E2E profile '$Profile'."}
$git=(Get-Command git -ErrorAction Stop).Source
function GitText([string[]]$Arguments){$out=& $git -C $root @Arguments 2>&1;if($LASTEXITCODE){throw 'Git preflight failed.'};($out -join "`n").Trim()}
function AddResult([string]$Id,[string]$Status,[int]$Code,[string]$Message,[string]$Proof){[void]$script:results.Add([pscustomobject][ordered]@{id=$Id;status=$Status;exit_code=$Code;message=$Message;proof_level=$Proof})}
$runId=Split-Path -Leaf $OutputRoot
$context=[ordered]@{schema_version='tbg-harness-run-context/v1';run_id=$runId;created_at=(Get-Date).ToString('o');repository='EndeavorEverlasting/BlacksmithGuild';profile=$Profile;git=[ordered]@{branch=(GitText @('branch','--show-current'));head=(GitText @('rev-parse','HEAD'));dirty=(-not [string]::IsNullOrWhiteSpace((GitText @('status','--porcelain=v1'))))};authority=[ordered]@{network=$false;game_mutation=$false;live_runtime=[bool]$AllowLiveRuntime;disposable_save_mutation=[bool]$AllowDisposableSaveMutation}}
$context | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $OutputRoot 'run-context.json') -Encoding utf8NoBOM
$results=[Collections.Generic.List[object]]::new(); $failure=$null; $blocked=$false; $proof='contract-proof'
try {
 foreach($journeyId in $selected.journey_ids){
  $journey=@($catalog.journeys | Where-Object id -eq $journeyId) | Select-Object -First 1
  if(-not $journey){throw "Unknown journey '$journeyId'."}
  $path=Join-Path $root ([string]$journey.script); Write-Host "`n=== $journeyId ===" -ForegroundColor Cyan
  switch([string]$journey.kind){
   'python' {$python=Get-Command python -ErrorAction SilentlyContinue;if(-not $python){$python=Get-Command python3 -ErrorAction Stop};& $python.Source $path;if($LASTEXITCODE){throw "$journeyId failed."};AddResult $journeyId passed 0 'Dependency-free contracts passed.' $journey.proof_level}
   'powershell' {& $path -RootPath $root;AddResult $journeyId passed 0 'PowerShell contracts passed.' $journey.proof_level}
   'dotnet-debug-build' {if(-not $GameFolder -or -not (Test-Path $GameFolder -PathType Container)){$blocked=$true;AddResult $journeyId blocked 30 'Valid -GameFolder required.' $journey.proof_level;throw 'Local build blocked: game root required.'};& (Get-Command dotnet -ErrorAction Stop).Source build $path -c Debug "-p:GameFolder=$GameFolder";if($LASTEXITCODE){throw 'Debug build failed.'};$proof='build-proof';AddResult $journeyId passed 0 'Debug build passed without Release install.' $journey.proof_level}
   'operator-gated-runtime' {if(-not $AllowLiveRuntime){$blocked=$true;AddResult $journeyId blocked 31 'Live runtime authority not supplied.' $journey.proof_level;throw 'Live profile requires -AllowLiveRuntime.'};if($journey.game_mutation -and -not $AllowDisposableSaveMutation){$blocked=$true;AddResult $journeyId blocked 32 'Disposable-save authority not supplied.' $journey.proof_level;throw 'Mutation profile requires -AllowDisposableSaveMutation.'};$blocked=$true;AddResult $journeyId blocked 33 'Live command/ACK implementation intentionally deferred.' $journey.proof_level;throw 'Live runner is not implemented by the foundation sprint.'}
   default {throw "Unsupported journey kind '$($journey.kind)'."}
  }
 }
} catch {$failure=$_.Exception.Message}
$status=if($failure){if($blocked){'blocked'}else{'failed'}}else{'completed'}
$ceiling=if($status -ne 'completed'){'No higher than the last passed journey.'}elseif($proof -eq 'build-proof'){'Contracts and local Debug build only; no install, launch, ACK, behavior, or save mutation.'}else{'Composed contract proof only; no game process, ACK, behavior, or save mutation.'}
$artifacts=@([ordered]@{type='run-context';path='run-context.json'},[ordered]@{type='artifact-registry';path='artifact-registry.json'},[ordered]@{type='e2e-result';path='result.json'},[ordered]@{type='operator-report';path='operator-report.md'},[ordered]@{type='sprint-capsule';path='sprint-capsule.json'})
$result=[ordered]@{schema_version='tbg-harness-result/v1';run_id=$runId;profile=$Profile;status=$status;proof_level=$proof;proof_ceiling=$ceiling;journeys=@($results);artifacts=$artifacts}
$result | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $OutputRoot 'result.json') -Encoding utf8NoBOM
[ordered]@{schema_version='tbg-artifact-registry/v1';run_id=$runId;artifacts=$artifacts} | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $OutputRoot 'artifact-registry.json') -Encoding utf8NoBOM
@("# BlacksmithGuild Harness E2E Result","","- Profile: $Profile","- Status: $status","- Proof: $proof","- Ceiling: $ceiling","- Blocker: $(if($failure){$failure}else{'none'})","","## Journeys") + @($results | ForEach-Object {"- [$($_.status)] $($_.id): $($_.message)"}) | Set-Content (Join-Path $OutputRoot 'operator-report.md') -Encoding utf8NoBOM
& (Join-Path $root 'scripts\New-TbgSprintCapsule.ps1') -SprintId "harness-e2e-$runId" -Title "BlacksmithGuild harness E2E $Profile" -Lane harness-validation -Mission 'Run the selected repository-owned E2E profile.' -Completed @($results|Where-Object status -eq passed|ForEach-Object id) -Remaining @($results|Where-Object status -ne passed|ForEach-Object id) -Blockers $(if($failure){@($failure)}else{@()}) -ValidationCommands @("Invoke-TbgHarnessE2E.ps1 -Profile $Profile") -ProofLevel $proof -ProofCeiling $ceiling -ClaimsNotMade @('install-proof','launcher-session-attach','command-ack','live-runtime-certified') -NextCommand 'git status --short' -OutputPath (Join-Path $OutputRoot 'sprint-capsule.json') | Out-Null
Write-Host "`nResult: $(Join-Path $OutputRoot 'result.json')" -ForegroundColor Cyan
if($status -eq 'completed'){return};if($status -eq 'blocked'){throw [Management.Automation.RuntimeException]::new("BLOCKED: $failure")};throw $failure
