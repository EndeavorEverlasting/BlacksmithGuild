[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SprintId,[Parameter(Mandatory=$true)][string]$Title,
 [Parameter(Mandatory=$true)][string]$Lane,[Parameter(Mandatory=$true)][string]$Mission,
 [string[]]$OwnedPaths=@(),[string[]]$ForbiddenScope=@(),[string[]]$Completed=@(),[string[]]$Remaining=@(),[string[]]$Blockers=@(),
 [string[]]$Validation=@(),[string[]]$SkippedChecks=@(),
 [Parameter(Mandatory=$true)][ValidateSet('contract','harness','static test','build','launcher','command ACK','behavior observed','live runtime')][string]$ProofLevel,
 [Parameter(Mandatory=$true)][string]$ProofCeiling,[string[]]$ClaimsNotMade=@(),[string[]]$ArtifactRefs=@(),
 [Parameter(Mandatory=$true)][string]$NextCommand,[string]$OutputPath='.local/tbg-e2e-runs/sprint-capsule.json',
 [string]$LatestPath='artifacts/latest/tbg-sprint-capsule.json',[switch]$ReadyForSysAdminSuite,[string]$SysAdminSuiteOperation=''
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path;$git=(Get-Command git -ErrorAction Stop).Source
function GitText([string[]]$Arguments){$out=& $git -C $root @Arguments 2>&1;if($LASTEXITCODE){throw "git failed: $($out -join ' ')"};($out-join "`n").Trim()}
$remote=GitText @('config','--get','remote.origin.url');if($remote -notmatch '(?i)(?:github\.com[:/])EndeavorEverlasting/BlacksmithGuild(?:\.git)?$'){throw "Unexpected origin: $remote"}
$branch=GitText @('branch','--show-current');$head=GitText @('rev-parse','HEAD');$dirty=-not [string]::IsNullOrWhiteSpace((GitText @('status','--porcelain=v1')))
$ownedPathsValue=@($OwnedPaths);$forbiddenScopeValue=@($ForbiddenScope);$completedValue=@($Completed);$remainingValue=@($Remaining);$blockersValue=@($Blockers);$validationValue=@($Validation);$skippedChecksValue=@($SkippedChecks);$claimsNotMadeValue=@($ClaimsNotMade);$artifactRefsValue=@($ArtifactRefs)
$asReady=(-not $dirty -and $blockersValue.Count -eq 0);$sasReady=($ReadyForSysAdminSuite -and $asReady -and -not [string]::IsNullOrWhiteSpace($SysAdminSuiteOperation))
$capsule=[ordered]@{schema='tbg.sprint-capsule.v1';generatedUtc=[DateTime]::UtcNow.ToString('o');producer='EndeavorEverlasting/BlacksmithGuild';sprint=[ordered]@{id=$SprintId;title=$Title;lane=$Lane;mission=$Mission};git=[ordered]@{branch=$branch;headCommit=$head;dirty=$dirty};scope=[ordered]@{ownedPaths=$ownedPathsValue;forbiddenScope=$forbiddenScopeValue};validation=[ordered]@{commands=$validationValue;skipped=$skippedChecksValue};proof=[ordered]@{level=$ProofLevel;ceiling=$ProofCeiling;claimsNotMade=$claimsNotMadeValue};handoff=[ordered]@{completed=$completedValue;remaining=$remainingValue;blockers=$blockersValue;receivingConsumerMustReinspectState=$true};consumers=[ordered]@{agentSwitchboard=[ordered]@{ready=$asReady;authority='coordination-only';reason=$(if($asReady){'Clean committed state with no declared blockers.'}else{'Dirty state or blockers require review.'})};sysAdminSuite=[ordered]@{ready=$sasReady;authority='explicit-tandem-consumer-only';operation=$SysAdminSuiteOperation;reason=$(if($sasReady){'Explicit authorized tandem operation.'}else{'No explicit ready tandem operation.'})}};artifactRefs=$artifactRefsValue;nextCommand=$NextCommand}
$json=$capsule|ConvertTo-Json -Depth 30;foreach($pattern in @('(?i)[A-Z]:\\Users\\','(?i)/home/[^/]+/','(?i)Game Saves','(?i)steamapps\\common')){if($json -match $pattern){throw 'Capsule contains a machine-local game, save, or home path.'}}
foreach($target in @($OutputPath,$LatestPath)){if([string]::IsNullOrWhiteSpace($target)){continue};$absolute=if([IO.Path]::IsPathRooted($target)){$target}else{Join-Path $root $target};$parent=Split-Path -Parent $absolute;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null};$json|Set-Content -LiteralPath $absolute -Encoding UTF8}
Write-Host "Sprint capsule: $OutputPath" -ForegroundColor Cyan;$capsule
