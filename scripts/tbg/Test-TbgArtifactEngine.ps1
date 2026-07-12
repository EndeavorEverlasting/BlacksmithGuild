[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Tbg {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Invoke-TbgChild {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

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
    return [pscustomobject]@{
        exitCode = $exitCode
        output = (($output | Out-String).TrimEnd())
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$scriptPath = Join-Path $repoRoot 'scripts/tbg/Invoke-TbgArtifactEngine.ps1'
$testPath = $PSCommandPath
$contractPath = Join-Path $repoRoot '.tbg/workflows/local-artifact-engine.contract.json'
$registryPath = Join-Path $repoRoot '.tbg/harness/artifact-engines.registry.json'
$wrapperPath = Join-Path $repoRoot 'ForgeArtifactEngine.cmd'

foreach ($path in @($scriptPath, $testPath)) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-Tbg -Condition ($errors.Count -eq 0) -Message "PowerShell parse errors were found in ${path}: $($errors.Message -join '; ')"
}

foreach ($path in @($contractPath, $registryPath)) {
    Assert-Tbg -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Required artifact engine file is missing: $path"
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
}
Assert-Tbg -Condition (Test-Path -LiteralPath $wrapperPath -PathType Leaf) -Message 'ForgeArtifactEngine.cmd is missing.'

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
Assert-Tbg -Condition ($contract.id -eq 'local-artifact-engine') -Message 'The artifact engine workflow contract has the wrong id.'
Assert-Tbg -Condition ($registry.schema -eq 'TbgArtifactEngineRegistry.v1') -Message 'The artifact engine registry has the wrong schema.'
Assert-Tbg -Condition (@($registry.engines).Count -ge 5) -Message 'The artifact engine registry must contain the index, repo-floor, recovery, proof-boundary, and handoff engines.'
Assert-Tbg -Condition (@($registry.engines | Where-Object { $_.authority -ne 'read_only' }).Count -eq 0) -Message 'Every registered artifact engine must remain read-only.'

$engineIds = @($registry.engines.id)
foreach ($requiredId in @('artifact-index', 'repo-floor-context', 'stale-pr-next-action', 'runtime-proof-boundary', 'handoff-compressor')) {
    Assert-Tbg -Condition ($engineIds -contains $requiredId) -Message "Required engine '$requiredId' is not registered."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-artifact-engine-test-" + [guid]::NewGuid().ToString('N'))
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

    [pscustomobject][ordered]@{
        schema = 'TbgRepoHygieneReport.v1'
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        repoRoot = $repoRoot.Path
        branch = 'fixture/main'
        head = '1111111111111111111111111111111111111111'
        upstream = 'origin/main'
        ahead = 0
        behind = 0
        verdict = 'CLEAN'
        blockedReason = ''
        nextCommand = 'git log --oneline --decorate -5'
        dirtyPaths = @()
        conflictedFiles = @()
        operations = @()
        worktrees = @([pscustomobject]@{ path = $repoRoot.Path; head = '1111111111111111111111111111111111111111'; branch = 'main' })
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $repoHygienePath -Encoding UTF8
    '# Fixture Repository Hygiene Report' | Set-Content -LiteralPath $repoHygieneMarkdownPath -Encoding UTF8

    [pscustomobject][ordered]@{
        schema = 'TbgStalePrRecoveryResult.v1'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
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

    $tempRegistry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
    $tempRegistry.defaults.outputRoot = $outputRoot
    $tempRegistry.defaults.stateRoot = $stateRoot
    $tempRegistry.defaults.excludePrefixes = @($outputRoot)

    foreach ($engine in @($tempRegistry.engines)) {
        switch ([string]$engine.id) {
            'artifact-index' {
                $engine.sourceRoots = @($fixtureRoot)
                $engine.rootFilePatterns = @()
            }
            'repo-floor-context' {
                $engine.candidatePaths = @($repoHygienePath, $repoHygieneMarkdownPath)
            }
            'stale-pr-next-action' {
                $engine.candidatePaths = @($staleResultPath, $staleReportPath)
            }
            'runtime-proof-boundary' {
                $engine.candidatePaths = @($commandAckPath)
            }
        }
    }
    $tempRegistry | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempRegistryPath -Encoding UTF8

    $common = @('-RegistryPath', $tempRegistryPath, '-OutputDirectory', $outputRoot)

    $off = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('off') + $common)
    Assert-Tbg -Condition ($off.exitCode -eq 0) -Message "The off command failed: $($off.output)"
    $state = Get-Content -LiteralPath (Join-Path $stateRoot 'state.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition (-not [bool]$state.enabled) -Message 'The off command did not disable automatic processing.'

    Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    $observe = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'observe') + $common)
    Assert-Tbg -Condition ($observe.exitCode -eq 0) -Message "Observe mode failed: $($observe.output)"
    $observeResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($observeResult.terminalState -eq 'READY_observe_complete') -Message 'Observe mode reported the wrong terminal state.'
    Assert-Tbg -Condition ([int]$observeResult.engineRunCount -eq 1) -Message 'Observe mode must run only the artifact-index engine.'
    Assert-Tbg -Condition (-not (Test-Path -LiteralPath (Join-Path $outputRoot 'repo-floor-context.result.json'))) -Message 'Observe mode incorrectly cascaded the repo-floor engine.'

    Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    $auto = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'auto') + $common)
    Assert-Tbg -Condition ($auto.exitCode -eq 0) -Message "Auto mode failed: $($auto.output)"
    $autoResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($autoResult.terminalState -eq 'READY_auto_cascade_complete') -Message 'Auto mode reported the wrong terminal state.'
    Assert-Tbg -Condition ([int]$autoResult.engineRunCount -eq 5) -Message 'Auto mode did not cascade all five registered engines.'

    foreach ($requiredOutput in @(
        'artifact-index.result.json',
        'repo-floor-context.result.json',
        'stale-pr-next-action.result.json',
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

    $repoFloorPacket = Get-Content -LiteralPath (Join-Path $outputRoot 'repo-floor-context.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($repoFloorPacket.terminalState -eq 'READY_repo_floor_clean') -Message 'The repo-floor engine did not classify the clean fixture.'
    $stalePacket = Get-Content -LiteralPath (Join-Path $outputRoot 'stale-pr-next-action.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($stalePacket.terminalState -eq 'READY_bounded_recovery_instruction') -Message 'The recovery engine did not preserve the bounded ready decision after clean floor proof.'
    $proofPacket = Get-Content -LiteralPath (Join-Path $outputRoot 'runtime-proof-boundary.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($proofPacket.payload.parserProofLevel -eq 'artifact_inspection') -Message 'The proof-boundary engine overclaimed parser proof.'

    $eventLines = @(Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.events.jsonl') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $progressLines = @(Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.progress.log') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-Tbg -Condition ($eventLines.Count -eq [int]$autoResult.engineRunCount) -Message 'The event count does not match the engine run count.'
    Assert-Tbg -Condition ($progressLines.Count -eq $eventLines.Count) -Message 'The progress count does not match the event count.'
    foreach ($eventLine in $eventLines) {
        $event = $eventLine | ConvertFrom-Json
        Assert-Tbg -Condition ([string]$event.sentence -match '[.!?]$') -Message 'An artifact engine event does not contain a complete English sentence.'
    }

    $on = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('on', '-Mode', 'auto', '-NoStart') + $common)
    Assert-Tbg -Condition ($on.exitCode -eq 0) -Message "The on command failed: $($on.output)"
    $state = Get-Content -LiteralPath (Join-Path $stateRoot 'state.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ([bool]$state.enabled) -Message 'The on command did not enable automatic processing.'

    $trigger = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('trigger', 'repo-hygiene') + $common)
    Assert-Tbg -Condition ($trigger.exitCode -eq 0) -Message "The producer trigger failed: $($trigger.output)"
    $triggerResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($triggerResult.source -eq 'repo-hygiene') -Message 'The producer trigger source was not preserved.'

    $toggle = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('toggle', '-NoStart') + $common)
    Assert-Tbg -Condition ($toggle.exitCode -eq 0) -Message "The toggle command failed: $($toggle.output)"
    $state = Get-Content -LiteralPath (Join-Path $stateRoot 'state.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition (-not [bool]$state.enabled) -Message 'The toggle command did not change enabled state from on to off.'

    '{ malformed fixture' | Set-Content -LiteralPath $repoHygienePath -Encoding UTF8
    $strict = Invoke-TbgChild -ScriptPath $scriptPath -Arguments (@('run', '-Mode', 'strict') + $common)
    Assert-Tbg -Condition ($strict.exitCode -eq 2) -Message "Strict mode did not fail closed on malformed artifact input. Output: $($strict.output)"
    $strictResult = Get-Content -LiteralPath (Join-Path $outputRoot 'artifact-engine.result.json') -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ($strictResult.terminalState -eq 'BLOCKED_artifact_engine_strict') -Message 'Strict mode reported the wrong blocked terminal state.'

    $wrapperText = Get-Content -LiteralPath $wrapperPath -Raw
    Assert-Tbg -Condition ($wrapperText -match 'Invoke-TbgArtifactEngine\.ps1') -Message 'The root wrapper does not invoke the artifact engine script.'

    Write-Host 'PASS: the local artifact engine exposes a persistent toggle, manual action, producer trigger, automatic cascade, proof boundary, paired artifacts, and strict fail-closed validation.'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
