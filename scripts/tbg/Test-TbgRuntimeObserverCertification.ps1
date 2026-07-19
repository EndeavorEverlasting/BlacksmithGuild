[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runnerPath = Join-Path $PSScriptRoot 'Invoke-TbgRuntimeObserverCertification.ps1'
$fixturePath = Join-Path $repoRoot '.tbg\harness\fixtures\runtime-observer-certification.fixtures.json'

function Assert-Tbg([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Host "PASS: $Message" -ForegroundColor Green
}
function Assert-TbgBom([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    Assert-Tbg ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) "UTF-8 BOM: $([IO.Path]::GetFileName($Path))"
}

foreach ($path in @($runnerPath, $fixturePath, $PSCommandPath)) {
    Assert-Tbg (Test-Path -LiteralPath $path -PathType Leaf) "Certification surface exists: $([IO.Path]::GetFileName($path))"
}
Assert-TbgBom $runnerPath
Assert-TbgBom $PSCommandPath
$tokens = $null
$parseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($runnerPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
Assert-Tbg (@($parseErrors).Count -eq 0) 'Certification runner parses in Windows PowerShell.'

$fixture = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Tbg ($fixture.schema -eq 'TbgRuntimeObserverCertificationFixture.v1') 'Certification fixture schema is canonical.'
$expectedScenarios = @('composed-fixture-validation', 'disposable-windows-smoke', 'missing-live-authority', 'authorized-live-observation')
foreach ($id in $expectedScenarios) {
    $scenario = @($fixture.scenarios | Where-Object { $_.id -eq $id })
    Assert-Tbg ($scenario.Count -eq 1) "Fixture scenario '$id' occurs exactly once."
    Assert-Tbg (-not [string]::IsNullOrWhiteSpace([string]$scenario[0].expectedProofLevel)) "Fixture scenario '$id' declares an exact proof level."
    Assert-Tbg (@($scenario[0].forbiddenClaims).Count -gt 0) "Fixture scenario '$id' declares forbidden claims."
}
$blocked = @($fixture.scenarios | Where-Object id -eq 'missing-live-authority' | Select-Object -First 1)
Assert-Tbg ([string]$blocked[0].expectedTerminalState -eq 'BLOCKED_live_authority_missing') 'Missing authority fixture fails closed.'
$authorized = @($fixture.scenarios | Where-Object id -eq 'authorized-live-observation' | Select-Object -First 1)
Assert-Tbg ((@($authorized[0].requiredAuthority) -join '|') -match 'active_owned') 'Authorized live fixture requires an owned session.'

$temporaryOutput = Join-Path ([IO.Path]::GetTempPath()) ('tbg-runtime-observer-certification-test-' + [Guid]::NewGuid().ToString('N'))
try {
    $result = & $runnerPath -Mode fixtures -OutputRoot $temporaryOutput -PassThru
    Assert-Tbg ($result.terminalState -eq 'BLOCKED_live_authority_missing') 'Fixture certification reports the live-authority blocker.'
    Assert-Tbg ($result.proofLevel -eq 'static_test') 'Fixture certification remains at static-test proof.'
    Assert-Tbg (@($result.checks | Where-Object { $_.id -eq 'fixture.composed-fixture-validation' -and $_.status -eq 'passed' }).Count -eq 1) 'Fixture certification composes the observer scenario.'
    Assert-Tbg (@($result.checks | Where-Object { $_.id -eq 'live.authority_gate' -and $_.status -eq 'blocked' }).Count -eq 1) 'Fixture certification does not attempt live attachment without authority.'
    Assert-Tbg (Test-Path -LiteralPath (Join-Path $temporaryOutput 'runtime-observer-certification.result.json') -PathType Leaf) 'Fixture certification wrote its local result.'
} finally {
    if (Test-Path -LiteralPath $temporaryOutput) { Remove-Item -LiteralPath $temporaryOutput -Recurse -Force }
}
Write-Host 'PASS: runtime observer certification fixtures enforce exact proof ceilings and fail closed without live authority.'
