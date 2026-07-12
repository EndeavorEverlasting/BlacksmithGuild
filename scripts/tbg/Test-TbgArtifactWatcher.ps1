[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Tbg {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-TbgEngineChild {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
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
    $global:LASTEXITCODE = 0
    return [pscustomobject]@{
        exitCode = $exitCode
        output = (($output | Out-String).TrimEnd())
    }
}

function Wait-TbgCondition {
    param(
        [scriptblock]$Condition,
        [int]$TimeoutSeconds = 15,
        [int]$PollMilliseconds = 250
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
    return $false
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$engineScript = Join-Path $repoRoot 'scripts\tbg\Invoke-TbgArtifactEngine.ps1'
$registryPath = Join-Path $repoRoot '.tbg\harness\artifact-engines.registry.json'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tbg-artifact-watcher-' + [guid]::NewGuid().ToString('N'))
$fixtureRoot = Join-Path $tempRoot 'fixtures'
$outputRoot = Join-Path $tempRoot 'output'
$stateRoot = Join-Path $tempRoot 'state'
$tempRegistryPath = Join-Path $tempRoot 'registry.json'
$statePath = Join-Path $stateRoot 'state.json'
$watcherPath = Join-Path $stateRoot 'watcher.json'
$resultPath = Join-Path $outputRoot 'artifact-engine.result.json'
$watcherPid = 0

New-Item -ItemType Directory -Force -Path $fixtureRoot, $outputRoot, $stateRoot | Out-Null

try {
    $baselinePath = Join-Path $fixtureRoot 'watcher-baseline.json'
    [pscustomobject][ordered]@{
        schema = 'TbgWatcherBaseline.v1'
        status = 'baseline'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $baselinePath -Encoding UTF8

    $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
    $registry.defaults.outputRoot = $outputRoot
    $registry.defaults.stateRoot = $stateRoot
    $registry.defaults.pollSeconds = 1
    $registry.defaults.settleMilliseconds = 100
    $registry.defaults.excludePrefixes = @($outputRoot)

    foreach ($engine in @($registry.engines)) {
        if ([string]$engine.id -eq 'artifact-index') {
            $engine.sourceRoots = @($fixtureRoot)
            $engine.rootFilePatterns = @()
        }
    }
    $registry | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempRegistryPath -Encoding UTF8

    $common = @('-RegistryPath', $tempRegistryPath, '-OutputDirectory', $outputRoot)
    $on = Invoke-TbgEngineChild -ScriptPath $engineScript -Arguments (@('on', '-Mode', 'observe', '-PollSeconds', '1') + $common)
    Assert-Tbg -Condition ($on.exitCode -eq 0) -Message "The Windows watcher on action failed: $($on.output)"

    Assert-Tbg -Condition (Test-Path -LiteralPath $statePath -PathType Leaf) -Message 'The on action did not write the local authority state.'
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ([bool]$state.enabled) -Message 'The on action did not enable automatic artifact processing.'
    Assert-Tbg -Condition ([string]$state.mode -eq 'observe') -Message 'The on action did not preserve observe mode.'

    $watcherReady = Wait-TbgCondition -Condition { Test-Path -LiteralPath $watcherPath -PathType Leaf }
    Assert-Tbg -Condition $watcherReady -Message 'The on action did not create a watcher lease.'
    $watcher = Get-Content -LiteralPath $watcherPath -Raw | ConvertFrom-Json
    $watcherPid = [int]$watcher.pid
    Assert-Tbg -Condition ($watcherPid -gt 0) -Message 'The watcher lease did not contain a process id.'
    Assert-Tbg -Condition ($null -ne (Get-Process -Id $watcherPid -ErrorAction SilentlyContinue)) -Message 'The recorded Windows watcher process is not running.'

    Assert-Tbg -Condition (Test-Path -LiteralPath $resultPath -PathType Leaf) -Message 'The toggle-on pass did not write an aggregate result.'
    $initialResult = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ([string]$initialResult.source -eq 'toggle_on') -Message 'The initial automatic pass did not record toggle_on as its source.'
    Assert-Tbg -Condition ([int]$initialResult.engineRunCount -eq 1) -Message 'The initial observe-mode pass did not run exactly the artifact-index engine.'

    $fixturePath = Join-Path $fixtureRoot 'watcher-smoke.json'
    [pscustomobject][ordered]@{
        schema = 'TbgWatcherSmoke.v1'
        status = 'ready'
        generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

    $watcherObserved = Wait-TbgCondition -TimeoutSeconds 20 -Condition {
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { return $false }
        try {
            $candidate = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            return ([string]$candidate.source -eq 'watcher_change_detection' -and [int]$candidate.engineRunCount -eq 1)
        }
        catch { return $false }
    }
    Assert-Tbg -Condition $watcherObserved -Message 'The Windows watcher did not detect and process the new local artifact.'

    $watcherResult = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Assert-Tbg -Condition ([string]$watcherResult.terminalState -eq 'READY_observe_complete') -Message 'The watcher pass reported the wrong terminal state.'
    Assert-Tbg -Condition ([string]$watcherResult.mode -eq 'observe') -Message 'The watcher pass did not preserve the selected mode.'

    $indexPacketPath = Join-Path $outputRoot 'artifact-index.result.json'
    Assert-Tbg -Condition (Test-Path -LiteralPath $indexPacketPath -PathType Leaf) -Message 'The watcher pass did not write an artifact-index packet.'
    $indexPacket = Get-Content -LiteralPath $indexPacketPath -Raw | ConvertFrom-Json
    $observedPaths = @($indexPacket.payload.artifacts | ForEach-Object { [string]$_.path })
    Assert-Tbg -Condition ($observedPaths -contains $baselinePath) -Message 'The artifact-index packet did not preserve the baseline artifact.'
    Assert-Tbg -Condition ($observedPaths -contains $fixturePath) -Message 'The artifact-index packet did not retain the newly written external artifact path.'

    $off = Invoke-TbgEngineChild -ScriptPath $engineScript -Arguments (@('off') + $common)
    Assert-Tbg -Condition ($off.exitCode -eq 0) -Message "The Windows watcher off action failed: $($off.output)"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert-Tbg -Condition (-not [bool]$state.enabled) -Message 'The off action did not revoke automatic artifact authority.'

    $watcherStopped = Wait-TbgCondition -Condition { $null -eq (Get-Process -Id $watcherPid -ErrorAction SilentlyContinue) }
    Assert-Tbg -Condition $watcherStopped -Message 'The off action did not stop the recorded Windows watcher process.'
    Assert-Tbg -Condition (-not (Test-Path -LiteralPath $watcherPath)) -Message 'The off action did not remove the watcher lease.'

    Write-Host 'PASS: Windows PowerShell started the artifact watcher, detected a local artifact change without a producer command, wrote an observe-mode packet, and stopped through the operator toggle.'
}
finally {
    if ($watcherPid -gt 0) {
        Stop-Process -Id $watcherPid -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
