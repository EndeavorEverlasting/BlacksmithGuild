[CmdletBinding()]
param([string]$RepoRoot = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Add-Pass([string]$Message) { $script:passes++; Write-Host ('PASS: {0}' -f $Message) -ForegroundColor Green }
function Add-Failure([string]$Message) { $script:failures.Add($Message) | Out-Null; Write-Host ('FAIL: {0}' -f $Message) -ForegroundColor Red }
function Assert-Tbg([bool]$Condition, [string]$Message) { if ($Condition) { Add-Pass $Message } else { Add-Failure $Message } }

$fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\version-upgrade-impact.fixtures.json'
$registryPath = Join-Path $RepoRoot '.tbg\state\version-upgrade-impact.registry.json'
$workflowPath = Join-Path $RepoRoot '.tbg\workflows\version-upgrade-impact-probe.contract.json'
$artifactRegistryPath = Join-Path $RepoRoot '.tbg\harness\version-upgrade-impact-artifacts.registry.json'
$schemaPath = Join-Path $RepoRoot '.tbg\harness\schemas\version-upgrade-impact-result.schema.json'
$invokePath = Join-Path $PSScriptRoot 'Invoke-TbgVersionUpgradeImpactProbe.ps1'
$publishPath = Join-Path $PSScriptRoot 'Publish-TbgVersionUpgradeSprintPacket.ps1'
$projectPath = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'

foreach ($required in @($fixturePath,$registryPath,$workflowPath,$artifactRegistryPath,$schemaPath,$invokePath,$publishPath,$projectPath)) {
    Assert-Tbg (Test-Path -LiteralPath $required -PathType Leaf) ('required file exists: {0}' -f [IO.Path]::GetFileName($required))
}

try { $fixtures = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'fixture JSON parses' } catch { Add-Failure ('fixture JSON parses: {0}' -f $_.Exception.Message); exit 1 }
try { $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'registry JSON parses' } catch { Add-Failure ('registry JSON parses: {0}' -f $_.Exception.Message); exit 1 }
try { $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'workflow JSON parses' } catch { Add-Failure ('workflow JSON parses: {0}' -f $_.Exception.Message); exit 1 }
try { $artifactRegistry = Get-Content -LiteralPath $artifactRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'artifact registry JSON parses' } catch { Add-Failure ('artifact registry JSON parses: {0}' -f $_.Exception.Message); exit 1 }
try { $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'result schema JSON parses' } catch { Add-Failure ('result schema JSON parses: {0}' -f $_.Exception.Message); exit 1 }

Assert-Tbg ([string]$workflow.proofCeiling -eq 'candidate static/build compatibility') 'workflow proof ceiling remains static/build compatibility'
Assert-Tbg ($workflow.mutatesGameInstall -eq $false) 'workflow forbids game-install mutation'
Assert-Tbg ($workflow.mutatesProductSource -eq $false) 'workflow forbids product-source mutation'
Assert-Tbg ($workflow.remoteEmission.remoteWriteRequiresExplicitPublishSwitch -eq $true) 'remote issue publication requires explicit operator switch'
Assert-Tbg ($workflow.remoteEmission.ciMayPublishIssues -eq $false) 'CI cannot publish upgrade issues'
Assert-Tbg ($workflow.remoteEmission.prePushMayPublishIssues -eq $false) 'pre-push cannot publish upgrade issues'
Assert-Tbg (@($registry.candidateAssemblies).Count -eq 9) 'registry tracks all nine Bannerlord project assembly references'

$projectText = Get-Content -LiteralPath $projectPath -Raw -Encoding UTF8
foreach ($assembly in @($registry.candidateAssemblies)) {
    Assert-Tbg ($projectText.Contains(('Reference Include="{0}"' -f [string]$assembly.include))) ('project reference tracked: {0}' -f [string]$assembly.include)
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-version-upgrade-impact-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
    foreach ($case in @($fixtures.cases)) {
        $caseOutput = Join-Path $tempRoot ([string]$case.id)
        $result = & $invokePath -Mode fixture -FixturePath $fixturePath -FixtureCaseId ([string]$case.id) -RepoRoot $RepoRoot -OutputDirectory $caseOutput -NoExit -PassThru
        Assert-Tbg ([string]$result.terminalState -eq [string]$case.expectedTerminalState) ('fixture {0} terminal state' -f [string]$case.id)
        Assert-Tbg ([string]$result.proofCeiling -eq 'candidate static/build compatibility') ('fixture {0} proof ceiling' -f [string]$case.id)

        if ($null -ne $case.PSObject.Properties['expectedSprintCount']) {
            Assert-Tbg (@($result.sprintCandidates).Count -eq [int]$case.expectedSprintCount) ('fixture {0} sprint count' -f [string]$case.id)
        }
        if ($null -ne $case.PSObject.Properties['expectedSprintOwners']) {
            $owners = @($result.sprintCandidates | ForEach-Object { [string]$_.owner })
            foreach ($expectedOwner in @($case.expectedSprintOwners)) {
                Assert-Tbg ($owners -contains [string]$expectedOwner) ('fixture {0} routes sprint to {1}' -f [string]$case.id,[string]$expectedOwner)
            }
        }

        $issuePath = [string]$result.evidencePaths.issueDraft
        Assert-Tbg (Test-Path -LiteralPath $issuePath -PathType Leaf) ('fixture {0} emits issue draft' -f [string]$case.id)
        if (Test-Path -LiteralPath $issuePath -PathType Leaf) {
            $issueText = Get-Content -LiteralPath $issuePath -Raw -Encoding UTF8
            Assert-Tbg ($issueText.Contains('## Actionable sprint order')) ('fixture {0} issue contains sprint order' -f [string]$case.id)
            Assert-Tbg (-not ($issueText -match '(?i)[A-Z]:\\Users\\|/home/[^/]+/')) ('fixture {0} issue is path-sanitized' -f [string]$case.id)
        }
    }

    $compileBreak = & $invokePath -Mode fixture -FixturePath $fixturePath -FixtureCaseId 'candidate_compile_break' -RepoRoot $RepoRoot -OutputDirectory (Join-Path $tempRoot 'compile-break-repeat') -NoExit -PassThru
    $compileFinding = @($compileBreak.findings | Where-Object { $_.probeFamily -eq 'candidate_compile' } | Select-Object -First 1)
    Assert-Tbg ($compileFinding.Count -eq 1) 'compile break produces a compile finding'
    if ($compileFinding.Count -eq 1) {
        Assert-Tbg ([string]$compileFinding[0].ownerLane -eq 'route-visible-trade') 'MapTrade compile break routes to route-visible-trade'
        Assert-Tbg ([string]$compileFinding[0].evidence.code -eq 'CS0117') 'compile finding preserves compiler code'
    }

    $dynamicCase = & $invokePath -Mode fixture -FixturePath $fixturePath -FixtureCaseId 'candidate_dynamic_binding_review' -RepoRoot $RepoRoot -OutputDirectory (Join-Path $tempRoot 'dynamic-repeat') -NoExit -PassThru
    $dynamicFinding = @($dynamicCase.findings | Where-Object { $_.probeFamily -eq 'dynamic_binding_inventory' } | Select-Object -First 1)
    Assert-Tbg ($dynamicFinding.Count -eq 1) 'version change exposes dynamic binding review finding'
    if ($dynamicFinding.Count -eq 1) { Assert-Tbg ([string]$dynamicFinding[0].ownerLane -eq 'launcher-lifecycle') 'QuickStart dynamic binding routes to launcher-lifecycle' }

    $invokeText = Get-Content -LiteralPath $invokePath -Raw -Encoding UTF8
    foreach ($forbidden in @('Start-Process','ForgeReboot.cmd','BlacksmithGuild_CommandInbox','copy-client-dll.ps1','gh issue create')) {
        Assert-Tbg (-not $invokeText.Contains($forbidden)) ('probe omits runtime/remote mutation token: {0}' -f $forbidden)
    }
    Assert-Tbg ($invokeText.Contains('-p:OutputPath=') -and $invokeText.Contains('-p:WEditorOutputPath=')) 'candidate compile redirects outputs away from product module paths'

    $publishText = Get-Content -LiteralPath $publishPath -Raw -Encoding UTF8
    Assert-Tbg ($publishText.Contains('[switch]$PublishIssue')) 'publisher exposes explicit PublishIssue switch'
    Assert-Tbg ($publishText.Contains('issue list') -and $publishText.Contains('issue create')) 'publisher deduplicates before creating an issue'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ('`nVersion upgrade impact validation: {0} passed, {1} failed' -f $passes,$failures.Count) -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host ('  {0}' -f $failure) -ForegroundColor Red }
    exit 1
}
Write-Host 'VERSION_UPGRADE_IMPACT_TESTS_REACHED_FINAL_SENTINEL' -ForegroundColor Green
exit 0
