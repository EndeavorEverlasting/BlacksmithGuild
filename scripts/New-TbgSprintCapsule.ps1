[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SprintId,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Lane,
    [Parameter(Mandatory)][string]$Mission,
    [string[]]$OwnedPaths=@(), [string[]]$ForbiddenScope=@(),
    [string[]]$Completed=@(), [string[]]$Remaining=@(), [string[]]$Blockers=@(),
    [string[]]$ValidationCommands=@(), [string[]]$SkippedChecks=@(),
    [Parameter(Mandatory)][ValidateSet('contract-proof','build-proof','install-proof','launcher-session-attach','command-issued','command-ack','behavior-observed','save-safe-mutation-observed','live-runtime-certified')][string]$ProofLevel,
    [Parameter(Mandatory)][string]$ProofCeiling,
    [string[]]$ClaimsNotMade=@(),
    [Parameter(Mandatory)][string]$NextCommand,
    [string]$OutputPath=(Join-Path (Split-Path -Parent $PSScriptRoot) '.local\harness-runs\sprint-capsule.json'),
    [switch]$ReadyForSysAdminSuite
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$git=(Get-Command git -ErrorAction Stop).Source
function GitText([string[]]$Arguments) { $out=& $git -C $root @Arguments 2>&1; if($LASTEXITCODE){throw "git failed: $($out -join ' ')"}; ($out -join "`n").Trim() }
$remote=GitText @('config','--get','remote.origin.url')
if($remote -notmatch '(?i)(?:github\.com[:/])EndeavorEverlasting/BlacksmithGuild(?:\.git)?$'){throw "Unexpected origin: $remote"}
$branch=GitText @('branch','--show-current'); $head=GitText @('rev-parse','HEAD'); $status=GitText @('status','--porcelain=v1')
$dirty=-not [string]::IsNullOrWhiteSpace($status); $asReady=(-not $dirty -and $Blockers.Count -eq 0); $sasReady=($ReadyForSysAdminSuite -and $asReady)
$capsule=[ordered]@{
 schema_version='tbg-sprint-capsule/v1'; created_at=(Get-Date).ToString('o'); repository='EndeavorEverlasting/BlacksmithGuild'
 sprint=[ordered]@{id=$SprintId;title=$Title;lane=$Lane;mission=$Mission}
 git_state=[ordered]@{branch=$branch;head=$head;dirty=$dirty}
 scope=[ordered]@{owned_paths=@($OwnedPaths);forbidden_scope=@($ForbiddenScope)}
 validation=[ordered]@{commands=@($ValidationCommands);skipped=@($SkippedChecks)}
 proof=[ordered]@{level=$ProofLevel;ceiling=$ProofCeiling;claims_not_made=@($ClaimsNotMade)}
 handoff=[ordered]@{completed=@($Completed);remaining=@($Remaining);blockers=@($Blockers);receiving_agent_must_reinspect_state=$true}
 consumers=[ordered]@{
  agent_switchboard=[ordered]@{ready=$asReady;contract='tbg-sprint-capsule/v1';authority='coordination-only';reason=$(if($asReady){'Clean state with no blockers.'}else{'Dirty state or blockers require review.'})}
  sysadminsuite=[ordered]@{ready=$sasReady;contract='tbg-sprint-capsule/v1';authority='explicit-tandem-consumer-only';reason=$(if($sasReady){'Explicit clean tandem handoff.'}else{'Not explicitly authorized or not ready.'})}
 }
 next_command=$NextCommand
}
$json=$capsule | ConvertTo-Json -Depth 20
foreach($pattern in @('(?i)[A-Z]:\\Users\\','(?i)/home/[^/]+/','(?i)Game Saves')){if($json -match $pattern){throw 'Capsule contains a machine-local or save path.'}}
$parent=Split-Path -Parent $OutputPath; if($parent){New-Item -ItemType Directory -Force -Path $parent | Out-Null}
$json | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM
Write-Host "Sprint capsule: $OutputPath" -ForegroundColor Cyan
$capsule
