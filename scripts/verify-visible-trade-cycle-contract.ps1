param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $RepoRoot 'scripts\visible-trade-cycle-contract.ps1')
. (Join-Path $RepoRoot 'scripts\visible-trade-launch-boundary.ps1')

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Needle
    )
    $full = Join-Path $RepoRoot $Path
    Assert-True (Test-Path -LiteralPath $full) "Missing contract file: $Path"
    $text = Get-Content -LiteralPath $full -Raw
    Assert-True ($text.Contains($Needle)) "$Path is missing required contract text: $Needle"
}

function Copy-FixtureValue {
    param($Value)
    return ($Value | ConvertTo-Json -Depth 50 | ConvertFrom-Json)
}

function Set-FixtureOverride {
    param(
        [Parameter(Mandatory = $true)]$Root,
        [Parameter(Mandatory = $true)]$Override
    )

    $segments = @([string]$Override.path -split '\.')
    $cursor = $Root
    for ($index = 0; $index -lt $segments.Count - 1; $index++) {
        $property = $cursor.PSObject.Properties[$segments[$index]]
        if ($null -eq $property) {
            throw "Fixture override parent is missing: $($Override.path)"
        }
        $cursor = $property.Value
    }

    $leaf = $segments[-1]
    $action = if ($Override.PSObject.Properties['action']) { [string]$Override.action } else { 'set' }
    if ($action -eq 'remove') {
        $cursor.PSObject.Properties.Remove($leaf)
        return
    }
    if (-not $Override.PSObject.Properties['value']) {
        throw "Fixture set override has no value: $($Override.path)"
    }
    if ($cursor.PSObject.Properties[$leaf]) {
        $cursor.$leaf = $Override.value
    } else {
        $cursor | Add-Member -NotePropertyName $leaf -NotePropertyValue $Override.value
    }
}

$launchStartedUtc = [datetime]::Parse('2026-07-12T05:00:00Z').ToUniversalTime()
$launcherFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'tbg-launch-boundary-fixture'
$launcherBaselinePath = Join-Path $launcherFixtureRoot 'window-snapshot-S1-pre-launch.json'
$launcherPath = Join-Path $launcherFixtureRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe'
$validContext = [PSCustomObject]@{
    schema = 'TbgLauncherWindowContext.v1'
    bannerlordRoot = $launcherFixtureRoot
    baselineSnapshotPath = $launcherBaselinePath
    baselineSource = 'S1_pre_launch'
    processId = 2400
    hwnd = 8800
    processName = 'TaleWorlds.MountAndBlade.Launcher'
    isFreshLaunch = $true
    isExistingLauncherReuse = $false
    createdBy = 'open-bannerlord-launcher.ps1'
    createdAtUtc = '2026-07-12T05:00:02Z'
}
$validBaseline = [PSCustomObject]@{
    label = 'S1_pre_launch'
    bannerlordRoot = $launcherFixtureRoot
    capturedAtUtc = '2026-07-12T05:00:00Z'
    processes = @([PSCustomObject]@{ pid = 99 })
}
$validLauncher = [PSCustomObject]@{
    pid = 2400
    hwnd = 8800
    name = 'TaleWorlds.MountAndBlade.Launcher'
    path = $launcherPath
    windowTitle = 'M&B II: Bannerlord'
    startedAtUtc = '2026-07-12T05:00:01Z'
}
function Test-LauncherCleanupFixture {
    param($Context, $Baseline, $Process, [bool]$RuntimeLive = $false)
    return Test-TbgOwnedLauncherCleanupFacts -Context $Context -Baseline $Baseline -Process $Process `
        -BannerlordRoot $launcherFixtureRoot -LaunchStartedAtUtc $launchStartedUtc -RuntimeLive $RuntimeLive
}

Assert-True ((Test-LauncherCleanupFixture $validContext $validBaseline $validLauncher).eligible) 'Fresh exact launcher cleanup fixture must be eligible'
$variant = Copy-FixtureValue $validContext; $variant.isExistingLauncherReuse = $true
Assert-True (-not (Test-LauncherCleanupFixture $variant $validBaseline $validLauncher).eligible) 'Reused launcher must be preserved'
$variant = Copy-FixtureValue $validContext; $variant.createdAtUtc = '2026-07-12T04:59:00Z'
Assert-True (-not (Test-LauncherCleanupFixture $variant $validBaseline $validLauncher).eligible) 'Stale launcher context must be preserved'
$variant = Copy-FixtureValue $validBaseline; $variant.processes = @([PSCustomObject]@{ pid = 2400 })
Assert-True (-not (Test-LauncherCleanupFixture $validContext $variant $validLauncher).eligible) 'PID present before launch must be preserved'
$variant = Copy-FixtureValue $validLauncher; $variant.pid = 2401
Assert-True (-not (Test-LauncherCleanupFixture $validContext $validBaseline $variant).eligible) 'Wrong launcher PID must be preserved'
$variant = Copy-FixtureValue $validLauncher; $variant.path = Join-Path $launcherFixtureRoot 'other.exe'
Assert-True (-not (Test-LauncherCleanupFixture $validContext $validBaseline $variant).eligible) 'Wrong launcher path must be preserved'
$variant = Copy-FixtureValue $validLauncher; $variant.hwnd = 8801
Assert-True (-not (Test-LauncherCleanupFixture $validContext $validBaseline $variant).eligible) 'Wrong launcher HWND must be preserved'
$variant = Copy-FixtureValue $validLauncher; $variant.windowTitle = 'Mount and Blade II Bannerlord - Singleplayer'
Assert-True (-not (Test-LauncherCleanupFixture $validContext $validBaseline $variant).eligible) 'Hosted game runtime must never be closed as a launcher'
Assert-True (-not (Test-LauncherCleanupFixture $validContext $validBaseline $validLauncher $true).eligible) 'Live runtime must suppress launcher cleanup'
$variant = Copy-FixtureValue $validBaseline; $variant.bannerlordRoot = Join-Path $launcherFixtureRoot 'other'
Assert-True (-not (Test-LauncherCleanupFixture $validContext $variant $validLauncher).eligible) 'Mismatched pre-launch baseline must preserve the launcher'
Assert-True (-not (Test-TbgLiveRuntimeAuthorityFacts -Confidence 'phase1_active' -ProcessId 2400 -ProcessExists $true)) 'Phase1 freshness must not authorize game commands'
Assert-True (Test-TbgLiveRuntimeAuthorityFacts -Confidence 'definite' -ProcessId 2400 -ProcessExists $true) 'Definite live process must authorize runtime commands'
Assert-True (Test-TbgLiveRuntimeAuthorityFacts -Confidence 'launcher_hosted' -ProcessId 2400 -ProcessExists $true -WindowTitle 'Mount and Blade II Bannerlord - Singleplayer') 'Hosted Singleplayer process must authorize runtime commands'
Assert-True (-not (Test-TbgLiveRuntimeAuthorityFacts -Confidence 'launcher_hosted' -ProcessId 2400 -ProcessExists $true -WindowTitle 'M&B II: Bannerlord')) 'Launcher menu must not authorize runtime commands'

$fixturePath = Join-Path $RepoRoot '.tbg\harness\fixtures\visible-trade-cycle.fixtures.json'
Assert-True (Test-Path -LiteralPath $fixturePath) 'Visible-trade fixture file is missing'
$fixtures = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
Assert-True ($fixtures.schemaVersion -eq 'TbgVisibleTradeCycleFixtures.v1') 'Unexpected visible-trade fixture schema'
Assert-True (@($fixtures.cases).Count -ge 10) 'Visible-trade verifier requires broad positive and negative fixtures'

foreach ($case in @($fixtures.cases)) {
    $data = Copy-FixtureValue $fixtures.baseCase
    foreach ($override in @($case.overrides)) {
        Set-FixtureOverride -Root $data -Override $override
    }

    $actual = Test-TbgVisibleTradeCycleEvidence `
        -Request $data.request `
        -SaveIdentity $data.saveIdentity `
        -AuthorityBefore $data.authorityBefore `
        -AuthorityAutomation $data.authorityAutomation `
        -RuntimeEvidence $data.runtimeEvidence `
        -AuthorityManual $data.authorityManual

    Assert-True ($actual.pass -eq [bool]$case.expectedPass) "Fixture $($case.id) pass mismatch"
    Assert-True ($actual.terminalState -eq [string]$case.expectedTerminalState) `
        "Fixture $($case.id) terminal mismatch: expected=$($case.expectedTerminalState) actual=$($actual.terminalState)"
}

$runner = 'scripts\run-tbg-visible-trade-cycle.ps1'
foreach ($needle in @(
        "throw 'FAILED_preflight:ExpectedHead is mandatory for certifying mode'",
        'preexisting_bannerlord_process',
        'Get-BannerlordRelatedProcesses',
        'Get-TbgBannerlordRuntimeDetection',
        'Test-TbgLiveRuntimeDetection',
        'Stop-TbgOwnedLauncherAfterFailedSpawn',
        'visible-trade-launch-boundary.ps1',
        '-AllowFocusSteal',
        'Get-BannerlordDevSaveCandidates',
        'Test-BannerlordRecognizedSavePath',
        'Get-TbgFileSha256',
        "requestedSaveId = `$requestedSaveId",
        "requestedSaveSha256AtStart = `$saveHash",
        "Join-Path `$bannerlordRoot 'BlacksmithGuild_VisibleTradeCycleRequest.json'",
        "--configuration Release",
        'installed_dll_hash_mismatch',
        "-LaunchIntent continue",
        "Invoke-ForgeCommandChecked -Command 'ReportSaveIdentityNow'",
        "'BlacksmithGuild_SaveIdentity.json'",
        "'activeSaveSlotName'",
        "Invoke-ForgeCommandChecked -Command 'SetMapTradeAutomation'",
        "Invoke-ForgeCommandChecked -Command 'RunAutonomousVisibleTradeRouteNow'",
        "'BlacksmithGuild_VisibleTradeCycle.json'",
        "'BlacksmithGuild_MapTradeRouteCert.json'",
        "'BlacksmithGuild_MapTradeCert.json'",
        "Invoke-ForgeCommandChecked -Command 'SetMapTradeManual'",
        "'SetMapTradeManual'",
        "'visible-trade-cycle.result.json'",
        "'visible-trade-cycle.report.md'",
        "if (`$diagnosticOnly) { exit 3 }"
    )) {
    Assert-Contains $runner $needle
}

$runnerText = Get-Content -LiteralPath (Join-Path $RepoRoot $runner) -Raw
$diagnosticGate = $runnerText.IndexOf("if (`$diagnosticOnly) {", [System.StringComparison]::Ordinal)
$buildCall = $runnerText.IndexOf('& dotnet build', [System.StringComparison]::Ordinal)
Assert-True ($diagnosticGate -ge 0 -and $buildCall -gt $diagnosticGate) `
    'Diagnostic gate must terminate the certifying try before build, launch, or runtime commands'
Assert-True (-not $runnerText.Contains("SetEngineToggleAutomation")) `
    'Visible-trade runner must never set global Automation; only MapTrade may be changed'
$runtimeGuard = $runnerText.IndexOf('if (-not (Test-TbgLiveRuntimeDetection -Detection $runtimeDetection))', [System.StringComparison]::Ordinal)
$runtimeOwnership = $runnerText.IndexOf('$script:ownsLaunchedSession = $true', $runtimeGuard, [System.StringComparison]::Ordinal)
Assert-True ($runtimeGuard -ge 0 -and $runtimeOwnership -gt $runtimeGuard) `
    'Runner may own a session only after shared detection proves a game runtime, never for launcher-only state'
Assert-True (-not $runnerText.Contains('@(Get-BannerlordProcesses).Count')) `
    'Runner must not treat the launcher process list as runtime command authority'
Assert-True ($runnerText.Contains('$script:mapTradeAutomationAttempted') -and $runnerText.Contains('$script:ownsLaunchedSession -and $script:mapTradeAutomationAttempted')) `
    'Manual cleanup must require this run to have attempted targeted MapTrade Automation'

foreach ($needle in @(
        'fakeGameplayDelta',
        'tradeDeltaArithmetic',
        'activeSaveSlotMatches',
        'Test-TbgSameNonMapTradeModes',
        'manualCleanupProven',
        'surfaceKindValid'
    )) {
    Assert-Contains 'scripts\visible-trade-cycle-contract.ps1' $needle
}

Assert-Contains 'Run-TbgVisibleTradeCycle.cmd' 'scripts\run-tbg-visible-trade-cycle.ps1'
Assert-Contains '.tbg\workflows\continue-visible-trade-cycle.contract.json' 'TbgVisibleTradeRuntimeEvidence.v1'
Assert-Contains '.tbg\operator\control-surface.json' '.\\Run-TbgVisibleTradeCycle.cmd'
Assert-Contains 'docs\operator\load-save-toggle-and-visible-trade-plan.md' '.\Run-TbgVisibleTradeCycle.cmd -ExpectedHead'

$diagnosticRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-visible-trade-contract-" + [guid]::NewGuid().ToString('N'))
try {
    $diagnosticProcess = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', (Join-Path $RepoRoot $runner),
            '-Diagnostic',
            '-SkipBuild',
            '-SkipLaunch',
            '-EvidenceRoot', $diagnosticRoot
        ) `
        -Wait `
        -PassThru `
        -WindowStyle Hidden
    Assert-True ($diagnosticProcess.ExitCode -eq 3) "Diagnostic mode must exit 3, got $($diagnosticProcess.ExitCode)"
    $diagnosticResult = Get-Content -LiteralPath (Join-Path $diagnosticRoot 'visible-trade-cycle.result.json') -Raw | ConvertFrom-Json
    $diagnosticReport = Get-Content -LiteralPath (Join-Path $diagnosticRoot 'visible-trade-cycle.report.md') -Raw
    Assert-True ($diagnosticResult.passFail -eq 'DIAGNOSTIC') 'Diagnostic mode must never write PASS'
    Assert-True ($diagnosticResult.terminalState -eq 'DIAGNOSTIC_ONLY') 'Diagnostic mode terminal state drift'
    Assert-True (-not [bool]$diagnosticResult.preflight.nativeContinueLaunched) 'Diagnostic mode must not launch Bannerlord'
    Assert-True (-not $diagnosticReport.Contains('$(')) 'English report must interpolate result fields instead of leaking PowerShell syntax'
    Assert-True (-not $diagnosticReport.Contains([char]11)) 'English report must not contain a vertical-tab escape from Markdown backticks'
    Assert-True ($diagnosticReport.Contains('not selected before the run stopped')) 'Early failure report must explain that no save was selected'
} finally {
    if (Test-Path -LiteralPath $diagnosticRoot) {
        Remove-Item -LiteralPath $diagnosticRoot -Recurse -Force
    }
}

Assert-True (-not $runnerText.Contains('Get-FileHash')) 'CMD runner must not depend on PowerShell module autoloading for SHA-256'

Write-Host "Visible trade cycle contract: PASS ($(@($fixtures.cases).Count) fixtures)"
