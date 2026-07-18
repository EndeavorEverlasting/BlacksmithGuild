[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Tbg {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-TbgChild {
    param([string]$ScriptPath, [string[]]$Arguments)

    $hostPath = (Get-Process -Id $PID).Path
    $hostArguments = New-Object System.Collections.Generic.List[string]
    $hostArguments.Add('-NoProfile') | Out-Null
    if ($env:OS -eq 'Windows_NT') {
        $hostArguments.Add('-ExecutionPolicy') | Out-Null
        $hostArguments.Add('Bypass') | Out-Null
    }
    $hostArguments.Add('-File') | Out-Null
    $hostArguments.Add($ScriptPath) | Out-Null
    foreach ($argument in $Arguments) { $hostArguments.Add($argument) | Out-Null }

    $output = & $hostPath @($hostArguments.ToArray()) 2>&1
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return [pscustomobject]@{
        exitCode = $exitCode
        output = (($output | Out-String).TrimEnd())
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scriptPath = Join-Path $repoRoot 'scripts/tbg/Invoke-TbgArtifactEngine.ps1'
$contractPath = Join-Path $repoRoot '.tbg/workflows/local-artifact-engine.contract.json'
$registryPath = Join-Path $repoRoot '.tbg/harness/artifact-engines.registry.json'
$wrapperPath = Join-Path $repoRoot 'ForgeArtifactEngine.cmd'
$producerWrappers = @(
    (Join-Path $repoRoot 'ForgeRepoHygiene.cmd'),
    (Join-Path $repoRoot 'ForgeStalePrRecovery.cmd')
)

foreach ($path in @($scriptPath, $PSCommandPath)) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors) | Out-Null
    $messages = @($parseErrors | ForEach-Object { $_.Message }) -join '; '
    Assert-Tbg -Condition (@($parseErrors).Count -eq 0) -Message "PowerShell parse errors were found in ${path}: $messages"
}

foreach ($path in @($contractPath, $registryPath)) {
    Assert-Tbg -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Required artifact engine file is missing: $path"
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
}
Assert-Tbg -Condition (Test-Path -LiteralPath $wrapperPath -PathType Leaf) -Message 'ForgeArtifactEngine.cmd is missing.'

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
Assert-Tbg -Condition ($contract.id -eq 'local-artifact-engine') -Message 'The workflow contract has the wrong id.'
Assert-Tbg -Condition ($registry.schema -eq 'TbgArtifactEngineRegistry.v1') -Message 'The registry has the wrong schema.'
Assert-Tbg -Condition (@($registry.engines).Count -eq 6) -Message 'The registry must contain exactly six engines including window-lifecycle-boundary.'
Assert-Tbg -Condition (@($registry.engines | Where-Object { $_.authority -ne 'read_only' }).Count -eq 0) -Message 'Every artifact engine must remain read-only.'

$engineIds = @($registry.engines.id)
foreach ($requiredId in @('artifact-index', 'repo-floor-context', 'stale-pr-next-action', 'window-lifecycle-boundary', 'runtime-proof-boundary', 'handoff-compressor')) {
    Assert-Tbg -Condition ($engineIds -contains $requiredId) -Message "Required engine '$requiredId' is missing."
}

$wrapperText = Get-Content -LiteralPath $wrapperPath -Raw
Assert-Tbg -Condition ($wrapperText -match 'Invoke-TbgArtifactEngine\.ps1') -Message 'The operator wrapper does not invoke the artifact engine.'
foreach ($producerWrapper in $producerWrappers) {
    $producerText = Get-Content -LiteralPath $producerWrapper -Raw
    Assert-Tbg -Condition ($producerText -match 'ForgeArtifactEngine\.cmd" trigger') -Message "Producer wrapper '$producerWrapper' does not emit an artifact-engine trigger."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tbg-artifact-engine-test-' + [guid]::NewGuid().ToString('N'))
$fixtureRoot = Join-Path $tempRoot 'fixtures'
$outputRoot = Join-Path $tempRoot 'output'
$stateRoot = Join-Path $tempRoot 'state'
$tempRegistryPath = Join-Path $tempRoot 'registry.json'
New-Item -ItemType Directory -Force -Path $fixtureRoot, $outputRoot, $stateRoot | Out-Null

try {
    $repoHygienePath = Join-Path $fixtureRoot 'repo-hygiene-report.json'
    $repoHygieneMarkdownPath = Join-Path $fixtureRoot 'repo-hygiene-report.md'
    $staleResultPath = Join-Path $fixtureRoot 'stale-pr-recovery.result.json'
    $staleReportPath = Join-Path $fixtureRoot 'stale-pr-recovery.report.md'
    $commandAckPath = Join-Path $fixtureRoot 'BlacksmithGuild_CommandAck.json'
    $lifecycleRoot = Join-Path $fixtureRoot 'window-lifecycle'
    New-Item -ItemType Directory -Force -Path $lifecycleRoot | Out-Null
    $lifecycleStatePath = Join-Path $lifecycleRoot 'window-lifecycle.state.json'
    $lifecycleResultPath = Join-Path $lifecycleRoot 'window-lifecycle.result.json'
    $lifecycleReportPath = Join-Path $lifecycleRoot 'window-lifecycle.report.md'

    [pscustomobject][ordered]@{
        schema = 'TbgRepoHygieneReport.v1'
        branch = 'fixture/main'
        head = '1111111111111111111111111111111111111111'
        upstream = 'origin/main'
        verdict = 'CLEAN'
        nextCommand = 'git log --oneline --decorate -5'
        dirtyPaths = @()
        conflictedFiles = @()
        operations = @()
        worktrees = @([pscustomobject]@{ path = $repoRoot; branch = 'main' })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $repoHygienePath -Encoding UTF8
    '# Fixture Repository Hygiene Report' | Set-Content -LiteralPath $repoHygieneMarkdownPath -Encoding UTF8

    [pscustomobject][ordered]@{
        schema = 'TbgStalePrRecoveryResult.v1'
        status = 'ready'
        verdict = 'READY'
        terminalState = 'READY_bounded_recovery_instruction'
        nextCommand = 'gh pr view 2 --json number,state,headRefOid'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $staleResultPath -Encoding UTF8
    '# Fixture Stale PR Recovery Report' | Set-Content -LiteralPath $staleReportPath -Encoding UTF8

    [pscustomobject][ordered]@{
        schema = 'TbgCommandAck.v1'
        status = 'success'
        verdict = 'ACK'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $commandAckPath -Encoding UTF8

    [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleMaterializedState.v1'
        windows = @([pscustomobject]@{ windowKey = 'pid:1|hwnd:1'; phase = 'action_dispatch'; identityId = 'bannerlord.launcher' })
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lifecycleStatePath -Encoding UTF8
    [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleRuntimeResult.v1'
        status = 'ready'
        proofLevel = 'runtime_adapter_harness'
        proofCeiling = 'launcher_lifecycle_harness'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lifecycleResultPath -Encoding UTF8
    '# Fixture Window Lifecycle Report' | Set-Content -LiteralPath $lifecycleReportPath -Encoding UTF8

    $fixtureRegistry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
    $fixtureRegistry.defaults.outputRoot = $outputRoot
    $fixtureRegistry.defaults.stateRoot = $stateRoot
    $fixtureRegistry.defaults.excludePrefixes = @($outputRoot)
    foreach ($engine in @($fixtureRegistry.engines)) {
        switch ([string]$engine.id) {
            'artifact-index' {
                $engine.sourceRoots = @($fixtureRoot)
                $engine.rootFilePatterns = @()
            }
            'repo-floor-context' { $engine.candidatePaths = @($repoHygienePath, $repoHygieneMarkdownPath) }
            'stale-pr-next-action' { $engine.candidatePaths = @($staleResultPath, $staleReportPath) }
            'window-lifecycle-boundary' { $engine.candidatePaths = @($lifecycleStatePath, $lifecycleResultPath, $lifecycleReportPath) }
            'runtime-proof-boundary' { $engine.candidatePaths = @($commandAckPath, $lifecycleResultPath) }
        }
    }
    $fixtureRegistry | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempRegistryPath -Encoding UTF8
    $common = @('-RegistryPath', $tempRegistryPath, '-OutputDirectory', $outputRoot)

    $off = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('off') + $common)
    Assert-Tbg -Condition ($off.exitCode -eq 0) -Message "The off action failed: $($off.output)"
    $state = Get-Content -LiteralPath (Join-Path $stateRoot 'state.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition (-not [bool]$state.enabled) -Message 'The off action did not disable automatic processing.'

    $observe = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'observe') + $common)
    Assert-Tbg -Condition ($observe.exitCode -eq 0) -Message "Observe mode failed: $($observe.output)"
    $observeResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($observeResult.terminalState -eq 'READY_observe_complete') -Message 'Observe mode reported the wrong terminal state.'
    Assert-Tbg -Condition ([int]$observeResult.engineRunCount -eq 1) -Message 'Observe mode cascaded beyond the artifact index.'
    Assert-Tbg -Condition (-not (Test-Path -LiteralPath (Join-Path $outputRoot 'repo-floor-context.result.json'))) -Message 'Observe mode wrote a downstream packet.'

    Remove-Item -LiteralPath $outputRoot -Recurse -Force
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    $auto = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'auto') + $common)
    Assert-Tbg -Condition ($auto.exitCode -eq 0) -Message "Auto mode failed: $($auto.output)"
    $autoResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($autoResult.terminalState -eq 'READY_auto_cascade_complete') -Message 'Auto mode reported the wrong terminal state.'
    Assert-Tbg -Condition ([int]$autoResult.engineRunCount -eq 6) -Message 'Auto mode did not run all six engines.'

    foreach ($requiredOutput in @(
        'artifact-index.result.json',
        'repo-floor-context.result.json',
        'stale-pr-next-action.result.json',
        'window-lifecycle-boundary.result.json',
        'runtime-proof-boundary.result.json',
        'handoff-compressor.result.json',
        'artifact-engine.result.json',
        'artifact-engine.report.md',
        'artifact-engine.events.jsonl',
        'artifact-engine.progress.log',
        'artifact-engine.handoff.md'
    )) {
        Assert-Tbg -Condition (Test-Path -LiteralPath (Join-Path $outputRoot $requiredOutput) -PathType Leaf) -Message "Auto mode did not write $requiredOutput."
    }

    $floorPacket = Get-Content -LiteralPath (Join-Path $outputRoot 'repo-floor-context.result.json') -Raw | ConvertFrom-Json
    $recoveryPacket = Get-Content -LiteralPath (Join-Path $outputRoot 'stale-pr-next-action.result.json') -Raw | ConvertFrom-Json
    $lifecyclePacket = Get-Content -LiteralPath (Join-Path $outputRoot 'window-lifecycle-boundary.result.json') -Raw | ConvertFrom-Json
    $proofPacket = Get-Content -LiteralPath (Join-Path $outputRoot 'runtime-proof-boundary.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($floorPacket.terminalState -eq 'READY_repo_floor_clean') -Message 'The floor engine did not classify the clean fixture.'
    Assert-Tbg -Condition ($recoveryPacket.terminalState -eq 'READY_bounded_recovery_instruction') -Message 'The recovery engine did not consume clean floor context.'
    Assert-Tbg -Condition ($lifecyclePacket.terminalState -eq 'READY_window_lifecycle_boundary_classified') -Message 'The lifecycle boundary engine did not classify fresh lifecycle fixtures.'
    Assert-Tbg -Condition ($lifecyclePacket.payload.actionAuthority -eq 'none') -Message 'The lifecycle boundary engine must never authorize actions.'
    Assert-Tbg -Condition ($proofPacket.payload.parserProofLevel -eq 'artifact_inspection') -Message 'The proof engine overclaimed parser proof.'

    $events = @(Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.events.jsonl') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $progress = @(Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.progress.log') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-Tbg -Condition ($events.Count -eq [int]$autoResult.engineRunCount) -Message 'The JSONL event count does not match the engine count.'
    Assert-Tbg -Condition ($progress.Count -eq $events.Count) -Message 'The progress count does not match the JSONL event count.'
    foreach ($eventLine in $events) {
        $event = $eventLine | ConvertFrom-Json
        Assert-Tbg -Condition ([string]$event.sentence -match '[.!?]$') -Message 'An engine event is not a complete English sentence.'
    }

    $on = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('on', '-Mode', 'auto', '-NoStart') + $common)
    Assert-Tbg -Condition ($on.exitCode -eq 0) -Message "The on action failed: $($on.output)"
    $state = Get-Content -LiteralPath (Join-Path $stateRoot 'state.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ([bool]$state.enabled) -Message 'The on action did not enable automatic processing.'

    $trigger = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('trigger', 'repo-hygiene') + $common)
    Assert-Tbg -Condition ($trigger.exitCode -eq 0) -Message "The producer trigger failed: $($trigger.output)"
    $triggerResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($triggerResult.source -eq 'repo-hygiene') -Message 'The producer identity was not preserved.'

    $toggle = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('toggle', '-NoStart') + $common)
    Assert-Tbg -Condition ($toggle.exitCode -eq 0) -Message "The toggle action failed: $($toggle.output)"
    $state = Get-Content -LiteralPath (Join-Path $stateRoot 'state.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition (-not [bool]$state.enabled) -Message 'Toggle did not change automatic processing from on to off.'

    '{ malformed fixture' | Set-Content -LiteralPath $repoHygienePath -Encoding UTF8
    $strict = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'strict') + $common)
    Assert-Tbg -Condition ($strict.exitCode -eq 2) -Message "Strict mode did not fail closed: $($strict.output)"
    $strictResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($strictResult.terminalState -eq 'BLOCKED_artifact_engine_strict') -Message 'Strict mode reported the wrong terminal state.'

    '{ malformed lifecycle' | Set-Content -LiteralPath $lifecycleResultPath -Encoding UTF8
    Remove-Item -LiteralPath $outputRoot -Recurse -Force
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    [pscustomobject][ordered]@{
        schema = 'TbgRepoHygieneReport.v1'
        branch = 'fixture/main'
        head = '1111111111111111111111111111111111111111'
        upstream = 'origin/main'
        verdict = 'CLEAN'
        nextCommand = 'git log --oneline --decorate -5'
        dirtyPaths = @()
        conflictedFiles = @()
        operations = @()
        worktrees = @([pscustomobject]@{ path = $repoRoot; branch = 'main' })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $repoHygienePath -Encoding UTF8
    $malformedLifecycle = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'strict') + $common)
    Assert-Tbg -Condition ($malformedLifecycle.exitCode -eq 2) -Message "Malformed lifecycle artifacts did not fail closed: $($malformedLifecycle.output)"
    $malformedLifecyclePacket = Get-Content -LiteralPath (Join-Path $outputRoot 'window-lifecycle-boundary.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($malformedLifecyclePacket.terminalState -eq 'BLOCKED_window_lifecycle_parse_error') -Message 'Malformed lifecycle artifacts did not block the lifecycle boundary engine.'

    [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleMaterializedState.v1'
        windows = @([pscustomobject]@{ windowKey = 'pid:2|hwnd:2'; phase = 'unknown_quarantined'; identityId = 'unknown' })
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lifecycleStatePath -Encoding UTF8
    [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleRuntimeResult.v1'
        status = 'ready'
        proofLevel = 'runtime_adapter_harness'
        proofCeiling = 'launcher_lifecycle_harness'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lifecycleResultPath -Encoding UTF8
    Remove-Item -LiteralPath $outputRoot -Recurse -Force
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    $quarantine = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'auto') + $common)
    Assert-Tbg -Condition ($quarantine.exitCode -eq 0) -Message "Quarantine lifecycle fixture failed: $($quarantine.output)"
    $quarantinePacket = Get-Content -LiteralPath (Join-Path $outputRoot 'window-lifecycle-boundary.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($quarantinePacket.terminalState -eq 'WAITING_window_lifecycle_quarantined') -Message 'Unknown quarantine did not wait without action authority.'
    Assert-Tbg -Condition ($quarantinePacket.payload.actionAuthority -eq 'none') -Message 'Quarantine must never authorize a click.'

    Write-Host 'PASS: the local artifact engine exposes a persistent toggle, manual action, producer triggers, an automatic read-only cascade, window-lifecycle boundary classification, conservative proof boundaries, paired artifacts, and strict fail-closed validation.'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
