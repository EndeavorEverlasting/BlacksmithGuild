[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-TbgTrue {
    param(
        [bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Assert-TbgEqual {
    param(
        $Actual,
        $Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ([string]$Actual -ne [string]$Expected) {
        throw "$Message Expected '$Expected' but received '$Actual'."
    }
}

function Assert-TbgPowerShellParses {
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) {
        throw "$Path does not parse: $(@($errors | ForEach-Object { $_.Message }) -join '; ')"
    }
}

function Read-TbgJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    Assert-TbgTrue (Test-Path -LiteralPath $Path -PathType Leaf) "Expected JSON file is missing: $Path"
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-TbgJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-TbgFixtureRun {
    param(
        [Parameter(Mandatory = $true)][string]$FixturePath,
        [Parameter(Mandatory = $true)][string]$OutputDirectory,
        [Parameter(Mandatory = $true)][string]$CachePath,
        [ValidateSet('observe','auto','strict')][string]$Mode = 'auto',
        [switch]$AllowKnownActions
    )
    $arguments = @{
        Command = 'scan'
        Mode = $Mode
        FixturePath = $FixturePath
        RegistryPath = $script:registryPath
        PolicyPath = $script:policyPath
        CachePath = $CachePath
        OutputDirectory = $OutputDirectory
        NoJournal = $true
    }
    if ($AllowKnownActions) { $arguments.AllowKnownActions = $true }
    & $script:invokePath @arguments | Out-Null
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return [pscustomobject][ordered]@{
        exitCode = $exitCode
        result = Read-TbgJson -Path (Join-Path $OutputDirectory 'window-intelligence.result.json')
        reportPath = Join-Path $OutputDirectory 'window-intelligence.report.md'
        eventsPath = Join-Path $OutputDirectory 'window-intelligence.events.jsonl'
        progressPath = Join-Path $OutputDirectory 'window-intelligence.progress.log'
        handoffPath = Join-Path $OutputDirectory 'window-intelligence.handoff.md'
        learningPath = Join-Path $OutputDirectory 'window-intelligence.learning-candidates.json'
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$script:invokePath = Join-Path $repoRoot 'scripts\tbg\Invoke-TbgWindowIntelligence.ps1'
$script:registryPath = Join-Path $repoRoot '.tbg\harness\window-identities.registry.json'
$script:policyPath = Join-Path $repoRoot '.tbg\harness\policies\window-intelligence.policy.json'
$contractPath = Join-Path $repoRoot '.tbg\workflows\window-metadata-intelligence.contract.json'
$fixturePath = Join-Path $repoRoot '.tbg\harness\fixtures\window-intelligence\dependency-version-caution.fixture.json'
$wrapperPath = Join-Path $repoRoot 'ForgeWindowIntel.cmd'
$launcherContextPath = Join-Path $repoRoot 'scripts\launcher-window-context.ps1'
$skillPath = Join-Path $repoRoot '.tbg\skills\launcher-lifecycle\SKILL.md'
$architecturePath = Join-Path $repoRoot 'docs\architecture\window-metadata-intelligence.md'
$workflowPath = Join-Path $repoRoot '.github\workflows\harness-policy-reports.yml'
$manifestPath = Join-Path $repoRoot '.tbg\harness\manifest.json'

foreach ($path in @(
    $script:invokePath,
    $script:registryPath,
    $script:policyPath,
    $contractPath,
    $fixturePath,
    $wrapperPath,
    $launcherContextPath,
    $skillPath,
    $architecturePath,
    $workflowPath,
    $manifestPath
)) {
    Assert-TbgTrue (Test-Path -LiteralPath $path -PathType Leaf) "Required window-intelligence surface is missing: $path"
}

foreach ($path in @($script:invokePath, $launcherContextPath, $PSCommandPath)) {
    Assert-TbgPowerShellParses -Path $path
}

$registry = Read-TbgJson -Path $script:registryPath
$policy = Read-TbgJson -Path $script:policyPath
$contract = Read-TbgJson -Path $contractPath
$fixture = Read-TbgJson -Path $fixturePath

Assert-TbgEqual $registry.schema 'TbgWindowIdentityRegistry.v1' 'The identity registry has the wrong schema.'
Assert-TbgEqual $policy.schema 'TbgWindowIntelligencePolicy.v1' 'The policy has the wrong schema.'
Assert-TbgEqual $contract.id 'window-metadata-intelligence' 'The workflow contract has the wrong id.'
Assert-TbgEqual $fixture.expectedResolution.identityId 'bannerlord.dependency-version-caution' 'The screenshot-derived fixture targets the wrong identity.'
Assert-TbgTrue ([int]$registry.defaultPolicy.pollMilliseconds -le 100) 'The default window-intelligence poll must be 100 milliseconds or faster.'
Assert-TbgEqual $registry.defaultPolicy.imageFallbackDisposition 'diagnostic_only' 'Image fallback must remain diagnostic only.'

$identityIds = @($registry.identities | ForEach-Object { [string]$_.id })
foreach ($requiredIdentity in @(
    'bannerlord.launcher.menu',
    'bannerlord.dependency-version-caution',
    'bannerlord.safe-mode',
    'bannerlord.singleplayer-host'
)) {
    Assert-TbgTrue ($identityIds -contains $requiredIdentity) "The registry is missing identity '$requiredIdentity'."
}

$launcherIdentity = @($registry.identities | Where-Object { [string]$_.id -eq 'bannerlord.launcher.menu' })[0]
$cautionIdentity = @($registry.identities | Where-Object { [string]$_.id -eq 'bannerlord.dependency-version-caution' })[0]
$safeModeIdentity = @($registry.identities | Where-Object { [string]$_.id -eq 'bannerlord.safe-mode' })[0]
$singleplayerIdentity = @($registry.identities | Where-Object { [string]$_.id -eq 'bannerlord.singleplayer-host' })[0]

Assert-TbgEqual $launcherIdentity.actionPolicy.kind 'context_owned' 'PLAY versus CONTINUE must remain context-owned.'
Assert-TbgTrue (-not [bool]$launcherIdentity.actionPolicy.automatic) 'The launcher menu must not guess an automatic PLAY or CONTINUE action.'
Assert-TbgEqual $cautionIdentity.actionPolicy.actionId 'confirm_dependency_version_caution' 'The dependency caution has the wrong action.'
Assert-TbgEqual $cautionIdentity.actionPolicy.semanticAction 'confirm' 'The dependency caution must map to Confirm.'
Assert-TbgTrue (@($cautionIdentity.actionPolicy.preferredControlNames) -contains 'Confirm') 'The dependency caution must prefer the exact Confirm control.'
Assert-TbgTrue (-not (@($cautionIdentity.actionPolicy.preferredControlNames) -contains 'Cancel')) 'The dependency caution must never prefer Cancel.'
Assert-TbgEqual $safeModeIdentity.actionPolicy.actionId 'decline_safe_mode' 'Safe Mode has the wrong action.'
Assert-TbgTrue (@($safeModeIdentity.actionPolicy.preferredControlNames) -contains 'No') 'Safe Mode must prefer No.'
Assert-TbgTrue (@($safeModeIdentity.actionPolicy.fallbackKeys) -contains 'ALT+N') 'Safe Mode must retain Alt+N as the bounded fallback.'
Assert-TbgTrue (-not (@($safeModeIdentity.actionPolicy.fallbackKeys) -contains 'ALT+C')) 'Safe Mode must never use Alt+C.'
Assert-TbgEqual $singleplayerIdentity.actionPolicy.kind 'terminal_observation' 'Singleplayer must be a terminal launcher observation.'

$policyMethods = @($policy.decisionOrder | Sort-Object order | ForEach-Object { [string]$_.method })
Assert-TbgEqual $policyMethods[0] 'exact_cached_fingerprint' 'The cache must be the first recognition method.'
Assert-TbgEqual $policyMethods[1] 'tracked_registry_metadata_match' 'The tracked registry must precede launch fallback.'
Assert-TbgTrue ($policyMethods.IndexOf('s1_s2_delta_discovery') -gt $policyMethods.IndexOf('module_dependency_prediction')) 'S1/S2 delta must follow direct metadata and prediction.'
Assert-TbgEqual $policyMethods[$policyMethods.Count - 1] 'image_or_manual_diagnostic' 'Image handling must remain the last fallback.'

$invokeText = Get-Content -LiteralPath $script:invokePath -Raw -Encoding UTF8
$launcherText = Get-Content -LiteralPath $launcherContextPath -Raw -Encoding UTF8
$skillText = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
$architectureText = Get-Content -LiteralPath $architecturePath -Raw -Encoding UTF8
$workflowText = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
$manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8

foreach ($needle in @(
    'exact_cached_fingerprint',
    'tracked_registry_metadata_match',
    'delta_discovery_required',
    'InvokePattern',
    'action-leases.json',
    'Write-TbgJournalEvent.ps1',
    'minimumRecognitionScore',
    'requiredDirectSignals'
)) {
    Assert-TbgTrue ($invokeText.Contains($needle)) "The core implementation is missing '$needle'."
}
foreach ($forbiddenNeedle in @('Tesseract', 'Windows.Media.Ocr', 'CopyFromScreen', 'BitBlt')) {
    Assert-TbgTrue (-not $invokeText.Contains($forbiddenNeedle)) "The core implementation unexpectedly depends on image/OCR primitive '$forbiddenNeedle'."
}
foreach ($needle in @(
    'Start-TbgWindowIntelligenceWatcher',
    '-DurationSeconds 90',
    '-PollMilliseconds 100',
    '-AllowKnownActions',
    'TBG_WINDOW_INTELLIGENCE_DISABLE'
)) {
    Assert-TbgTrue ($launcherText.Contains($needle)) "Launcher context integration is missing '$needle'."
}
Assert-TbgTrue ($skillText.Contains('.\ForgeWindowIntel.cmd status')) 'The launcher skill must require agents to inspect window intelligence before proposing another fallback.'
Assert-TbgTrue ($skillText.Contains('launcher-window-context.json')) 'The launcher skill must name the sole PLAY-versus-CONTINUE authority.'
Assert-TbgTrue ($architectureText.Contains('exact learned fingerprint')) 'The architecture document must lead with the learned fingerprint strategy.'
Assert-TbgTrue ($architectureText.Contains('Image and OCR fallback remain diagnostic')) 'The architecture document must preserve the image fallback boundary.'
Assert-TbgTrue ($workflowText.Contains('Test-TbgWindowIntelligence.ps1')) 'Harness Policy Reports must execute the window-intelligence validator.'
Assert-TbgTrue ($workflowText.Contains('ForgeWindowIntel.cmd')) 'Harness Policy Reports path filters must include the root window-intelligence command.'
foreach ($needle in @(
    'windowIdentityRegistry',
    'windowIntelligencePolicy',
    'windowIntelligenceContract',
    'windowIntelligenceValidator',
    'windowIntelligenceOutput'
)) {
    Assert-TbgTrue ($manifestText.Contains($needle)) "The harness manifest is missing '$needle'."
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-window-intelligence-{0}' -f [Guid]::NewGuid().ToString('N'))
try {
    $cachePath = Join-Path $tempRoot 'cache\learned-window-aliases.json'
    $fixtureOutput = Join-Path $tempRoot 'fixture-first'
    $firstRun = Invoke-TbgFixtureRun -FixturePath $fixturePath -OutputDirectory $fixtureOutput -CachePath $cachePath -Mode auto -AllowKnownActions
    Assert-TbgEqual $firstRun.exitCode 0 'The screenshot-derived fixture run failed.'
    Assert-TbgEqual $firstRun.result.verdict 'PASS' 'The screenshot-derived fixture did not pass.'
    Assert-TbgEqual $firstRun.result.terminalState 'PASS_known_windows_classified' 'The fixture should classify the known window without claiming a live action dispatch.'
    Assert-TbgEqual $firstRun.result.counts.observed 1 'The fixture should contain one observed window.'
    Assert-TbgEqual $firstRun.result.counts.recognized 1 'The fixture should recognize one window.'
    Assert-TbgEqual $firstRun.result.counts.unknown 0 'The fixture should contain no unknown windows.'

    $firstWindow = @($firstRun.result.windowResults)[0]
    Assert-TbgEqual $firstWindow.resolution.identityId 'bannerlord.dependency-version-caution' 'The screenshot-derived fixture resolved to the wrong identity.'
    Assert-TbgTrue ([int]$firstWindow.resolution.score -ge 90) 'The screenshot-derived fixture score is below the automatic-action threshold.'
    Assert-TbgEqual $firstWindow.resolution.basis 'tracked_registry_metadata_match' 'The first fixture pass must resolve from the tracked registry.'
    Assert-TbgEqual $firstWindow.actionDecision.actionId 'confirm_dependency_version_caution' 'The fixture selected the wrong action.'
    Assert-TbgTrue ([bool]$firstWindow.actionDecision.allowed) 'The fixture should prove that the known action is allowed.'
    Assert-TbgTrue ([bool]$firstWindow.actionResult.wouldDispatch) 'The fixture should simulate a ready action without mutating a real window.'
    Assert-TbgEqual $firstWindow.actionResult.method 'fixture_simulation' 'The fixture used an unexpected action method.'
    Assert-TbgEqual @($firstWindow.parsedDependencies).Count 4 'The fixture must parse all four dependency mismatches.'

    $expectedVersions = @{
        Native = @('1.4.6.0','1.4.7.117484')
        SandBoxCore = @('1.4.6.0','1.4.7.117484')
        Sandbox = @('1.4.6.0','1.4.7.117484')
        StoryMode = @('1.4.6.0','1.4.7.117484')
    }
    foreach ($dependency in @($firstWindow.parsedDependencies)) {
        Assert-TbgTrue $expectedVersions.ContainsKey([string]$dependency.module) "Unexpected dependency '$($dependency.module)' was parsed."
        Assert-TbgEqual $dependency.expectedVersion $expectedVersions[[string]$dependency.module][0] "The expected version for $($dependency.module) is wrong."
        Assert-TbgEqual $dependency.currentVersion $expectedVersions[[string]$dependency.module][1] "The current version for $($dependency.module) is wrong."
    }

    foreach ($artifactPath in @($firstRun.reportPath, $firstRun.eventsPath, $firstRun.progressPath, $firstRun.handoffPath)) {
        Assert-TbgTrue (Test-Path -LiteralPath $artifactPath -PathType Leaf) "Fixture output is missing: $artifactPath"
    }
    $reportText = Get-Content -LiteralPath $firstRun.reportPath -Raw -Encoding UTF8
    Assert-TbgTrue ($reportText.Contains('Blacksmith Guild dependency-version caution')) 'The English report omitted the canonical window name.'
    Assert-TbgTrue ($reportText.Contains('| Native | 1.4.6.0 | 1.4.7.117484 |')) 'The English report omitted the parsed Native version row.'
    Assert-TbgTrue ($reportText.Contains('does not prove that the game accepted an action')) 'The English report collapsed the action-dispatch proof boundary.'
    $eventLines = @(Get-Content -LiteralPath $firstRun.eventsPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-TbgTrue ($eventLines.Count -ge 2) 'The fixture should produce classification and action-ready events.'
    foreach ($eventLine in $eventLines) {
        $event = $eventLine | ConvertFrom-Json
        Assert-TbgTrue ([string]$event.sentence -match '[.!?]$') 'Every window-intelligence event must contain a complete sentence.'
    }

    $cache = Read-TbgJson -Path $cachePath
    Assert-TbgEqual @($cache.aliases).Count 1 'The first high-confidence fixture pass should cache one fingerprint.'
    Assert-TbgEqual @($cache.aliases)[0].identityId 'bannerlord.dependency-version-caution' 'The cache stored the wrong canonical identity.'

    $secondOutput = Join-Path $tempRoot 'fixture-second'
    $secondRun = Invoke-TbgFixtureRun -FixturePath $fixturePath -OutputDirectory $secondOutput -CachePath $cachePath -Mode observe
    Assert-TbgEqual $secondRun.exitCode 0 'The cached fixture rerun failed.'
    $secondWindow = @($secondRun.result.windowResults)[0]
    Assert-TbgEqual $secondWindow.resolution.basis 'exact_cached_fingerprint' 'The second fixture pass did not use the exact learned fingerprint.'
    Assert-TbgEqual $secondWindow.resolution.score 100 'The exact cached fingerprint did not receive a deterministic score of 100.'

    $predictionOnlyPath = Join-Path $tempRoot 'prediction-only.fixture.json'
    $predictionOnly = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $predictionOnly.fixtureId = 'prediction-only-no-visible-modal'
    $predictionOnly.window.title = 'Mount and Blade II Bannerlord - Singleplayer'
    $predictionOnly.win32Texts = @('Mount and Blade II Bannerlord - Singleplayer')
    $predictionOnly.uiaElements = @()
    Write-TbgJson -Value $predictionOnly -Path $predictionOnlyPath
    $predictionRun = Invoke-TbgFixtureRun -FixturePath $predictionOnlyPath -OutputDirectory (Join-Path $tempRoot 'prediction-only') -CachePath (Join-Path $tempRoot 'prediction-cache.json') -Mode auto -AllowKnownActions
    Assert-TbgEqual $predictionRun.exitCode 0 'The prediction-only fixture failed unexpectedly.'
    $predictionWindow = @($predictionRun.result.windowResults)[0]
    Assert-TbgTrue (-not [bool]$predictionWindow.actionDecision.allowed) 'A predicted mismatch without a visible CAUTION and Confirm control must not authorize an action.'
    Assert-TbgTrue (-not [bool]$predictionWindow.actionResult.dispatched) 'A predicted mismatch without direct modal signals dispatched an action.'

    $unknownPath = Join-Path $tempRoot 'unknown.fixture.json'
    $unknown = $fixture | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $unknown.fixtureId = 'unknown-window'
    $unknown.window.title = 'Unexpected launcher dialog'
    $unknown.win32Texts = @('Unexpected launcher dialog', 'Mysterious operation')
    $unknown.uiaElements = @([pscustomobject][ordered]@{
        name = 'Proceed'
        automationId = 'Proceed'
        className = ''
        controlType = 'Button'
        enabled = $true
        offscreen = $false
    })
    $unknown.dependencyComparison = @()
    Write-TbgJson -Value $unknown -Path $unknownPath

    $unknownOutput = Join-Path $tempRoot 'unknown-output'
    $unknownRun = Invoke-TbgFixtureRun -FixturePath $unknownPath -OutputDirectory $unknownOutput -CachePath (Join-Path $tempRoot 'unknown-cache.json') -Mode auto -AllowKnownActions
    Assert-TbgEqual $unknownRun.exitCode 0 'The unknown-window attention fixture should not fail outside strict mode.'
    Assert-TbgEqual $unknownRun.result.verdict 'ATTENTION' 'The unknown window should produce ATTENTION.'
    Assert-TbgEqual $unknownRun.result.terminalState 'ATTENTION_unknown_window_delta_discovery_required' 'The unknown window produced the wrong terminal state.'
    Assert-TbgEqual $unknownRun.result.counts.unknown 1 'The unknown fixture did not remain unknown.'
    Assert-TbgTrue (Test-Path -LiteralPath $unknownRun.learningPath -PathType Leaf) 'The unknown fixture did not write a learning candidate.'
    Assert-TbgTrue (-not [bool](@($unknownRun.result.windowResults)[0].actionResult.dispatched)) 'The unknown fixture dispatched an action.'

    $strictRun = Invoke-TbgFixtureRun -FixturePath $unknownPath -OutputDirectory (Join-Path $tempRoot 'unknown-strict') -CachePath (Join-Path $tempRoot 'unknown-strict-cache.json') -Mode strict -AllowKnownActions
    Assert-TbgEqual $strictRun.exitCode 2 'Strict mode must return exit code 2 for an unknown window.'
    Assert-TbgEqual $strictRun.result.verdict 'BLOCKED' 'Strict mode must block an unknown window.'
    Assert-TbgEqual $strictRun.result.terminalState 'BLOCKED_unknown_window_in_strict_mode' 'Strict mode produced the wrong unknown-window terminal state.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host 'PASS: window intelligence classified the dependency CAUTION from metadata, parsed four version mismatches, proved exact Confirm action gating, reused a learned fingerprint, rejected prediction-only action authority, and quarantined unknown windows behind one-time delta discovery.'
