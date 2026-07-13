[CmdletBinding()]
param(
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)

function Assert-Tbg {
    param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-TbgFileContains {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)
    Assert-Tbg -Condition (Test-Path -LiteralPath $Path -PathType Leaf) -Message "Required file is missing: $Path"
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert-Tbg -Condition $content.Contains($Text) -Message "Expected '$Text' in $Path."
}

$scriptPath = Join-Path $RepoRoot 'scripts/tbg/Invoke-TbgGameCompatibility.ps1'
$wrapperPath = Join-Path $RepoRoot 'ForgeGameUpdate.cmd'
$registryPath = Join-Path $RepoRoot '.tbg/state/game-compatibility.registry.json'
$schemaPath = Join-Path $RepoRoot '.tbg/harness/schemas/game-compatibility-result.schema.json'
$contractPath = Join-Path $RepoRoot '.tbg/workflows/bannerlord-game-compatibility-updater.contract.json'
$manifestFixture = Join-Path $RepoRoot '.tbg/harness/fixtures/game-compatibility/appmanifest_261550.fixture.acf'
$upToDateFixture = Join-Path $RepoRoot '.tbg/harness/fixtures/game-compatibility/up-to-date.fixture.json'
$updateFixture = Join-Path $RepoRoot '.tbg/harness/fixtures/game-compatibility/update-available.fixture.json'

foreach ($required in @($scriptPath, $wrapperPath, $registryPath, $schemaPath, $contractPath, $manifestFixture, $upToDateFixture, $updateFixture)) {
    Assert-Tbg -Condition (Test-Path -LiteralPath $required -PathType Leaf) -Message "Required compatibility surface is missing: $required"
}

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
Assert-Tbg -Condition (@($parseErrors).Count -eq 0) -Message "Compatibility script has parser errors: $($parseErrors -join '; ')"

Assert-TbgFileContains -Path $wrapperPath -Text 'Invoke-TbgGameCompatibility.ps1'
Assert-TbgFileContains -Path $wrapperPath -Text 'metadata-only'
Assert-TbgFileContains -Path $wrapperPath -Text 'pause'
Assert-TbgFileContains -Path $wrapperPath -Text 'exit /b %TBG_EXIT%'

$scriptText = Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8
foreach ($forbidden in @('ForgeReboot.cmd', 'Run-VisibleTradeProof.cmd', 'BlacksmithGuild_CommandInbox', 'Start-Process')) {
    Assert-Tbg -Condition (-not $scriptText.Contains($forbidden)) -Message "Compatibility implementation must not contain runtime action '$forbidden'."
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-game-compatibility-' + [Guid]::NewGuid().ToString('N'))
try {
    $gameRoot = Join-Path $tempRoot 'Mount & Blade II Bannerlord'
    $nativeRoot = Join-Path $gameRoot 'Modules/Native'
    $installedRoot = Join-Path $gameRoot 'Modules/BlacksmithGuild/bin/Win64_Shipping_Client'
    $builtRoot = Join-Path $tempRoot 'built'
    New-Item -ItemType Directory -Force -Path $nativeRoot, $installedRoot, $builtRoot | Out-Null
    @(
        '<?xml version="1.0" encoding="utf-8"?>',
        '<Module><Version value="v1.4.6" /></Module>'
    ) -join "`r`n" | Set-Content -LiteralPath (Join-Path $nativeRoot 'SubModule.xml') -Encoding UTF8
    $builtDll = Join-Path $builtRoot 'BlacksmithGuild.dll'
    $installedDll = Join-Path $installedRoot 'BlacksmithGuild.dll'
    [IO.File]::WriteAllBytes($builtDll, [Text.Encoding]::UTF8.GetBytes('exact fixture dll'))
    Copy-Item -LiteralPath $builtDll -Destination $installedDll

    $passOutput = Join-Path $tempRoot 'pass-output'
    $passState = Join-Path $tempRoot 'pass-state'
    $result = & $scriptPath -RepoRoot $RepoRoot -BannerlordRoot $gameRoot -AppManifestPath $manifestFixture -UpstreamFixturePath $upToDateFixture -BuiltDllPath $builtDll -InstalledDllPath $installedDll -OutputDirectory $passOutput -StateObjectRoot $passState -NoJournal -NoEnvelope -NoExit -PassThru
    Assert-Tbg -Condition ($result.schema -eq 'TbgGameCompatibilityResult.v1') -Message 'Fixture result schema drifted.'
    Assert-Tbg -Condition ($result.terminalState -eq 'PASS_compatibility_metadata_aligned') -Message "Aligned fixture did not pass: $($result.terminalState)"
    Assert-Tbg -Condition ($result.upstreamAvailableBuild.buildId -eq '12345678') -Message 'Upstream fixture build was not recorded.'
    Assert-Tbg -Condition ($result.locallyInstalledBuild.steamBuildId -eq '12345678') -Message 'Installed fixture build was not recorded.'
    Assert-Tbg -Condition ($result.repoSupportedBuild.id -eq 'bannerlord-public-v1-4-6') -Message 'Repo support baseline was not recorded.'
    Assert-Tbg -Condition ([bool]$result.comparisons.repoBaselineMatchesModuleDependencies) -Message 'Compatibility registry drifted from module dependencies.'
    Assert-Tbg -Condition ($result.sourceCommit.commit.Length -eq 40) -Message 'Exact source commit was not recorded.'
    Assert-Tbg -Condition ($result.builtModDll.sha256 -eq $result.installedModDll.sha256) -Message 'Built and installed fingerprints should match.'
    Assert-Tbg -Condition ([bool]$result.comparisons.builtMatchesInstalled) -Message 'DLL comparison should be true.'
    Assert-Tbg -Condition (Test-Path -LiteralPath (Join-Path $passOutput 'game-compatibility.result.json')) -Message 'Latest result was not written.'
    Assert-Tbg -Condition (@(Get-ChildItem -LiteralPath (Join-Path $passState 'observations') -File).Count -eq 1) -Message 'Exactly one observation was not written.'
    Assert-Tbg -Condition (@(Get-ChildItem -LiteralPath (Join-Path $passState 'evidence') -File).Count -eq 1) -Message 'Exactly one evidence record was not written.'

    $blocked = & $scriptPath -RepoRoot $RepoRoot -BannerlordRoot $gameRoot -AppManifestPath $manifestFixture -UpstreamFixturePath $updateFixture -BuiltDllPath $builtDll -InstalledDllPath $installedDll -OutputDirectory (Join-Path $tempRoot 'blocked-output') -StateObjectRoot (Join-Path $tempRoot 'blocked-state') -NoJournal -NoEnvelope -NoExit -PassThru
    Assert-Tbg -Condition ($blocked.terminalState -eq 'BLOCKED_game_update_available') -Message "Available-update fixture did not block: $($blocked.terminalState)"
    Assert-Tbg -Condition ($blocked.nextCommand -match 'Update Bannerlord through Steam') -Message 'Blocked result did not provide the update next action.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Host 'Bannerlord game compatibility updater contract: PASS'
