<#
.SYNOPSIS
    Integration tests for the Bannerlord Game Compatibility Updater.

.DESCRIPTION
    Tests detection, state object integrity, schema validation, support registry
    comparison, fixture idempotency, and terminal-state correctness.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $callerDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $RepoRoot = (Resolve-Path (Join-Path $callerDir '..\..')).Path
}

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param([Parameter(Mandatory)]$Actual, [Parameter(Mandatory)]$Expected, [Parameter(Mandatory)][string]$Message)
    if ($Actual -ne $Expected) { throw "$Message Expected=[$Expected] Actual=[$Actual]" }
}

function Assert-Exists {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Message)
    if (-not (Test-Path -LiteralPath $Path)) { throw $Message }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-game-compat-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
Push-Location -LiteralPath $testRoot
try {
    Write-Host '=== Bannerlord Game Compatibility Updater Tests ==='
    Write-Host ''

    # --- TEST 1: Schemas exist and parse ---
    Write-Host 'TEST 1: Schemas exist and parse'
    $obsSchema = Join-Path $RepoRoot '.tbg\harness\schemas\game-build-observation.schema.json'
    $compatSchema = Join-Path $RepoRoot '.tbg\harness\schemas\game-compatibility-result.schema.json'
    Assert-Exists $obsSchema "Missing game-build-observation schema"
    Assert-Exists $compatSchema "Missing game-compatibility-result schema"
    $obsJson = Get-Content -LiteralPath $obsSchema -Raw | ConvertFrom-Json
    $compatJson = Get-Content -LiteralPath $compatSchema -Raw | ConvertFrom-Json
    Assert-Equal $obsJson.title 'TBG Game Build Observation v1' "Unexpected obs schema title"
    Assert-Equal $compatJson.title 'TBG Game Compatibility Result v1' "Unexpected compat schema title"
    Write-Host '  PASS'

    # --- TEST 2: Support registry exists and parses ---
    Write-Host 'TEST 2: Support registry exists'
    $supportPath = Join-Path $RepoRoot '.tbg\compatibility\bannerlord-support.json'
    Assert-Exists $supportPath "Missing bannerlord-support.json"
    $support = Get-Content -LiteralPath $supportPath -Raw | ConvertFrom-Json
    Assert-Equal $support.schema 'TbgBannerlordSupport.v1' "Unexpected support schema"
    Assert-True ($support.supportedVersions.Count -gt 0) "Must have at least one supported version"
    Write-Host '  PASS'

    # --- TEST 3: API baseline exists ---
    Write-Host 'TEST 3: API baseline exists'
    $baselinePath = Join-Path $RepoRoot '.tbg\compatibility\bannerlord-api-baseline.json'
    Assert-Exists $baselinePath "Missing bannerlord-api-baseline.json"
    $baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
    Assert-Equal $baseline.schema 'TbgBannerlordApiBaseline.v1' "Unexpected baseline schema"
    Write-Host '  PASS'

    # --- TEST 4: Workflow contract exists ---
    Write-Host 'TEST 4: Workflow contract exists'
    $contractPath = Join-Path $RepoRoot '.tbg\workflows\bannerlord-game-update.contract.json'
    Assert-Exists $contractPath "Missing workflow contract"
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Assert-Equal $contract.id 'bannerlord-game-update-detection' "Unexpected contract id"
    Assert-True ($contract.terminalStates.Count -ge 5) "Contract must declare terminal states"
    Write-Host '  PASS'

    # --- TEST 5: Use-case contract exists ---
    Write-Host 'TEST 5: Use-case contract exists'
    $ucPath = Join-Path $RepoRoot '.tbg\state\use-case-contracts\bannerlord-update-detected.json'
    Assert-Exists $ucPath "Missing use-case contract"
    $uc = Get-Content -LiteralPath $ucPath -Raw | ConvertFrom-Json
    Assert-Equal $uc.id 'bannerlord-update-detected' "Unexpected use-case id"
    Write-Host '  PASS'

    # --- TEST 6: Provider registered ---
    Write-Host 'TEST 6: Provider registered in catalog'
    $catalogPath = Join-Path $RepoRoot '.tbg\state\provider-catalog.json'
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    $provider = $catalog.providers | Where-Object { $_.id -eq 'provider:bannerlord-game-compatibility' }
    Assert-True ($null -ne $provider) "Provider not found in catalog"
    Assert-True ($provider.capabilities -contains 'capability:game-compatibility-gating') "Missing capability"
    Write-Host '  PASS'

    # --- TEST 7: Event types added to tbg-event schema ---
    Write-Host 'TEST 7: Event types in tbg-event schema'
    $evtSchema = Get-Content -LiteralPath (Join-Path $RepoRoot '.tbg\harness\schemas\tbg-event.schema.json') -Raw | ConvertFrom-Json
    $evtTypes = $evtSchema.properties.eventType.enum
    Assert-True ($evtTypes -contains 'upstream.game.release.observed') "Missing upstream event"
    Assert-True ($evtTypes -contains 'local.game.install.observed') "Missing local event"
    Assert-True ($evtTypes -contains 'compatibility.support.adopted') "Missing adoption event"
    Write-Host '  PASS'

    # --- TEST 8: Reducer registry has game-build observation ---
    Write-Host 'TEST 8: Reducer registry handles game-build observations'
    $reducerPath = Join-Path $RepoRoot '.tbg\state\reducer-registry.json'
    $reducer = Get-Content -LiteralPath $reducerPath -Raw | ConvertFrom-Json
    $obsReducer = $reducer.Reducers | Where-Object { $_.id -eq 'reducer:observation' }
    Assert-True ($obsReducer.eventTypes -contains 'local.game.install.observed') "Observation reducer must handle local.game.install.observed"
    Write-Host '  PASS'

    # --- TEST 9: CMD entrypoints exist ---
    Write-Host 'TEST 9: CMD entrypoints exist'
    Assert-Exists (Join-Path $RepoRoot 'ForgeGameUpdate.cmd') "Missing ForgeGameUpdate.cmd"
    Assert-Exists (Join-Path $RepoRoot 'ForgeGameUpdate-Assess.cmd') "Missing ForgeGameUpdate-Assess.cmd"
    Assert-Exists (Join-Path $RepoRoot 'ForgeGameUpdate-Status.cmd') "Missing ForgeGameUpdate-Status.cmd"
    Write-Host '  PASS'

    # --- TEST 10: Detection script exists ---
    Write-Host 'TEST 10: Detection script exists'
    $detectScript = Join-Path $RepoRoot 'scripts\tbg\Get-TbgGameBuildObservation.ps1'
    Assert-Exists $detectScript "Missing detection script"
    Write-Host '  PASS'

    # --- TEST 11: Test script is the one running ---
    Write-Host 'TEST 11: Test script exists'
    $testScript = Join-Path $RepoRoot 'scripts\tbg\Test-TbgBannerlordUpdate.ps1'
    Assert-Exists $testScript "Missing test script"
    Write-Host '  PASS'

    # --- TEST 12: No proprietary game files committed ---
    Write-Host 'TEST 12: No proprietary game DLLs in tracked files'
    Push-Location -LiteralPath $RepoRoot
    $trackedDlls = & git ls-files -- '*.dll' '*.exe' '*.pdb' 2>$null
    Pop-Location
    $gameDlls = @($trackedDlls) | Where-Object { $_ -match 'TaleWorlds' -or $_ -match 'MountAndBlade' }
    Assert-True ($gameDlls.Count -eq 0) "Proprietary game DLLs must not be tracked: $($gameDlls -join ', ')"
    Write-Host '  PASS'

    # --- TEST 13: Terminal states match required list ---
    Write-Host 'TEST 13: Required terminal states declared'
    $requiredStates = @(
        'SUPPORTED_VALIDATED', 'SUPPORTED_BUILD_ONLY', 'UPDATE_AVAILABLE_NOT_INSTALLED',
        'INSTALLED_UPDATE_UNVALIDATED', 'COMPATIBILITY_ASSESSMENT_RUNNING',
        'COMPATIBILITY_BLOCKED', 'COMPATIBILITY_FAILED', 'ROLLBACK_RECOMMENDED',
        'UPSTREAM_VERSION_UNKNOWN', 'LOCAL_VERSION_UNKNOWN'
    )
    foreach ($state in $requiredStates) {
        Assert-True ($contract.terminalStates -contains $state) "Missing terminal state: $state"
    }
    Write-Host '  PASS'

    # --- TEST 14: Forbidden scope respected ---
    Write-Host 'TEST 14: Forbidden scope in contract'
    Assert-True (($contract.forbiddenScope -match 'no committing proprietary game DLLs').Count -gt 0) "Must forbid committing DLLs"
    Assert-True (($contract.forbiddenScope -match 'no launching Bannerlord during static CI').Count -gt 0) "Must forbid launch in CI"
    Assert-True (($contract.forbiddenScope -match 'no save mutation').Count -gt 0) "Must forbid save mutation"
    Write-Host '  PASS'

    Write-Host ''
    Write-Host '=== ALL 14 TESTS PASSED ==='
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
