[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'on', 'off', 'toggle', 'run', 'watch', 'trigger')]
    [string]$Command = 'status',

    [Parameter(Position = 1)]
    [string]$Source = 'operator',

    [ValidateSet('observe', 'auto', 'strict')]
    [string]$Mode = 'auto',

    [string]$RegistryPath = '.tbg/harness/artifact-engines.registry.json',
    [string]$OutputDirectory = 'artifacts/latest/artifact-engine',
    [string[]]$AdditionalArtifactRoot = @(),

    [ValidateRange(1, 3600)]
    [int]$PollSeconds = 1,

    [switch]$NoStart,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TbgPropertyValue {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function ConvertTo-TbgHashtable {
    param([AllowNull()][object]$Object)

    $table = @{}
    if ($null -eq $Object) { return $table }
    foreach ($property in $Object.PSObject.Properties) {
        $table[$property.Name] = $property.Value
    }
    return $table
}

function Resolve-TbgPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-TbgRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if ($pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $pathFull.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'
    }
    return $pathFull
}

function Write-TbgJsonAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value,
        [int]$Depth = 20
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temporaryPath = "$Path.tmp.$PID"
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Write-TbgTextAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temporaryPath = "$Path.tmp.$PID"
    $Text | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Get-TbgSha256Text {
    param([Parameter(Mandatory = $true)][string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-TbgState {
    param(
        [Parameter(Mandatory = $true)][string]$StatePath,
        [Parameter(Mandatory = $true)][string]$DefaultMode
    )

    if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
        try {
            return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        }
        catch {
            throw "The artifact engine state file is invalid: $StatePath. $($_.Exception.Message)"
        }
    }

    return [pscustomobject][ordered]@{
        schema = 'TbgArtifactEngineState.v1'
        enabled = $false
        mode = $DefaultMode
        generation = 0
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        updatedBy = 'default'
        additionalArtifactRoots = @()
    }
}

function Set-TbgState {
    param(
        [Parameter(Mandatory = $true)][string]$StatePath,
        [Parameter(Mandatory = $true)][bool]$Enabled,
        [Parameter(Mandatory = $true)][string]$StateMode,
        [Parameter(Mandatory = $true)][string]$UpdatedBy,
        [string[]]$Roots = @()
    )

    $current = Get-TbgState -StatePath $StatePath -DefaultMode $StateMode
    $generation = [int](Get-TbgPropertyValue -Object $current -Name 'generation' -Default 0) + 1
    $state = [pscustomobject][ordered]@{
        schema = 'TbgArtifactEngineState.v1'
        enabled = $Enabled
        mode = $StateMode
        generation = $generation
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        updatedBy = $UpdatedBy
        additionalArtifactRoots = @($Roots)
    }
    Write-TbgJsonAtomic -Path $StatePath -Value $state
    return $state
}

function Get-TbgWatcherState {
    param([Parameter(Mandatory = $true)][string]$WatcherPath)

    if (-not (Test-Path -LiteralPath $WatcherPath -PathType Leaf)) { return $null }
    try {
        return Get-Content -LiteralPath $WatcherPath -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Test-TbgWatcherRunning {
    param([AllowNull()][object]$Watcher)

    if ($null -eq $Watcher) { return $false }
    $watcherPid = [int](Get-TbgPropertyValue -Object $Watcher -Name 'pid' -Default 0)
    if ($watcherPid -le 0) { return $false }
    $process = Get-Process -Id $watcherPid -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }

    $recordedStart = [string](Get-TbgPropertyValue -Object $Watcher -Name 'startedUtc' -Default '')
    if ([string]::IsNullOrWhiteSpace($recordedStart)) { return $true }
    try {
        $difference = [math]::Abs(($process.StartTime.ToUniversalTime() - [datetime]::Parse($recordedStart).ToUniversalTime()).TotalSeconds)
        return ($difference -lt 3)
    }
    catch {
        return $true
    }
}

function Stop-TbgWatcher {
    param([Parameter(Mandatory = $true)][string]$WatcherPath)

    $watcher = Get-TbgWatcherState -WatcherPath $WatcherPath
    if (Test-TbgWatcherRunning -Watcher $watcher) {
        $watcherPid = [int]$watcher.pid
        Stop-Process -Id $watcherPid -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $WatcherPath -Force -ErrorAction SilentlyContinue
}

function Start-TbgWatcher {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$Registry,
        [Parameter(Mandatory = $true)][string]$Output,
        [Parameter(Mandatory = $true)][string]$WatcherPath,
        [Parameter(Mandatory = $true)][int]$Interval,
        [string[]]$Roots = @()
    )

    $existing = Get-TbgWatcherState -WatcherPath $WatcherPath
    if (Test-TbgWatcherRunning -Watcher $existing) {
        return $existing
    }

    $hostProcess = Get-Process -Id $PID
    $hostPath = $hostProcess.Path
    if ([string]::IsNullOrWhiteSpace($hostPath)) {
        $hostPath = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }
    }

    $arguments = New-Object System.Collections.Generic.List[string]
    $arguments.Add('-NoProfile') | Out-Null
    if ($IsWindows -or $PSVersionTable.PSEdition -ne 'Core') {
        $arguments.Add('-ExecutionPolicy') | Out-Null
        $arguments.Add('Bypass') | Out-Null
    }
    $arguments.Add('-File') | Out-Null
    $arguments.Add(('"{0}"' -f $ScriptPath)) | Out-Null
    $arguments.Add('watch') | Out-Null
    $arguments.Add('-RegistryPath') | Out-Null
    $arguments.Add(('"{0}"' -f $Registry)) | Out-Null
    $arguments.Add('-OutputDirectory') | Out-Null
    $arguments.Add(('"{0}"' -f $Output)) | Out-Null
    $arguments.Add('-PollSeconds') | Out-Null
    $arguments.Add([string]$Interval) | Out-Null
    foreach ($root in @($Roots)) {
        $arguments.Add('-AdditionalArtifactRoot') | Out-Null
        $arguments.Add(('"{0}"' -f $root)) | Out-Null
    }

    $startParameters = @{
        FilePath = $hostPath
        ArgumentList = @($arguments.ToArray())
        PassThru = $true
    }
    if ($env:OS -eq 'Windows_NT') {
        $startParameters['WindowStyle'] = 'Hidden'
    }

    $process = Start-Process @startParameters
    Start-Sleep -Milliseconds 150
    $watcher = [pscustomobject][ordered]@{
        schema = 'TbgArtifactEngineWatcher.v1'
        pid = $process.Id
        startedUtc = $process.StartTime.ToUniversalTime().ToString('o')
        scriptPath = $ScriptPath
        pollSeconds = $Interval
    }
    Write-TbgJsonAtomic -Path $WatcherPath -Value $watcher
    return $watcher
}

function Get-TbgEngineFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine,
        [Parameter(Mandatory = $true)][object]$Registry,
        [string[]]$ExtraRoots = @()
    )

    $files = New-Object System.Collections.Generic.List[object]
    $excludePrefixes = @($Registry.defaults.excludePrefixes)
    $extensions = @($Engine.extensions | ForEach-Object { ([string]$_).ToLowerInvariant() })

    foreach ($sourceRoot in @($Engine.sourceRoots) + @($ExtraRoots)) {
        if ([string]::IsNullOrWhiteSpace([string]$sourceRoot)) { continue }
        $resolvedRoot = Resolve-TbgPath -RepoRoot $RepoRoot -Path ([string]$sourceRoot)
        if (-not (Test-Path -LiteralPath $resolvedRoot)) { continue }

        if (Test-Path -LiteralPath $resolvedRoot -PathType Leaf) {
            $candidates = @(Get-Item -LiteralPath $resolvedRoot)
        }
        else {
            $candidates = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue)
        }

        foreach ($candidate in $candidates) {
            if ($extensions.Count -gt 0 -and $extensions -notcontains $candidate.Extension.ToLowerInvariant()) { continue }
            $relative = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $candidate.FullName
            $excluded = $false
            foreach ($prefix in $excludePrefixes) {
                $normalizedPrefix = ([string]$prefix).TrimEnd('/', '\')
                if ($relative.StartsWith($normalizedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) { $files.Add($candidate) | Out-Null }
        }
    }

    foreach ($pattern in @($Engine.rootFilePatterns)) {
        foreach ($candidate in @(Get-ChildItem -LiteralPath $RepoRoot -File -Filter ([string]$pattern) -ErrorAction SilentlyContinue)) {
            $files.Add($candidate) | Out-Null
        }
    }

    return @($files.ToArray() | Sort-Object FullName -Unique)
}

function Get-TbgCandidateFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = New-Object System.Collections.Generic.List[object]
    foreach ($candidatePath in @($Engine.candidatePaths)) {
        $resolved = Resolve-TbgPath -RepoRoot $RepoRoot -Path ([string]$candidatePath)
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $files.Add((Get-Item -LiteralPath $resolved)) | Out-Null
        }
    }
    return @($files.ToArray())
}

function Get-TbgFileSetFingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object[]]$Files
    )

    $parts = @($Files | Sort-Object FullName | ForEach-Object {
        $relative = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $_.FullName
        "$relative|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
    })
    return Get-TbgSha256Text -Text ($parts -join "`n")
}

function ConvertFrom-TbgArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][long]$MaxBytes
    )

    $record = [ordered]@{
        schema = 'TbgArtifactObservation.v1'
        path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $File.FullName
        fullPath = $File.FullName
        extension = $File.Extension.ToLowerInvariant()
        bytes = $File.Length
        lastWriteUtc = $File.LastWriteTimeUtc.ToString('o')
        parseStatus = 'metadata_only'
        artifactSchema = ''
        status = ''
        verdict = ''
        terminalState = ''
        proofLevel = ''
        nextCommand = ''
        summary = ''
        lineCount = 0
        parseError = ''
    }

    if ($File.Length -gt $MaxBytes) {
        $record.summary = "The artifact exceeds the configured parse limit of $MaxBytes bytes."
        return [pscustomobject]$record
    }

    try {
        $content = Get-Content -LiteralPath $File.FullName -Raw -ErrorAction Stop
        $record.lineCount = if ([string]::IsNullOrEmpty($content)) { 0 } else { @($content -split "`r?`n").Count }
        switch ($record.extension) {
            '.json' {
                $value = $content | ConvertFrom-Json -ErrorAction Stop
                $record.parseStatus = 'parsed'
                $record.artifactSchema = [string](Get-TbgPropertyValue -Object $value -Name 'schema' -Default '')
                $record.status = [string](Get-TbgPropertyValue -Object $value -Name 'status' -Default '')
                $record.verdict = [string](Get-TbgPropertyValue -Object $value -Name 'verdict' -Default (Get-TbgPropertyValue -Object $value -Name 'passFail' -Default ''))
                $record.terminalState = [string](Get-TbgPropertyValue -Object $value -Name 'terminalState' -Default '')
                $record.proofLevel = [string](Get-TbgPropertyValue -Object $value -Name 'proofLevel' -Default '')
                $record.nextCommand = [string](Get-TbgPropertyValue -Object $value -Name 'nextCommand' -Default '')
                $record.summary = "The JSON artifact parsed successfully."
            }
            '.jsonl' {
                $lineErrors = 0
                $nonEmptyLines = @($content -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                foreach ($line in $nonEmptyLines) {
                    try { $line | ConvertFrom-Json -ErrorAction Stop | Out-Null }
                    catch { $lineErrors++ }
                }
                if ($lineErrors -gt 0) { throw "$lineErrors JSONL lines did not parse." }
                $record.parseStatus = 'parsed'
                $record.summary = "The JSONL artifact contains $($nonEmptyLines.Count) valid event lines."
            }
            default {
                $lines = @($content -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                $first = if ($lines.Count -gt 0) { $lines[0].Trim() } else { 'The artifact is empty.' }
                if ($first.Length -gt 240) { $first = $first.Substring(0, 240) }
                $record.parseStatus = 'parsed'
                $record.summary = $first
            }
        }
    }
    catch {
        $record.parseStatus = 'error'
        $record.parseError = $_.Exception.Message
        $record.summary = 'The artifact could not be parsed.'
    }

    return [pscustomobject]$record
}

function New-TbgEnginePacket {
    param(
        [Parameter(Mandatory = $true)][string]$EngineId,
        [Parameter(Mandatory = $true)][string]$Schema,
        [Parameter(Mandatory = $true)][string]$TerminalState,
        [Parameter(Mandatory = $true)][string]$NextCommand,
        [Parameter(Mandatory = $true)][object]$Payload,
        [Parameter(Mandatory = $true)][string[]]$Sentences,
        [bool]$Blocking = $false
    )

    return [pscustomobject][ordered]@{
        engineId = $EngineId
        result = [pscustomobject][ordered]@{
            schema = $Schema
            generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
            engineId = $EngineId
            terminalState = $TerminalState
            blocking = $Blocking
            nextCommand = $NextCommand
            payload = $Payload
            sentences = @($Sentences)
        }
        reportLines = @($Sentences)
    }
}

function Invoke-TbgInventoryEngine {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine,
        [Parameter(Mandatory = $true)][object]$Registry,
        [string[]]$ExtraRoots = @()
    )

    $files = @(Get-TbgEngineFiles -RepoRoot $RepoRoot -Engine $Engine -Registry $Registry -ExtraRoots $ExtraRoots)
    $maxBytes = [long]$Registry.defaults.maxParseBytes
    $observations = @($files | ForEach-Object { ConvertFrom-TbgArtifact -RepoRoot $RepoRoot -File $_ -MaxBytes $maxBytes })
    $errors = @($observations | Where-Object { $_.parseStatus -eq 'error' })
    $parsed = @($observations | Where-Object { $_.parseStatus -eq 'parsed' })
    $metadataOnly = @($observations | Where-Object { $_.parseStatus -eq 'metadata_only' })
    $terminal = if ($errors.Count -gt 0) { 'ATTENTION_artifact_parse_errors' } else { 'READY_artifact_index_updated' }
    $next = if ($errors.Count -gt 0) { "Get-Content -LiteralPath '$($errors[0].path)' -Raw" } else { '.\ForgeArtifactEngine.cmd status' }
    $sentences = @(
        "The artifact-index engine inspected $($observations.Count) configured local artifacts.",
        "The artifact-index engine parsed $($parsed.Count) artifacts, retained metadata only for $($metadataOnly.Count) oversized artifacts, and recorded $($errors.Count) parse errors.",
        "The artifact-index engine excluded its own output directory so generated reports cannot create an infinite trigger loop.",
        "The operator should run '$next' as the next command."
    )
    $payload = [pscustomobject][ordered]@{
        count = $observations.Count
        parsedCount = $parsed.Count
        metadataOnlyCount = $metadataOnly.Count
        parseErrorCount = $errors.Count
        artifacts = @($observations)
    }
    return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgArtifactIndex.v1' -TerminalState $terminal -NextCommand $next -Payload $payload -Sentences $sentences -Blocking:$false
}

function Invoke-TbgRepoFloorEngine {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidateFiles -RepoRoot $RepoRoot -Engine $Engine)
    $jsonFile = @($files | Where-Object { $_.Extension -eq '.json' } | Select-Object -First 1)
    if ($jsonFile.Count -eq 0) {
        $sentences = @(
            "The repo-floor-context engine did not find a repository hygiene JSON artifact.",
            "The missing repository hygiene artifact does not prove that the repository floor is clean.",
            "The operator should run '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked' as the next command."
        )
        return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgRepoFloorContext.v1' -TerminalState 'UNAVAILABLE_repo_floor_artifact_missing' -NextCommand '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked' -Payload ([pscustomobject]@{ artifactFound = $false }) -Sentences $sentences -Blocking:$false
    }

    try {
        $source = Get-Content -LiteralPath $jsonFile[0].FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $sentences = @(
            "The repo-floor-context engine found the repository hygiene artifact but could not parse it.",
            "The operator should inspect '$($jsonFile[0].FullName)' before any floor-dependent action runs."
        )
        return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgRepoFloorContext.v1' -TerminalState 'BLOCKED_repo_floor_parse_error' -NextCommand "Get-Content -LiteralPath '$($jsonFile[0].FullName)' -Raw" -Payload ([pscustomobject]@{ artifactFound = $true; parseError = $_.Exception.Message }) -Sentences $sentences -Blocking:$true
    }

    $verdict = [string](Get-TbgPropertyValue -Object $source -Name 'verdict' -Default 'UNKNOWN')
    $dirty = @((Get-TbgPropertyValue -Object $source -Name 'dirtyPaths' -Default @()))
    $conflicts = @((Get-TbgPropertyValue -Object $source -Name 'conflictedFiles' -Default @()))
    $operations = @((Get-TbgPropertyValue -Object $source -Name 'operations' -Default @()))
    $worktrees = @((Get-TbgPropertyValue -Object $source -Name 'worktrees' -Default @()))
    $next = [string](Get-TbgPropertyValue -Object $source -Name 'nextCommand' -Default 'git status --short')
    $terminal = switch ($verdict) {
        'CLEAN' { 'READY_repo_floor_clean' }
        'BLOCKED' { 'BLOCKED_repo_floor' }
        default { 'ATTENTION_repo_floor_needs_review' }
    }
    $blocking = ($verdict -eq 'BLOCKED')
    $sentences = @(
        "The repo-floor-context engine parsed repository hygiene evidence for branch '$([string](Get-TbgPropertyValue -Object $source -Name 'branch' -Default 'unknown'))' at HEAD '$([string](Get-TbgPropertyValue -Object $source -Name 'head' -Default 'unknown'))'.",
        "The repository hygiene artifact reports verdict '$verdict', $($dirty.Count) dirty paths, $($conflicts.Count) conflicted files, $($operations.Count) active Git operations, and $($worktrees.Count) registered worktrees.",
        "The repo-floor-context engine classified the floor as '$terminal'.",
        "The operator should run '$next' as the next command."
    )
    $payload = [pscustomobject][ordered]@{
        artifactFound = $true
        sourcePath = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $jsonFile[0].FullName
        branch = [string](Get-TbgPropertyValue -Object $source -Name 'branch' -Default '')
        head = [string](Get-TbgPropertyValue -Object $source -Name 'head' -Default '')
        upstream = [string](Get-TbgPropertyValue -Object $source -Name 'upstream' -Default '')
        verdict = $verdict
        dirtyCount = $dirty.Count
        conflictCount = $conflicts.Count
        operationCount = $operations.Count
        worktreeCount = $worktrees.Count
    }
    return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgRepoFloorContext.v1' -TerminalState $terminal -NextCommand $next -Payload $payload -Sentences $sentences -Blocking:$blocking
}

function Invoke-TbgStalePrEngine {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidateFiles -RepoRoot $RepoRoot -Engine $Engine)
    $jsonFile = @($files | Where-Object { $_.Extension -eq '.json' } | Select-Object -First 1)
    if ($jsonFile.Count -eq 0) {
        $sentences = @(
            "The stale-pr-next-action engine did not find a stale PR recovery result artifact.",
            "The operator should run '.\ForgeStalePrRecovery.cmd -Wave 0' before requesting a recovery action."
        )
        return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgStalePrNextAction.v1' -TerminalState 'UNAVAILABLE_stale_pr_recovery_artifact_missing' -NextCommand '.\ForgeStalePrRecovery.cmd -Wave 0' -Payload ([pscustomobject]@{ artifactFound = $false }) -Sentences $sentences -Blocking:$false
    }

    try {
        $source = Get-Content -LiteralPath $jsonFile[0].FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $sentences = @(
            "The stale-pr-next-action engine found the recovery artifact but could not parse it.",
            "The operator should inspect '$($jsonFile[0].FullName)' before any recovery action runs."
        )
        return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgStalePrNextAction.v1' -TerminalState 'BLOCKED_stale_pr_parse_error' -NextCommand "Get-Content -LiteralPath '$($jsonFile[0].FullName)' -Raw" -Payload ([pscustomobject]@{ artifactFound = $true; parseError = $_.Exception.Message }) -Sentences $sentences -Blocking:$true
    }

    $repoFloorPath = Join-Path $OutputRoot 'repo-floor-context.result.json'
    $repoFloorReady = $false
    $repoFloorTerminal = 'UNAVAILABLE_repo_floor_context'
    if (Test-Path -LiteralPath $repoFloorPath -PathType Leaf) {
        try {
            $repoFloor = Get-Content -LiteralPath $repoFloorPath -Raw | ConvertFrom-Json
            $repoFloorTerminal = [string]$repoFloor.terminalState
            $repoFloorReady = ($repoFloorTerminal -eq 'READY_repo_floor_clean')
        }
        catch {
            $repoFloorReady = $false
        }
    }

    $sourceTerminal = [string](Get-TbgPropertyValue -Object $source -Name 'terminalState' -Default 'UNKNOWN_stale_pr_state')
    $sourceNext = [string](Get-TbgPropertyValue -Object $source -Name 'nextCommand' -Default '.\ForgeStalePrRecovery.cmd -Wave 0')
    $sourceVerdict = [string](Get-TbgPropertyValue -Object $source -Name 'verdict' -Default (Get-TbgPropertyValue -Object $source -Name 'status' -Default 'UNKNOWN'))
    $terminal = $sourceTerminal
    $next = $sourceNext
    $blocking = ($sourceVerdict -eq 'BLOCKED' -or $sourceTerminal.StartsWith('BLOCKED_'))

    if ($sourceTerminal -eq 'READY_bounded_recovery_instruction' -and -not $repoFloorReady) {
        $terminal = 'BLOCKED_local_floor_context_not_clean'
        $next = '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked'
        $blocking = $true
    }

    $sentences = @(
        "The stale-pr-next-action engine parsed recovery state '$sourceTerminal' with verdict '$sourceVerdict'.",
        "The repo-floor dependency currently reports '$repoFloorTerminal'.",
        "The stale-pr-next-action engine classified the executable next decision as '$terminal'.",
        "The operator should run '$next' as the next command."
    )
    $payload = [pscustomobject][ordered]@{
        artifactFound = $true
        sourcePath = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $jsonFile[0].FullName
        sourceTerminalState = $sourceTerminal
        sourceVerdict = $sourceVerdict
        repoFloorTerminalState = $repoFloorTerminal
        repoFloorReady = $repoFloorReady
    }
    return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgStalePrNextAction.v1' -TerminalState $terminal -NextCommand $next -Payload $payload -Sentences $sentences -Blocking:$blocking
}

function Invoke-TbgProofBoundaryEngine {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidateFiles -RepoRoot $RepoRoot -Engine $Engine)
    $claims = New-Object System.Collections.Generic.List[object]
    foreach ($file in $files) {
        try {
            $value = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            $schema = [string](Get-TbgPropertyValue -Object $value -Name 'schema' -Default '')
            $status = [string](Get-TbgPropertyValue -Object $value -Name 'status' -Default '')
            $verdict = [string](Get-TbgPropertyValue -Object $value -Name 'verdict' -Default (Get-TbgPropertyValue -Object $value -Name 'passFail' -Default ''))
            $sourceProof = [string](Get-TbgPropertyValue -Object $value -Name 'proofLevel' -Default '')
            $candidate = 'artifact_inspection'
            if ($file.Name -eq 'BlacksmithGuild_CommandAck.json' -and ($status -match 'success|pass|ack' -or $verdict -match 'success|pass|ack')) {
                $candidate = 'command_ack_candidate'
            }
            elseif ($file.FullName -match 'launcher' -and ($status -match 'success|pass|ready' -or $verdict -match 'success|pass|ready')) {
                $candidate = 'launcher_harness_candidate'
            }
            elseif (-not [string]::IsNullOrWhiteSpace($sourceProof)) {
                $candidate = "source_claimed_$sourceProof"
            }
            $claims.Add([pscustomobject][ordered]@{
                path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $file.FullName
                schema = $schema
                status = $status
                verdict = $verdict
                sourceProofLevel = $sourceProof
                candidateClassification = $candidate
                freshnessVerified = $false
                independentlyValidated = $false
            }) | Out-Null
        }
        catch {
            $claims.Add([pscustomobject][ordered]@{
                path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $file.FullName
                schema = ''
                status = ''
                verdict = ''
                sourceProofLevel = ''
                candidateClassification = 'parse_error'
                freshnessVerified = $false
                independentlyValidated = $false
            }) | Out-Null
        }
    }

    $next = if ($files.Count -gt 0) { '.\ForgeArtifactEngine.cmd run -Mode strict' } else { '.\ForgeArtifactEngine.cmd status' }
    $sentences = @(
        "The runtime-proof-boundary engine inspected $($files.Count) known runtime or launcher artifacts.",
        "The parser classified every source claim conservatively because parsing alone does not verify freshness, causality, or observed behavior.",
        "The highest proof level created by this engine is artifact inspection, even when a source artifact reports a higher candidate level.",
        "The operator should run '$next' as the next command."
    )
    $payload = [pscustomobject][ordered]@{
        artifactCount = $files.Count
        parserProofLevel = 'artifact_inspection'
        claims = @($claims.ToArray())
    }
    return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgRuntimeProofBoundary.v1' -TerminalState 'READY_proof_boundary_classified' -NextCommand $next -Payload $payload -Sentences $sentences -Blocking:$false
}

function Invoke-TbgHandoffEngine {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $summaries = New-Object System.Collections.Generic.List[object]
    $nextCommands = New-Object System.Collections.Generic.List[string]
    $blocking = $false
    foreach ($engineId in @($Engine.consumesEngineResults)) {
        $path = Join-Path $OutputRoot "$engineId.result.json"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        try {
            $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $summaries.Add([pscustomobject][ordered]@{
                engineId = $engineId
                terminalState = [string]$value.terminalState
                blocking = [bool]$value.blocking
                nextCommand = [string]$value.nextCommand
                resultPath = $path
            }) | Out-Null
            if ([bool]$value.blocking) { $blocking = $true }
            if (-not [string]::IsNullOrWhiteSpace([string]$value.nextCommand)) {
                $nextCommands.Add([string]$value.nextCommand) | Out-Null
            }
        }
        catch {
            $blocking = $true
            $summaries.Add([pscustomobject][ordered]@{
                engineId = $engineId
                terminalState = 'BLOCKED_engine_result_parse_error'
                blocking = $true
                nextCommand = "Get-Content -LiteralPath '$path' -Raw"
                resultPath = $path
            }) | Out-Null
        }
    }

    $next = if ($nextCommands.Count -gt 0) { $nextCommands[0] } else { '.\ForgeArtifactEngine.cmd status' }
    $terminal = if ($blocking) { 'BLOCKED_handoff_contains_blockers' } else { 'READY_handoff_compressed' }
    $sentences = @(
        "The handoff-compressor engine collected $($summaries.Count) upstream engine results.",
        "The compressed handoff reports terminal state '$terminal'.",
        "The handoff preserves each upstream terminal state and next command without converting parser output into runtime proof.",
        "The operator should run '$next' as the next command."
    )
    $payload = [pscustomobject][ordered]@{
        engines = @($summaries.ToArray())
        recommendedNextCommand = $next
    }
    return New-TbgEnginePacket -EngineId $Engine.id -Schema 'TbgArtifactEngineHandoff.v1' -TerminalState $terminal -NextCommand $next -Payload $payload -Sentences $sentences -Blocking:$blocking
}

function Write-TbgEnginePacket {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][object]$Engine,
        [Parameter(Mandatory = $true)][object]$Packet
    )

    $stem = [string]$Engine.outputStem
    $resultPath = Join-Path $OutputRoot "$($Engine.id).result.json"
    $namedResultPath = Join-Path $OutputRoot "$stem.result.json"
    $reportPath = Join-Path $OutputRoot "$stem.report.md"
    Write-TbgJsonAtomic -Path $resultPath -Value $Packet.result
    if ($namedResultPath -ne $resultPath) {
        Write-TbgJsonAtomic -Path $namedResultPath -Value $Packet.result
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $($Engine.id) Engine Report") | Out-Null
    $lines.Add('') | Out-Null
    foreach ($sentence in @($Packet.reportLines)) {
        $lines.Add([string]$sentence) | Out-Null
    }
    Write-TbgTextAtomic -Path $reportPath -Text (($lines -join "`n") + "`n")
}

function Invoke-TbgArtifactPass {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Registry,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$StateMode,
        [Parameter(Mandatory = $true)][string]$TriggerSource,
        [Parameter(Mandatory = $true)][string]$FingerprintPath,
        [Parameter(Mandatory = $true)][string]$LockPath,
        [string[]]$ExtraRoots = @(),
        [switch]$ForcePass,
        [switch]$WatchPass
    )

    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LockPath) | Out-Null
    $lock = $null
    try {
        try {
            $lock = New-Object System.IO.FileStream($LockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        }
        catch {
            Write-Host 'The artifact engine skipped this pass because another engine pass owns the local lock.'
            return $null
        }

        $fingerprints = @{}
        if (Test-Path -LiteralPath $FingerprintPath -PathType Leaf) {
            try { $fingerprints = ConvertTo-TbgHashtable (Get-Content -LiteralPath $FingerprintPath -Raw | ConvertFrom-Json) }
            catch { $fingerprints = @{} }
        }

        $engineMap = @{}
        foreach ($engine in @($Registry.engines)) {
            if ($engineMap.ContainsKey([string]$engine.id)) { throw "The registry contains duplicate engine '$($engine.id)'." }
            $engineMap[[string]$engine.id] = $engine
        }

        foreach ($engine in @($Registry.engines)) {
            foreach ($downstream in @($engine.downstream)) {
                if (-not $engineMap.ContainsKey([string]$downstream)) {
                    throw "Engine '$($engine.id)' names unregistered downstream engine '$downstream'."
                }
            }
        }

        $queue = New-Object System.Collections.Generic.Queue[string]
        $queue.Enqueue('artifact-index')
        $queued = @{ 'artifact-index' = $true }
        $completed = @{}
        $runs = New-Object System.Collections.Generic.List[object]
        $events = New-Object System.Collections.Generic.List[object]
        $progress = New-Object System.Collections.Generic.List[string]
        $maxCascade = [int]$Registry.defaults.maxCascadeEngines
        $sequence = 0

        while ($queue.Count -gt 0) {
            if ($runs.Count -ge $maxCascade) {
                throw "The artifact engine exceeded the configured cascade limit of $maxCascade engines."
            }

            $engineId = $queue.Dequeue()
            $queued.Remove($engineId)
            if ($completed.ContainsKey($engineId)) {
                throw "The artifact engine detected a registry cycle at '$engineId'."
            }
            if (-not $engineMap.ContainsKey($engineId)) {
                throw "The artifact engine '$engineId' is not registered."
            }

            $engine = $engineMap[$engineId]
            $implementation = [string]$engine.implementation
            $inputFiles = @()
            if ($implementation -eq 'inventory') {
                $inputFiles = @(Get-TbgEngineFiles -RepoRoot $RepoRoot -Engine $engine -Registry $Registry -ExtraRoots $ExtraRoots)
            }
            elseif ($implementation -ne 'handoff') {
                $inputFiles = @(Get-TbgCandidateFiles -RepoRoot $RepoRoot -Engine $engine)
            }

            $fingerprint = if ($implementation -eq 'handoff') {
                $upstreamParts = @($engine.consumesEngineResults | ForEach-Object {
                    $path = Join-Path $OutputRoot "$_.result.json"
                    if (Test-Path -LiteralPath $path) {
                        $item = Get-Item -LiteralPath $path
                        "$($_)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
                    }
                })
                Get-TbgSha256Text -Text ($upstreamParts -join "`n")
            }
            else {
                Get-TbgFileSetFingerprint -RepoRoot $RepoRoot -Files $inputFiles
            }

            $previousFingerprint = if ($fingerprints.ContainsKey($engineId)) { [string]$fingerprints[$engineId] } else { '' }
            $changed = ($fingerprint -ne $previousFingerprint)
            $shouldRun = $ForcePass -or -not $WatchPass -or $changed
            if (-not $shouldRun) {
                $completed[$engineId] = $true
                continue
            }

            $packet = switch ($implementation) {
                'inventory' { Invoke-TbgInventoryEngine -RepoRoot $RepoRoot -Engine $engine -Registry $Registry -ExtraRoots $ExtraRoots }
                'repo_floor' { Invoke-TbgRepoFloorEngine -RepoRoot $RepoRoot -Engine $engine }
                'stale_pr' { Invoke-TbgStalePrEngine -RepoRoot $RepoRoot -OutputRoot $OutputRoot -Engine $engine }
                'proof_boundary' { Invoke-TbgProofBoundaryEngine -RepoRoot $RepoRoot -Engine $engine }
                'handoff' { Invoke-TbgHandoffEngine -OutputRoot $OutputRoot -Engine $engine }
                default { throw "The artifact engine implementation '$implementation' is not supported." }
            }

            Write-TbgEnginePacket -OutputRoot $OutputRoot -Engine $engine -Packet $packet
            $fingerprints[$engineId] = $fingerprint
            $completed[$engineId] = $true
            $sequence++
            $eventSentence = "The local artifact router ran engine '$engineId' and produced terminal state '$($packet.result.terminalState)'."
            $events.Add([pscustomobject][ordered]@{
                schema = 'TbgArtifactEngineEvent.v1'
                sequence = $sequence
                generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
                source = $TriggerSource
                mode = $StateMode
                engineId = $engineId
                terminalState = [string]$packet.result.terminalState
                blocking = [bool]$packet.result.blocking
                nextCommand = [string]$packet.result.nextCommand
                sentence = $eventSentence
            }) | Out-Null
            $progress.Add($eventSentence) | Out-Null
            $runs.Add([pscustomobject][ordered]@{
                engineId = $engineId
                implementation = $implementation
                inputCount = $inputFiles.Count
                changed = $changed
                terminalState = [string]$packet.result.terminalState
                blocking = [bool]$packet.result.blocking
                nextCommand = [string]$packet.result.nextCommand
            }) | Out-Null

            if ($StateMode -ne 'observe') {
                foreach ($downstream in @($engine.downstream)) {
                    $downstreamId = [string]$downstream
                    if (-not $completed.ContainsKey($downstreamId) -and -not $queued.ContainsKey($downstreamId)) {
                        $queue.Enqueue($downstreamId)
                        $queued[$downstreamId] = $true
                    }
                }
            }
        }

        Write-TbgJsonAtomic -Path $FingerprintPath -Value ([pscustomobject]$fingerprints)
        $blockingRuns = @($runs.ToArray() | Where-Object { $_.blocking })
        $parseErrorRuns = @($runs.ToArray() | Where-Object { $_.terminalState -match 'parse_error|parse_errors' })
        $strictFailure = ($StateMode -eq 'strict' -and ($blockingRuns.Count -gt 0 -or $parseErrorRuns.Count -gt 0))
        $terminal = if ($strictFailure) {
            'BLOCKED_artifact_engine_strict'
        }
        elseif ($StateMode -eq 'observe') {
            'READY_observe_complete'
        }
        else {
            'READY_auto_cascade_complete'
        }
        $next = if ($blockingRuns.Count -gt 0) { [string]$blockingRuns[0].nextCommand } else { '.\ForgeArtifactEngine.cmd status' }
        $result = [pscustomobject][ordered]@{
            schema = 'TbgArtifactEngineRun.v1'
            generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
            source = $TriggerSource
            mode = $StateMode
            terminalState = $terminal
            blocking = $strictFailure
            engineRunCount = $runs.Count
            nextCommand = $next
            engineRuns = @($runs.ToArray())
            artifactPaths = [pscustomobject][ordered]@{
                result = 'artifacts/latest/artifact-engine/artifact-engine.result.json'
                report = 'artifacts/latest/artifact-engine/artifact-engine.report.md'
                events = 'artifacts/latest/artifact-engine/artifact-engine.events.jsonl'
                progress = 'artifacts/latest/artifact-engine/artifact-engine.progress.log'
                handoff = 'artifacts/latest/artifact-engine/artifact-engine.handoff.md'
            }
        }
        Write-TbgJsonAtomic -Path (Join-Path $OutputRoot 'artifact-engine.result.json') -Value $result

        $eventLines = @($events.ToArray() | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress })
        Write-TbgTextAtomic -Path (Join-Path $OutputRoot 'artifact-engine.events.jsonl') -Text (($eventLines -join "`n") + "`n")
        Write-TbgTextAtomic -Path (Join-Path $OutputRoot 'artifact-engine.progress.log') -Text ((@($progress.ToArray()) -join "`n") + "`n")

        $reportLines = New-Object System.Collections.Generic.List[string]
        $reportLines.Add('# TBG Local Artifact Engine Report') | Out-Null
        $reportLines.Add('') | Out-Null
        $reportLines.Add("The local artifact router ran in '$StateMode' mode because '$TriggerSource' triggered the pass.") | Out-Null
        $reportLines.Add("The router completed $($runs.Count) registered engines and produced terminal state '$terminal'.") | Out-Null
        $reportLines.Add("The router found $($blockingRuns.Count) blocking engine results and $($parseErrorRuns.Count) parse-error engine results.") | Out-Null
        $reportLines.Add("The operator should run '$next' as the next command.") | Out-Null
        $reportLines.Add('') | Out-Null
        $reportLines.Add('## Engine Results') | Out-Null
        $reportLines.Add('') | Out-Null
        foreach ($run in @($runs.ToArray())) {
            $reportLines.Add("- The '$($run.engineId)' engine produced '$($run.terminalState)' and recommends '$($run.nextCommand)'.") | Out-Null
        }
        $reportLines.Add('') | Out-Null
        $reportLines.Add('The parser does not claim build, launcher, movement, trade, behavior-observed, or live runtime proof merely because it parsed an artifact.') | Out-Null
        Write-TbgTextAtomic -Path (Join-Path $OutputRoot 'artifact-engine.report.md') -Text (($reportLines -join "`n") + "`n")

        $handoffLines = New-Object System.Collections.Generic.List[string]
        $handoffLines.Add('# TBG Artifact Engine Handoff') | Out-Null
        $handoffLines.Add('') | Out-Null
        $handoffLines.Add("Repository: $RepoRoot") | Out-Null
        $handoffLines.Add("Trigger source: $TriggerSource") | Out-Null
        $handoffLines.Add("Mode: $StateMode") | Out-Null
        $handoffLines.Add("Terminal state: $terminal") | Out-Null
        $handoffLines.Add("Next command: $next") | Out-Null
        $handoffLines.Add('') | Out-Null
        $handoffLines.Add('Engine packets:') | Out-Null
        foreach ($run in @($runs.ToArray())) {
            $handoffLines.Add("- $($run.engineId): $($run.terminalState); $(Join-Path $OutputRoot "$($run.engineId).result.json")") | Out-Null
        }
        $handoffLines.Add('') | Out-Null
        $handoffLines.Add('Proof boundary: artifact parsing and static harness proof only. Inspect source evidence and run the owning validator before making a higher claim.') | Out-Null
        Write-TbgTextAtomic -Path (Join-Path $OutputRoot 'artifact-engine.handoff.md') -Text (($handoffLines -join "`n") + "`n")

        Write-Host "Artifact engine terminal state: $terminal"
        Write-Host "Artifact engine report: $(Join-Path $OutputRoot 'artifact-engine.report.md')"
        Write-Host "Next command: $next"
        if ($strictFailure) { return [pscustomobject]@{ exitCode = 2; result = $result } }
        return [pscustomobject]@{ exitCode = 0; result = $result }
    }
    finally {
        if ($null -ne $lock) { $lock.Dispose() }
    }
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$resolvedRegistryPath = Resolve-TbgPath -RepoRoot $repoRoot -Path $RegistryPath
if (-not (Test-Path -LiteralPath $resolvedRegistryPath -PathType Leaf)) {
    throw "The artifact engine registry is missing: $resolvedRegistryPath"
}
$registry = Get-Content -LiteralPath $resolvedRegistryPath -Raw | ConvertFrom-Json
if ([string]$registry.schema -ne 'TbgArtifactEngineRegistry.v1') {
    throw "The artifact engine registry schema is unsupported: $($registry.schema)"
}

$outputRoot = Resolve-TbgPath -RepoRoot $repoRoot -Path $OutputDirectory
$stateRoot = Resolve-TbgPath -RepoRoot $repoRoot -Path ([string]$registry.defaults.stateRoot)
$statePath = Join-Path $stateRoot 'state.json'
$fingerprintPath = Join-Path $stateRoot 'fingerprints.json'
$watcherPath = Join-Path $stateRoot 'watcher.json'
$lockPath = Join-Path $stateRoot 'engine.lock'
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null

switch ($Command) {
    'status' {
        $state = Get-TbgState -StatePath $statePath -DefaultMode $Mode
        $watcher = Get-TbgWatcherState -WatcherPath $watcherPath
        $watcherRunning = Test-TbgWatcherRunning -Watcher $watcher
        $status = [pscustomobject][ordered]@{
            schema = 'TbgArtifactEngineStatus.v1'
            enabled = [bool]$state.enabled
            mode = [string]$state.mode
            watcherRunning = $watcherRunning
            watcherPid = if ($watcherRunning) { [int]$watcher.pid } else { 0 }
            statePath = $statePath
            registryPath = $resolvedRegistryPath
            outputDirectory = $outputRoot
            additionalArtifactRoots = @($state.additionalArtifactRoots)
        }
        $status | ConvertTo-Json -Depth 8
        if ($status.enabled) {
            Write-Host "The local artifact engine is enabled in '$($status.mode)' mode, and watcherRunning=$watcherRunning."
        }
        else {
            Write-Host 'The local artifact engine automatic toggle is off. Manual run remains available.'
        }
        exit 0
    }
    'on' {
        $state = Set-TbgState -StatePath $statePath -Enabled $true -StateMode $Mode -UpdatedBy 'operator_on' -Roots $AdditionalArtifactRoot
        $pass = Invoke-TbgArtifactPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode $Mode -TriggerSource 'toggle_on' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $AdditionalArtifactRoot -ForcePass
        if (-not $NoStart) {
            $watcher = Start-TbgWatcher -ScriptPath $PSCommandPath -Registry $resolvedRegistryPath -Output $outputRoot -WatcherPath $watcherPath -Interval $PollSeconds -Roots $AdditionalArtifactRoot
            Write-Host "The local artifact engine is on in '$Mode' mode with watcher PID $($watcher.pid)."
        }
        else {
            Write-Host "The local artifact engine is on in '$Mode' mode without starting a watcher because -NoStart was supplied."
        }
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'off' {
        $current = Get-TbgState -StatePath $statePath -DefaultMode $Mode
        Set-TbgState -StatePath $statePath -Enabled $false -StateMode ([string]$current.mode) -UpdatedBy 'operator_off' -Roots @($current.additionalArtifactRoots) | Out-Null
        Stop-TbgWatcher -WatcherPath $watcherPath
        Write-Host 'The local artifact engine automatic toggle is off. Manual run remains available.'
        exit 0
    }
    'toggle' {
        $current = Get-TbgState -StatePath $statePath -DefaultMode $Mode
        if ([bool]$current.enabled) {
            Set-TbgState -StatePath $statePath -Enabled $false -StateMode ([string]$current.mode) -UpdatedBy 'operator_toggle_off' -Roots @($current.additionalArtifactRoots) | Out-Null
            Stop-TbgWatcher -WatcherPath $watcherPath
            Write-Host 'The local artifact engine toggle changed from on to off.'
            exit 0
        }
        $state = Set-TbgState -StatePath $statePath -Enabled $true -StateMode $Mode -UpdatedBy 'operator_toggle_on' -Roots $AdditionalArtifactRoot
        $pass = Invoke-TbgArtifactPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode $Mode -TriggerSource 'toggle_on' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $AdditionalArtifactRoot -ForcePass
        if (-not $NoStart) {
            $watcher = Start-TbgWatcher -ScriptPath $PSCommandPath -Registry $resolvedRegistryPath -Output $outputRoot -WatcherPath $watcherPath -Interval $PollSeconds -Roots $AdditionalArtifactRoot
            Write-Host "The local artifact engine toggle changed from off to on with watcher PID $($watcher.pid)."
        }
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'run' {
        $state = Get-TbgState -StatePath $statePath -DefaultMode $Mode
        $runMode = if ($PSBoundParameters.ContainsKey('Mode')) { $Mode } else { [string]$state.mode }
        $roots = if ($AdditionalArtifactRoot.Count -gt 0) { $AdditionalArtifactRoot } else { @($state.additionalArtifactRoots) }
        $pass = Invoke-TbgArtifactPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode $runMode -TriggerSource 'manual_run' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $roots -ForcePass
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'trigger' {
        $state = Get-TbgState -StatePath $statePath -DefaultMode $Mode
        if (-not [bool]$state.enabled) {
            Write-Host "The producer '$Source' did not start an artifact pass because the automatic toggle is off."
            exit 0
        }
        $roots = if ($AdditionalArtifactRoot.Count -gt 0) { $AdditionalArtifactRoot } else { @($state.additionalArtifactRoots) }
        $pass = Invoke-TbgArtifactPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode ([string]$state.mode) -TriggerSource $Source -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $roots -ForcePass
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'watch' {
        $state = Get-TbgState -StatePath $statePath -DefaultMode $Mode
        if (-not [bool]$state.enabled) {
            Write-Host 'The watcher did not start because the automatic toggle is off.'
            exit 0
        }
        $watcher = [pscustomobject][ordered]@{
            schema = 'TbgArtifactEngineWatcher.v1'
            pid = $PID
            startedUtc = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
            scriptPath = $PSCommandPath
            pollSeconds = $PollSeconds
        }
        Write-TbgJsonAtomic -Path $watcherPath -Value $watcher
        try {
            while ($true) {
                $state = Get-TbgState -StatePath $statePath -DefaultMode $Mode
                if (-not [bool]$state.enabled) { break }
                $roots = @($state.additionalArtifactRoots)
                $pass = Invoke-TbgArtifactPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode ([string]$state.mode) -TriggerSource 'watcher_change_detection' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $roots -WatchPass
                if ($null -ne $pass -and [int]$pass.exitCode -ne 0 -and [string]$state.mode -eq 'strict') {
                    Write-Error 'The strict artifact watcher found a blocker. The watcher will remain alive so the operator can inspect and correct the source artifact.'
                }
                Start-Sleep -Seconds $PollSeconds
            }
        }
        finally {
            $currentWatcher = Get-TbgWatcherState -WatcherPath $watcherPath
            if ($null -ne $currentWatcher -and [int]$currentWatcher.pid -eq $PID) {
                Remove-Item -LiteralPath $watcherPath -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host 'The local artifact watcher stopped because the automatic toggle is off.'
        exit 0
    }
}
