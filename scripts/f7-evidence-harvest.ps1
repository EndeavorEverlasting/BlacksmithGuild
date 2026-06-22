# F7 gate evidence harvest helpers — dot-sourced from run-f7-gate-continue.ps1 only.

function Copy-F7EvidenceArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$CheckpointDir,
        [Parameter(Mandatory = $true)]
        [string]$DestName
    )

    $result = [ordered]@{
        name = $DestName
        copied = $false
        sourcePath = $SourcePath
        sizeBytes = $null
        lastWriteUtc = $null
        reason = $null
    }

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        $result.reason = 'not_present'
        return [pscustomobject]$result
    }

    try {
        $destPath = Join-Path $CheckpointDir $DestName
        Copy-Item -LiteralPath $SourcePath -Destination $destPath -Force
        $item = Get-Item -LiteralPath $destPath
        $result.copied = $true
        $result.sizeBytes = [long]$item.Length
        $result.lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
    } catch {
        $result.reason = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Write-F7FilteredTimestampTail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceLocal,
        [int]$MaxLines = 220
    )

    $lineCount = 0
    try {
        $raw = Get-Content -LiteralPath $InputPath -Tail 4000 -ErrorAction Stop
    } catch {
        return 0
    }

    $filtered = New-Object System.Collections.Generic.List[string]
    foreach ($line in $raw) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { continue }
        $lineTime = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($lineTime -lt $SinceLocal) { continue }
        $filtered.Add($line)
    }

    if ($filtered.Count -gt $MaxLines) {
        $filtered = $filtered.GetRange($filtered.Count - $MaxLines, $MaxLines)
    }

    if ($filtered.Count -gt 0) {
        $filtered | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        $lineCount = $filtered.Count
    }

    return $lineCount
}

function Write-F7UnfilteredTail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [int]$MaxLines = 300
    )

    try {
        $raw = Get-Content -LiteralPath $InputPath -Tail $MaxLines -ErrorAction Stop
        if ($raw) {
            $raw | Set-Content -LiteralPath $OutputPath -Encoding UTF8
            return @($raw).Count
        }
    } catch { }
    return 0
}

function Get-F7Phase1Markers {
    param([string[]]$TailLines)

    $lastTrace = $null
    $lastMapReady = $null
    $lastReady = $null
    $lastPhase1 = $null

    if (-not $TailLines) {
        return [pscustomobject]@{
            lastTraceMarker = $null
            lastMapReadyMarker = $null
            lastReadyMarker = $null
            lastPhase1Marker = $null
        }
    }

    foreach ($line in $TailLines) {
        if ($line -match '\[TBG TRACE\]') {
            $lastTrace = $line
            $lastPhase1 = $line
        }
        if ($line -match '\[TBG MAPREADY\]') {
            $lastMapReady = $line
            $lastPhase1 = $line
        }
        if (Test-Phase1ReadyLine -Line $line) {
            $lastReady = $line
            $lastPhase1 = $line
        }
    }

    if (-not $lastPhase1) {
        $lastPhase1 = $TailLines[-1]
    }

    return [pscustomobject]@{
        lastTraceMarker = $lastTrace
        lastMapReadyMarker = $lastMapReady
        lastReadyMarker = $lastReady
        lastPhase1Marker = $lastPhase1
    }
}

function Read-F7CrashContextSummary {
    param([string]$CrashContextPath)

    $empty = [pscustomobject]@{
        operation = $null
        stage = $null
        area = $null
        lastBegin = $null
        lastSuccess = $null
        lastException = $null
        sequence = $null
        present = $false
    }

    if (-not $CrashContextPath -or -not (Test-Path -LiteralPath $CrashContextPath)) {
        return $empty
    }

    try {
        $ctx = Get-Content -LiteralPath $CrashContextPath -Raw | ConvertFrom-Json
        return [pscustomobject]@{
            operation = if ($ctx.operation) { [string]$ctx.operation } else { $null }
            stage = if ($ctx.stage) { [string]$ctx.stage } else { $null }
            area = if ($ctx.area) { [string]$ctx.area } else { $null }
            lastBegin = if ($ctx.lastBegin) { [string]$ctx.lastBegin } else { $null }
            lastSuccess = if ($ctx.lastSuccess) { [string]$ctx.lastSuccess } else { $null }
            lastException = if ($ctx.lastException) { [string]$ctx.lastException } else { $null }
            sequence = if ($null -ne $ctx.sequence) { [int]$ctx.sequence } else { $null }
            present = $true
        }
    } catch {
        return $empty
    }
}

function Get-F7WindowsCrashEventSummary {
    param(
        [datetime]$StartUtc,
        [datetime]$EndUtc,
        [string]$CheckpointDir
    )

    $result = [ordered]@{
        windowsCrashEventStatus = 'not_available'
        windowsCrashEventCopied = $false
        eventCount = 0
    }

    if (-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)) {
        $result.windowsCrashEventStatus = 'not_available'
        return [pscustomobject]$result
    }

    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            ProviderName = 'Application Error'
            StartTime = $StartUtc
            EndTime = $EndUtc
        } -MaxEvents 20 -ErrorAction Stop

        $matched = @()
        foreach ($ev in $events) {
            $msg = $ev.Message
            if ($msg -match 'Bannerlord|TaleWorlds') {
                $matched += [ordered]@{
                    timeCreatedUtc = $ev.TimeCreated.ToUniversalTime().ToString('o')
                    id = $ev.Id
                    message = $msg
                }
            }
        }

        if ($matched.Count -eq 0) {
            $result.windowsCrashEventStatus = 'none_found'
            return [pscustomobject]$result
        }

        $destPath = Join-Path $CheckpointDir 'WindowsCrashEvents.json'
        $matched | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $destPath -Encoding UTF8
        $result.windowsCrashEventStatus = 'copied'
        $result.windowsCrashEventCopied = $true
        $result.eventCount = $matched.Count
    } catch {
        $result.windowsCrashEventStatus = 'query_failed'
        $result.queryError = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Get-F7EvidenceCompleteness {
    param(
        [bool]$StatusJsonCopied,
        [bool]$CrashContextCopied,
        [bool]$WindowsCrashEventCopied,
        [string]$WindowsCrashEventStatus,
        [int]$Phase1TailLineCount,
        [int]$LaunchTailLineCount,
        [string]$LastTraceMarker,
        [string]$LastPhase1Marker,
        [string]$PassFail
    )

    $required = @(
        @{ name = 'manifest.json'; present = $true }
        @{ name = 'Launch.tail.txt'; present = ($LaunchTailLineCount -gt 0) }
        @{ name = 'Phase1.tail.txt'; present = ($Phase1TailLineCount -gt 0) }
    )

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($r in $required) {
        if (-not $r.present) { $missing.Add([string]$r.name) | Out-Null }
    }

    $instrumentationGap = $false
    if ($PassFail -eq 'FAIL') {
        if ($LastPhase1Marker -match 'StatusFlush begin' -and -not $LastTraceMarker) {
            $instrumentationGap = $true
        }
        if ($LastPhase1Marker -match '\[TBG MAPREADY\]' -and -not $LastTraceMarker -and $LastPhase1Marker -notmatch 'immediate hooks complete|TBG READY') {
            $instrumentationGap = $true
        }
        if ($Phase1TailLineCount -lt 50 -and $Phase1TailLineCount -gt 0) {
            $missing.Add('Phase1.tail.txt (sparse session filter)') | Out-Null
        }
    }

    $score = 'sufficient'
    if ($missing.Count -gt 0 -or $instrumentationGap) {
        $score = if ($instrumentationGap) { 'insufficient' } else { 'partial' }
    }

    return [ordered]@{
        score = $score
        instrumentationGap = $instrumentationGap
        traceMarkersPresent = [bool]$LastTraceMarker
        missing = @($missing)
        required = $required
    }
}

function Invoke-F7EvidenceHarvest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CheckpointDir,
        [Parameter(Mandatory = $true)]
        [string]$BannerlordRoot,
        [Parameter(Mandatory = $true)]
        [datetime]$SinceLocal,
        [Parameter(Mandatory = $true)]
        [datetime]$StartedAtUtc,
        [Parameter(Mandatory = $true)]
        [string]$PassFail,
        [string]$Phase1Path,
        [string]$LaunchLogPath,
        [string]$RunnerCommandLine,
        [string]$HookMask,
        $ProcessTimestamps,
        [string]$GamePhaseAtEnd
    )

    $artifactMeta = New-Object System.Collections.Generic.List[object]
    $phase1MaxLines = if ($PassFail -eq 'FAIL') { 300 } else { 220 }

    $statusArtifact = Copy-F7EvidenceArtifact -SourcePath (Get-StatusJsonPath -BannerlordRoot $BannerlordRoot) `
        -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_Status.json'
    $artifactMeta.Add($statusArtifact) | Out-Null

    $crashPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot
    $crashArtifact = Copy-F7EvidenceArtifact -SourcePath $crashPath `
        -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_CrashContext.json'
    $artifactMeta.Add($crashArtifact) | Out-Null

    $phase1TailLineCount = 0
    $launchTailLineCount = 0
    if ($Phase1Path -and (Test-Path -LiteralPath $Phase1Path)) {
        $phase1TailLineCount = Write-F7FilteredTimestampTail `
            -InputPath $Phase1Path `
            -OutputPath (Join-Path $CheckpointDir 'Phase1.tail.txt') `
            -SinceLocal $SinceLocal -MaxLines $phase1MaxLines
        if ($phase1TailLineCount -lt 50) {
            Write-F7UnfilteredTail -InputPath $Phase1Path `
                -OutputPath (Join-Path $CheckpointDir 'Phase1.full.tail.txt') -MaxLines 300 | Out-Null
        }
    }
    if ($LaunchLogPath -and (Test-Path -LiteralPath $LaunchLogPath)) {
        $launchTailLineCount = Write-F7FilteredTimestampTail `
            -InputPath $LaunchLogPath `
            -OutputPath (Join-Path $CheckpointDir 'Launch.tail.txt') `
            -SinceLocal $SinceLocal -MaxLines 220
    }

    $tailLines = @()
    $phase1TailPath = Join-Path $CheckpointDir 'Phase1.tail.txt'
    if (Test-Path -LiteralPath $phase1TailPath) {
        $tailLines = @(Get-Content -LiteralPath $phase1TailPath -ErrorAction SilentlyContinue)
    }
    $markers = Get-F7Phase1Markers -TailLines $tailLines

    $crashSummary = Read-F7CrashContextSummary -CrashContextPath $crashPath
    $endUtc = (Get-Date).ToUniversalTime()
    $winEvent = Get-F7WindowsCrashEventSummary -StartUtc $StartedAtUtc -EndUtc $endUtc -CheckpointDir $CheckpointDir

    $copiedCount = @($artifactMeta | Where-Object { $_.copied }).Count
    if ($phase1TailLineCount -gt 0) { $copiedCount++ }
    if ($launchTailLineCount -gt 0) { $copiedCount++ }
    if ($winEvent.windowsCrashEventCopied) { $copiedCount++ }

    $missingArtifacts = New-Object System.Collections.Generic.List[string]
    if (-not $statusArtifact.copied) { $missingArtifacts.Add('BlacksmithGuild_Status.json') | Out-Null }
    if (-not $crashArtifact.copied) { $missingArtifacts.Add('BlacksmithGuild_CrashContext.json') | Out-Null }
    if ($phase1TailLineCount -eq 0) { $missingArtifacts.Add('Phase1.tail.txt') | Out-Null }
    if ($launchTailLineCount -eq 0) { $missingArtifacts.Add('Launch.tail.txt') | Out-Null }

    $completeness = Get-F7EvidenceCompleteness `
        -StatusJsonCopied $statusArtifact.copied `
        -CrashContextCopied $crashArtifact.copied `
        -WindowsCrashEventCopied $winEvent.windowsCrashEventCopied `
        -WindowsCrashEventStatus $winEvent.windowsCrashEventStatus `
        -Phase1TailLineCount $phase1TailLineCount `
        -LaunchTailLineCount $launchTailLineCount `
        -LastTraceMarker $markers.lastTraceMarker `
        -LastPhase1Marker $markers.lastPhase1Marker `
        -PassFail $PassFail

    $artifactsSidecar = [ordered]@{
        artifacts = @($artifactMeta)
        phase1TailLineCount = $phase1TailLineCount
        launchTailLineCount = $launchTailLineCount
    }
    $artifactsSidecar | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $CheckpointDir 'artifacts.json') -Encoding UTF8

    return [ordered]@{
        evidenceCompleteness = $completeness
        lastPhase1Marker = $markers.lastPhase1Marker
        lastTraceMarker = $markers.lastTraceMarker
        lastMapReadyMarker = $markers.lastMapReadyMarker
        lastCrashContextOperation = $crashSummary.operation
        lastCrashContextStage = $crashSummary.stage
        lastCrashContextArea = $crashSummary.area
        statusJsonCopied = [bool]$statusArtifact.copied
        crashContextCopied = [bool]$crashArtifact.copied
        windowsCrashEventCopied = [bool]$winEvent.windowsCrashEventCopied
        windowsCrashEventStatus = $winEvent.windowsCrashEventStatus
        phase1TailLineCount = $phase1TailLineCount
        launchTailLineCount = $launchTailLineCount
        runnerCommandLine = $RunnerCommandLine
        processTimestamps = $ProcessTimestamps
        artifactMeta = @($artifactMeta)
        copiedArtifactCount = $copiedCount
        missingArtifacts = @($missingArtifacts)
        gamePhaseAtEnd = $GamePhaseAtEnd
        instrumentationGap = [bool]$completeness.instrumentationGap
    }
}
