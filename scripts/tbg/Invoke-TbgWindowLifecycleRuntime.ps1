[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('reduce', 'replay', 'status')]
    [string]$Command,

    [string]$RunId,
    [string]$CorrelationId,
    [string]$EventJson,
    [string]$EventPath,
    [string]$FixturePath,
    [string]$CaseId,
    [string]$OutputRoot,
    [string]$LatestOutputDirectory,
    [string]$LauncherContextPath,
    [Nullable[int]]$TargetProcessId,
    [Nullable[Int64]]$TargetHwnd,
    [ValidateSet('play', 'continue', 'fixture', 'unknown')]
    [string]$LaunchIntent = 'unknown',
    [ValidateSet('fixture', 'live')]
    [string]$Mode = 'fixture',
    [string]$CreatedBy = 'Invoke-TbgWindowLifecycleRuntime.ps1',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$reducerPath = Join-Path $repoRoot 'scripts\tbg\Resolve-TbgWindowLifecycle.ps1'
if (-not (Test-Path -LiteralPath $reducerPath -PathType Leaf)) {
    throw "The pure lifecycle reducer is missing: $reducerPath"
}
. $reducerPath

$defaultLatest = Join-Path $repoRoot 'artifacts\latest\window-lifecycle'
$defaultRuntimeRoot = Join-Path $repoRoot '.local\tbg-window-lifecycle'
$pointerPath = Join-Path $defaultLatest 'window-lifecycle.latest-run.json'

function Ensure-TbgDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Write-TbgAtomicJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 30
    )
    $parent = Split-Path -Parent $Path
    if ($parent) { Ensure-TbgDirectory -Path $parent }
    $tempPath = "$Path.tmp"
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $tempPath -Encoding UTF8
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function Read-TbgJsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-TbgRepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/')
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $full.Substring($root.Length).TrimStart('\', '/')
        return ($relative -replace '\\', '/')
    }
    return ($full -replace '\\', '/')
}

function Get-TbgGitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    try {
        $output = & git -C $repoRoot @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return '' }
        return ([string](@($output) -join "`n")).Trim()
    }
    catch {
        return ''
    }
}

function New-TbgLifecycleRunId {
    return 'wl-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
}

function Resolve-TbgLifecyclePaths {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRunId,
        [string]$ResolvedOutputRoot,
        [string]$ResolvedLatest
    )

    $baseRoot = if ([string]::IsNullOrWhiteSpace($ResolvedOutputRoot)) {
        $defaultRuntimeRoot
    }
    else {
        if ([IO.Path]::IsPathRooted($ResolvedOutputRoot)) { $ResolvedOutputRoot } else { Join-Path $repoRoot $ResolvedOutputRoot }
    }
    $runRoot = Join-Path $baseRoot $ResolvedRunId

    $latest = if ([string]::IsNullOrWhiteSpace($ResolvedLatest)) { $defaultLatest } else {
        if ([IO.Path]::IsPathRooted($ResolvedLatest)) { $ResolvedLatest } else { Join-Path $repoRoot $ResolvedLatest }
    }

    return [pscustomobject][ordered]@{
        runRoot = $runRoot
        latest = $latest
        runContextPath = Join-Path $runRoot 'run-context.json'
        artifactRegistryPath = Join-Path $runRoot 'artifact-registry.json'
        eventsPath = Join-Path $runRoot 'events.jsonl'
        statePath = Join-Path $runRoot 'state.json'
        resultPath = Join-Path $runRoot 'result.json'
        reportPath = Join-Path $runRoot 'operator-report.md'
        handoffPath = Join-Path $runRoot 'handoff.md'
        latestRunContextPath = Join-Path $latest 'window-lifecycle.run-context.json'
        latestArtifactRegistryPath = Join-Path $latest 'window-lifecycle.artifact-registry.json'
        latestEventsPath = Join-Path $latest 'window-lifecycle.events.jsonl'
        latestStatePath = Join-Path $latest 'window-lifecycle.state.json'
        latestResultPath = Join-Path $latest 'window-lifecycle.result.json'
        latestReportPath = Join-Path $latest 'window-lifecycle.report.md'
        latestHandoffPath = Join-Path $latest 'window-lifecycle.handoff.md'
    }
}

function New-TbgLifecycleRunContext {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRunId,
        [Parameter(Mandatory = $true)][string]$ResolvedCorrelationId,
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][string]$ResolvedMode,
        [string]$ResolvedLaunchIntent,
        [string]$ResolvedLauncherContextPath,
        [Nullable[int]]$ResolvedTargetProcessId,
        [Nullable[Int64]]$ResolvedTargetHwnd,
        [string]$ResolvedFixturePath,
        [string]$ResolvedCreatedBy
    )

    $branch = Get-TbgGitText -Arguments @('branch', '--show-current')
    if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'detached' }
    $sourceCommit = Get-TbgGitText -Arguments @('rev-parse', 'HEAD')
    if ([string]::IsNullOrWhiteSpace($sourceCommit)) { $sourceCommit = 'unknown-source-commit' }

    $launcherRelative = $null
    if (-not [string]::IsNullOrWhiteSpace($ResolvedLauncherContextPath)) {
        $launcherRelative = Get-TbgRepoRelativePath -Path $ResolvedLauncherContextPath
    }

    $fixtureRelative = $null
    if (-not [string]::IsNullOrWhiteSpace($ResolvedFixturePath)) {
        $fixtureRelative = Get-TbgRepoRelativePath -Path $ResolvedFixturePath
    }

    return [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleRunContext.v1'
        runId = $ResolvedRunId
        correlationId = $ResolvedCorrelationId
        sourceCommit = $sourceCommit
        branch = $branch
        launcherContextPath = $launcherRelative
        targetProcessId = if ($null -eq $ResolvedTargetProcessId) { $null } else { [int]$ResolvedTargetProcessId }
        targetHwnd = if ($null -eq $ResolvedTargetHwnd) { $null } else { [Int64]$ResolvedTargetHwnd }
        launchIntent = if ([string]::IsNullOrWhiteSpace($ResolvedLaunchIntent)) { 'unknown' } else { $ResolvedLaunchIntent }
        mode = $ResolvedMode
        startedUtc = [DateTime]::UtcNow.ToString('o')
        proofCeiling = 'launcher_lifecycle_harness'
        outputRoot = Get-TbgRepoRelativePath -Path $Paths.runRoot
        latestOutputDirectory = Get-TbgRepoRelativePath -Path $Paths.latest
        fixturePath = $fixtureRelative
        createdBy = $ResolvedCreatedBy
    }
}

function New-TbgLifecycleMaterializedState {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRunId,
        [Parameter(Mandatory = $true)][string]$ResolvedCorrelationId
    )

    return [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleMaterializedState.v1'
        runId = $ResolvedRunId
        correlationId = $ResolvedCorrelationId
        updatedUtc = [DateTime]::UtcNow.ToString('o')
        windows = @()
        sequenceCursor = [pscustomobject]@{}
        rejectedTransitions = @()
    }
}

function Get-TbgLifecycleWindowState {
    param(
        [Parameter(Mandatory = $true)]$Materialized,
        [Parameter(Mandatory = $true)][string]$WindowKey
    )

    $existing = @($Materialized.windows | Where-Object { [string]$_.windowKey -eq $WindowKey } | Select-Object -First 1)
    if ($existing.Count -gt 0) { return $existing[0] }
    return New-TbgWindowLifecycleState -WindowKey $WindowKey
}

function Set-TbgLifecycleWindowState {
    param(
        [Parameter(Mandatory = $true)]$Materialized,
        [Parameter(Mandatory = $true)]$State
    )

    $windows = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Materialized.windows)) {
        if ([string]$item.windowKey -ne [string]$State.windowKey) {
            $windows.Add($item) | Out-Null
        }
    }
    $windows.Add($State) | Out-Null
    $Materialized.windows = @($windows.ToArray())
    $Materialized.updatedUtc = [DateTime]::UtcNow.ToString('o')
    return $Materialized
}

function Get-TbgLifecycleSequenceCursor {
    param(
        [Parameter(Mandatory = $true)]$Materialized,
        [Parameter(Mandatory = $true)][string]$WindowKey
    )

    $property = $Materialized.sequenceCursor.PSObject.Properties[$WindowKey]
    if ($null -eq $property) { return 0 }
    return [int]$property.Value
}

function Set-TbgLifecycleSequenceCursor {
    param(
        [Parameter(Mandatory = $true)]$Materialized,
        [Parameter(Mandatory = $true)][string]$WindowKey,
        [Parameter(Mandatory = $true)][int]$Sequence
    )

    $Materialized.sequenceCursor | Add-Member -NotePropertyName $WindowKey -NotePropertyValue $Sequence -Force
    return $Materialized
}

function New-TbgLifecycleRuntimeEventObject {
    param(
        [Parameter(Mandatory = $true)]$RunContext,
        [Parameter(Mandatory = $true)]$EventInput,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $sequence = [int](Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'sequence' -DefaultValue 0)
    $eventType = [string](Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'eventType' -DefaultValue '')
    $windowKey = [string](Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'windowKey' -DefaultValue '')
    if ([string]::IsNullOrWhiteSpace($windowKey)) {
        throw 'Runtime lifecycle events require windowKey.'
    }
    if ($sequence -lt 1) { throw 'Runtime lifecycle event sequence must be at least 1.' }
    if ([string]::IsNullOrWhiteSpace($eventType)) { throw 'Runtime lifecycle eventType must not be empty.' }

    $identityId = Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'identityId'
    $actionId = Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'actionId'
    $reason = Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'reason'
    $sentence = Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'sentence'
    $observedUtc = Get-TbgWindowLifecycleEventProperty -Event $EventInput -Name 'observedUtc' -DefaultValue ([DateTime]::UtcNow.ToString('o'))

    return [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleRuntimeEvent.v1'
        runId = [string]$RunContext.runId
        correlationId = [string]$RunContext.correlationId
        windowKey = $windowKey
        sequence = $sequence
        eventType = $eventType
        identityId = if ($null -eq $identityId) { $null } else { [string]$identityId }
        actionId = if ($null -eq $actionId) { $null } else { [string]$actionId }
        reason = if ($null -eq $reason) { $null } else { [string]$reason }
        observedUtc = [string]$observedUtc
        source = $Source
        sentence = if ($null -eq $sentence) { $null } else { [string]$sentence }
    }
}

function New-TbgLifecycleRejectedTransition {
    param(
        [Parameter(Mandatory = $true)][string]$WindowKey,
        [Parameter(Mandatory = $true)][int]$Sequence,
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][string]$FromState
    )

    $transitionId = Get-TbgWindowLifecycleTransitionId -WindowKey $WindowKey -Sequence $Sequence -EventType $EventType
    return [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleTransition.v1'
        transitionId = $transitionId
        windowKey = $WindowKey
        sequence = $Sequence
        eventType = $EventType
        fromState = $FromState
        toState = $FromState
        accepted = $false
        reason = $Reason
        identityId = $null
        actionId = $null
        proofBoundary = 'A lifecycle transition proves deterministic harness state only. Action dispatch does not prove application acceptance, campaign readiness, movement, arrival, trade, or live product success.'
    }
}

function Write-TbgLifecycleEnglishArtifacts {
    param(
        [Parameter(Mandatory = $true)]$RunContext,
        [Parameter(Mandatory = $true)]$Materialized,
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)]$Paths
    )

    $report = New-Object System.Collections.Generic.List[string]
    $report.Add('# Window lifecycle runtime report')
    $report.Add('')
    $report.Add(('The runtime adapter reduced run `{0}` on branch `{1}` at commit `{2}`.' -f $RunContext.runId, $RunContext.branch, $RunContext.sourceCommit))
    $report.Add(('The correlation identifier is `{0}` and the declared proof ceiling is `{1}`.' -f $RunContext.correlationId, $RunContext.proofCeiling))
    $report.Add(('This run accepted {0} transitions and rejected {1} transitions across {2} window keys.' -f $Result.acceptedTransitions, $Result.rejectedTransitions, @($Materialized.windows).Count))
    $report.Add('')
    $report.Add('## Window states')
    $report.Add('')
    if (@($Materialized.windows).Count -eq 0) {
        $report.Add('No window lifecycle state has been materialized yet.')
    }
    foreach ($window in @($Materialized.windows)) {
        $report.Add(('### `{0}`' -f $window.windowKey))
        $report.Add('')
        $report.Add(('The window is in phase `{0}` with proof level `{1}`.' -f $window.phase, $window.proofLevel))
        if ($null -ne $window.identityId) {
            $report.Add(('The retained identity is `{0}`.' -f $window.identityId))
        }
        if ($null -ne $window.actionId) {
            $report.Add(('The retained action identifier is `{0}`.' -f $window.actionId))
        }
        $report.Add(('The terminal flag is `{0}`.' -f ([bool]$window.terminal).ToString().ToLowerInvariant()))
        $report.Add('')
    }
    $report.Add('## Proof boundary')
    $report.Add('')
    $report.Add('This report proves deterministic lifecycle reduction and artifact materialization only. Action dispatch does not prove application acceptance. Window disappearance does not prove Bannerlord accepted an action. Terminal observation does not prove campaign readiness, command acknowledgement, movement, arrival, trade, or live product success.')
    $report | Set-Content -LiteralPath $Paths.reportPath -Encoding UTF8

    $handoff = New-Object System.Collections.Generic.List[string]
    $handoff.Add('# Window lifecycle runtime handoff')
    $handoff.Add('')
    $handoff.Add(('Consume the materialized artifacts for run `{0}` under `{1}`.' -f $RunContext.runId, $RunContext.outputRoot))
    $handoff.Add(('The latest view is mirrored under `{0}`.' -f $RunContext.latestOutputDirectory))
    $handoff.Add('')
    $handoff.Add('P20 may route skills, capabilities, operations, and artifact-engine triggers against these contracts. P21 may consume the artifacts as an upstream launcher-lifecycle gate. Neither consumer may invent alternate lifecycle output shapes.')
    $handoff.Add('')
    $handoff.Add('Exact status command:')
    $handoff.Add('')
    $handoff.Add('```powershell')
    $handoff.Add('.\ForgeWindowLifecycle.cmd status')
    $handoff.Add('```')
    $handoff | Set-Content -LiteralPath $Paths.handoffPath -Encoding UTF8
}

function Write-TbgLifecycleArtifacts {
    param(
        [Parameter(Mandatory = $true)]$RunContext,
        [Parameter(Mandatory = $true)]$Materialized,
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)]$Paths,
        [Parameter(Mandatory = $true)][object[]]$EventLines
    )

    Ensure-TbgDirectory -Path $Paths.runRoot
    Ensure-TbgDirectory -Path $Paths.latest

    Write-TbgAtomicJson -Value $RunContext -Path $Paths.runContextPath
    Write-TbgAtomicJson -Value $Materialized -Path $Paths.statePath
    Write-TbgAtomicJson -Value $Result -Path $Paths.resultPath

    $eventsText = (@($EventLines | ForEach-Object { $_ | ConvertTo-Json -Depth 20 -Compress }) -join [Environment]::NewLine)
    if ([string]::IsNullOrWhiteSpace($eventsText)) { $eventsText = '' }
    Set-Content -LiteralPath $Paths.eventsPath -Value $eventsText -Encoding UTF8

    $artifactRegistry = [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleArtifactRegistry.v1'
        runId = [string]$RunContext.runId
        correlationId = [string]$RunContext.correlationId
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        artifacts = @(
            [pscustomobject][ordered]@{ type = 'run-context'; path = 'run-context.json'; latestPath = 'window-lifecycle.run-context.json' }
            [pscustomobject][ordered]@{ type = 'artifact-registry'; path = 'artifact-registry.json'; latestPath = 'window-lifecycle.artifact-registry.json' }
            [pscustomobject][ordered]@{ type = 'events'; path = 'events.jsonl'; latestPath = 'window-lifecycle.events.jsonl' }
            [pscustomobject][ordered]@{ type = 'state'; path = 'state.json'; latestPath = 'window-lifecycle.state.json' }
            [pscustomobject][ordered]@{ type = 'result'; path = 'result.json'; latestPath = 'window-lifecycle.result.json' }
            [pscustomobject][ordered]@{ type = 'operator-report'; path = 'operator-report.md'; latestPath = 'window-lifecycle.report.md' }
            [pscustomobject][ordered]@{ type = 'handoff'; path = 'handoff.md'; latestPath = 'window-lifecycle.handoff.md' }
        )
    }
    Write-TbgAtomicJson -Value $artifactRegistry -Path $Paths.artifactRegistryPath
    Write-TbgLifecycleEnglishArtifacts -RunContext $RunContext -Materialized $Materialized -Result $Result -Paths $Paths

    Copy-Item -LiteralPath $Paths.runContextPath -Destination $Paths.latestRunContextPath -Force
    Copy-Item -LiteralPath $Paths.artifactRegistryPath -Destination $Paths.latestArtifactRegistryPath -Force
    Copy-Item -LiteralPath $Paths.eventsPath -Destination $Paths.latestEventsPath -Force
    Copy-Item -LiteralPath $Paths.statePath -Destination $Paths.latestStatePath -Force
    Copy-Item -LiteralPath $Paths.resultPath -Destination $Paths.latestResultPath -Force
    Copy-Item -LiteralPath $Paths.reportPath -Destination $Paths.latestReportPath -Force
    Copy-Item -LiteralPath $Paths.handoffPath -Destination $Paths.latestHandoffPath -Force

    Write-TbgAtomicJson -Value ([pscustomobject][ordered]@{
            schema = 'TbgWindowLifecycleLatestPointer.v1'
            runId = [string]$RunContext.runId
            correlationId = [string]$RunContext.correlationId
            outputRoot = [string]$RunContext.outputRoot
            updatedUtc = [DateTime]::UtcNow.ToString('o')
        }) -Path $pointerPath

    return $artifactRegistry
}

function Initialize-TbgLifecycleRun {
    param(
        [string]$ResolvedRunId,
        [string]$ResolvedCorrelationId,
        [string]$ResolvedMode,
        [string]$ResolvedLaunchIntent,
        [string]$ResolvedLauncherContextPath,
        [Nullable[int]]$ResolvedTargetProcessId,
        [Nullable[Int64]]$ResolvedTargetHwnd,
        [string]$ResolvedFixturePath,
        [string]$ResolvedCreatedBy,
        [string]$ResolvedOutputRoot,
        [string]$ResolvedLatest
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedRunId)) { $ResolvedRunId = New-TbgLifecycleRunId }
    if ([string]::IsNullOrWhiteSpace($ResolvedCorrelationId)) {
        $ResolvedCorrelationId = 'wl-corr-{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 12))
    }

    $paths = Resolve-TbgLifecyclePaths -ResolvedRunId $ResolvedRunId -ResolvedOutputRoot $ResolvedOutputRoot -ResolvedLatest $ResolvedLatest
    Ensure-TbgDirectory -Path $paths.runRoot
    Ensure-TbgDirectory -Path $paths.latest

    $runContext = Read-TbgJsonFile -Path $paths.runContextPath
    if ($null -eq $runContext) {
        $runContext = New-TbgLifecycleRunContext `
            -ResolvedRunId $ResolvedRunId `
            -ResolvedCorrelationId $ResolvedCorrelationId `
            -Paths $paths `
            -ResolvedMode $ResolvedMode `
            -ResolvedLaunchIntent $ResolvedLaunchIntent `
            -ResolvedLauncherContextPath $ResolvedLauncherContextPath `
            -ResolvedTargetProcessId $ResolvedTargetProcessId `
            -ResolvedTargetHwnd $ResolvedTargetHwnd `
            -ResolvedFixturePath $ResolvedFixturePath `
            -ResolvedCreatedBy $ResolvedCreatedBy
        Write-TbgAtomicJson -Value $runContext -Path $paths.runContextPath
    }

    $materialized = Read-TbgJsonFile -Path $paths.statePath
    if ($null -eq $materialized) {
        $materialized = New-TbgLifecycleMaterializedState -ResolvedRunId ([string]$runContext.runId) -ResolvedCorrelationId ([string]$runContext.correlationId)
        Write-TbgAtomicJson -Value $materialized -Path $paths.statePath
    }

    $eventLines = @()
    if (Test-Path -LiteralPath $paths.eventsPath -PathType Leaf) {
        $eventLines = @(Get-Content -LiteralPath $paths.eventsPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
    }

    return [pscustomobject][ordered]@{
        runContext = $runContext
        materialized = $materialized
        paths = $paths
        eventLines = $eventLines
    }
}

function Invoke-TbgLifecycleReduceEvents {
    param(
        [Parameter(Mandatory = $true)]$Session,
        [Parameter(Mandatory = $true)][object[]]$Events,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $runContext = $Session.runContext
    $materialized = $Session.materialized
    $eventLines = New-Object System.Collections.Generic.List[object]
    foreach ($existing in @($Session.eventLines)) { $eventLines.Add($existing) | Out-Null }

    $accepted = 0
    $rejected = 0
    $transitions = New-Object System.Collections.Generic.List[object]
    $rejectedHistory = New-Object System.Collections.Generic.List[object]
    foreach ($existingRejected in @($materialized.rejectedTransitions)) { $rejectedHistory.Add($existingRejected) | Out-Null }

    foreach ($rawEvent in @($Events)) {
        $runtimeEvent = New-TbgLifecycleRuntimeEventObject -RunContext $runContext -EventInput $rawEvent -Source $Source
        $windowKey = [string]$runtimeEvent.windowKey
        $state = Get-TbgLifecycleWindowState -Materialized $materialized -WindowKey $windowKey
        $lastSequence = Get-TbgLifecycleSequenceCursor -Materialized $materialized -WindowKey $windowKey
        $expectedNext = $lastSequence + 1

        if ([int]$runtimeEvent.sequence -le $lastSequence) {
            $transition = New-TbgLifecycleRejectedTransition -WindowKey $windowKey -Sequence ([int]$runtimeEvent.sequence) -EventType ([string]$runtimeEvent.eventType) -Reason 'duplicate_sequence' -FromState ([string]$state.phase)
            $rejected++
            $transitions.Add($transition) | Out-Null
            $rejectedHistory.Add($transition) | Out-Null
            $materialized.rejectedTransitions = @($rejectedHistory.ToArray())
            $eventLines.Add($runtimeEvent) | Out-Null
            continue
        }

        if ([int]$runtimeEvent.sequence -ne $expectedNext) {
            $transition = New-TbgLifecycleRejectedTransition -WindowKey $windowKey -Sequence ([int]$runtimeEvent.sequence) -EventType ([string]$runtimeEvent.eventType) -Reason 'out_of_order_sequence' -FromState ([string]$state.phase)
            $rejected++
            $transitions.Add($transition) | Out-Null
            $rejectedHistory.Add($transition) | Out-Null
            $materialized.rejectedTransitions = @($rejectedHistory.ToArray())
            $eventLines.Add($runtimeEvent) | Out-Null
            continue
        }

        $reducerEvent = [pscustomobject][ordered]@{
            windowKey = $windowKey
            sequence = [int]$runtimeEvent.sequence
            eventType = [string]$runtimeEvent.eventType
            identityId = $runtimeEvent.identityId
            actionId = $runtimeEvent.actionId
            reason = $runtimeEvent.reason
        }
        $reduction = Resolve-TbgWindowLifecycleTransition -PreviousState $state -Event $reducerEvent
        $transitions.Add($reduction.transition) | Out-Null
        if ([bool]$reduction.transition.accepted) {
            $accepted++
            $materialized = Set-TbgLifecycleWindowState -Materialized $materialized -State $reduction.state
            $materialized = Set-TbgLifecycleSequenceCursor -Materialized $materialized -WindowKey $windowKey -Sequence ([int]$runtimeEvent.sequence)
        }
        else {
            $rejected++
            # Preserve rejected transitions without mutating accepted state, but advance the sequence cursor
            # so duplicate retries of the same rejected sequence are classified as duplicate_sequence.
            $materialized = Set-TbgLifecycleSequenceCursor -Materialized $materialized -WindowKey $windowKey -Sequence ([int]$runtimeEvent.sequence)
            $rejectedHistory.Add($reduction.transition) | Out-Null
            $materialized.rejectedTransitions = @($rejectedHistory.ToArray())
        }
        $eventLines.Add($runtimeEvent) | Out-Null
    }

    $primary = $null
    if (@($materialized.windows).Count -gt 0) {
        $primary = @($materialized.windows | Sort-Object { [int]$_.generation } -Descending | Select-Object -First 1)[0]
    }

    $result = [pscustomobject][ordered]@{
        schema = 'TbgWindowLifecycleRuntimeResult.v1'
        runId = [string]$runContext.runId
        correlationId = [string]$runContext.correlationId
        mode = [string]$runContext.mode
        completedUtc = [DateTime]::UtcNow.ToString('o')
        acceptedTransitions = $accepted
        rejectedTransitions = $rejected
        windowCount = @($materialized.windows).Count
        primaryWindowKey = if ($null -eq $primary) { $null } else { [string]$primary.windowKey }
        primaryPhase = if ($null -eq $primary) { $null } else { [string]$primary.phase }
        primaryProofLevel = if ($null -eq $primary) { $null } else { [string]$primary.proofLevel }
        proofCeiling = [string]$runContext.proofCeiling
        proofLevel = 'runtime_adapter_harness'
        transitions = @($transitions.ToArray())
        forbiddenClaims = @(
            'Action dispatch does not prove application acceptance.',
            'Window disappearance does not prove Bannerlord accepted an action.',
            'Terminal observation does not prove campaign readiness or live product success.'
        )
    }

    $artifactRegistry = Write-TbgLifecycleArtifacts -RunContext $runContext -Materialized $materialized -Result $result -Paths $Session.paths -EventLines @($eventLines.ToArray())
    return [pscustomobject][ordered]@{
        runContext = $runContext
        materialized = $materialized
        result = $result
        artifactRegistry = $artifactRegistry
        paths = $Session.paths
        transitions = @($transitions.ToArray())
    }
}

function Get-TbgLatestLifecyclePointer {
    $pointer = Read-TbgJsonFile -Path $pointerPath
    if ($null -ne $pointer) { return $pointer }
    $latestResult = Read-TbgJsonFile -Path (Join-Path $defaultLatest 'window-lifecycle.result.json')
    if ($null -ne $latestResult) {
        return [pscustomobject][ordered]@{
            schema = 'TbgWindowLifecycleLatestPointer.v1'
            runId = [string]$latestResult.runId
            correlationId = [string]$latestResult.correlationId
            outputRoot = $null
            updatedUtc = [string]$latestResult.completedUtc
        }
    }
    return $null
}

switch ($Command) {
    'status' {
        $pointer = Get-TbgLatestLifecyclePointer
        if ($null -eq $pointer) {
            Write-Host 'No window-lifecycle runtime artifacts exist yet.'
            Write-Host 'Proof level: none'
            Write-Host 'Proof ceiling: launcher_lifecycle_harness'
            if ($PassThru) { return $null }
            exit 2
        }

        $paths = Resolve-TbgLifecyclePaths -ResolvedRunId ([string]$pointer.runId) -ResolvedOutputRoot $OutputRoot -ResolvedLatest $LatestOutputDirectory
        $runContext = Read-TbgJsonFile -Path $paths.latestRunContextPath
        if ($null -eq $runContext -and -not [string]::IsNullOrWhiteSpace([string]$pointer.outputRoot)) {
            $paths = Resolve-TbgLifecyclePaths -ResolvedRunId ([string]$pointer.runId) -ResolvedOutputRoot ([string]$pointer.outputRoot) -ResolvedLatest $LatestOutputDirectory
            $runContext = Read-TbgJsonFile -Path $paths.runContextPath
        }
        $result = Read-TbgJsonFile -Path $paths.latestResultPath
        $state = Read-TbgJsonFile -Path $paths.latestStatePath

        Write-Host ('Window lifecycle run: {0}' -f [string]$pointer.runId)
        Write-Host ('Correlation: {0}' -f [string]$pointer.correlationId)
        if ($null -ne $runContext) {
            Write-Host ('Mode: {0}' -f [string]$runContext.mode)
            Write-Host ('Source commit: {0}' -f [string]$runContext.sourceCommit)
            Write-Host ('Proof ceiling: {0}' -f [string]$runContext.proofCeiling)
        }
        else {
            Write-Host 'Proof ceiling: launcher_lifecycle_harness'
        }
        if ($null -ne $result) {
            Write-Host ('Proof level: {0}' -f [string]$result.proofLevel)
            Write-Host ('Accepted={0} Rejected={1} Windows={2}' -f [int]$result.acceptedTransitions, [int]$result.rejectedTransitions, [int]$result.windowCount)
            Write-Host ('Primary phase: {0}' -f [string]$result.primaryPhase)
        }
        if ($null -ne $state) {
            Write-Host ('State path: {0}' -f $paths.latestStatePath)
        }
        Write-Host ('Report: {0}' -f $paths.latestReportPath)
        if ($PassThru) {
            return [pscustomobject][ordered]@{
                pointer = $pointer
                runContext = $runContext
                result = $result
                state = $state
                paths = $paths
            }
        }
        exit 0
    }

    'reduce' {
        $eventInputs = @()
        if (-not [string]::IsNullOrWhiteSpace($EventPath)) {
            $loaded = Read-TbgJsonFile -Path $EventPath
            if ($null -eq $loaded) { throw "EventPath is missing or invalid: $EventPath" }
            if ($loaded -is [System.Array]) { $eventInputs = @($loaded) }
            elseif ($loaded.PSObject.Properties['events']) { $eventInputs = @($loaded.events) }
            else { $eventInputs = @($loaded) }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($EventJson)) {
            $loaded = $EventJson | ConvertFrom-Json
            if ($loaded -is [System.Array]) { $eventInputs = @($loaded) }
            elseif ($loaded.PSObject.Properties['events']) { $eventInputs = @($loaded.events) }
            else { $eventInputs = @($loaded) }
        }
        else {
            throw 'reduce requires -EventJson or -EventPath.'
        }

        $session = Initialize-TbgLifecycleRun `
            -ResolvedRunId $RunId `
            -ResolvedCorrelationId $CorrelationId `
            -ResolvedMode $Mode `
            -ResolvedLaunchIntent $LaunchIntent `
            -ResolvedLauncherContextPath $LauncherContextPath `
            -ResolvedTargetProcessId $TargetProcessId `
            -ResolvedTargetHwnd $TargetHwnd `
            -ResolvedFixturePath $FixturePath `
            -ResolvedCreatedBy $CreatedBy `
            -ResolvedOutputRoot $OutputRoot `
            -ResolvedLatest $LatestOutputDirectory

        $reduceResult = Invoke-TbgLifecycleReduceEvents -Session $session -Events $eventInputs -Source 'window-intelligence'
        Write-Host ('Window lifecycle reduce completed for run {0}.' -f $reduceResult.runContext.runId)
        Write-Host ('Accepted={0} Rejected={1}' -f $reduceResult.result.acceptedTransitions, $reduceResult.result.rejectedTransitions)
        Write-Host ('Proof level: {0}' -f $reduceResult.result.proofLevel)
        Write-Host ('Proof ceiling: {0}' -f $reduceResult.result.proofCeiling)
        if ($PassThru) { return $reduceResult }
        exit 0
    }

    'replay' {
        $resolvedFixture = if ([string]::IsNullOrWhiteSpace($FixturePath)) {
            Join-Path $repoRoot '.tbg\harness\fixtures\window-intelligence\window-lifecycle-runtime.fixture.json'
        }
        else {
            if ([IO.Path]::IsPathRooted($FixturePath)) { $FixturePath } else { Join-Path $repoRoot $FixturePath }
        }
        $fixture = Read-TbgJsonFile -Path $resolvedFixture
        if ($null -eq $fixture) { throw "Runtime lifecycle fixture is missing or invalid: $resolvedFixture" }

        $cases = @($fixture.cases)
        if (-not [string]::IsNullOrWhiteSpace($CaseId)) {
            $cases = @($cases | Where-Object { [string]$_.caseId -eq $CaseId })
            if ($cases.Count -eq 0) { throw "Runtime lifecycle fixture case '$CaseId' was not found." }
        }

        $caseResults = New-Object System.Collections.Generic.List[object]
        foreach ($case in $cases) {
            $caseRunId = if ([string]::IsNullOrWhiteSpace($RunId)) {
                'wl-replay-{0}-{1}' -f ([string]$case.caseId), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
            }
            else {
                '{0}-{1}' -f $RunId, [string]$case.caseId
            }
            $caseCorrelation = if ([string]::IsNullOrWhiteSpace($CorrelationId)) {
                'wl-replay-corr-{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 10))
            }
            else {
                '{0}-{1}' -f $CorrelationId, [string]$case.caseId
            }

            $session = Initialize-TbgLifecycleRun `
                -ResolvedRunId $caseRunId `
                -ResolvedCorrelationId $caseCorrelation `
                -ResolvedMode 'fixture' `
                -ResolvedLaunchIntent 'fixture' `
                -ResolvedLauncherContextPath $LauncherContextPath `
                -ResolvedTargetProcessId $TargetProcessId `
                -ResolvedTargetHwnd $TargetHwnd `
                -ResolvedFixturePath $resolvedFixture `
                -ResolvedCreatedBy $CreatedBy `
                -ResolvedOutputRoot $OutputRoot `
                -ResolvedLatest $LatestOutputDirectory

            $events = @($case.events | ForEach-Object {
                    [pscustomobject][ordered]@{
                        windowKey = [string]$case.windowKey
                        sequence = [int]$_.sequence
                        eventType = [string]$_.eventType
                        identityId = if ($null -eq $_.PSObject.Properties['identityId']) { $null } else { $_.identityId }
                        actionId = if ($null -eq $_.PSObject.Properties['actionId']) { $null } else { $_.actionId }
                        reason = if ($null -eq $_.PSObject.Properties['reason']) { $null } else { $_.reason }
                        sentence = if ($null -eq $_.PSObject.Properties['sentence']) { $null } else { [string]$_.sentence }
                    }
                })

            $reduceResult = Invoke-TbgLifecycleReduceEvents -Session $session -Events $events -Source 'fixture-replay'
            $windowState = Get-TbgLifecycleWindowState -Materialized $reduceResult.materialized -WindowKey ([string]$case.windowKey)
            $caseResults.Add([pscustomobject][ordered]@{
                    caseId = [string]$case.caseId
                    runId = [string]$reduceResult.runContext.runId
                    windowKey = [string]$case.windowKey
                    finalState = $windowState
                    acceptedTransitions = [int]$reduceResult.result.acceptedTransitions
                    rejectedTransitions = [int]$reduceResult.result.rejectedTransitions
                    transitions = @($reduceResult.transitions)
                    paths = $reduceResult.paths
                }) | Out-Null
        }

        Write-Host ('Window lifecycle fixture replay completed for {0} case(s).' -f $caseResults.Count)
        Write-Host 'Proof level: runtime_adapter_harness'
        Write-Host 'Proof ceiling: launcher_lifecycle_harness'
        if ($PassThru) {
            return [pscustomobject][ordered]@{
                schema = 'TbgWindowLifecycleRuntimeReplay.v1'
                fixturePath = Get-TbgRepoRelativePath -Path $resolvedFixture
                cases = @($caseResults.ToArray())
            }
        }
        exit 0
    }
}
