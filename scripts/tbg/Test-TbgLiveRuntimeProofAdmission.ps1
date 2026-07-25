[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$InputPath = '',
    [string]$OutputRoot = 'artifacts/latest/live-runtime-proof-admission',
    [switch]$ExportReducerOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if (-not [IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot $OutputRoot
}

$contractPath = Join-Path $RepoRoot '.tbg\workflows\live-runtime-proof-admission.contract.json'
$registryPath = Join-Path $RepoRoot '.tbg\harness\live-runtime-proof-artifacts.registry.json'
$fixturesPath = Join-Path $RepoRoot '.tbg\harness\fixtures\live-runtime-proof-admission.fixtures.json'
$resultPath = Join-Path $OutputRoot 'live-runtime-proof-admission.result.json'
$reportPath = Join-Path $OutputRoot 'live-runtime-proof-admission.report.md'

$script:failures = New-Object System.Collections.Generic.List[string]
$script:passes = 0

function Add-Pass([string]$Message) {
    $script:passes = [int]$script:passes + 1
    Write-Host "PASS: $Message"
}
function Add-Failure([string]$Message) {
    [void]$script:failures.Add($Message)
    Write-Host "FAIL: $Message"
}
function Get-JsonFile([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure "$Label missing: $Path"
        return $null
    }
    try {
        $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        return $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Add-Failure "$Label invalid JSON: $($_.Exception.Message)"
        return $null
    }
}
function Get-PropertyValue($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $matched = $Object.PSObject.Properties.Match($Name)
    if ($matched -and $matched.Count -gt 0) { return $matched[0].Value }
    return $Default
}
function Get-Bool($Object, [string]$Name) {
    return [bool](Get-PropertyValue $Object $Name $false)
}
function New-AdmissionDecision([string]$TerminalState, [string]$ProofLevel, [string]$Reason) {
    return [pscustomobject][ordered]@{
        terminalState = $TerminalState
        proofLevel = $ProofLevel
        reason = $Reason
        pass = ($TerminalState -eq 'PASS_LIVE_RUNTIME' -or $TerminalState -eq 'PASS_STATIC_ONLY')
    }
}
function Resolve-LiveProofAdmission($Case) {
    $mode = [string](Get-PropertyValue $Case 'mode' '')
    if ($mode -eq 'static_validation') {
        return New-AdmissionDecision 'PASS_STATIC_ONLY' 'static_test' 'Static validation is intentionally capped below live runtime.'
    }
    if ($mode -ne 'live_fresh_launch' -and $mode -ne 'attach_existing') {
        return New-AdmissionDecision 'FAIL_UNKNOWN_MODE' 'contract' "Unknown mode '$mode'."
    }

    if ($mode -eq 'live_fresh_launch') {
        if (Get-Bool $Case 'skipLaunch') {
            return New-AdmissionDecision 'BLOCKED_LIVE_MODE_SKIP_LAUNCH' 'build' 'LiveFreshLaunch cannot suppress launch.'
        }
        if (-not (Get-Bool $Case 'launchRequested')) {
            return New-AdmissionDecision 'BLOCKED_LAUNCH_NOT_REQUESTED' 'build' 'Launch was not requested; this is not an environment blocker.'
        }
        if (-not (Get-Bool $Case 'launchAttempted')) {
            return New-AdmissionDecision 'FAIL_LAUNCH_NOT_ATTEMPTED' 'build' 'Launch request existed but no launch attempt was recorded.'
        }
        if (-not (Get-Bool $Case 'launcherProcessObserved')) {
            return New-AdmissionDecision 'FAIL_LAUNCHER_PROCESS_NOT_OBSERVED' 'build' 'No launcher process was observed.'
        }
        if (-not (Get-Bool $Case 'launcherHwndObserved')) {
            return New-AdmissionDecision 'FAIL_LAUNCHER_HWND_NOT_BOUND' 'launcher' 'Launcher process existed but no usable HWND was bound.'
        }
        if (-not (Get-Bool $Case 'launchActionDispatched')) {
            return New-AdmissionDecision 'FAIL_LAUNCH_ACTION_NOT_DISPATCHED' 'launcher' 'No PLAY/CONTINUE action was dispatched.'
        }
    }
    else {
        if (-not (Get-Bool $Case 'attachExistingAuthority')) {
            return New-AdmissionDecision 'BLOCKED_ATTACH_AUTHORITY_MISSING' 'launcher' 'AttachExisting requires explicit workflow authority.'
        }
    }

    if (-not (Get-Bool $Case 'gameProcessObserved')) {
        return New-AdmissionDecision 'FAIL_GAME_PROCESS_NOT_OBSERVED' 'launcher' 'No correlated game process was observed.'
    }
    if (-not (Get-Bool $Case 'campaignAttached')) {
        return New-AdmissionDecision 'FAIL_CAMPAIGN_ATTACH_NOT_OBSERVED' 'launcher' 'Campaign runtime attachment was not observed.'
    }
    if (-not (Get-Bool $Case 'campaignReady')) {
        return New-AdmissionDecision 'FAIL_CAMPAIGN_NOT_READY' 'launcher' 'Campaign readiness was not observed.'
    }
    if (-not (Get-Bool $Case 'commandIssued')) {
        return New-AdmissionDecision 'FAIL_COMMAND_NOT_ISSUED' 'launcher' 'Required command or trigger was not issued.'
    }
    if (-not (Get-Bool $Case 'commandAckObserved')) {
        return New-AdmissionDecision 'FAIL_COMMAND_ACK_NOT_OBSERVED' 'command_ack' 'Command ACK was not observed.'
    }
    if (-not (Get-Bool $Case 'behaviorObserved')) {
        return New-AdmissionDecision 'FAIL_BEHAVIOR_NOT_OBSERVED' 'command_ack' 'ACK alone is not behavior proof.'
    }
    if (-not (Get-Bool $Case 'runtimeArtifactCollected')) {
        return New-AdmissionDecision 'FAIL_RUNTIME_ARTIFACT_NOT_COLLECTED' 'behavior_observed' 'Behavior was observed but no fresh runtime artifact was collected.'
    }
    if (-not (Get-Bool $Case 'evidenceFresh')) {
        return New-AdmissionDecision 'FAIL_STALE_EVIDENCE' 'behavior_observed' 'Runtime evidence is stale.'
    }
    if (-not (Get-Bool $Case 'correlationContinuous')) {
        return New-AdmissionDecision 'FAIL_CORRELATION_MISMATCH' 'behavior_observed' 'Run/correlation continuity was broken.'
    }

    return New-AdmissionDecision 'PASS_LIVE_RUNTIME' 'live_runtime' 'All required live stages were observed with fresh same-run evidence.'
}

if ($ExportReducerOnly) {
    return
}

$contract = Get-JsonFile $contractPath 'contract'
$registry = Get-JsonFile $registryPath 'artifact registry'
$fixtures = Get-JsonFile $fixturesPath 'fixtures'

if ($contract) {
    if ([string](Get-PropertyValue $contract 'schema') -eq 'TbgLiveRuntimeProofAdmissionContract.v1') { Add-Pass 'contract schema' } else { Add-Failure 'contract schema mismatch' }
    if ([string](Get-PropertyValue $contract 'id') -eq 'live-runtime-proof-admission') { Add-Pass 'contract id' } else { Add-Failure 'contract id mismatch' }

    $modes = Get-PropertyValue $contract 'modes'
    $liveFresh = Get-PropertyValue $modes 'live_fresh_launch'
    $rejectSkip = Get-PropertyValue $liveFresh 'rejectSkipLaunch'
    if ($rejectSkip -eq $true) { Add-Pass 'live fresh launch rejects SkipLaunch' } else { Add-Failure 'live fresh launch must reject SkipLaunch' }

    $staticVal = Get-PropertyValue $modes 'static_validation'
    $proofCeil = Get-PropertyValue $staticVal 'proofCeiling'
    if ([string]$proofCeil -eq 'static_test') { Add-Pass 'static mode proof ceiling' } else { Add-Failure 'static mode proof ceiling mismatch' }

    $terminalStates = @(Get-PropertyValue $contract 'terminalStates' @())
    foreach ($requiredState in @('PASS_LIVE_RUNTIME','BLOCKED_LIVE_MODE_SKIP_LAUNCH','BLOCKED_LAUNCH_NOT_REQUESTED','FAIL_GAME_PROCESS_NOT_OBSERVED','FAIL_BEHAVIOR_NOT_OBSERVED','FAIL_STALE_EVIDENCE','FAIL_CORRELATION_MISMATCH')) {
        if ($terminalStates -contains $requiredState) { Add-Pass "terminal $requiredState" } else { Add-Failure "terminal missing: $requiredState" }
    }
}

if ($registry) {
    if ([string](Get-PropertyValue $registry 'schema') -eq 'TbgLiveRuntimeProofArtifactRegistry.v1') { Add-Pass 'artifact registry schema' } else { Add-Failure 'artifact registry schema mismatch' }
    $artifactsList = @(Get-PropertyValue $registry 'artifacts' @())
    $artifactIds = @($artifactsList | ForEach-Object { [string](Get-PropertyValue $_ 'id') })
    foreach ($requiredArtifact in @('run-context','launcher-context','launch-log','runtime-status','command-ack','behavior-evidence','admission-result')) {
        if ($artifactIds -contains $requiredArtifact) { Add-Pass "artifact $requiredArtifact" } else { Add-Failure "artifact missing: $requiredArtifact" }
    }
    $retention = Get-PropertyValue $registry 'retention'
    $forbidSecrets = Get-PropertyValue $retention 'forbidSecretsSavesAndPersonalPaths'
    if ($forbidSecrets -eq $true) { Add-Pass 'artifact retention safety' } else { Add-Failure 'artifact retention safety missing' }
}

$fixtureResults = @()
if ($fixtures) {
    if ([string](Get-PropertyValue $fixtures 'schema') -eq 'TbgLiveRuntimeProofAdmissionFixtures.v1') { Add-Pass 'fixture schema' } else { Add-Failure 'fixture schema mismatch' }
    $fixtureCases = @(Get-PropertyValue $fixtures 'cases' @())
    if ($fixtureCases.Count -ge 10) { Add-Pass 'fixture coverage count' } else { Add-Failure 'at least 10 admission fixtures are required' }
    foreach ($case in $fixtureCases) {
        $decision = Resolve-LiveProofAdmission $case
        $expectedState = [string](Get-PropertyValue $case 'expectedTerminalState' '')
        $expectedProof = [string](Get-PropertyValue $case 'expectedProofLevel' '')
        $statePass = $decision.terminalState -eq $expectedState
        $proofPass = $decision.proofLevel -eq $expectedProof
        $fixtureResults += [ordered]@{
            id = [string]$case.id
            expectedTerminalState = $expectedState
            actualTerminalState = $decision.terminalState
            expectedProofLevel = $expectedProof
            actualProofLevel = $decision.proofLevel
            pass = ($statePass -and $proofPass)
        }
        if ($statePass -and $proofPass) { Add-Pass "fixture $($case.id)" }
        else { Add-Failure "fixture $($case.id): expected $expectedState/$expectedProof got $($decision.terminalState)/$($decision.proofLevel)" }
    }
}

$inputDecision = $null
$inputResolvedPath = $null
if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $inputResolvedPath = if ([IO.Path]::IsPathRooted($InputPath)) { $InputPath } else { Join-Path $RepoRoot $InputPath }
    $input = Get-JsonFile $inputResolvedPath 'input proof packet'
    if ($input) {
        $inputDecision = Resolve-LiveProofAdmission $input
        Write-Host "INPUT TERMINAL: $($inputDecision.terminalState) proof=$($inputDecision.proofLevel)"
    }
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$result = [ordered]@{
    schema = 'TbgLiveRuntimeProofAdmissionValidation.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    pass = ($failures.Count -eq 0 -and ($null -eq $inputDecision -or $inputDecision.pass))
    staticValidationPass = ($failures.Count -eq 0)
    passCount = $passes
    failureCount = $failures.Count
    failures = @($failures)
    fixtureCount = @($fixtureResults).Count
    fixtures = @($fixtureResults)
    inputPath = $inputResolvedPath
    inputDecision = $inputDecision
    proofLevel = 'static_test'
    proofCeiling = 'static_test unless -InputPath supplies a workflow-owned live proof packet; even then the decision is computed, never narrated'
}
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Force -Encoding UTF8

$terminalLine = if ($inputDecision) { '- Terminal state: `{0}`' -f $inputDecision.terminalState } else { '- No live proof packet supplied; fixture/static validation only.' }
$proofLine = if ($inputDecision) { '- Proof level: `{0}`' -f $inputDecision.proofLevel } else { '- Proof level: `static_test`' }
$report = @(
    '# Live Runtime Proof Admission Report',
    '',
    "Static contract validation: **$(if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' })**",
    "Fixtures: **$(@($fixtureResults).Count)**",
    "Failures: **$($failures.Count)**",
    '',
    '## Machine rule',
    '',
    'The harness computes the terminal state. Agent prose cannot convert a skipped launch, launcher-only result, command ACK, stale artifact, or broken correlation into live-runtime proof.',
    '',
    '## Input decision',
    '',
    $terminalLine,
    $proofLine,
    '',
    'Generated output is evidence, not authority. Runtime mutation still requires the owning workflow contract.'
)
$report -join "`r`n" | Set-Content -LiteralPath $reportPath -Force -Encoding UTF8

Write-Host "`nLive runtime proof admission: $passes passed, $($failures.Count) failed"
if ($failures.Count -gt 0) { exit 1 }
if ($inputDecision -and -not $inputDecision.pass) { exit 2 }
exit 0
