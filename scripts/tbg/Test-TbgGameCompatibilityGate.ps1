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

$gatePath = Join-Path $RepoRoot 'scripts/tbg/Assert-TbgGameCompatibilityGate.ps1'
$launcherPath = Join-Path $RepoRoot 'scripts/open-bannerlord-launcher.ps1'
$rebootPath = Join-Path $RepoRoot 'ForgeReboot.cmd'
$manifestFixture = Join-Path $RepoRoot '.tbg/harness/fixtures/game-compatibility/appmanifest_261550.fixture.acf'
$upToDateFixture = Join-Path $RepoRoot '.tbg/harness/fixtures/game-compatibility/up-to-date.fixture.json'
$updateFixture = Join-Path $RepoRoot '.tbg/harness/fixtures/game-compatibility/update-available.fixture.json'

foreach ($required in @($gatePath, $launcherPath, $rebootPath, $manifestFixture, $upToDateFixture, $updateFixture)) {
    Assert-Tbg -Condition (Test-Path -LiteralPath $required -PathType Leaf) -Message "Required compatibility gate surface is missing: $required"
}

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($gatePath, [ref]$tokens, [ref]$parseErrors) | Out-Null
Assert-Tbg -Condition (@($parseErrors).Count -eq 0) -Message "Compatibility gate has parser errors: $($parseErrors -join '; ')"

$gateText = Get-Content -LiteralPath $gatePath -Raw -Encoding UTF8
foreach ($forbidden in @('open-bannerlord-launcher.ps1', 'launcher-auto-nav.ps1', 'BlacksmithGuild_CommandInbox', 'Start-Process')) {
    Assert-Tbg -Condition (-not $gateText.Contains($forbidden)) -Message "Compatibility gate must not contain runtime action '$forbidden'."
}
Assert-Tbg -Condition $gateText.Contains('PASS_compatibility_metadata_aligned') -Message 'Compatibility gate no longer requires the canonical PASS state.'
Assert-Tbg -Condition $gateText.Contains('BLOCKED_GAME_BUILD_UNVALIDATED') -Message 'Compatibility gate no longer emits the canonical blocked classification.'

$launcherText = Get-Content -LiteralPath $launcherPath -Raw -Encoding UTF8
$launcherGateIndex = $launcherText.IndexOf('Assert-TbgGameCompatibilityGate.ps1', [StringComparison]::Ordinal)
$launcherActionIndex = $launcherText.IndexOf('Ensure-TbgLauncherWindowContext', [StringComparison]::Ordinal)
Assert-Tbg -Condition ($launcherGateIndex -ge 0) -Message 'Launcher entrypoint does not invoke the compatibility gate.'
Assert-Tbg -Condition ($launcherActionIndex -gt $launcherGateIndex) -Message 'Launcher compatibility gate must run before launcher context creation or reuse.'

$rebootText = Get-Content -LiteralPath $rebootPath -Raw -Encoding UTF8
$rebootGateIndex = $rebootText.IndexOf('Assert-TbgGameCompatibilityGate.ps1', [StringComparison]::Ordinal)
$rebootRunnerIndex = $rebootText.IndexOf('run-reboot-iteration.ps1', [StringComparison]::Ordinal)
Assert-Tbg -Condition ($rebootGateIndex -ge 0) -Message 'ForgeReboot does not invoke the compatibility gate.'
Assert-Tbg -Condition ($rebootRunnerIndex -gt $rebootGateIndex) -Message 'ForgeReboot compatibility gate must run before the runtime-proof coordinator.'

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-game-compatibility-gate-' + [Guid]::NewGuid().ToString('N'))
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

    $aligned = & $gatePath -Gate launcher -RepoRoot $RepoRoot -BannerlordRoot $gameRoot `
        -AppManifestPath $manifestFixture -UpstreamFixturePath $upToDateFixture `
        -BuiltDllPath $builtDll -InstalledDllPath $installedDll `
        -OutputDirectory (Join-Path $tempRoot 'aligned-output') -StateObjectRoot (Join-Path $tempRoot 'aligned-state') `
        -NoJournal -NoEnvelope -NoExit -PassThru
    Assert-Tbg -Condition ([bool]$aligned.allowed) -Message "Aligned compatibility fixture was blocked: $($aligned.terminalState)"
    Assert-Tbg -Condition ($aligned.terminalState -eq 'PASS_compatibility_metadata_aligned') -Message 'Aligned gate terminal state drifted.'

    $updateAvailable = & $gatePath -Gate runtime-proof -RepoRoot $RepoRoot -BannerlordRoot $gameRoot `
        -AppManifestPath $manifestFixture -UpstreamFixturePath $updateFixture `
        -BuiltDllPath $builtDll -InstalledDllPath $installedDll `
        -OutputDirectory (Join-Path $tempRoot 'update-output') -StateObjectRoot (Join-Path $tempRoot 'update-state') `
        -NoJournal -NoEnvelope -NoExit -PassThru
    Assert-Tbg -Condition (-not [bool]$updateAvailable.allowed) -Message 'Available game update did not block runtime proof.'
    Assert-Tbg -Condition ($updateAvailable.terminalState -eq 'BLOCKED_game_update_available') -Message "Update gate classification drifted: $($updateAvailable.terminalState)"

    [IO.File]::WriteAllBytes($installedDll, [Text.Encoding]::UTF8.GetBytes('different installed dll'))
    $dllDrift = & $gatePath -Gate launcher -RepoRoot $RepoRoot -BannerlordRoot $gameRoot `
        -AppManifestPath $manifestFixture -UpstreamFixturePath $upToDateFixture `
        -BuiltDllPath $builtDll -InstalledDllPath $installedDll `
        -OutputDirectory (Join-Path $tempRoot 'drift-output') -StateObjectRoot (Join-Path $tempRoot 'drift-state') `
        -NoJournal -NoEnvelope -NoExit -PassThru
    Assert-Tbg -Condition (-not [bool]$dllDrift.allowed) -Message 'Built/installed DLL drift did not block launcher entry.'
    Assert-Tbg -Condition ($dllDrift.terminalState -eq 'BLOCKED_built_installed_dll_drift') -Message "DLL drift classification drifted: $($dllDrift.terminalState)"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Host 'Bannerlord game compatibility runtime gate: PASS'
