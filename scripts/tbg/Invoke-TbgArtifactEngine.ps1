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

function Get-TbgValue {
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

    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($full.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/')
    }
    return $full
}

function Write-TbgJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value,
        [int]$Depth = 24
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temporary = "$Path.tmp.$PID"
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Write-TbgText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temporary = "$Path.tmp.$PID"
    $Text | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-TbgHash {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-TbgState {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$DefaultMode
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
        catch { throw "The artifact engine state file is invalid: $Path. $($_.Exception.Message)" }
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
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][bool]$Enabled,
        [Parameter(Mandatory = $true)][string]$StateMode,
        [Parameter(Mandatory = $true)][string]$UpdatedBy,
        [string[]]$Roots = @()
    )

    $current = Get-TbgState -Path $Path -DefaultMode $StateMode
    $state = [pscustomobject][ordered]@{
        schema = 'TbgArtifactEngineState.v1'
        enabled = $Enabled
        mode = $StateMode
        generation = ([int](Get-TbgValue -Object $current -Name 'generation' -Default 0) + 1)
        updatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        updatedBy = $UpdatedBy
        additionalArtifactRoots = @($Roots)
    }
    Write-TbgJson -Path $Path -Value $state
    return $state
}

function Get-TbgWatcher {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Test-TbgWatcher {
    param([AllowNull()][object]$Watcher)

    if ($null -eq $Watcher) { return $false }
    $watcherPid = [int](Get-TbgValue -Object $Watcher -Name 'pid' -Default 0)
    if ($watcherPid -le 0) { return $false }
    $process = Get-Process -Id $watcherPid -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }

    $recordedStart = [string](Get-TbgValue -Object $Watcher -Name 'startedUtc' -Default '')
    if ([string]::IsNullOrWhiteSpace($recordedStart)) { return $true }
    try {
        $difference = [math]::Abs(($process.StartTime.ToUniversalTime() - [datetime]::Parse($recordedStart).ToUniversalTime()).TotalSeconds)
        return ($difference -lt 3)
    }
    catch { return $true }
}

function Stop-TbgWatcher {
    param([Parameter(Mandatory = $true)][string]$Path)

    $watcher = Get-TbgWatcher -Path $Path
    if (Test-TbgWatcher -Watcher $watcher) {
        Stop-Process -Id ([int]$watcher.pid) -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
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

    $existing = Get-TbgWatcher -Path $WatcherPath
    if (Test-TbgWatcher -Watcher $existing) { return $existing }

    $hostPath = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($hostPath)) {
        $hostPath = if ([string](Get-TbgValue -Object $PSVersionTable -Name 'PSEdition' -Default 'Desktop') -eq 'Core') { 'pwsh' } else { 'powershell.exe' }
    }

    $arguments = New-Object System.Collections.Generic.List[string]
    $arguments.Add('-NoProfile') | Out-Null
    if ($env:OS -eq 'Windows_NT') {
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

    $parameters = @{
        FilePath = $hostPath
        ArgumentList = @($arguments.ToArray())
        PassThru = $true
    }
    if ($env:OS -eq 'Windows_NT') { $parameters['WindowStyle'] = 'Hidden' }
    $process = Start-Process @parameters
    Start-Sleep -Milliseconds 150

    $watcher = [pscustomobject][ordered]@{
        schema = 'TbgArtifactEngineWatcher.v1'
        pid = $process.Id
        startedUtc = $process.StartTime.ToUniversalTime().ToString('o')
        scriptPath = $ScriptPath
        pollSeconds = $Interval
    }
    Write-TbgJson -Path $WatcherPath -Value $watcher
    return $watcher
}

function Get-TbgFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine,
        [Parameter(Mandatory = $true)][object]$Registry,
        [string[]]$ExtraRoots = @()
    )

    $files = New-Object System.Collections.Generic.List[object]
    $extensions = @((Get-TbgValue -Object $Engine -Name 'extensions' -Default @()) | ForEach-Object { ([string]$_).ToLowerInvariant() })
    $excludePrefixes = @($Registry.defaults.excludePrefixes)
    $roots = @((Get-TbgValue -Object $Engine -Name 'sourceRoots' -Default @())) + @($ExtraRoots)

    foreach ($sourceRoot in $roots) {
        if ([string]::IsNullOrWhiteSpace([string]$sourceRoot)) { continue }
        $resolvedRoot = Resolve-TbgPath -RepoRoot $RepoRoot -Path ([string]$sourceRoot)
        if (-not (Test-Path -LiteralPath $resolvedRoot)) { continue }
        $candidates = if (Test-Path -LiteralPath $resolvedRoot -PathType Leaf) {
            @(Get-Item -LiteralPath $resolvedRoot)
        }
        else {
            @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue)
        }

        foreach ($candidate in $candidates) {
            if ($extensions.Count -gt 0 -and $extensions -notcontains $candidate.Extension.ToLowerInvariant()) { continue }
            $relative = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $candidate.FullName
            $excluded = $false
            foreach ($prefix in $excludePrefixes) {
                $normalized = ([string]$prefix).TrimEnd('/', '\')
                if ($relative.StartsWith($normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) { $files.Add($candidate) | Out-Null }
        }
    }

    foreach ($pattern in @((Get-TbgValue -Object $Engine -Name 'rootFilePatterns' -Default @()))) {
        foreach ($candidate in @(Get-ChildItem -LiteralPath $RepoRoot -File -Filter ([string]$pattern) -ErrorAction SilentlyContinue)) {
            $files.Add($candidate) | Out-Null
        }
    }

    return @($files.ToArray() | Sort-Object FullName -Unique)
}

function Get-TbgCandidates {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = New-Object System.Collections.Generic.List[object]
    foreach ($candidatePath in @((Get-TbgValue -Object $Engine -Name 'candidatePaths' -Default @()))) {
        $resolved = Resolve-TbgPath -RepoRoot $RepoRoot -Path ([string]$candidatePath)
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $files.Add((Get-Item -LiteralPath $resolved)) | Out-Null
        }
    }
    return @($files.ToArray())
}

function Get-TbgFingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [object[]]$Files = @()
    )

    $parts = @($Files | Sort-Object FullName | ForEach-Object {
        "$(Get-TbgRelativePath -RepoRoot $RepoRoot -Path $_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
    })
    $text = ($parts -join "`n")
    if ([string]::IsNullOrEmpty($text)) { $text = 'empty' }
    return Get-TbgHash -Text $text
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
        $content = Get-Content -LiteralPath $File.FullName -Raw
        $record.lineCount = if ([string]::IsNullOrEmpty($content)) { 0 } else { @($content -split "`r?`n").Count }
        switch ($record.extension) {
            '.json' {
                $value = $content | ConvertFrom-Json -ErrorAction Stop
                $record.parseStatus = 'parsed'
                $record.artifactSchema = [string](Get-TbgValue -Object $value -Name 'schema' -Default '')
                $record.status = [string](Get-TbgValue -Object $value -Name 'status' -Default '')
                $record.verdict = [string](Get-TbgValue -Object $value -Name 'verdict' -Default (Get-TbgValue -Object $value -Name 'passFail' -Default ''))
                $record.terminalState = [string](Get-TbgValue -Object $value -Name 'terminalState' -Default '')
                $record.proofLevel = [string](Get-TbgValue -Object $value -Name 'proofLevel' -Default '')
                $record.nextCommand = [string](Get-TbgValue -Object $value -Name 'nextCommand' -Default '')
                $record.summary = 'The JSON artifact parsed successfully.'
            }
            '.jsonl' {
                $lines = @($content -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                foreach ($line in $lines) { $line | ConvertFrom-Json -ErrorAction Stop | Out-Null }
                $record.parseStatus = 'parsed'
                $record.summary = "The JSONL artifact contains $($lines.Count) valid event lines."
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

function New-TbgPacket {
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

function Invoke-TbgInventory {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine,
        [Parameter(Mandatory = $true)][object]$Registry,
        [string[]]$ExtraRoots = @()
    )

    $files = @(Get-TbgFiles -RepoRoot $RepoRoot -Engine $Engine -Registry $Registry -ExtraRoots $ExtraRoots)
    $observations = @($files | ForEach-Object { ConvertFrom-TbgArtifact -RepoRoot $RepoRoot -File $_ -MaxBytes ([long]$Registry.defaults.maxParseBytes) })
    $errors = @($observations | Where-Object { $_.parseStatus -eq 'error' })
    $parsed = @($observations | Where-Object { $_.parseStatus -eq 'parsed' })
    $metadata = @($observations | Where-Object { $_.parseStatus -eq 'metadata_only' })
    $terminal = if ($errors.Count -gt 0) { 'ATTENTION_artifact_parse_errors' } else { 'READY_artifact_index_updated' }
    $next = if ($errors.Count -gt 0) { "Get-Content -LiteralPath '$($errors[0].path)' -Raw" } else { '.\ForgeArtifactEngine.cmd status' }
    $sentences = @(
        "The artifact-index engine inspected $($observations.Count) configured local artifacts.",
        "The artifact-index engine parsed $($parsed.Count) artifacts, retained metadata for $($metadata.Count) oversized artifacts, and recorded $($errors.Count) parse errors.",
        'The artifact-index engine excluded its own output directory so generated reports cannot create an infinite trigger loop.',
        "The operator should run '$next' as the next command."
    )
    $payload = [pscustomobject][ordered]@{
        count = $observations.Count
        parsedCount = $parsed.Count
        metadataOnlyCount = $metadata.Count
        parseErrorCount = $errors.Count
        artifacts = @($observations)
    }
    return New-TbgPacket -EngineId $Engine.id -Schema 'TbgArtifactIndex.v1' -TerminalState $terminal -NextCommand $next -Payload $payload -Sentences $sentences
}

function Invoke-TbgRepoFloor {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidates -RepoRoot $RepoRoot -Engine $Engine)
    $jsonFile = @($files | Where-Object { $_.Extension -eq '.json' } | Select-Object -First 1)
    if ($jsonFile.Count -eq 0) {
        return New-TbgPacket -EngineId $Engine.id -Schema 'TbgRepoFloorContext.v1' -TerminalState 'UNAVAILABLE_repo_floor_artifact_missing' -NextCommand '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked' -Payload ([pscustomobject]@{ artifactFound = $false }) -Sentences @(
            'The repo-floor-context engine did not find a repository hygiene JSON artifact.',
            'The missing repository hygiene artifact does not prove that the repository floor is clean.',
            "The operator should run '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked' as the next command."
        )
    }

    try { $source = Get-Content -LiteralPath $jsonFile[0].FullName -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch {
        return New-TbgPacket -EngineId $Engine.id -Schema 'TbgRepoFloorContext.v1' -TerminalState 'BLOCKED_repo_floor_parse_error' -NextCommand "Get-Content -LiteralPath '$($jsonFile[0].FullName)' -Raw" -Payload ([pscustomobject]@{ artifactFound = $true; parseError = $_.Exception.Message }) -Sentences @(
            'The repo-floor-context engine found the repository hygiene artifact but could not parse it.',
            "The operator should inspect '$($jsonFile[0].FullName)' before any floor-dependent action runs."
        ) -Blocking $true
    }

    $verdict = [string](Get-TbgValue -Object $source -Name 'verdict' -Default 'UNKNOWN')
    $dirty = @((Get-TbgValue -Object $source -Name 'dirtyPaths' -Default @()))
    $conflicts = @((Get-TbgValue -Object $source -Name 'conflictedFiles' -Default @()))
    $operations = @((Get-TbgValue -Object $source -Name 'operations' -Default @()))
    $worktrees = @((Get-TbgValue -Object $source -Name 'worktrees' -Default @()))
    $next = [string](Get-TbgValue -Object $source -Name 'nextCommand' -Default 'git status --short')
    $terminal = if ($verdict -eq 'CLEAN') { 'READY_repo_floor_clean' } elseif ($verdict -eq 'BLOCKED') { 'BLOCKED_repo_floor' } else { 'ATTENTION_repo_floor_needs_review' }
    $blocking = ($verdict -eq 'BLOCKED')
    return New-TbgPacket -EngineId $Engine.id -Schema 'TbgRepoFloorContext.v1' -TerminalState $terminal -NextCommand $next -Payload ([pscustomobject][ordered]@{
        artifactFound = $true
        sourcePath = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $jsonFile[0].FullName
        branch = [string](Get-TbgValue -Object $source -Name 'branch' -Default '')
        head = [string](Get-TbgValue -Object $source -Name 'head' -Default '')
        upstream = [string](Get-TbgValue -Object $source -Name 'upstream' -Default '')
        verdict = $verdict
        dirtyCount = $dirty.Count
        conflictCount = $conflicts.Count
        operationCount = $operations.Count
        worktreeCount = $worktrees.Count
    }) -Sentences @(
        "The repo-floor-context engine parsed repository hygiene evidence for branch '$([string](Get-TbgValue -Object $source -Name 'branch' -Default 'unknown'))' at HEAD '$([string](Get-TbgValue -Object $source -Name 'head' -Default 'unknown'))'.",
        "The repository hygiene artifact reports verdict '$verdict', $($dirty.Count) dirty paths, $($conflicts.Count) conflicted files, $($operations.Count) active Git operations, and $($worktrees.Count) registered worktrees.",
        "The repo-floor-context engine classified the floor as '$terminal'.",
        "The operator should run '$next' as the next command."
    ) -Blocking $blocking
}

function Invoke-TbgStalePr {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidates -RepoRoot $RepoRoot -Engine $Engine)
    $jsonFile = @($files | Where-Object { $_.Extension -eq '.json' } | Select-Object -First 1)
    if ($jsonFile.Count -eq 0) {
        return New-TbgPacket -EngineId $Engine.id -Schema 'TbgStalePrNextAction.v1' -TerminalState 'UNAVAILABLE_stale_pr_recovery_artifact_missing' -NextCommand '.\ForgeStalePrRecovery.cmd -Wave 0' -Payload ([pscustomobject]@{ artifactFound = $false }) -Sentences @(
            'The stale-pr-next-action engine did not find a stale PR recovery result artifact.',
            "The operator should run '.\ForgeStalePrRecovery.cmd -Wave 0' before requesting a recovery action."
        )
    }

    try { $source = Get-Content -LiteralPath $jsonFile[0].FullName -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch {
        return New-TbgPacket -EngineId $Engine.id -Schema 'TbgStalePrNextAction.v1' -TerminalState 'BLOCKED_stale_pr_parse_error' -NextCommand "Get-Content -LiteralPath '$($jsonFile[0].FullName)' -Raw" -Payload ([pscustomobject]@{ artifactFound = $true; parseError = $_.Exception.Message }) -Sentences @(
            'The stale-pr-next-action engine found the recovery artifact but could not parse it.',
            "The operator should inspect '$($jsonFile[0].FullName)' before any recovery action runs."
        ) -Blocking $true
    }

    $floorTerminal = 'UNAVAILABLE_repo_floor_context'
    $floorReady = $false
    $floorPath = Join-Path $OutputRoot 'repo-floor-context.result.json'
    if (Test-Path -LiteralPath $floorPath -PathType Leaf) {
        try {
            $floor = Get-Content -LiteralPath $floorPath -Raw | ConvertFrom-Json
            $floorTerminal = [string]$floor.terminalState
            $floorReady = ($floorTerminal -eq 'READY_repo_floor_clean')
        }
        catch { $floorReady = $false }
    }

    $sourceTerminal = [string](Get-TbgValue -Object $source -Name 'terminalState' -Default 'UNKNOWN_stale_pr_state')
    $sourceVerdict = [string](Get-TbgValue -Object $source -Name 'verdict' -Default (Get-TbgValue -Object $source -Name 'status' -Default 'UNKNOWN'))
    $terminal = $sourceTerminal
    $next = [string](Get-TbgValue -Object $source -Name 'nextCommand' -Default '.\ForgeStalePrRecovery.cmd -Wave 0')
    $blocking = ($sourceVerdict -eq 'BLOCKED' -or $sourceTerminal.StartsWith('BLOCKED_'))
    if ($sourceTerminal -eq 'READY_bounded_recovery_instruction' -and -not $floorReady) {
        $terminal = 'BLOCKED_local_floor_context_not_clean'
        $next = '.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked'
        $blocking = $true
    }

    return New-TbgPacket -EngineId $Engine.id -Schema 'TbgStalePrNextAction.v1' -TerminalState $terminal -NextCommand $next -Payload ([pscustomobject][ordered]@{
        artifactFound = $true
        sourcePath = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $jsonFile[0].FullName
        sourceTerminalState = $sourceTerminal
        sourceVerdict = $sourceVerdict
        repoFloorTerminalState = $floorTerminal
        repoFloorReady = $floorReady
    }) -Sentences @(
        "The stale-pr-next-action engine parsed recovery state '$sourceTerminal' with verdict '$sourceVerdict'.",
        "The repo-floor dependency currently reports '$floorTerminal'.",
        "The stale-pr-next-action engine classified the executable next decision as '$terminal'.",
        "The operator should run '$next' as the next command."
    ) -Blocking $blocking
}

function Invoke-TbgWindowLifecycleBoundary {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidates -RepoRoot $RepoRoot -Engine $Engine)
    $jsonFiles = @($files | Where-Object { $_.Extension -eq '.json' })
    $reportFiles = @($files | Where-Object { $_.Extension -eq '.md' })
    if ($files.Count -eq 0) {
        return New-TbgPacket -EngineId $Engine.id -Schema 'TbgWindowLifecycleBoundary.v1' -TerminalState 'UNAVAILABLE_window_lifecycle_artifacts_missing' -NextCommand '.\ForgeWindowLifecycle.cmd replay' -Payload ([pscustomobject][ordered]@{
            artifactFound = $false
            parserProofLevel = 'artifact_inspection'
            freshnessVerified = $false
            independentlyValidated = $false
            actionAuthority = 'none'
        }) -Sentences @(
            'The window-lifecycle-boundary engine did not find registered P19 lifecycle state, result, or report artifacts.',
            "The operator should run '.\ForgeWindowLifecycle.cmd replay' before treating lifecycle routing as fresh."
        )
    }

    $claims = New-Object System.Collections.Generic.List[object]
    $blocking = $false
    $quarantined = $false
    $parseError = $false
    $freshnessVerified = $true
    $maxAgeHours = 24
    $now = [DateTime]::UtcNow

    foreach ($file in $jsonFiles) {
        $ageHours = ($now - $file.LastWriteTimeUtc).TotalHours
        $fileFresh = ($ageHours -le $maxAgeHours)
        if (-not $fileFresh) { $freshnessVerified = $false }
        try {
            $value = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            $schema = [string](Get-TbgValue -Object $value -Name 'schema' -Default '')
            $status = [string](Get-TbgValue -Object $value -Name 'status' -Default '')
            $proofLevel = [string](Get-TbgValue -Object $value -Name 'proofLevel' -Default '')
            $proofCeiling = [string](Get-TbgValue -Object $value -Name 'proofCeiling' -Default '')
            $windows = @(Get-TbgValue -Object $value -Name 'windows' -Default @())
            if ($windows.Count -eq 0) {
                $state = Get-TbgValue -Object $value -Name 'state' -Default $null
                $windows = @(Get-TbgValue -Object $state -Name 'windows' -Default @())
            }
            foreach ($window in $windows) {
                $phase = [string](Get-TbgValue -Object $window -Name 'phase' -Default '')
                $identity = [string](Get-TbgValue -Object $window -Name 'identity' -Default (Get-TbgValue -Object $window -Name 'identityId' -Default ''))
                if ($phase -match 'unknown|quarantine' -or $identity -match 'unknown|quarantine') {
                    $quarantined = $true
                }
            }
            if ($proofLevel -match 'live runtime|behavior observed|campaign' -or $status -match 'live_runtime|gameplay_pass') {
                $blocking = $true
                $claims.Add([pscustomobject][ordered]@{
                    path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $file.FullName
                    schema = $schema
                    status = $status
                    proofLevel = $proofLevel
                    proofCeiling = $proofCeiling
                    candidateClassification = 'blocked_overclaim'
                    freshnessVerified = $fileFresh
                    independentlyValidated = $false
                }) | Out-Null
            }
            else {
                $claims.Add([pscustomobject][ordered]@{
                    path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $file.FullName
                    schema = $schema
                    status = $status
                    proofLevel = $proofLevel
                    proofCeiling = $proofCeiling
                    candidateClassification = if ($quarantined) { 'quarantine_or_unknown' } else { 'lifecycle_harness_observation' }
                    freshnessVerified = $fileFresh
                    independentlyValidated = $false
                }) | Out-Null
            }
        }
        catch {
            $parseError = $true
            $blocking = $true
            $freshnessVerified = $false
            $claims.Add([pscustomobject][ordered]@{
                path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $file.FullName
                schema = ''
                status = ''
                proofLevel = ''
                proofCeiling = ''
                candidateClassification = 'parse_error'
                freshnessVerified = $false
                independentlyValidated = $false
            }) | Out-Null
        }
    }

    foreach ($file in $reportFiles) {
        $claims.Add([pscustomobject][ordered]@{
            path = Get-TbgRelativePath -RepoRoot $RepoRoot -Path $file.FullName
            schema = 'markdown-report'
            status = ''
            proofLevel = ''
            proofCeiling = ''
            candidateClassification = 'report_present'
            freshnessVerified = (($now - $file.LastWriteTimeUtc).TotalHours -le $maxAgeHours)
            independentlyValidated = $false
        }) | Out-Null
    }

    if ($parseError) {
        $terminal = 'BLOCKED_window_lifecycle_parse_error'
        $next = '.\ForgeWindowLifecycle.cmd validate'
    }
    elseif ($blocking) {
        $terminal = 'BLOCKED_window_lifecycle_proof_overclaim'
        $next = '.\ForgeWindowLifecycle.cmd status'
    }
    elseif (-not $freshnessVerified) {
        $terminal = 'BLOCKED_window_lifecycle_stale'
        $next = '.\ForgeWindowLifecycle.cmd replay'
        $blocking = $true
    }
    elseif ($quarantined) {
        $terminal = 'WAITING_window_lifecycle_quarantined'
        $next = '.\ForgeWindowLifecycle.cmd status'
    }
    else {
        $terminal = 'READY_window_lifecycle_boundary_classified'
        $next = '.\ForgeArtifactEngine.cmd run -Mode observe'
    }

    return New-TbgPacket -EngineId $Engine.id -Schema 'TbgWindowLifecycleBoundary.v1' -TerminalState $terminal -NextCommand $next -Payload ([pscustomobject][ordered]@{
        artifactFound = $true
        artifactCount = $files.Count
        parserProofLevel = 'artifact_inspection'
        freshnessVerified = $freshnessVerified
        independentlyValidated = $false
        actionAuthority = 'none'
        claims = @($claims.ToArray())
    }) -Sentences @(
        "The window-lifecycle-boundary engine inspected $($files.Count) registered P19 lifecycle artifact(s).",
        'The engine remains read-only and never authorizes clicks, launches, or gameplay mutation.',
        "The window-lifecycle-boundary engine classified the current boundary as '$terminal'.",
        "The operator should run '$next' as the next command."
    ) -Blocking $blocking
}

function Invoke-TbgProofBoundary {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][object]$Engine
    )

    $files = @(Get-TbgCandidates -RepoRoot $RepoRoot -Engine $Engine)
    $claims = New-Object System.Collections.Generic.List[object]
    foreach ($file in $files) {
        try {
            $value = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            $status = [string](Get-TbgValue -Object $value -Name 'status' -Default '')
            $verdict = [string](Get-TbgValue -Object $value -Name 'verdict' -Default (Get-TbgValue -Object $value -Name 'passFail' -Default ''))
            $sourceProof = [string](Get-TbgValue -Object $value -Name 'proofLevel' -Default '')
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
                schema = [string](Get-TbgValue -Object $value -Name 'schema' -Default '')
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
    return New-TbgPacket -EngineId $Engine.id -Schema 'TbgRuntimeProofBoundary.v1' -TerminalState 'READY_proof_boundary_classified' -NextCommand $next -Payload ([pscustomobject][ordered]@{
        artifactCount = $files.Count
        parserProofLevel = 'artifact_inspection'
        claims = @($claims.ToArray())
    }) -Sentences @(
        "The runtime-proof-boundary engine inspected $($files.Count) known runtime or launcher artifacts.",
        'The parser classified every source claim conservatively because parsing alone does not verify freshness, causality, or observed behavior.',
        'The highest proof level created by this engine is artifact inspection, even when a source artifact reports a higher candidate level.',
        "The operator should run '$next' as the next command."
    )
}

function Invoke-TbgHandoff {
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
                engineId = [string]$engineId
                terminalState = [string]$value.terminalState
                blocking = [bool]$value.blocking
                nextCommand = [string]$value.nextCommand
                resultPath = $path
            }) | Out-Null
            if ([bool]$value.blocking) { $blocking = $true }
            if (-not [string]::IsNullOrWhiteSpace([string]$value.nextCommand)) { $nextCommands.Add([string]$value.nextCommand) | Out-Null }
        }
        catch {
            $blocking = $true
            $summaries.Add([pscustomobject][ordered]@{
                engineId = [string]$engineId
                terminalState = 'BLOCKED_engine_result_parse_error'
                blocking = $true
                nextCommand = "Get-Content -LiteralPath '$path' -Raw"
                resultPath = $path
            }) | Out-Null
        }
    }

    $next = if ($nextCommands.Count -gt 0) { $nextCommands[0] } else { '.\ForgeArtifactEngine.cmd status' }
    $terminal = if ($blocking) { 'BLOCKED_handoff_contains_blockers' } else { 'READY_handoff_compressed' }
    return New-TbgPacket -EngineId $Engine.id -Schema 'TbgArtifactEngineHandoff.v1' -TerminalState $terminal -NextCommand $next -Payload ([pscustomobject][ordered]@{
        engines = @($summaries.ToArray())
        recommendedNextCommand = $next
    }) -Sentences @(
        "The handoff-compressor engine collected $($summaries.Count) upstream engine results.",
        "The compressed handoff reports terminal state '$terminal'.",
        'The handoff preserves each upstream terminal state and next command without converting parser output into runtime proof.',
        "The operator should run '$next' as the next command."
    ) -Blocking $blocking
}

function Write-TbgPacket {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][object]$Engine,
        [Parameter(Mandatory = $true)][object]$Packet
    )

    $engineResult = Join-Path $OutputRoot "$($Engine.id).result.json"
    $namedResult = Join-Path $OutputRoot "$($Engine.outputStem).result.json"
    Write-TbgJson -Path $engineResult -Value $Packet.result
    if ($namedResult -ne $engineResult) { Write-TbgJson -Path $namedResult -Value $Packet.result }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $($Engine.id) Engine Report") | Out-Null
    $lines.Add('') | Out-Null
    foreach ($sentence in @($Packet.reportLines)) { $lines.Add([string]$sentence) | Out-Null }
    Write-TbgText -Path (Join-Path $OutputRoot "$($Engine.outputStem).report.md") -Text (($lines -join "`n") + "`n")
}

function Assert-TbgRegistry {
    param([Parameter(Mandatory = $true)][object]$Registry)

    $map = @{}
    foreach ($engine in @($Registry.engines)) {
        $id = [string]$engine.id
        if ([string]::IsNullOrWhiteSpace($id)) { throw 'The registry contains an engine without an id.' }
        if ($map.ContainsKey($id)) { throw "The registry contains duplicate engine '$id'." }
        if ([string]$engine.authority -ne 'read_only') { throw "Engine '$id' does not declare read_only authority." }
        $map[$id] = $engine
    }

    foreach ($engine in @($Registry.engines)) {
        foreach ($downstream in @((Get-TbgValue -Object $engine -Name 'downstream' -Default @()))) {
            if (-not $map.ContainsKey([string]$downstream)) { throw "Engine '$($engine.id)' names unregistered downstream engine '$downstream'." }
        }
    }

    $visiting = @{}
    $visited = @{}
    function Visit-TbgNode {
        param([string]$Id)
        if ($visiting.ContainsKey($Id)) { throw "The artifact engine registry contains a cycle at '$Id'." }
        if ($visited.ContainsKey($Id)) { return }
        $visiting[$Id] = $true
        foreach ($child in @((Get-TbgValue -Object $map[$Id] -Name 'downstream' -Default @()))) { Visit-TbgNode -Id ([string]$child) }
        $visiting.Remove($Id)
        $visited[$Id] = $true
    }
    foreach ($id in @($map.Keys)) { Visit-TbgNode -Id $id }
    return $map
}

function Invoke-TbgPass {
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
        try { $lock = New-Object System.IO.FileStream($LockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
        catch {
            Write-Host 'The artifact engine skipped this pass because another pass owns the local lock.'
            return $null
        }

        $engineMap = Assert-TbgRegistry -Registry $Registry
        $fingerprints = @{}
        if (Test-Path -LiteralPath $FingerprintPath -PathType Leaf) {
            try { $fingerprints = ConvertTo-TbgHashtable (Get-Content -LiteralPath $FingerprintPath -Raw | ConvertFrom-Json) }
            catch { $fingerprints = @{} }
        }

        $queue = New-Object System.Collections.Generic.Queue[string]
        $queue.Enqueue('artifact-index')
        $queued = @{ 'artifact-index' = $true }
        $completed = @{}
        $runs = New-Object System.Collections.Generic.List[object]
        $events = New-Object System.Collections.Generic.List[object]
        $progress = New-Object System.Collections.Generic.List[string]
        $maximum = [int]$Registry.defaults.maxCascadeEngines
        $sequence = 0

        while ($queue.Count -gt 0) {
            if ($runs.Count -ge $maximum) { throw "The artifact engine exceeded the configured cascade limit of $maximum engines." }
            $engineId = $queue.Dequeue()
            $queued.Remove($engineId)
            if ($completed.ContainsKey($engineId)) { continue }
            if (-not $engineMap.ContainsKey($engineId)) { throw "The artifact engine '$engineId' is not registered." }

            $engine = $engineMap[$engineId]
            $implementation = [string]$engine.implementation
            $inputFiles = if ($implementation -eq 'inventory') {
                @(Get-TbgFiles -RepoRoot $RepoRoot -Engine $engine -Registry $Registry -ExtraRoots $ExtraRoots)
            }
            elseif ($implementation -eq 'handoff') { @() }
            else { @(Get-TbgCandidates -RepoRoot $RepoRoot -Engine $engine) }

            $fingerprint = if ($implementation -eq 'handoff') {
                $upstreamParts = @($engine.consumesEngineResults | ForEach-Object {
                    $path = Join-Path $OutputRoot "$_.result.json"
                    if (Test-Path -LiteralPath $path) {
                        $item = Get-Item -LiteralPath $path
                        "$($_)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
                    }
                })
                Get-TbgHash -Text ($upstreamParts -join "`n")
            }
            else { Get-TbgFingerprint -RepoRoot $RepoRoot -Files $inputFiles }

            $previous = if ($fingerprints.ContainsKey($engineId)) { [string]$fingerprints[$engineId] } else { '' }
            $changed = ($fingerprint -ne $previous)
            $shouldRun = $ForcePass -or (-not $WatchPass) -or $changed
            if (-not $shouldRun) {
                $completed[$engineId] = $true
                continue
            }

            $packet = switch ($implementation) {
                'inventory' { Invoke-TbgInventory -RepoRoot $RepoRoot -Engine $engine -Registry $Registry -ExtraRoots $ExtraRoots }
                'repo_floor' { Invoke-TbgRepoFloor -RepoRoot $RepoRoot -Engine $engine }
                'stale_pr' { Invoke-TbgStalePr -RepoRoot $RepoRoot -OutputRoot $OutputRoot -Engine $engine }
                'window_lifecycle_boundary' { Invoke-TbgWindowLifecycleBoundary -RepoRoot $RepoRoot -Engine $engine }
                'proof_boundary' { Invoke-TbgProofBoundary -RepoRoot $RepoRoot -Engine $engine }
                'handoff' { Invoke-TbgHandoff -OutputRoot $OutputRoot -Engine $engine }
                default { throw "The artifact engine implementation '$implementation' is not supported." }
            }

            Write-TbgPacket -OutputRoot $OutputRoot -Engine $engine -Packet $packet
            $fingerprints[$engineId] = $fingerprint
            $completed[$engineId] = $true
            $sequence++
            $sentence = "The local artifact router ran engine '$engineId' and produced terminal state '$($packet.result.terminalState)'."
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
                sentence = $sentence
            }) | Out-Null
            $progress.Add($sentence) | Out-Null
            $runs.Add([pscustomobject][ordered]@{
                engineId = $engineId
                implementation = $implementation
                inputCount = @($inputFiles).Count
                changed = $changed
                terminalState = [string]$packet.result.terminalState
                blocking = [bool]$packet.result.blocking
                nextCommand = [string]$packet.result.nextCommand
            }) | Out-Null

            if ($StateMode -ne 'observe') {
                foreach ($downstream in @((Get-TbgValue -Object $engine -Name 'downstream' -Default @()))) {
                    $downstreamId = [string]$downstream
                    if (-not $completed.ContainsKey($downstreamId) -and -not $queued.ContainsKey($downstreamId)) {
                        $queue.Enqueue($downstreamId)
                        $queued[$downstreamId] = $true
                    }
                }
            }
        }

        Write-TbgJson -Path $FingerprintPath -Value ([pscustomobject]$fingerprints
        )
        if ($runs.Count -eq 0) {
            return [pscustomobject]@{ exitCode = 0; result = $null }
        }
        $blockingRuns = @($runs.ToArray() | Where-Object { $_.blocking })
        $parseRuns = @($runs.ToArray() | Where-Object { $_.terminalState -match 'parse_error|parse_errors' })
        $strictFailure = ($StateMode -eq 'strict' -and ($blockingRuns.Count -gt 0 -or $parseRuns.Count -gt 0))
        $terminal = if ($strictFailure) { 'BLOCKED_artifact_engine_strict' } elseif ($StateMode -eq 'observe') { 'READY_observe_complete' } else { 'READY_auto_cascade_complete' }
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
        Write-TbgJson -Path (Join-Path $OutputRoot 'artifact-engine.result.json') -Value $result
        Write-TbgText -Path (Join-Path $OutputRoot 'artifact-engine.events.jsonl') -Text ((@($events.ToArray() | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }) -join "`n") + "`n")
        Write-TbgText -Path (Join-Path $OutputRoot 'artifact-engine.progress.log') -Text ((@($progress.ToArray()) -join "`n") + "`n")

        $report = New-Object System.Collections.Generic.List[string]
        $report.Add('# TBG Local Artifact Engine Report') | Out-Null
        $report.Add('') | Out-Null
        $report.Add("The local artifact router ran in '$StateMode' mode because '$TriggerSource' triggered the pass.") | Out-Null
        $report.Add("The router completed $($runs.Count) registered engines and produced terminal state '$terminal'.") | Out-Null
        $report.Add("The router found $($blockingRuns.Count) blocking engine results and $($parseRuns.Count) parse-error engine results.") | Out-Null
        $report.Add("The operator should run '$next' as the next command.") | Out-Null
        $report.Add('') | Out-Null
        $report.Add('## Engine Results') | Out-Null
        $report.Add('') | Out-Null
        foreach ($run in @($runs.ToArray())) { $report.Add("- The '$($run.engineId)' engine produced '$($run.terminalState)' and recommends '$($run.nextCommand)'.") | Out-Null }
        $report.Add('') | Out-Null
        $report.Add('The parser does not claim build, launcher, movement, trade, behavior-observed, or live runtime proof merely because it parsed an artifact.') | Out-Null
        Write-TbgText -Path (Join-Path $OutputRoot 'artifact-engine.report.md') -Text (($report -join "`n") + "`n")

        $handoff = New-Object System.Collections.Generic.List[string]
        $handoff.Add('# TBG Artifact Engine Handoff') | Out-Null
        $handoff.Add('') | Out-Null
        $handoff.Add("Repository: $RepoRoot") | Out-Null
        $handoff.Add("Trigger source: $TriggerSource") | Out-Null
        $handoff.Add("Mode: $StateMode") | Out-Null
        $handoff.Add("Terminal state: $terminal") | Out-Null
        $handoff.Add("Next command: $next") | Out-Null
        $handoff.Add('') | Out-Null
        $handoff.Add('Engine packets:') | Out-Null
        foreach ($run in @($runs.ToArray())) { $handoff.Add("- $($run.engineId): $($run.terminalState); $(Join-Path $OutputRoot "$($run.engineId).result.json")") | Out-Null }
        $handoff.Add('') | Out-Null
        $handoff.Add('Proof boundary: artifact parsing and static harness proof only. Inspect source evidence and run the owning validator before making a higher claim.') | Out-Null
        Write-TbgText -Path (Join-Path $OutputRoot 'artifact-engine.handoff.md') -Text (($handoff -join "`n") + "`n")

        Write-Host "Artifact engine terminal state: $terminal"
        Write-Host "Artifact engine report: $(Join-Path $OutputRoot 'artifact-engine.report.md')"
        Write-Host "Next command: $next"
        return [pscustomobject]@{ exitCode = $(if ($strictFailure) { 2 } else { 0 }); result = $result }
    }
    finally {
        if ($null -ne $lock) { $lock.Dispose() }
    }
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$resolvedRegistryPath = Resolve-TbgPath -RepoRoot $repoRoot -Path $RegistryPath
if (-not (Test-Path -LiteralPath $resolvedRegistryPath -PathType Leaf)) { throw "The artifact engine registry is missing: $resolvedRegistryPath" }
$registry = Get-Content -LiteralPath $resolvedRegistryPath -Raw | ConvertFrom-Json
if ([string]$registry.schema -ne 'TbgArtifactEngineRegistry.v1') { throw "The artifact engine registry schema is unsupported: $($registry.schema)" }
Assert-TbgRegistry -Registry $registry | Out-Null

$outputRoot = Resolve-TbgPath -RepoRoot $repoRoot -Path $OutputDirectory
$stateRoot = Resolve-TbgPath -RepoRoot $repoRoot -Path ([string]$registry.defaults.stateRoot)
$statePath = Join-Path $stateRoot 'state.json'
$fingerprintPath = Join-Path $stateRoot 'fingerprints.json'
$watcherPath = Join-Path $stateRoot 'watcher.json'
$lockPath = Join-Path $stateRoot 'engine.lock'
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null

switch ($Command) {
    'status' {
        $state = Get-TbgState -Path $statePath -DefaultMode $Mode
        $watcher = Get-TbgWatcher -Path $watcherPath
        $running = Test-TbgWatcher -Watcher $watcher
        [pscustomobject][ordered]@{
            schema = 'TbgArtifactEngineStatus.v1'
            enabled = [bool]$state.enabled
            mode = [string]$state.mode
            watcherRunning = $running
            watcherPid = if ($running) { [int]$watcher.pid } else { 0 }
            statePath = $statePath
            registryPath = $resolvedRegistryPath
            outputDirectory = $outputRoot
            additionalArtifactRoots = @($state.additionalArtifactRoots)
        } | ConvertTo-Json -Depth 8
        if ([bool]$state.enabled) { Write-Host "The local artifact engine is enabled in '$($state.mode)' mode, and watcherRunning=$running." }
        else { Write-Host 'The local artifact engine automatic toggle is off. Manual run remains available.' }
        exit 0
    }
    'off' {
        $current = Get-TbgState -Path $statePath -DefaultMode $Mode
        Set-TbgState -Path $statePath -Enabled $false -StateMode ([string]$current.mode) -UpdatedBy 'operator_off' -Roots @($current.additionalArtifactRoots) | Out-Null
        Stop-TbgWatcher -Path $watcherPath
        Write-Host 'The local artifact engine automatic toggle is off. Manual run remains available.'
        exit 0
    }
    'on' {
        Set-TbgState -Path $statePath -Enabled $true -StateMode $Mode -UpdatedBy 'operator_on' -Roots $AdditionalArtifactRoot | Out-Null
        $pass = Invoke-TbgPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode $Mode -TriggerSource 'toggle_on' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $AdditionalArtifactRoot -ForcePass
        if (-not $NoStart) {
            $watcher = Start-TbgWatcher -ScriptPath $PSCommandPath -Registry $resolvedRegistryPath -Output $outputRoot -WatcherPath $watcherPath -Interval $PollSeconds -Roots $AdditionalArtifactRoot
            Write-Host "The local artifact engine is on in '$Mode' mode with watcher PID $($watcher.pid)."
        }
        else { Write-Host "The local artifact engine is on in '$Mode' mode without starting a watcher because -NoStart was supplied." }
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'toggle' {
        $current = Get-TbgState -Path $statePath -DefaultMode $Mode
        if ([bool]$current.enabled) {
            Set-TbgState -Path $statePath -Enabled $false -StateMode ([string]$current.mode) -UpdatedBy 'operator_toggle_off' -Roots @($current.additionalArtifactRoots) | Out-Null
            Stop-TbgWatcher -Path $watcherPath
            Write-Host 'The local artifact engine toggle changed from on to off.'
            exit 0
        }
        Set-TbgState -Path $statePath -Enabled $true -StateMode $Mode -UpdatedBy 'operator_toggle_on' -Roots $AdditionalArtifactRoot | Out-Null
        $pass = Invoke-TbgPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode $Mode -TriggerSource 'toggle_on' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $AdditionalArtifactRoot -ForcePass
        if (-not $NoStart) {
            $watcher = Start-TbgWatcher -ScriptPath $PSCommandPath -Registry $resolvedRegistryPath -Output $outputRoot -WatcherPath $watcherPath -Interval $PollSeconds -Roots $AdditionalArtifactRoot
            Write-Host "The local artifact engine toggle changed from off to on with watcher PID $($watcher.pid)."
        }
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'run' {
        $state = Get-TbgState -Path $statePath -DefaultMode $Mode
        $runMode = if ($PSBoundParameters.ContainsKey('Mode')) { $Mode } else { [string]$state.mode }
        $roots = if ($AdditionalArtifactRoot.Count -gt 0) { $AdditionalArtifactRoot } else { @($state.additionalArtifactRoots) }
        $pass = Invoke-TbgPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode $runMode -TriggerSource 'manual_run' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $roots -ForcePass:$Force
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'trigger' {
        $state = Get-TbgState -Path $statePath -DefaultMode $Mode
        if (-not [bool]$state.enabled) {
            Write-Host "The producer '$Source' did not start an artifact pass because the automatic toggle is off."
            exit 0
        }
        Start-Sleep -Milliseconds ([int]$registry.defaults.settleMilliseconds)
        $roots = if ($AdditionalArtifactRoot.Count -gt 0) { $AdditionalArtifactRoot } else { @($state.additionalArtifactRoots) }
        $pass = Invoke-TbgPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode ([string]$state.mode) -TriggerSource $Source -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots $roots -ForcePass
        if ($null -ne $pass) { exit [int]$pass.exitCode }
        exit 0
    }
    'watch' {
        $state = Get-TbgState -Path $statePath -DefaultMode $Mode
        if (-not [bool]$state.enabled) { Write-Host 'The watcher did not start because the automatic toggle is off.'; exit 0 }
        Write-TbgJson -Path $watcherPath -Value ([pscustomobject][ordered]@{
            schema = 'TbgArtifactEngineWatcher.v1'
            pid = $PID
            startedUtc = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
            scriptPath = $PSCommandPath
            pollSeconds = $PollSeconds
        })
        try {
            while ($true) {
                $state = Get-TbgState -Path $statePath -DefaultMode $Mode
                if (-not [bool]$state.enabled) { break }
                $pass = Invoke-TbgPass -RepoRoot $repoRoot -Registry $registry -OutputRoot $outputRoot -StateMode ([string]$state.mode) -TriggerSource 'watcher_change_detection' -FingerprintPath $fingerprintPath -LockPath $lockPath -ExtraRoots @($state.additionalArtifactRoots) -WatchPass
                if ($null -ne $pass -and [int]$pass.exitCode -ne 0 -and [string]$state.mode -eq 'strict') {
                    Write-Warning 'The strict artifact watcher found a blocker. The watcher remains active so the operator can correct the source artifact.'
                }
                Start-Sleep -Seconds $PollSeconds
            }
        }
        finally {
            $currentWatcher = Get-TbgWatcher -Path $watcherPath
            if ($null -ne $currentWatcher -and [int]$currentWatcher.pid -eq $PID) { Remove-Item -LiteralPath $watcherPath -Force -ErrorAction SilentlyContinue }
        }
        Write-Host 'The local artifact watcher stopped because the automatic toggle is off.'
        exit 0
    }
}
