param([string]$RepoRoot='',[string]$OutputRoot='artifacts/latest/one-click-cascade')
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
if(-not $RepoRoot){$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path}
$RepoRoot=[IO.Path]::GetFullPath($RepoRoot);$e=@();$p=0
function Add-Check([bool]$C,[string]$N,[string]$M='failed'){if($C){$script:p=$script:p+1;Write-Host "[PASS] $N" -ForegroundColor Green}else{$script:e+="${N}: $M";Write-Host "[FAIL] $N - $M" -ForegroundColor Red}}
function RepoPath([string]$R){Join-Path $RepoRoot ($R -replace '/','\')}
$req=@('scripts/tbg/Resolve-TbgOneClickCascade.ps1','scripts/tbg/Test-TbgOneClickCascade.ps1')
foreach($f in $req){Add-Check (Test-Path (RepoPath $f) -PathType Leaf) "required/$f"}
$cascadeScript=RepoPath 'scripts/tbg/Resolve-TbgOneClickCascade.ps1'
$tokens=$null;$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile($cascadeScript,[ref]$tokens,[ref]$parseErrors)
$parseOk=$parseErrors.Count -eq 0;$parseErrStr=''
if(-not $parseOk){$parts=@();foreach($pe in $parseErrors){$parts+=$pe.Message};$parseErrStr=$parts-join'; '}
Add-Check $parseOk 'parse/Resolve-TbgOneClickCascade.ps1' $parseErrStr
$triggersDir=RepoPath '.tbg/harness/triggers.d'
Add-Check (Test-Path $triggersDir -PathType Container) 'cascade/triggers-dir'
# Build a minimal run fixture to test cascade processing
$fixtureRoot=Join-Path $RepoRoot '.local\tbg-cascade-test-fixture'
New-Item -ItemType Directory -Force -Path $fixtureRoot|Out-Null
$fixtureEvents=@'
{"eventId":"e1","eventType":"test.started","runId":"fixture-run","correlationId":"fx-corr","testId":"test.a","timestamp":"2026-07-19T12:00:00Z","ingestionSequence":1,"source":"test","proofLevel":"static test","payload":{}}
{"eventId":"e2","eventType":"test.failed","runId":"fixture-run","correlationId":"fx-corr","testId":"test.b","timestamp":"2026-07-19T12:00:01Z","ingestionSequence":2,"source":"test","proofLevel":"static test","payload":{"exitCode":1,"reason":"assertion failure"}}
{"eventId":"e3","eventType":"artifact.registered","runId":"fixture-run","correlationId":"fx-corr","testId":"test.c","timestamp":"2026-07-19T12:00:02Z","ingestionSequence":3,"source":"test","proofLevel":"static test","payload":{"path":"test-c-output.log"}}
{"eventId":"e4","eventType":"observer.completed","runId":"fixture-run","correlationId":"fx-corr","testId":"observer.a","timestamp":"2026-07-19T12:00:03Z","ingestionSequence":4,"source":"test","proofLevel":"harness","payload":{"observerResult":"clean"}}
'@
$fixtureEvents|Set-Content (Join-Path $fixtureRoot 'events.jsonl') -Encoding UTF8
# Run cascade
try{
  $result=./scripts/tbg/Resolve-TbgOneClickCascade.ps1 -RunRoot $fixtureRoot -OutputRoot (Join-Path $fixtureRoot 'cascade-output') 2>&1
  $resultPath=Join-Path $fixtureRoot 'cascade-output\cascade-result.json'
  Add-Check (Test-Path $resultPath -PathType Leaf) 'cascade/runs'
  if(Test-Path $resultPath){
    $cr=Get-Content $resultPath -Raw|ConvertFrom-Json
    Add-Check ($cr.schema -eq 'tbg.one-click-cascade.v1') 'cascade/result-schema'
    Add-Check ($cr.eventCount -ge 4) 'cascade/event-count' "Expected >=4 got $($cr.eventCount)"
    Add-Check ($cr.matchedTriggerCount -ge 2) 'cascade/trigger-matches' "Expected >=2 got $($cr.matchedTriggerCount)"
  }
  $ledgerPath=Join-Path $fixtureRoot 'cascade-output\trigger-ledger.json'
  if(Test-Path $ledgerPath){
    $ledger=Get-Content $ledgerPath -Raw|ConvertFrom-Json
    Add-Check (@($ledger).Count -ge 2) 'cascade/ledger-entries' "Expected >=2 got $(@($ledger).Count)"
  }
}catch{Add-Check $false 'cascade/execution' "Cascade execution failed: $_"}
Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
$output=if([IO.Path]::IsPathRooted($OutputRoot)){[IO.Path]::GetFullPath($OutputRoot)}else{RepoPath $OutputRoot}
New-Item -ItemType Directory -Force -Path $output|Out-Null
$s=if($e.Count){'FAIL'}else{'PASS'}
[ordered]@{schema='tbg.one-click-cascade-test.v1';generatedUtc=[DateTime]::UtcNow.ToString('o');status=$s;passes=$p;errors=@($e);proofLevel='static test'}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $output 'one-click-cascade.validation.json')-Encoding UTF8
Write-Host "Cascade validation: $s - $p passed, $($e.Count) failed"
if($e.Count){exit 1}
