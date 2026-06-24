# F7 gate evidence harvest helpers — dot-sourced from run-f7-gate-continue.ps1 only.

function New-F7JsonSafeValue {
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) { return [long]$Value }
    if ($Value -is [string]) { return [string]$Value }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('o') }
    if ($Value -is [System.Collections.IDictionary]) {
        $safe = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $safe[[string]$key] = New-F7JsonSafeValue -Value $Value[$key]
        }
        return $safe
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { New-F7JsonSafeValue -Value $_ })
    }
    return [string]$Value
}

function Add-F7HarvestWarning {
    param(
        [System.Collections.Generic.List[string]]$Warnings,
        [string]$Message
    )
    if (-not $Warnings) { return }
    $Warnings.Add([string]$Message) | Out-Null
}

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
        name = [string]$DestName
        copied = $false
        sourcePath = [string]$SourcePath
        sizeBytes = $null
        lastWriteUtc = $null
        reason = $null
    }

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        $result.reason = 'not_present'
        return $result
    }

    try {
        $destPath = Join-Path $CheckpointDir $DestName
        Copy-Item -LiteralPath $SourcePath -Destination $destPath -Force
        $item = Get-Item -LiteralPath $destPath
        $result.copied = $true
        $result.sizeBytes = [long]$item.Length
        $result.lastWriteUtc = [string]$item.LastWriteTimeUtc.ToString('o')
    } catch {
        $result.reason = [string]$_.Exception.Message
    }

    return $result
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
        $filtered.Add([string]$line)
    }

    if ($filtered.Count -gt $MaxLines) {
        $filtered = $filtered.GetRange($filtered.Count - $MaxLines, $MaxLines)
    }

    if ($filtered.Count -gt 0) {
        $filtered | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        $lineCount = $filtered.Count
    }

    return [int]$lineCount
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
            return [int]@($raw).Count
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

    if (-not $TailLines -or $TailLines.Count -eq 0) {
        return [ordered]@{
            lastTraceMarker = $null
            lastMapReadyMarker = $null
            lastReadyMarker = $null
            lastPhase1Marker = $null
        }
    }

    foreach ($line in $TailLines) {
        $text = [string]$line
        if ($text -match '\[TBG TRACE\]') {
            $lastTrace = $text
            $lastPhase1 = $text
        }
        if ($text -match '\[TBG MAPREADY\]') {
            $lastMapReady = $text
            $lastPhase1 = $text
        }
        if (Test-Phase1ReadyLine -Line $text) {
            $lastReady = $text
            $lastPhase1 = $text
        }
    }

    if (-not $lastPhase1) {
        $lastPhase1 = [string]$TailLines[-1]
    }

    return [ordered]@{
        lastTraceMarker = if ($lastTrace) { [string]$lastTrace } else { $null }
        lastMapReadyMarker = if ($lastMapReady) { [string]$lastMapReady } else { $null }
        lastReadyMarker = if ($lastReady) { [string]$lastReady } else { $null }
        lastPhase1Marker = [string]$lastPhase1
    }
}

function Read-F7CrashContextSummary {
    param([string]$CrashContextPath)

    $empty = [ordered]@{
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
        return [ordered]@{
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
        queryError = $null
    }

    if (-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)) {
        return $result
    }

    try {
        $start = if ($StartUtc.Kind -eq [Globalization.DateTimeKind]::Unspecified) {
            [datetime]::SpecifyKind($StartUtc, [Globalization.DateTimeKind]::Utc)
        } else {
            $StartUtc.ToUniversalTime()
        }
        $end = if ($EndUtc.Kind -eq [Globalization.DateTimeKind]::Unspecified) {
            [datetime]::SpecifyKind($EndUtc, [Globalization.DateTimeKind]::Utc)
        } else {
            $EndUtc.ToUniversalTime()
        }

        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            ProviderName = 'Application Error'
            StartTime = $start
            EndTime = $end
        } -MaxEvents 20 -ErrorAction Stop

        $matched = New-Object System.Collections.Generic.List[object]
        foreach ($ev in $events) {
            $msg = [string]$ev.Message
            if ($msg -match 'Bannerlord|TaleWorlds') {
                $matched.Add([ordered]@{
                    timeCreatedUtc = [string]$ev.TimeCreated.ToUniversalTime().ToString('o')
                    id = [int]$ev.Id
                    message = $msg
                }) | Out-Null
            }
        }

        if ($matched.Count -eq 0) {
            $result.windowsCrashEventStatus = 'none_found'
            return $result
        }

        $destPath = Join-Path $CheckpointDir 'WindowsCrashEvents.json'
        @($matched) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $destPath -Encoding UTF8
        $result.windowsCrashEventStatus = 'copied'
        $result.windowsCrashEventCopied = $true
        $result.eventCount = [int]$matched.Count
    } catch {
        $result.windowsCrashEventStatus = 'query_failed'
        $result.queryError = [string]$_.Exception.Message
    }

    return $result
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
        [string]$PassFail,
        [bool]$HarvestFailed = $false,
        [bool]$HarvestPartial = $false
    )

    $required = @(
        [ordered]@{ name = 'manifest.json'; present = $true }
        [ordered]@{ name = 'Launch.tail.txt'; present = ([bool]($LaunchTailLineCount -gt 0)) }
        [ordered]@{ name = 'Phase1.tail.txt'; present = ([bool]($Phase1TailLineCount -gt 0)) }
    )

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($r in $required) {
        if (-not $r.present) { $missing.Add([string]$r.name) | Out-Null }
    }

    $instrumentationGap = $false
    if ($PassFail -eq 'FAIL' -and -not $HarvestFailed) {
        if ($LastPhase1Marker -match 'StatusFlush begin' -and -not $LastTraceMarker) {
            $instrumentationGap = $true
        }
        if ($Phase1TailLineCount -lt 50 -and $Phase1TailLineCount -gt 0) {
            $missing.Add('Phase1.tail.txt (sparse session filter)') | Out-Null
        }
    }

    $score = 'sufficient'
    if ($HarvestFailed) {
        $score = 'harvest_failed'
    } elseif ($missing.Count -gt 0 -or $instrumentationGap) {
        $score = if ($instrumentationGap) { 'insufficient' } else { 'partial' }
    } elseif ($HarvestPartial) {
        $score = 'partial'
    }

    return [ordered]@{
        score = [string]$score
        instrumentationGap = [bool]$instrumentationGap
        traceMarkersPresent = [bool]$LastTraceMarker
        missing = @($missing)
        required = $required
        harvestFailed = [bool]$HarvestFailed
        harvestPartial = [bool]$HarvestPartial
        crashContextOptional = $true
    }
}

function Get-F7AssistiveEvidenceCompleteness {
    param(
        [bool]$StatusJsonCopied,
        [bool]$AssistiveSessionCopied,
        [bool]$ProbeJsonCopied,
        [bool]$CrashContextCopied,
        [int]$Phase1TailLineCount,
        [int]$LaunchTailLineCount,
        [string]$PassFail,
        [bool]$LaunchUsed = $false,
        [bool]$HarvestFailed = $false,
        [bool]$HarvestPartial = $false
    )

    $requiredArr = @(
        [ordered]@{ name = 'manifest.json'; present = $true },
        [ordered]@{ name = 'BlacksmithGuild_Status.json'; present = $StatusJsonCopied },
        [ordered]@{ name = 'BlacksmithGuild_TownToTownTradeProbe.json'; present = $ProbeJsonCopied },
        [ordered]@{ name = 'Phase1.tail.txt'; present = ($Phase1TailLineCount -gt 0) }
    )
    if ($LaunchUsed) {
        $requiredArr += [ordered]@{ name = 'Launch.tail.txt'; present = ($LaunchTailLineCount -gt 0) }
    }

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($r in $requiredArr) {
        if (-not $r.present) { $missing.Add([string]$r.name) | Out-Null }
    }

    $score = 'sufficient'
    if ($HarvestFailed) {
        $score = 'harvest_failed'
    } elseif ($missing.Count -gt 0) {
        $score = 'partial'
    } elseif ($HarvestPartial) {
        $score = 'partial'
    }

    return [ordered]@{
        score = [string]$score
        instrumentationGap = $false
        traceMarkersPresent = $true
        missing = @($missing)
        required = $requiredArr
        harvestFailed = [bool]$HarvestFailed
        harvestPartial = [bool]$HarvestPartial
        crashContextOptional = $true
        launchUsed = [bool]$LaunchUsed
    }
}

function Test-F7AssistiveTownTradeCertPass {
    param(
        $Readiness,
        $ProbeJson,
        [bool]$ProbeAckOk = $false
    )

    if (-not $Readiness) { return $false }
    if (-not $Readiness.canPollFileInbox) { return $false }
    if (-not $Readiness.inGameAssistReady) { return $false }
    if (-not $Readiness.canAcceptAssistiveCommand) { return $false }
    if (-not $ProbeAckOk) { return $false }
    if (-not $ProbeJson) { return $false }
    if (-not $ProbeJson.currentSettlement) { return $false }
    if (-not $ProbeJson.recommendedNextTown) { return $false }
    if ($ProbeJson.fakeGameplayDelta -eq $true) { return $false }
    return $true
}

function Invoke-F7AssistiveEvidenceHarvest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CheckpointDir,
        [Parameter(Mandatory = $true)]
        [string]$BannerlordRoot,
        [datetime]$StartedAtUtc,
        [datetime]$SinceLocal,
        [string]$PassFail = 'FAIL',
        [bool]$LaunchUsed = $false,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [string]$CrashContextPath = $null,
        [string]$LaunchLogPath = $null,
        [string]$RunnerCommandLine = $null
    )

    if (-not (Test-Path -LiteralPath $CheckpointDir)) {
        New-Item -ItemType Directory -Force -Path $CheckpointDir | Out-Null
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    $artifactMeta = New-Object System.Collections.Generic.List[object]
    $phase1TailLineCount = 0
    $launchTailLineCount = 0
    $markers = @{ lastPhase1Marker = $null; lastTraceMarker = $null; lastMapReadyMarker = $null }

    if (-not $Phase1Path) { $Phase1Path = Get-Phase1LogPath -BannerlordRoot $BannerlordRoot }
    if (-not $StatusPath) { $StatusPath = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot }
    if (-not $CrashContextPath) { $CrashContextPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot }
    if (-not $LaunchLogPath) { $LaunchLogPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot }

    $statusArtifact = Copy-F7EvidenceArtifact -SourcePath $StatusPath `
        -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_Status.json'
    $artifactMeta.Add($statusArtifact) | Out-Null

    $assistPath = Get-AssistiveSessionJsonPath -BannerlordRoot $BannerlordRoot
    $assistArtifact = Copy-F7EvidenceArtifact -SourcePath $assistPath `
        -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_AssistiveSession.json'
    $artifactMeta.Add($assistArtifact) | Out-Null

    $probePath = Get-TownToTownTradeProbeJsonPath -BannerlordRoot $BannerlordRoot
    $probeArtifact = Copy-F7EvidenceArtifact -SourcePath $probePath `
        -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_TownToTownTradeProbe.json'
    $artifactMeta.Add($probeArtifact) | Out-Null

    $crashArtifact = [ordered]@{ name = 'BlacksmithGuild_CrashContext.json'; copied = $false; reason = 'not_present' }
    if ($CrashContextPath -and (Test-Path -LiteralPath $CrashContextPath)) {
        $crashArtifact = Copy-F7EvidenceArtifact -SourcePath $CrashContextPath `
            -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_CrashContext.json'
    }
    $artifactMeta.Add($crashArtifact) | Out-Null

    try {
        if (Test-Path -LiteralPath $Phase1Path) {
            $phase1TailPath = Join-Path $CheckpointDir 'Phase1.tail.txt'
            $phase1TailLineCount = Write-F7FilteredTimestampTail `
                -InputPath $Phase1Path -OutputPath $phase1TailPath -SinceLocal $SinceLocal -MaxLines 300
            if ($phase1TailLineCount -lt 50) {
                $phase1TailLineCount = Write-F7UnfilteredTail -InputPath $Phase1Path `
                    -OutputPath $phase1TailPath -MaxLines 300
            }
        }
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "phase1 tail: $($_.Exception.Message)"
    }

    if ($LaunchUsed) {
        try {
            if (Test-Path -LiteralPath $LaunchLogPath) {
                $launchTailLineCount = Write-F7FilteredTimestampTail `
                    -InputPath $LaunchLogPath `
                    -OutputPath (Join-Path $CheckpointDir 'Launch.tail.txt') `
                    -SinceLocal $SinceLocal -MaxLines 220
            }
        } catch {
            Add-F7HarvestWarning -Warnings $warnings -Message "launch tail: $($_.Exception.Message)"
        }
    }

    $timelinePath = Join-Path $CheckpointDir 'ExternalStateTimeline.json'
    $externalStateTimelineCopied = (Test-Path -LiteralPath $timelinePath)

    $harvestPartial = ($warnings.Count -gt 0) -or ($crashArtifact.copied -ne $true)
    $completeness = Get-F7AssistiveEvidenceCompleteness `
        -StatusJsonCopied ([bool]($statusArtifact.copied -eq $true)) `
        -AssistiveSessionCopied ([bool]($assistArtifact.copied -eq $true)) `
        -ProbeJsonCopied ([bool]($probeArtifact.copied -eq $true)) `
        -CrashContextCopied ([bool]($crashArtifact.copied -eq $true)) `
        -Phase1TailLineCount $phase1TailLineCount `
        -LaunchTailLineCount $launchTailLineCount `
        -PassFail $PassFail `
        -LaunchUsed $LaunchUsed `
        -HarvestPartial $harvestPartial

    return [ordered]@{
        evidenceCompleteness = $completeness
        statusJsonCopied = [bool]($statusArtifact.copied -eq $true)
        assistiveSessionCopied = [bool]($assistArtifact.copied -eq $true)
        probeJsonCopied = [bool]($probeArtifact.copied -eq $true)
        crashContextCopied = [bool]($crashArtifact.copied -eq $true)
        externalStateTimelineCopied = [bool]$externalStateTimelineCopied
        phase1TailLineCount = [int]$phase1TailLineCount
        launchTailLineCount = [int]$launchTailLineCount
        harvestPartial = [bool]$harvestPartial
        harvestWarnings = @($warnings)
        artifactMeta = @($artifactMeta | ForEach-Object { New-F7JsonSafeValue -Value $_ })
        runnerCommandLine = $RunnerCommandLine
    }
}

function Get-F7SafeArtifactFreshnessState {
    param(
        [string]$Path,
        [datetime]$CertStartedUtc
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return 'missing'
    }
    if (Get-Command Get-F7ArtifactFreshnessState -ErrorAction SilentlyContinue) {
        return [string](Get-F7ArtifactFreshnessState -Path $Path -CertStartedUtc $CertStartedUtc)
    }
    return 'unknown'
}

function Write-F7ArtifactsSidecar {
    param(
        [string]$CheckpointDir,
        [array]$ArtifactMeta,
        [int]$Phase1TailLineCount,
        [int]$LaunchTailLineCount
    )

    $safeArtifacts = @($ArtifactMeta | ForEach-Object { New-F7JsonSafeValue -Value $_ })
    $sidecar = [ordered]@{
        artifacts = $safeArtifacts
        phase1TailLineCount = [int]$Phase1TailLineCount
        launchTailLineCount = [int]$LaunchTailLineCount
    }
    $sidecar | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath (Join-Path $CheckpointDir 'artifacts.json') -Encoding UTF8
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

    $warnings = New-Object System.Collections.Generic.List[string]
    $artifactMeta = New-Object System.Collections.Generic.List[object]
    $phase1MaxLines = if ($PassFail -eq 'FAIL') { 300 } else { 220 }
    $phase1TailLineCount = 0
    $phase1FullTailLineCount = 0
    $launchTailLineCount = 0
    $markers = [ordered]@{
        lastTraceMarker = $null
        lastMapReadyMarker = $null
        lastReadyMarker = $null
        lastPhase1Marker = $null
    }
    $crashSummary = Read-F7CrashContextSummary -CrashContextPath $null
    $winEvent = [ordered]@{
        windowsCrashEventStatus = 'not_available'
        windowsCrashEventCopied = $false
        eventCount = 0
        queryError = $null
    }
    $statusArtifact = [ordered]@{ name = 'BlacksmithGuild_Status.json'; copied = $false; reason = 'not_attempted' }
    $crashArtifact = [ordered]@{ name = 'BlacksmithGuild_CrashContext.json'; copied = $false; reason = 'not_attempted' }
    $externalStateTimelineCopied = $false
    $crashPath = $null
    $statusSource = $null
    $harvestError = $null
    $completeness = $null

    try {
        $statusSource = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
        $statusArtifact = Copy-F7EvidenceArtifact -SourcePath $statusSource `
            -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_Status.json'
        if ($statusArtifact.copied) {
            $statusArtifact.freshness = Get-F7SafeArtifactFreshnessState -Path $statusSource -CertStartedUtc $StartedAtUtc
        }
        $artifactMeta.Add($statusArtifact) | Out-Null
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "status copy: $($_.Exception.Message)"
    }

    try {
        $crashPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot
        if ($crashPath -and (Test-Path -LiteralPath $crashPath)) {
            $crashArtifact = Copy-F7EvidenceArtifact -SourcePath $crashPath `
                -CheckpointDir $CheckpointDir -DestName 'BlacksmithGuild_CrashContext.json'
            if ($crashArtifact.copied) {
                $crashArtifact.freshness = Get-F7SafeArtifactFreshnessState -Path $crashPath -CertStartedUtc $StartedAtUtc
            }
        } else {
            $crashArtifact.reason = 'not_present'
            Add-F7HarvestWarning -Warnings $warnings -Message 'BlacksmithGuild_CrashContext.json not present (optional)'
        }
        $artifactMeta.Add($crashArtifact) | Out-Null
    } catch {
        $crashArtifact.reason = 'copy_error'
        Add-F7HarvestWarning -Warnings $warnings -Message "crash context copy: $($_.Exception.Message)"
        $artifactMeta.Add($crashArtifact) | Out-Null
    }

    try {
        if ($Phase1Path -and (Test-Path -LiteralPath $Phase1Path)) {
            $phase1TailPath = Join-Path $CheckpointDir 'Phase1.tail.txt'
            $phase1FullTailPath = Join-Path $CheckpointDir 'Phase1.full.tail.txt'
            $phase1TailLineCount = Write-F7FilteredTimestampTail `
                -InputPath $Phase1Path `
                -OutputPath $phase1TailPath `
                -SinceLocal $SinceLocal -MaxLines $phase1MaxLines
            if ($phase1TailLineCount -lt 50) {
                $phase1FullTailLineCount = Write-F7UnfilteredTail -InputPath $Phase1Path `
                    -OutputPath $phase1FullTailPath -MaxLines 300
                if ($phase1TailLineCount -eq 0 -and $phase1FullTailLineCount -gt 0) {
                    Copy-Item -LiteralPath $phase1FullTailPath -Destination $phase1TailPath -Force
                    $phase1TailLineCount = $phase1FullTailLineCount
                }
            }
        }
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "phase1 tail: $($_.Exception.Message)"
    }

    try {
        if ($LaunchLogPath -and (Test-Path -LiteralPath $LaunchLogPath)) {
            $launchTailLineCount = Write-F7FilteredTimestampTail `
                -InputPath $LaunchLogPath `
                -OutputPath (Join-Path $CheckpointDir 'Launch.tail.txt') `
                -SinceLocal $SinceLocal -MaxLines 220
        }
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "launch tail: $($_.Exception.Message)"
    }

    try {
        $phase1TailPath = Join-Path $CheckpointDir 'Phase1.tail.txt'
        if (Test-Path -LiteralPath $phase1TailPath) {
            $tailLines = @(Get-Content -LiteralPath $phase1TailPath -ErrorAction SilentlyContinue)
            $markers = Get-F7Phase1Markers -TailLines $tailLines
        }
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "marker scan: $($_.Exception.Message)"
    }

    try {
        if (-not $crashPath) {
            $crashPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot
        }
        if ($crashPath -and (Test-Path -LiteralPath $crashPath)) {
            $crashSummary = Read-F7CrashContextSummary -CrashContextPath $crashPath
        }
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "crash context parse: $($_.Exception.Message)"
    }

    try {
        $endUtc = (Get-Date).ToUniversalTime()
        $winEvent = Get-F7WindowsCrashEventSummary -StartUtc $StartedAtUtc -EndUtc $endUtc -CheckpointDir $CheckpointDir
    } catch {
        $winEvent = [ordered]@{
            windowsCrashEventStatus = 'query_failed'
            windowsCrashEventCopied = $false
            eventCount = 0
            queryError = [string]$_.Exception.Message
        }
        Add-F7HarvestWarning -Warnings $warnings -Message "windows events: $($_.Exception.Message)"
    }

    $copiedCount = 0
    foreach ($artifact in $artifactMeta) {
        if ($artifact -and $artifact.copied -eq $true) { $copiedCount++ }
    }
    if ($phase1TailLineCount -gt 0) { $copiedCount++ }
    if ($launchTailLineCount -gt 0) { $copiedCount++ }
    if ($winEvent.windowsCrashEventCopied -eq $true) { $copiedCount++ }

    $missingArtifacts = New-Object System.Collections.Generic.List[string]
    if ($statusArtifact.copied -ne $true) { $missingArtifacts.Add('BlacksmithGuild_Status.json') | Out-Null }
    if ($phase1TailLineCount -eq 0) { $missingArtifacts.Add('Phase1.tail.txt') | Out-Null }
    if ($launchTailLineCount -eq 0) { $missingArtifacts.Add('Launch.tail.txt') | Out-Null }

    $harvestPartial = ($warnings.Count -gt 0) -or ($crashArtifact.copied -ne $true)

    $completeness = Get-F7EvidenceCompleteness `
        -StatusJsonCopied ([bool]($statusArtifact.copied -eq $true)) `
        -CrashContextCopied ([bool]($crashArtifact.copied -eq $true)) `
        -WindowsCrashEventCopied ([bool]($winEvent.windowsCrashEventCopied -eq $true)) `
        -WindowsCrashEventStatus ([string]$winEvent.windowsCrashEventStatus) `
        -Phase1TailLineCount ([int]$phase1TailLineCount) `
        -LaunchTailLineCount ([int]$launchTailLineCount) `
        -LastTraceMarker ([string]$markers.lastTraceMarker) `
        -LastPhase1Marker ([string]$markers.lastPhase1Marker) `
        -PassFail ([string]$PassFail) `
        -HarvestPartial ([bool]$harvestPartial)

    try {
        Write-F7ArtifactsSidecar -CheckpointDir $CheckpointDir `
            -ArtifactMeta @($artifactMeta) `
            -Phase1TailLineCount ([int]$phase1TailLineCount) `
            -LaunchTailLineCount ([int]$launchTailLineCount)
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "artifacts sidecar: $($_.Exception.Message)"
        $harvestPartial = $true
    }

    $safeProcessTimestamps = New-F7JsonSafeValue -Value $ProcessTimestamps
    $safeArtifactMeta = @()
    foreach ($artifact in $artifactMeta) {
        $safeArtifactMeta += ,(New-F7JsonSafeValue -Value $artifact)
    }

    $phase1ArtifactState = 'unknown'
    $statusArtifactState = 'unknown'
    $crashArtifactState = 'missing'
    try {
        $phase1ArtifactState = Get-F7SafeArtifactFreshnessState -Path $Phase1Path -CertStartedUtc $StartedAtUtc
        if (-not $statusSource) {
            $statusSource = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
        }
        $statusArtifactState = Get-F7SafeArtifactFreshnessState -Path $statusSource -CertStartedUtc $StartedAtUtc
        if ($crashPath -and (Test-Path -LiteralPath $crashPath)) {
            $crashArtifactState = Get-F7SafeArtifactFreshnessState -Path $crashPath -CertStartedUtc $StartedAtUtc
        }
    } catch {
        Add-F7HarvestWarning -Warnings $warnings -Message "artifact freshness: $($_.Exception.Message)"
        $harvestPartial = $true
    }

    $timelinePath = Join-Path $CheckpointDir 'ExternalStateTimeline.json'
    if (Test-Path -LiteralPath $timelinePath) {
        $externalStateTimelineCopied = $true
        $artifactMeta.Add([ordered]@{
            name = 'ExternalStateTimeline.json'
            copied = $true
            reason = 'written_by_runner'
        }) | Out-Null
    }

    return [ordered]@{
        evidenceCompleteness = $completeness
        harvestError = if ($harvestError) { [string]$harvestError } else { $null }
        lastPhase1Marker = [string]$markers.lastPhase1Marker
        lastTraceMarker = if ($markers.lastTraceMarker) { [string]$markers.lastTraceMarker } else { $null }
        lastMapReadyMarker = if ($markers.lastMapReadyMarker) { [string]$markers.lastMapReadyMarker } else { $null }
        lastCrashContextOperation = if ($crashSummary.operation) { [string]$crashSummary.operation } else { $null }
        lastCrashContextStage = if ($crashSummary.stage) { [string]$crashSummary.stage } else { $null }
        lastCrashContextArea = if ($crashSummary.area) { [string]$crashSummary.area } else { $null }
        statusJsonCopied = [bool]($statusArtifact.copied -eq $true)
        externalStateTimelineCopied = [bool]$externalStateTimelineCopied
        crashContextCopied = [bool]($crashArtifact.copied -eq $true)
        windowsCrashEventCopied = [bool]($winEvent.windowsCrashEventCopied -eq $true)
        windowsCrashEventStatus = [string]$winEvent.windowsCrashEventStatus
        phase1TailLineCount = [int]$phase1TailLineCount
        launchTailLineCount = [int]$launchTailLineCount
        runnerCommandLine = if ($RunnerCommandLine) { [string]$RunnerCommandLine } else { $null }
        hookMask = if ($HookMask) { [string]$HookMask } else { $null }
        processTimestamps = $safeProcessTimestamps
        artifactMeta = $safeArtifactMeta
        copiedArtifactCount = [int]$copiedCount
        missingArtifacts = @($missingArtifacts)
        gamePhaseAtEnd = if ($GamePhaseAtEnd) { [string]$GamePhaseAtEnd } else { $null }
        instrumentationGap = [bool]$completeness.instrumentationGap
        harvestPartial = [bool]$harvestPartial
        harvestWarnings = @($warnings)
        phase1ArtifactState = [string]$phase1ArtifactState
        statusArtifactState = [string]$statusArtifactState
        crashContextArtifactState = [string]$crashArtifactState
    }
}
