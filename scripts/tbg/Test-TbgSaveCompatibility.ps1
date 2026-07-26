[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

$failures = [System.Collections.Generic.List[string]]::new()
$passes = 0
function Add-Pass([string]$Message) { $script:passes++; Write-Host "PASS: $Message" -ForegroundColor Green }
function Add-Failure([string]$Message) { $script:failures.Add($Message) | Out-Null; Write-Host "FAIL: $Message" -ForegroundColor Red }
function Assert-Tbg([bool]$Condition, [string]$Message) { if ($Condition) { Add-Pass $Message } else { Add-Failure $Message } }
function Get-TestSha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToUpperInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

$fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\save-compatibility.fixtures.json'
$registryPath = Join-Path $RepoRoot '.tbg\state\save-compatibility.registry.json'
$workflowPath = Join-Path $RepoRoot '.tbg\workflows\save-compatibility-classification.contract.json'
$artifactRegistryPath = Join-Path $RepoRoot '.tbg\harness\save-compatibility-artifacts.registry.json'
$invokePath = Join-Path $PSScriptRoot 'Invoke-TbgSaveCompatibility.ps1'

foreach ($required in @($fixturePath, $registryPath, $workflowPath, $artifactRegistryPath, $invokePath)) {
    Assert-Tbg (Test-Path -LiteralPath $required -PathType Leaf) "required file exists: $([IO.Path]::GetFileName($required))"
}

try { $fixtures = Get-Content -LiteralPath $fixturePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'fixture JSON parses' } catch { Add-Failure "fixture JSON parses: $($_.Exception.Message)"; exit 1 }
try { $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'registry JSON parses' } catch { Add-Failure "registry JSON parses: $($_.Exception.Message)"; exit 1 }
try { $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'workflow JSON parses' } catch { Add-Failure "workflow JSON parses: $($_.Exception.Message)"; exit 1 }
try { $artifactRegistry = Get-Content -LiteralPath $artifactRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop; Add-Pass 'artifact registry JSON parses' } catch { Add-Failure "artifact registry JSON parses: $($_.Exception.Message)"; exit 1 }

Assert-Tbg ([string]$workflow.proofCeiling -eq 'real-file read-only parsing') 'workflow proof ceiling remains read-only parsing'
Assert-Tbg ($workflow.mutatesSaves -eq $false) 'workflow forbids save mutation'
Assert-Tbg ([string]$registry.newSaveContract.creationOwnedBy -eq 'launcher/runtime lane') 'new-save creation stays outside harness authority'
Assert-Tbg ([string]$registry.proofBoundary -match 'does not prove successful load') 'registry separates compatibility from load proof'

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('tbg-save-compatibility-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    foreach ($case in @($fixtures.cases)) {
        $caseRoot = Join-Path $tempRoot ([string]$case.id)
        New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
        $savePath = Join-Path $caseRoot ([string]$case.leafName)
        [IO.File]::WriteAllBytes($savePath, [Text.Encoding]::ASCII.GetBytes([string]$case.headerText))
        $beforeHash = Get-TestSha256 $savePath
        $beforeWrite = (Get-Item -LiteralPath $savePath).LastWriteTimeUtc
        $output = Join-Path $caseRoot 'out'
        $result = & $invokePath -Mode gate -SavePath $savePath -TargetSavePath $savePath -GameVersion ([string]$fixtures.gameVersion) -RepoRoot $RepoRoot -OutputDirectory $output -NoExit -PassThru
        Assert-Tbg ([string]$result.targetGateTerminalState -eq [string]$case.expectedTerminalState) "fixture $($case.id) terminal state"
        $record = @($result.saveRecords | Where-Object { $_.leafName -eq [string]$case.leafName } | Select-Object -First 1)
        Assert-Tbg ($record.Count -eq 1) "fixture $($case.id) produced one save record"
        if ($record.Count -eq 1) {
            Assert-Tbg ([string]$record[0].role -eq [string]$case.expectedRole) "fixture $($case.id) role"
            Assert-Tbg ([bool]$record[0].autoLoadEligible -eq [bool]$case.expectedAutoLoadEligible) "fixture $($case.id) auto-load eligibility"
        }
        Assert-Tbg ((Get-TestSha256 $savePath) -eq $beforeHash) "fixture $($case.id) bytes unchanged"
        Assert-Tbg ((Get-Item -LiteralPath $savePath).LastWriteTimeUtc -eq $beforeWrite) "fixture $($case.id) write timestamp unchanged"
    }

    foreach ($pairCase in @($fixtures.pairCases)) {
        $caseRoot = Join-Path $tempRoot ([string]$pairCase.id)
        $nativeRoot = Join-Path $caseRoot 'Native'
        New-Item -ItemType Directory -Force -Path $nativeRoot | Out-Null
        $leftPath = Join-Path $caseRoot ([string]$pairCase.leftLeafName)
        $rightPath = Join-Path $nativeRoot ([string]$pairCase.rightLeafName)
        $leftText = if ($null -ne $pairCase.PSObject.Properties['headerText']) { [string]$pairCase.headerText } else { [string]$pairCase.leftHeaderText }
        $rightText = if ($null -ne $pairCase.PSObject.Properties['headerText']) { [string]$pairCase.headerText } else { [string]$pairCase.rightHeaderText }
        [IO.File]::WriteAllBytes($leftPath, [Text.Encoding]::ASCII.GetBytes($leftText))
        [IO.File]::WriteAllBytes($rightPath, [Text.Encoding]::ASCII.GetBytes($rightText))
        $leftHashBefore = Get-TestSha256 $leftPath
        $rightHashBefore = Get-TestSha256 $rightPath
        $result = & $invokePath -Mode gate -SavePath @($leftPath, $rightPath) -TargetSavePath $leftPath -GameVersion ([string]$fixtures.gameVersion) -RepoRoot $RepoRoot -OutputDirectory (Join-Path $caseRoot 'out') -NoExit -PassThru
        Assert-Tbg ([bool]$result.approvedAliasPair.byteIdentical -eq [bool]$pairCase.expectedByteIdentical) "pair fixture $($pairCase.id) byte identity"
        Assert-Tbg ([string]$result.targetGateTerminalState -eq [string]$pairCase.expectedTerminalState) "pair fixture $($pairCase.id) terminal state"
        Assert-Tbg ((Get-TestSha256 $leftPath) -eq $leftHashBefore -and (Get-TestSha256 $rightPath) -eq $rightHashBefore) "pair fixture $($pairCase.id) bytes unchanged"
    }

    $catalogRoot = Join-Path $tempRoot 'catalog_mixed_versions'
    New-Item -ItemType Directory -Force -Path $catalogRoot | Out-Null
    $exactPath = Join-Path $catalogRoot 'BlacksmithGuildDevStart.sav'
    $newerPath = Join-Path $catalogRoot 'saveauto1.sav'
    [IO.File]::WriteAllBytes($exactPath, [Text.Encoding]::ASCII.GetBytes('ApplicationVersion=1.4.6.115628'))
    [IO.File]::WriteAllBytes($newerPath, [Text.Encoding]::ASCII.GetBytes('ApplicationVersion=1.4.7.117484'))
    $catalog = & $invokePath -Mode catalog -SavePath @($exactPath, $newerPath) -GameVersion ([string]$fixtures.gameVersion) -RepoRoot $RepoRoot -OutputDirectory (Join-Path $catalogRoot 'out') -NoExit -PassThru
    Assert-Tbg ([string]$catalog.terminalState -eq 'PASS_SAVE_CATALOG_CLASSIFIED') 'catalog mode classifies mixed-version saves without treating an unrelated autosave as the selected target'
    Assert-Tbg (@($catalog.saveRecords | Where-Object { $_.leafName -eq 'saveauto1.sav' -and $_.terminalState -eq 'BLOCKED_SAVE_NEWER_THAN_GAME' }).Count -eq 1) 'catalog preserves newer autosave block classification'

    $scriptText = Get-Content -LiteralPath $invokePath -Raw -Encoding UTF8
    foreach ($forbidden in @('Set-ItemProperty','LastWriteTime =','LastAccessTime =','Copy-Item -LiteralPath $path','Remove-Item -LiteralPath $path','Start-Process','BlacksmithGuild_CommandInbox')) {
        Assert-Tbg (-not $scriptText.Contains($forbidden)) "classifier omits save/runtime mutation token: $forbidden"
    }
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nSave compatibility validation: $passes passed, $($failures.Count) failed" -ForegroundColor $(if ($failures.Count -eq 0) { 'Green' } else { 'Red' })
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "  $failure" -ForegroundColor Red }
    exit 1
}
Write-Host 'SAVE_COMPATIBILITY_TESTS_REACHED_FINAL_SENTINEL' -ForegroundColor Green
exit 0
