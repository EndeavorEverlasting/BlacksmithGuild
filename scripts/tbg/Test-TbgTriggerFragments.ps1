param([string]$RepoRoot='',[string]$OutputRoot='artifacts/latest/triggers')
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($RepoRoot)){$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path}
$RepoRoot=[IO.Path]::GetFullPath($RepoRoot);$errors=@();$passes=0
function Add-Check([bool]$C,[string]$N,[string]$M='failed'){if($C){$script:passes++;Write-Host "[PASS] $N" -ForegroundColor Green}else{$script:errors+="${N}: $M";Write-Host "[FAIL] $N - $M" -ForegroundColor Red}}
function Resolve-Relative([string]$R){Join-Path $RepoRoot ($R -replace '/','\')}
$triggerDir=Resolve-Relative '.tbg/harness/triggers.d'
Add-Check (Test-Path $triggerDir -PathType Container) 'triggers/dir'
$triggerFiles=@(Get-ChildItem -LiteralPath $triggerDir -Filter '*.trigger.json' -File)
Add-Check ($triggerFiles.Count -ge 1) 'triggers/count' "Found $($triggerFiles.Count) trigger files"
$requiredProps=@('triggerId','displayName','eventMatch','downstreamOperation','maxCascadeDepth','deduplicationKey','mutationAuthority')
foreach($f in $triggerFiles){
  try{$t=Get-Content -LiteralPath $f.FullName -Raw|ConvertFrom-Json
    Add-Check ($t.schema -eq 'tbg.one-click-test.trigger.v1') "triggers/$($t.triggerId)/schema"
    foreach($prop in $requiredProps){Add-Check ($null -ne $t.$prop) "triggers/$($t.triggerId)/$prop"}
    Add-Check ($t.maxCascadeDepth -ge 1 -and $t.maxCascadeDepth -le 10) "triggers/$($t.triggerId)/depth" "maxCascadeDepth=$($t.maxCascadeDepth)"
    Add-Check (@('none','read_only','local_write') -contains $t.mutationAuthority) "triggers/$($t.triggerId)/authority"
  }catch{Add-Check $false "triggers/$($f.Name)/parse" $_.Exception.Message}
}
$output=if([IO.Path]::IsPathRooted($OutputRoot)){[IO.Path]::GetFullPath($OutputRoot)}else{Resolve-Relative $OutputRoot}
New-Item -ItemType Directory -Force -Path $output|Out-Null
$status=if($errors.Count){'FAIL'}else{'PASS'}
[ordered]@{schema='tbg.trigger-fragments-result.v1';generatedUtc=[DateTime]::UtcNow.ToString('o');status=$status;passes=$passes;errors=@($errors);filesChecked=$triggerFiles.Count;proofLevel='static test'}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $output 'trigger-fragments.validation.json')-Encoding UTF8
Write-Host "Trigger fragments: $status - $passes passed, $($errors.Count) failed"
if($errors.Count){exit 1}
