[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Assert-True([bool]$Condition,[string]$Message) { if(-not $Condition){throw $Message}; Write-Host "PASS: $Message" -ForegroundColor Green }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Assert-Bom([string]$Path) { $b=[IO.File]::ReadAllBytes($Path); Assert-True ($b.Length -ge 3 -and $b[0] -eq 0xef -and $b[1] -eq 0xbb -and $b[2] -eq 0xbf) "UTF-8 BOM: $([IO.Path]::GetFileName($Path))" }
$scripts=@('Start-TbgGameRuntimeObserver.ps1','Get-TbgWindowsCrashEvidence.ps1','Get-TbgTaleWorldsCrashEvidence.ps1','Get-TbgRuntimeHeartbeatEvidence.ps1')
foreach($name in $scripts) {
    $path=Join-Path $PSScriptRoot $name
    Assert-True (Test-Path -LiteralPath $path) "observer script exists: $name"
    $tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)|Out-Null
    Assert-True (@($errors).Count -eq 0) "PowerShell parses: $name"
    Assert-Bom $path
}
$fixturePath=Join-Path $repoRoot '.tbg\harness\fixtures\game-runtime-observer.fixtures.json'
$fixture=Read-Json $fixturePath
Assert-True ($fixture.schema -eq 'TbgGameRuntimeObserverFixture.v1') 'fixture schema'
$ids=@($fixture.cases|ForEach-Object id)
foreach($id in @('clean-exit','exit-without-wer','wer-native-crash','taleworlds-report','stale-log-healthy-process','missing-observer','hang-suspected','wrong-run','duplicate-wer','process-reconciliation')) { Assert-True ($ids -contains $id) "fixture case: $id" }
Assert-True (@($fixture.nonEquivalences) -contains 'stale_log_alone_is_not_native_crash_confirmed') 'fixture preserves stale-log boundary'
$temp=Join-Path ([IO.Path]::GetTempPath()) ("tbg-game-runtime-observer-$([Guid]::NewGuid().ToString('N'))")
try {
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    # Disposable child smoke: the observer watches only this test PID and never Bannerlord.
    $child=Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c','timeout /t 2 /nobreak >nul' -PassThru
    $start=Join-Path $PSScriptRoot 'Start-TbgGameRuntimeObserver.ps1'
    $result=& $start -Command start -DurationSeconds 5 -OutputRoot $temp -TestProcessId $child.Id -PassThru
    Assert-True (Test-Path -LiteralPath (Join-Path $result.runRoot 'events.jsonl')) 'disposable process smoke emitted events'
    $events=@(Get-Content -LiteralPath (Join-Path $result.runRoot 'events.jsonl') -Encoding UTF8 | Where-Object {$_} | ForEach-Object {$_|ConvertFrom-Json})
    Assert-True (@($events|Where-Object {$_.eventType -eq 'process.started'}).Count -ge 1) 'disposable process start observed'
    Assert-True (@($events|Where-Object {$_.eventType -eq 'process.exited'}).Count -ge 1) 'disposable process exit observed'
    $status=& $start -Command status -RunId $result.runId -OutputRoot $temp -PassThru
    Assert-True ($status.leaseId -eq $result.leaseId) 'owned lease status'
    & (Join-Path $PSScriptRoot 'Get-TbgWindowsCrashEvidence.ps1') -RunId 'eventlog-smoke' -CorrelationId 'eventlog-smoke' -SinceUtc ([DateTime]::UtcNow.AddMinutes(-1)) -OutputRoot $temp | Out-Null
    $werPath=Join-Path $temp 'eventlog-smoke\windows-crash-evidence.jsonl'
    $werText=if(Test-Path $werPath){Get-Content $werPath -Raw -Encoding UTF8}else{''}
    Assert-True (-not ([string]$werText -match '(?i)unrelated-process-attribution')) 'bounded event-log query avoids false attribution'
    & (Join-Path $PSScriptRoot 'Get-TbgTaleWorldsCrashEvidence.ps1') -RunId 'no-data-smoke' -CorrelationId 'no-data-smoke' -SearchRoots @($temp) -OutputRoot $temp | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $temp 'no-data-smoke\taleworlds-crash-evidence.jsonl')) 'TaleWorlds no-data collector writes bounded result'
    $heartbeat=& (Join-Path $PSScriptRoot 'Get-TbgRuntimeHeartbeatEvidence.ps1') -RunId 'heartbeat-smoke' -CorrelationId 'heartbeat-smoke' -ObserverActive:$false -OutputRoot $temp -PassThru
    Assert-True (@($heartbeat|Where-Object {$_.eventType -eq 'observer.gap'}).Count -eq 1) 'missing observer remains unknown evidence'
} finally { if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force} }
Write-Host 'PASS: game runtime observer static and disposable-process smoke checks completed.'
