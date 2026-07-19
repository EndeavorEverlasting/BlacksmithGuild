[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command='run',
  [string]$Profile='',
  [string]$Test='',
  [string]$RunId='',
  [string]$OutputRoot='',
  [switch]$NoPause,
  [switch]$Help
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$schemaVersion = 'tbg.one-click-test.run-context.v1'
$runId = if ($RunId) { $RunId } else { Get-Date -Format 'yyyyMMdd-HHmmss-fff' }
$correlationId = [guid]::NewGuid().ToString('N')
$script:eventSequence = 0
$global:tbgEvents = @()
$script:proofLevel = 'contract'
$script:testResult = $null

function Write-Event {
  param([string]$EventType,[string]$TestId=$null,[string]$ParentEventId=$null,$Payload=$null)
  $script:eventSequence++
  $e = [pscustomobject]@{
    eventId=[guid]::NewGuid().ToString('N');eventType=$EventType;runId=$runId
    correlationId=$correlationId;parentEventId=$ParentEventId;testId=$TestId
    source='Invoke-TbgOneClickTest.ps1';timestamp=[DateTime]::UtcNow.ToString('o')
    ingestionSequence=$eventSequence;proofLevel=$script:proofLevel
    payload=$(if($Payload){$Payload}else{@{}})
  }
  $global:tbgEvents += $e
  return $e.eventId
}

function Write-Progress {
  param([string]$Status,[string]$TestId,[string]$Message,[string]$Elapsed=$null)
  $ts=[DateTime]::UtcNow.ToString('HH:mm:ss')
  $line="[$ts] [$Status] $TestId"
  if($Message){$line+=" - $Message"}
  if($Elapsed){$line+=" ($Elapsed)"}
  $c='White'
  if($Status -eq 'PASS'){$c='Green'}
  elseif($Status -eq 'FAIL'){$c='Red'}
  elseif($Status -eq 'SKIP'){$c='Gray'}
  elseif($Status -eq 'RUN'){$c='Cyan'}
  Write-Host $line -ForegroundColor $c
}

function Get-GitContext {
  $git=(Get-Command git -ErrorAction Stop).Source
  $b=@(& $git -C $root branch --show-current 2>&1)
  $h=@(& $git -C $root rev-parse HEAD 2>&1)
  $s=@(& $git -C $root status --porcelain=v1 2>&1)
  $bd='';foreach($x in $b){$bd+=$x};$hd='';foreach($x in $h){$hd+=$x};$sd='';foreach($x in $s){$sd+=$x}
  return [pscustomobject]@{branch=$bd.Trim();head=$hd.Trim();dirty=(-not[string]::IsNullOrWhiteSpace($sd));worktree=$root}
}

function Read-Profiles {
  $d=Join-Path $root '.tbg\harness\test-profiles.d'
  if(-not(Test-Path $d -PathType Container)){return @()}
  $r=@()
  foreach($f in Get-ChildItem -LiteralPath $d -Filter '*.profile.json' -Recurse -File){
    try{$p=Get-Content -LiteralPath $f.FullName -Raw|ConvertFrom-Json
      $r+=[pscustomobject]@{profileId=[string]$p.profileId;displayName=[string]$p.displayName;description=[string]$p.description
        includeTags=@($p.includeTags);excludeTags=@($p.excludeTags);includeTestIds=@($p.includeTestIds);excludeTestIds=@($p.excludeTestIds)
        failFast=[bool][int]$p.failFast;mutationAuthority=[string]$p.mutationAuthority}
    }catch{Write-Warning "Failed to parse profile '$($f.FullName)': $_"}
  }
  return $r
}

function Read-Catalog {
  $d=Join-Path $root '.tbg\harness\test-catalog.d'
  if(-not(Test-Path $d -PathType Container)){return @()}
  $r=@();$seen=@{}
  foreach($f in Get-ChildItem -LiteralPath $d -Filter '*.test.json' -Recurse -File){
    try{$t=Get-Content -LiteralPath $f.FullName -Raw|ConvertFrom-Json
      $tid=[string]$t.testId
      if($seen.ContainsKey($tid)){throw "Duplicate test ID '$tid' in '$($f.FullName)' and '$($seen[$tid])'"}
      $seen[$tid]=$f.FullName
      $src=[string]$t.sourcePath
      if($src -and -not([IO.Path]::IsPathRooted($src))){$src=Join-Path $root ($src -replace '/','\')}
      $r+=[pscustomobject]@{testId=$tid;displayName=[string]$t.displayName;ownerLane=[string]$t.ownerLane
        sourcePath=$src;command=[string]$t.command;arguments=@($t.arguments);supportedHosts=@($t.supportedHosts)
        requiredTools=@($t.requiredTools);timeoutSeconds=[int]$t.timeoutSeconds;tags=@($t.tags)
        mutationClass=[string]$t.mutationClass;proofLevel=[string]$t.proofLevel;proofCeiling=[string]$t.proofCeiling
        defaultProfileMembership=@($t.defaultProfileMembership)}
    }catch{Write-Warning "Failed to parse test '$($f.FullName)': $_"}
  }
  return $r
}

function Invoke-Test {
  param($Test,$TestOutputRoot)
  New-Item -ItemType Directory -Force -Path $TestOutputRoot|Out-Null
  $tid=$Test.testId;$eid=Write-Event 'test.started' -TestId $tid;$start=[DateTime]::UtcNow
  Write-Progress 'RUN' $tid "Starting..."
  if(-not(Test-Path -LiteralPath $Test.sourcePath -PathType Leaf)){
    $el=[DateTime]::UtcNow-$start;$es=$el.ToString('hh\:mm\:ss')
    Write-Event 'test.failed' -TestId $tid -ParentEventId $eid -Payload @{exitCode=-1;message="Script not found"}
    Write-Progress 'FAIL' $tid "Script not found" $es
    $script:testResult=[pscustomobject]@{testId=$tid;status='failed';exitCode=-1;message="Script not found: $($Test.sourcePath)";elapsed=$es;proofLevel=$Test.proofLevel}
    return
  }
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=$Test.command;$argParts=@()
  foreach($a in $Test.arguments){$argParts+=$a}
  $psi.Arguments=$argParts -join ' '
  $psi.WorkingDirectory=$root;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
  $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;[void]$p.Start()
  $outT=$p.StandardOutput.ReadToEndAsync();$errT=$p.StandardError.ReadToEndAsync()
  $to=-not $p.WaitForExit($Test.timeoutSeconds*1000)
  if($to){& taskkill.exe /PID $p.Id /T /F 2>$null|Out-Null;$p.WaitForExit()}
  $stdout=$outT.Result;$stderr=$errT.Result
  if($stdout){Write-Event 'test.stdout' -TestId $tid -ParentEventId $eid -Payload @{text=$stdout}}
  if($stderr){Write-Event 'test.stderr' -TestId $tid -ParentEventId $eid -Payload @{text=$stderr}}
  $ec=if($to){124}else{$p.ExitCode}
  $el=[DateTime]::UtcNow-$start;$es=$el.ToString('hh\:mm\:ss')
  $sp=Join-Path $TestOutputRoot "$tid.stdout.txt";$ep=Join-Path $TestOutputRoot "$tid.stderr.txt"
  if($stdout){Set-Content -LiteralPath $sp -Value $stdout -Encoding UTF8}
  if($stderr){Set-Content -LiteralPath $ep -Value $stderr -Encoding UTF8}
  $s=if($ec-eq 0){'passed'}else{'failed'}
  Write-Event $(if($s-eq 'passed'){'test.completed'}else{'test.failed'}) -TestId $tid -ParentEventId $eid -Payload @{exitCode=$ec;elapsed=$es}
  Write-Progress $(if($s-eq 'passed'){'PASS'}else{'FAIL'}) $tid "Exit code: $ec" $es
  $script:testResult=[pscustomobject]@{testId=$tid;status=$s;exitCode=$ec;message=$(if($s-eq 'passed'){"Passed (exit $ec)"}else{"Failed (exit $ec): $stderr"});elapsed=$es;proofLevel=$Test.proofLevel}
}

function Write-Report {
  param($Path,$Run,$Prof,$Status,$PLevel,$Ceil,$Results)
  $l=@();$l+="# ForgeTest Operator Report";$l+="";$l+="- **Run ID:** $Run"
  $l+="- **Profile:** $Prof";$l+="- **Status:** $Status";$l+="- **Proof Level:** $PLevel"
  $l+="- **Proof Ceiling:** $Ceil";$l+="";$l+="## Tests"
  $l+="| Test ID | Status | Exit Code | Elapsed |";$l+="|---|---|---|---|"
  foreach($r in $Results){$l+="| $($r.testId) | $($r.status) | $($r.exitCode) | $($r.elapsed) |"}
  $l+="";$l+="## Analysis"
  $p2=0;$f2=0;$s2=0
  foreach($r in $Results){if($r.status -eq 'passed'){$p2++}elseif($r.status -eq 'failed'){$f2++}elseif($r.status -eq 'skipped'){$s2++}}
  $l+="- **$p2 passed**, **$f2 failed**, **$s2 skipped**";$l+="";$l+="---"
  $l+="_Generated by Invoke-TbgOneClickTest.ps1_"
  Set-Content -LiteralPath $Path -Value ($l -join "`r`n") -Encoding UTF8
}

# --- MAIN ---
if($Help){Get-Help $MyInvocation.MyCommand.Path;exit 0}
if(-not $OutputRoot){$OutputRoot=Join-Path $root ".local\tbg-one-click-tests\$runId"}
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
$latestDir=Join-Path $root 'artifacts\latest\one-click-test'
New-Item -ItemType Directory -Force -Path $OutputRoot|Out-Null
New-Item -ItemType Directory -Force -Path $latestDir|Out-Null

$gitCtx=Get-GitContext
$profiles=Read-Profiles
$allTests=Read-Catalog

# Commands without profile
if($Command -eq 'list'){
  Write-Host "`n=== ForgeTest Test Catalog ===" -ForegroundColor Cyan
  Write-Host "Available tests: $(@($allTests).Count)`n"
  foreach($t in ($allTests|Sort-Object testId)){
    Write-Host "  $($t.testId)" -ForegroundColor White
    Write-Host "    Name: $($t.displayName)  |  Lane: $($t.ownerLane)  |  Proof: $($t.proofLevel)"
  }
  Write-Host "`nProfiles:"
  foreach($p in $profiles){Write-Host "  $($p.profileId) - $($p.displayName): $($p.description)"}
  exit 0
}
if($Command -eq 'status'){
  Write-Host "ForgeTest Status" -ForegroundColor Cyan
  Write-Host "  Branch: $($gitCtx.branch)  Head: $($gitCtx.head)"
  Write-Host "  Profiles: $(@($profiles).Count)  Tests: $(@($allTests).Count)"
  exit 0
}
if($Command -ne 'run'){Write-Host "Unknown command '$Command'. Use: list, status, run" -ForegroundColor Red;exit 1}

# Select profile
$selProfile=$null
if($Profile){
  foreach($p in $profiles){if($p.profileId -eq $Profile){$selProfile=$p;break}}
  if($null -eq $selProfile){
    $avail=@();foreach($p in $profiles){$avail+=$p.profileId}
    throw "Unknown profile '$Profile'. Available: $($avail -join ', ')"
  }
}else{
  foreach($p in $profiles){if($p.profileId -eq 'default-static'){$selProfile=$p;break}}
  if($null -eq $selProfile){foreach($p in $profiles){$selProfile=$p;break}}
  if($null -eq $selProfile){throw "No profiles found"}
}

# Select tests by profile or --test
$selectedTests=@()
if($Test){
  foreach($t in $allTests){if($t.testId -eq $Test){$selectedTests=@($t);break}}
  if(@($selectedTests).Count -eq 0){throw "Unknown test ID '$Test'"}
}else{
  foreach($t in $allTests){
    $matched=$false
    $mem=@($t.defaultProfileMembership)
    foreach($m in $mem){if($m -eq $selProfile.profileId){$matched=$true;break}}
    if(-not $matched){
      $tg=@($t.tags);$ptg=@($selProfile.includeTags)
      if(@($ptg).Count -gt 0){
        foreach($tag in $tg){foreach($pt in $ptg){if($tag -eq $pt){$matched=$true;break}};if($matched){break}}
      }
    }
    if($matched){
      $eid=@($selProfile.excludeTestIds)
      foreach($id in $eid){if($id -eq $t.testId){$matched=$false;break}}
    }
    if($matched){
      $etg=@($selProfile.excludeTags)
      if(@($etg).Count -gt 0){
        foreach($tag in $t.tags){foreach($et in $etg){if($tag -eq $et){$matched=$false;break}};if(-not $matched){break}}
      }
    }
    if($matched){$selectedTests+=$t}
  }
}

if(@($selectedTests).Count -eq 0){throw "No tests match the selected profile/test."}

Write-Event 'run.started'
Write-Event 'profile.selected' -Payload @{profileId=$selProfile.profileId}
Write-Host "`n=== ForgeTest [$($selProfile.profileId)] ===" -ForegroundColor Cyan
Write-Host "Run ID: $runId" -ForegroundColor Yellow
Write-Host "Tests selected: $(@($selectedTests).Count)" -ForegroundColor Yellow
Write-Host ""

$results=@()

foreach($t in $selectedTests){
  $tOut=Join-Path $OutputRoot $t.testId
  
  $supp=$false
  foreach($h in @($t.supportedHosts)){if($h -eq 'win'-or$h -eq 'win_pwsh'-or$h -eq 'win_powershell'){$supp=$true;break}}
  if(-not $supp){
    Write-Event 'test.skipped' -TestId $t.testId -Payload @{reason="Unsupported host"}
    Write-Progress 'SKIP' $t.testId "Unsupported host"
    $results+=[pscustomobject]@{testId=$t.testId;status='skipped';exitCode=0;message='Unsupported host';elapsed='00:00:00';proofLevel=$t.proofLevel}
    continue
  }
  
  $missing=@()
  foreach($tool in @($t.requiredTools)){$found=Get-Command $tool -ErrorAction SilentlyContinue;if($null -eq $found){$missing+=$tool}}
  if(@($missing).Count -gt 0){
    $msg="Missing tools: $($missing -join ', ')"
    Write-Event 'test.skipped' -TestId $t.testId -Payload @{reason=$msg}
    Write-Progress 'SKIP' $t.testId $msg
    $results+=[pscustomobject]@{testId=$t.testId;status='skipped';exitCode=0;message=$msg;elapsed='00:00:00';proofLevel=$t.proofLevel}
    continue
  }
  
  $script:testResult=$null
  try{Invoke-Test $t $tOut}
  catch{
    $script:testResult=[pscustomobject]@{testId=$t.testId;status='failed';exitCode=-1;message="Exception: $_";elapsed='00:00:00';proofLevel=$t.proofLevel}
    Write-Progress 'FAIL' $t.testId "Exception: $_"
  }
  $results+=$script:testResult
}

$resultList=@($results)
$anyFailed=$false
foreach($r in $resultList){if($r.status -eq 'failed'){$anyFailed=$true}}
$status=if($anyFailed){'failed'}else{'completed'}
$ceiling="Observed through $($script:proofLevel). No higher claim."
Write-Event $(if($status -eq 'completed'){'run.completed'}else{'run.blocked'})

# Write events artifact registry and result
$runCtx=[ordered]@{schema=$schemaVersion;runId=$runId;correlationId=$correlationId;generatedUtc=[DateTime]::UtcNow.ToString('o')
  repository='EndeavorEverlasting/BlacksmithGuild';profile=$selProfile.profileId
  git=@{branch=$gitCtx.branch;head=$gitCtx.head;dirty=$gitCtx.dirty}
  authority=@{observer=$false;launcher=$false;gameMutation=$false;deployment=$false}
  purpose="One-click test: $($selProfile.profileId)"}
$runCtx|ConvertTo-Json -Depth 10|Set-Content (Join-Path $OutputRoot 'run-context.json') -Encoding UTF8

foreach($e in $global:tbgEvents){$e|ConvertTo-Json -Depth 5 -Compress|Add-Content (Join-Path $OutputRoot 'events.jsonl') -Encoding UTF8}

$testsJson=@()
foreach($r in $resultList){
  $testsJson+=[ordered]@{testId=$r.testId;status=$r.status;exitCode=$r.exitCode;message=$r.message;elapsed=$r.elapsed;proofLevel=$r.proofLevel}
}
[ordered]@{schema='tbg.one-click-test.result.v1';runId=$runId;correlationId=$correlationId;profile=$selProfile.profileId
  status=$status;proofLevel=$script:proofLevel;proofCeiling=$ceiling;tests=$testsJson
  finalGit=@{branch=$gitCtx.branch;head=$gitCtx.head;dirty=$gitCtx.dirty}}|
  ConvertTo-Json -Depth 20|Set-Content (Join-Path $OutputRoot 'result.json') -Encoding UTF8

Write-Report -Path (Join-Path $OutputRoot 'operator-report.md') -Run $runId -Prof $selProfile.profileId -Status $status -PLevel $script:proofLevel -Ceil $ceiling -Results $resultList

Copy-Item (Join-Path $OutputRoot 'result.json') (Join-Path $latestDir 'one-click-test.result.json') -Force
Copy-Item (Join-Path $OutputRoot 'operator-report.md') (Join-Path $latestDir 'one-click-test.report.md') -Force

Write-Host "`n=== ForgeTest $status ===" -ForegroundColor $(if($status -eq 'completed'){'Green'}else{'Red'})
Write-Host "Result: $(Join-Path $OutputRoot 'result.json')" -ForegroundColor Cyan

if($status -eq 'completed'){
  if(-not $NoPause -and (-not $env:CI)){Write-Host "`nPress any key..." -ForegroundColor Gray;$null=$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')}
  exit 0
}else{exit 1}
