param(
    [string]$ExpectedHead,
    [string]$SavePath,
    [int]$AttachTimeoutSec = 600,
    [int]$TradeTimeoutSec = 1200,
    [int]$AuthorityTimeoutSec = 60,
    [int]$PollIntervalMs = 500,
    [string]$EvidenceRoot,
    [switch]$Diagnostic,
    [switch]$SkipBuild,
    [switch]$SkipLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'visible-trade-cycle-contract.ps1')
. (Join-Path $PSScriptRoot 'visible-trade-launch-boundary.ps1')

if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $repoRoot 'artifacts\latest'
}
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null

$resultPath = Join-Path $EvidenceRoot 'visible-trade-cycle.result.json'
$reportPath = Join-Path $EvidenceRoot 'visible-trade-cycle.report.md'
$requestCopyPath = Join-Path $EvidenceRoot 'visible-trade-cycle.request.json'
$runId = 'visible-trade-' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')
$startedAtUtc = (Get-Date).ToUniversalTime()
$diagnosticOnly = $Diagnostic -or $SkipBuild -or $SkipLaunch
$certifyingMode = -not $diagnosticOnly

function Write-AtomicUtf8Json {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 40
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temp = "$Path.$PID.tmp"
    $json = $Value | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Write-AtomicUtf8Text {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temp = "$Path.$PID.tmp"
    [System.IO.File]::WriteAllText($temp, $Value, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Read-JsonSafe {
    param([Parameter(Mandatory = $true)][string]$Path)

    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if (Test-Path -LiteralPath $Path) {
                return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            }
        } catch {
            Start-Sleep -Milliseconds (75 * $attempt)
        }
    }
    return $null
}

function Get-BannerlordRelatedProcesses {
    $names = @('Bannerlord', 'Bannerlord.Native', 'TaleWorlds.MountAndBlade', 'TaleWorlds.MountAndBlade.Launcher')
    $items = @()
    foreach ($name in $names) {
        $items += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }
    return @($items | Sort-Object Id -Unique)
}

function Get-TbgBannerlordRuntimeDetection {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][datetime]$LaunchStartedAtUtc
    )

    return Get-BannerlordProcessDetection `
        -BannerlordRoot $BannerlordRoot `
        -Phase1Path (Get-Phase1LogPath -BannerlordRoot $BannerlordRoot) `
        -StatusPath (Get-StatusJsonPath -BannerlordRoot $BannerlordRoot) `
        -CrashContextPath (Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot) `
        -LaunchStartedAtUtc $LaunchStartedAtUtc `
        -CacheSec 0
}

function Test-TbgLiveRuntimeDetection {
    param($Detection)

    if ($null -eq $Detection -or $null -eq $Detection.gameProcessPid) { return $false }
    $process = Get-Process -Id ([int]$Detection.gameProcessPid) -ErrorAction SilentlyContinue
    if ($process) { try { $process.Refresh() } catch { } }
    return Test-TbgLiveRuntimeAuthorityFacts `
        -Confidence ([string]$Detection.gameAliveConfidence) `
        -ProcessId ([int]$Detection.gameProcessPid) `
        -ProcessExists ($null -ne $process) `
        -WindowTitle $(if ($process) { [string]$process.MainWindowTitle } else { '' })
}

function Stop-TbgOwnedLauncherAfterFailedSpawn {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][datetime]$LaunchStartedAtUtc
    )

    $contextPath = Join-Path $BannerlordRoot 'launcher-window-context.json'
    $context = Read-JsonSafe -Path $contextPath
    if ($null -eq $context) { return @() }
    $expectedBaselinePath = Join-Path $BannerlordRoot 'window-snapshot-S1-pre-launch.json'
    if (-not [string]::Equals([string]$context.baselineSnapshotPath, $expectedBaselinePath, [System.StringComparison]::OrdinalIgnoreCase)) { return @() }
    $baseline = Read-JsonSafe -Path $expectedBaselinePath
    if ($null -eq $baseline) { return @() }
    $launcherPid = [int]$context.processId
    $launcher = Get-Process -Id $launcherPid -ErrorAction SilentlyContinue
    if (-not $launcher) { return @() }
    try { $launcher.Refresh() } catch { return @() }

    $lastDetection = Get-TbgBannerlordRuntimeDetection -BannerlordRoot $BannerlordRoot -LaunchStartedAtUtc $LaunchStartedAtUtc
    $runtimeLive = Test-TbgLiveRuntimeDetection -Detection $lastDetection
    $processFacts = [PSCustomObject][ordered]@{
        pid = [int]$launcher.Id
        hwnd = [int64]$launcher.MainWindowHandle
        name = [string]$launcher.ProcessName
        path = Get-ProcessExecutablePathSafe -Process $launcher
        windowTitle = [string]$launcher.MainWindowTitle
        startedAtUtc = $launcher.StartTime.ToUniversalTime().ToString('o')
    }
    $decision = Test-TbgOwnedLauncherCleanupFacts `
        -Context $context `
        -Baseline $baseline `
        -Process $processFacts `
        -BannerlordRoot $BannerlordRoot `
        -LaunchStartedAtUtc $LaunchStartedAtUtc `
        -RuntimeLive $runtimeLive
    if (-not $decision.eligible) { return @() }

    $launcher = Get-Process -Id $launcherPid -ErrorAction SilentlyContinue
    if (-not $launcher) { return @() }
    try { $launcher.Refresh() } catch { return @() }
    if (Test-LauncherSingleplayerHostedTitle -Title ([string]$launcher.MainWindowTitle)) { return @() }
    if ([int64]$launcher.MainWindowHandle -ne [int64]$context.hwnd) { return @() }
    $expectedPath = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe'
    if (-not [string]::Equals((Get-ProcessExecutablePathSafe -Process $launcher), $expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) { return @() }
    $lastDetection = Get-TbgBannerlordRuntimeDetection -BannerlordRoot $BannerlordRoot -LaunchStartedAtUtc $LaunchStartedAtUtc
    if (Test-TbgLiveRuntimeDetection -Detection $lastDetection) { return @() }

    Stop-Process -Id $launcherPid -Force -ErrorAction Stop
    Wait-Process -Id $launcherPid -Timeout 10 -ErrorAction SilentlyContinue
    return @($launcherPid)
}

function Wait-TbgJsonEvidence {
    param(
        [Parameter(Mandatory = $true)][string[]]$Candidates,
        [Parameter(Mandatory = $true)][datetime]$NotBeforeUtc,
        [Parameter(Mandatory = $true)][scriptblock]$Accept,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        foreach ($candidate in $Candidates) {
            if (-not (Test-Path -LiteralPath $candidate)) {
                continue
            }
            $item = Get-Item -LiteralPath $candidate
            if ($item.LastWriteTimeUtc -lt $NotBeforeUtc) {
                continue
            }
            $value = Read-JsonSafe -Path $candidate
            if ($null -ne $value -and (& $Accept $value)) {
                return [PSCustomObject]@{
                    Path = $candidate
                    Value = $value
                    LastWriteTimeUtc = $item.LastWriteTimeUtc
                    Sha256 = Get-TbgFileSha256 -LiteralPath $candidate
                }
            }
        }
        Start-Sleep -Milliseconds ([Math]::Max(250, $PollIntervalMs))
    } while ((Get-Date) -lt $deadline)

    throw "${Label}_timeout after ${TimeoutSec}s"
}

function Invoke-ForgeCommandChecked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [int]$TimeoutSec = 45
    )

    if (-not $script:ownsLaunchedSession -or $script:diagnosticOnly) {
        throw "command_authority_denied:$Command"
    }
    & (Join-Path $repoRoot 'forge.ps1') -Command $Command -Wait -TimeoutSec $TimeoutSec
    if ($LASTEXITCODE -ne 0) {
        throw "command_failed:$Command exit=$LASTEXITCODE"
    }
}

function Find-ExplicitDevSave {
    param([string]$RequestedPath)

    $docsRoot = Get-BannerlordDocsRoot
    $saveRoots = @(Get-BannerlordExistingGameSaveRoots -DocsRoot $docsRoot)
    if ($saveRoots.Count -eq 0) {
        throw "BLOCKED_save_identity:save_roots_missing:$(@(Get-BannerlordGameSaveRoots -DocsRoot $docsRoot) -join ',')"
    }

    $candidate = $null
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = Resolve-Path -LiteralPath $RequestedPath -ErrorAction Stop
        $candidate = Get-Item -LiteralPath $resolved.Path
    } else {
        $candidate = Get-BannerlordDevSaveCandidates -DocsRoot $docsRoot | Select-Object -First 1
    }

    if ($null -eq $candidate -or -not (Test-BannerlordDevSaveName -Name $candidate.Name)) {
        throw 'BLOCKED_save_identity:no_explicit_BlacksmithGuildDevStart_save'
    }
    if (-not (Test-BannerlordRecognizedSavePath -Path $candidate.FullName -DocsRoot $docsRoot)) {
        throw "BLOCKED_save_identity:save_outside_recognized_root:$($candidate.FullName)"
    }
    return $candidate
}

function New-EvidenceReference {
    param($Record)
    if ($null -eq $Record) { return $null }
    return [ordered]@{
        path = $Record.Path
        lastWriteTimeUtc = $Record.LastWriteTimeUtc.ToString('o')
        sha256 = $Record.Sha256
    }
}

function Get-FailureTerminalState {
    param([string]$Detail)
    if ([string]::IsNullOrWhiteSpace($Detail)) { return 'FAILED_runtime' }
    $prefix = ($Detail -split '[: ]')[0]
    if ($prefix -match '^(BLOCKED|FAILED|ABORTED)_') { return $prefix }
    return 'FAILED_runtime'
}

function Write-EnglishReport {
    param($Result)

    $requestedSaveLabel = if ([string]::IsNullOrWhiteSpace([string]$Result.request.requestedSaveId)) {
        'not selected before the run stopped'
    } else {
        [string]$Result.request.requestedSaveId
    }
    $saveSentence = if ($Result.evidenceSummary.saveIdentityVerified) {
        "The runtime proved that Bannerlord loaded the requested save **$requestedSaveLabel** by matching MBSaveLoad.ActiveSaveSlotName to the pinned request."
    } else {
        "The runtime did not prove that Bannerlord loaded the pinned save (**$requestedSaveLabel**)."
    }
    $tradeSentence = if ($Result.evidenceSummary.realBuyDelta) {
        "Bannerlord recorded a real buy: gold changed by $($Result.evidenceSummary.goldDelta), inventory changed by $($Result.evidenceSummary.inventoryDelta), and the runtime marked the delta as non-fake."
    } else {
        'No certifiable real buy delta was established for this run.'
    }
    $surfaceSentence = if ($Result.evidenceSummary.tradeSurfaceVisible) {
        "The runtime reported the $($Result.evidenceSummary.tradeSurface) surface as visibly open at $($Result.evidenceSummary.arrivedSettlement)."
    } else {
        'The run did not establish that an Inventory or Trade surface was visibly open for the user.'
    }
    $cleanupSentence = if ($Result.evidenceSummary.manualCleanupProven) {
        'After the terminal observation, a fresh authority snapshot proved that MapTrade returned to Manual while every other engine retained its baseline mode.'
    } else {
        'A command acknowledgement alone was not accepted as cleanup; fresh Manual authority evidence is absent or invalid.'
    }

    $body = @"
# TBG visible trade cycle

This run ended as **$($Result.terminalState)** on branch **$($Result.branch)** at commit **$($Result.headSha)**. Its machine-readable result is **visible-trade-cycle.result.json**, and both files are overwritten on the next run so routine evidence stays bounded.

$saveSentence

$tradeSentence $surfaceSentence

$cleanupSentence

The runner used only Bannerlord's native Continue path and the MapTrade command surface. It did not grant gold, inventory, movement, or any other gameplay outcome. A diagnostic or skip-mode observation can never become a PASS.

"@
    Write-AtomicUtf8Text -Value $body -Path $reportPath
}

$branch = (git branch --show-current).Trim()
$head = (git rev-parse HEAD).Trim()
$status = @(git status --porcelain)
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$docsRoot = Get-BannerlordDocsRoot
$requestPath = Join-Path $bannerlordRoot 'BlacksmithGuild_VisibleTradeCycleRequest.json'
$saveIdentityCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_SaveIdentity.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_SaveIdentity.json')
)
$authorityCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_EngineToggleAuthority.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_EngineToggleAuthority.json')
)
$runtimeCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_VisibleTradeCycle.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_VisibleTradeCycle.json')
)
$routeCertCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_MapTradeRouteCert.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_MapTradeRouteCert.json')
)
$tradeCertCandidates = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_MapTradeCert.json'),
    (Join-Path $docsRoot 'BlacksmithGuild_MapTradeCert.json')
)
$localDllPath = Join-Path $repoRoot 'Module\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'
$installedDllPath = Join-Path $bannerlordRoot 'Modules\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'

$script:ownsLaunchedSession = $false
$script:mapTradeAutomationAttempted = $false
$launchAttemptUtc = $null
$runtimeDetection = $null
$saveIdentityRecord = $null
$authorityBeforeRecord = $null
$authorityAutomationRecord = $null
$runtimeRecord = $null
$authorityManualRecord = $null
$routeCertRecord = $null
$tradeCertRecord = $null
$request = $null
$selectedSave = $null
$localDllHash = $null
$installedDllHash = $null
$failureDetail = $null
$evaluation = $null
$preflightChecks = [ordered]@{
    certifyingMode = $certifyingMode
    expectedHeadProvided = $false
    exactCommittedHead = $false
    cleanWorktree = $false
    noPreexistingBannerlord = $false
    explicitDevSavePinned = $false
    releaseBuildInstalled = $false
    installedDllHashMatches = $false
    nativeContinueLaunched = $false
    gameRuntimeObserved = $false
    ownedLauncherCleanedAfterFailedSpawn = $false
    standardRouteCertFresh = $false
    standardTradeCertFresh = $false
}

try {
    if ($diagnosticOnly) {
        throw 'DIAGNOSTIC_ONLY:skip and diagnostic modes never launch, command, or certify a session'
    }
    if ([string]::IsNullOrWhiteSpace($ExpectedHead)) {
        throw 'FAILED_preflight:ExpectedHead is mandatory for certifying mode'
    }
    $preflightChecks.expectedHeadProvided = $true
    if ($ExpectedHead -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'FAILED_preflight:ExpectedHead must be a full 40-character commit SHA'
    }
    if (-not [string]::Equals($head, $ExpectedHead, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "FAILED_preflight:wrong_head expected=$ExpectedHead actual=$head"
    }
    & git cat-file -e "$ExpectedHead`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "FAILED_preflight:uncommitted_head:$ExpectedHead" }
    $preflightChecks.exactCommittedHead = $true

    if ($status.Count -gt 0) {
        throw "FAILED_preflight:dirty_worktree:$($status -join '; ')"
    }
    $preflightChecks.cleanWorktree = $true

    $preexisting = @(Get-BannerlordRelatedProcesses)
    if ($preexisting.Count -gt 0) {
        throw "FAILED_preflight:preexisting_bannerlord_process:$(@($preexisting.Id) -join ',')"
    }
    $preflightChecks.noPreexistingBannerlord = $true

    $selectedSave = Find-ExplicitDevSave -RequestedPath $SavePath
    $requestedSaveId = [System.IO.Path]::GetFileNameWithoutExtension($selectedSave.Name)
    $saveHash = Get-TbgFileSha256 -LiteralPath $selectedSave.FullName
    $selectedSave.LastWriteTimeUtc = (Get-Date).ToUniversalTime()
    $selectedSave.LastAccessTimeUtc = $selectedSave.LastWriteTimeUtc
    $preflightChecks.explicitDevSavePinned = $true

    $request = [ordered]@{
        schemaVersion = 'TbgVisibleTradeCycleRequest.v1'
        runId = $runId
        correlationId = $runId
        requestedSaveId = $requestedSaveId
        requestedSaveFileName = $selectedSave.Name
        requestedSaveSha256AtStart = $saveHash
        requestedSaveLengthAtStart = $selectedSave.Length
        headSha = $head
        branch = $branch
        createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        certifyingMode = $true
    }
    Write-AtomicUtf8Json -Value $request -Path $requestPath
    Write-AtomicUtf8Json -Value $request -Path $requestCopyPath

    & dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') --configuration Release
    if ($LASTEXITCODE -ne 0) { throw "FAILED_preflight:release_build_failed exit=$LASTEXITCODE" }
    if (@(Get-BannerlordRelatedProcesses).Count -gt 0) { throw 'FAILED_preflight:bannerlord_started_during_build' }
    & (Join-Path $PSScriptRoot 'install-mod.ps1')
    if ($LASTEXITCODE -ne 0) { throw "FAILED_preflight:install_failed exit=$LASTEXITCODE" }
    $preflightChecks.releaseBuildInstalled = $true

    if (-not (Test-Path -LiteralPath $localDllPath)) { throw "FAILED_preflight:local_dll_missing:$localDllPath" }
    if (-not (Test-Path -LiteralPath $installedDllPath)) { throw "FAILED_preflight:installed_dll_missing:$installedDllPath" }
    $localDllHash = Get-TbgFileSha256 -LiteralPath $localDllPath
    $installedDllHash = Get-TbgFileSha256 -LiteralPath $installedDllPath
    if (-not [string]::Equals($localDllHash, $installedDllHash, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "FAILED_preflight:installed_dll_hash_mismatch local=$localDllHash installed=$installedDllHash"
    }
    $preflightChecks.installedDllHashMatches = $true

    if (@(Get-BannerlordRelatedProcesses).Count -gt 0) { throw 'FAILED_preflight:preexisting_bannerlord_before_launch' }
    $launchAttemptUtc = (Get-Date).ToUniversalTime()
    $launchFailure = $null
    try {
        & (Join-Path $PSScriptRoot 'invoke-forge-launch-operator.ps1') `
            -RepoRoot $repoRoot `
            -LaunchIntent continue `
            -TimeoutSec $AttachTimeoutSec `
            -AllowFocusSteal
        if ($LASTEXITCODE -ne 0) { $launchFailure = "exit=$LASTEXITCODE" }
    } catch {
        $launchFailure = $_.Exception.Message
    }

    $runtimeDetection = Get-TbgBannerlordRuntimeDetection -BannerlordRoot $bannerlordRoot -LaunchStartedAtUtc $launchAttemptUtc
    if (-not (Test-TbgLiveRuntimeDetection -Detection $runtimeDetection)) {
        $detail = if ([string]::IsNullOrWhiteSpace($launchFailure)) { 'no game runtime observed' } else { $launchFailure }
        throw "FAILED_runtime:native_continue_launch_failed:$detail"
    }
    $script:ownsLaunchedSession = $true
    $preflightChecks.nativeContinueLaunched = $true
    $preflightChecks.gameRuntimeObserved = $true

    Invoke-ForgeCommandChecked -Command 'ReportSaveIdentityNow' -TimeoutSec 45
    $saveIdentityRecord = Wait-TbgJsonEvidence `
        -Candidates $saveIdentityCandidates `
        -NotBeforeUtc $startedAtUtc `
        -TimeoutSec $AttachTimeoutSec `
        -Label 'BLOCKED_save_identity' `
        -Accept {
            param($value)
            [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                -and [string](Get-TbgObjectProperty $value 'requestedSaveId' '') -eq $request.requestedSaveId `
                -and [string](Get-TbgObjectProperty $value 'loadedSaveId' '') -eq $request.requestedSaveId `
                -and [string](Get-TbgObjectProperty $value 'activeSaveSlotName' '') -eq $request.requestedSaveId `
                -and (Get-TbgObjectProperty $value 'identityVerified' $false) -eq $true
        }

    $baselineCommandUtc = (Get-Date).ToUniversalTime()
    Invoke-ForgeCommandChecked -Command 'ShowEngineToggleState' -TimeoutSec 45
    $authorityBeforeRecord = Wait-TbgJsonEvidence `
        -Candidates $authorityCandidates `
        -NotBeforeUtc $baselineCommandUtc `
        -TimeoutSec $AuthorityTimeoutSec `
        -Label 'BLOCKED_engine_authority_baseline' `
        -Accept {
            param($value)
            [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                -and [string](Get-TbgObjectProperty $value 'source' '') -eq 'ShowEngineToggleState'
        }

    $automationCommandUtc = (Get-Date).ToUniversalTime()
    $script:mapTradeAutomationAttempted = $true
    Invoke-ForgeCommandChecked -Command 'SetMapTradeAutomation' -TimeoutSec 45
    $authorityAutomationRecord = Wait-TbgJsonEvidence `
        -Candidates $authorityCandidates `
        -NotBeforeUtc $automationCommandUtc `
        -TimeoutSec $AuthorityTimeoutSec `
        -Label 'BLOCKED_engine_authority_automation' `
        -Accept {
            param($value)
            $modes = Get-TbgEngineModes $value
            [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                -and [string](Get-TbgObjectProperty $value 'source' '') -eq 'SetMapTradeAutomation' `
                -and $modes.Contains('MapTrade') `
                -and [string]$modes['MapTrade'] -eq 'Automation' `
                -and (Test-TbgSameNonMapTradeModes $authorityBeforeRecord.Value $value)
        }

    $routeCommandUtc = (Get-Date).ToUniversalTime()
    Invoke-ForgeCommandChecked -Command 'RunAutonomousVisibleTradeRouteNow' -TimeoutSec 60
    $runtimeRecord = Wait-TbgJsonEvidence `
        -Candidates $runtimeCandidates `
        -NotBeforeUtc $routeCommandUtc `
        -TimeoutSec $TradeTimeoutSec `
        -Label 'FAILED_runtime_terminal' `
        -Accept {
            param($value)
            [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                -and [string](Get-TbgObjectProperty $value 'source' '') -eq 'RunAutonomousVisibleTradeRouteNow' `
                -and (Get-TbgObjectProperty $value 'terminal' $false) -eq $true
        }

    $routeCertRecord = Wait-TbgJsonEvidence `
        -Candidates $routeCertCandidates `
        -NotBeforeUtc $routeCommandUtc `
        -TimeoutSec 30 `
        -Label 'BLOCKED_route_cert' `
        -Accept {
            param($value)
            [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                -and [string](Get-TbgObjectProperty $value 'source' '') -eq 'RunAutonomousVisibleTradeRouteNow'
        }
    $preflightChecks.standardRouteCertFresh = $true

    $tradeCertRecord = Wait-TbgJsonEvidence `
        -Candidates $tradeCertCandidates `
        -NotBeforeUtc $routeCommandUtc `
        -TimeoutSec 30 `
        -Label 'BLOCKED_trade_cert' `
        -Accept {
            param($value)
            [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                -and [string](Get-TbgObjectProperty $value 'source' '') -eq 'RunAutonomousVisibleTradeRouteNow'
        }
    $preflightChecks.standardTradeCertFresh = $true
} catch {
    $failureDetail = $_.Exception.Message
} finally {
    if ($launchAttemptUtc) {
        $runtimeDetection = Get-TbgBannerlordRuntimeDetection -BannerlordRoot $bannerlordRoot -LaunchStartedAtUtc $launchAttemptUtc
        if (Test-TbgLiveRuntimeDetection -Detection $runtimeDetection) {
            $script:ownsLaunchedSession = $true
            $preflightChecks.gameRuntimeObserved = $true
        }
    }

    if ($script:ownsLaunchedSession -and $script:mapTradeAutomationAttempted -and -not $diagnosticOnly -and (Test-TbgLiveRuntimeDetection -Detection $runtimeDetection)) {
        try {
            $manualCommandUtc = (Get-Date).ToUniversalTime()
            Invoke-ForgeCommandChecked -Command 'SetMapTradeManual' -TimeoutSec 45
            $authorityManualRecord = Wait-TbgJsonEvidence `
                -Candidates $authorityCandidates `
                -NotBeforeUtc $manualCommandUtc `
                -TimeoutSec $AuthorityTimeoutSec `
                -Label 'BLOCKED_manual_cleanup' `
                -Accept {
                    param($value)
                    $modes = Get-TbgEngineModes $value
                    [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                        -and [string](Get-TbgObjectProperty $value 'headSha' '') -eq $head `
                        -and [string](Get-TbgObjectProperty $value 'source' '') -eq 'SetMapTradeManual' `
                        -and $modes.Contains('MapTrade') `
                        -and [string]$modes['MapTrade'] -eq 'Manual'
                }
        } catch {
            if ([string]::IsNullOrWhiteSpace($failureDetail)) {
                $failureDetail = $_.Exception.Message
            } else {
                $failureDetail += "; cleanup=$($_.Exception.Message)"
            }
        }
    } elseif ($launchAttemptUtc -and -not $diagnosticOnly -and (-not (Test-TbgLiveRuntimeDetection -Detection $runtimeDetection))) {
        try {
            $closedLaunchers = @(Stop-TbgOwnedLauncherAfterFailedSpawn -BannerlordRoot $bannerlordRoot -LaunchStartedAtUtc $launchAttemptUtc)
            $preflightChecks.ownedLauncherCleanedAfterFailedSpawn = $closedLaunchers.Count -gt 0
        } catch {
            if ([string]::IsNullOrWhiteSpace($failureDetail)) {
                $failureDetail = "launcher_cleanup=$($_.Exception.Message)"
            } else {
                $failureDetail += "; launcher_cleanup=$($_.Exception.Message)"
            }
        }
    }
}

if ($null -ne $request) {
    $evaluation = Test-TbgVisibleTradeCycleEvidence `
        -Request ([PSCustomObject]$request) `
        -SaveIdentity $(if ($saveIdentityRecord) { $saveIdentityRecord.Value } else { $null }) `
        -AuthorityBefore $(if ($authorityBeforeRecord) { $authorityBeforeRecord.Value } else { $null }) `
        -AuthorityAutomation $(if ($authorityAutomationRecord) { $authorityAutomationRecord.Value } else { $null }) `
        -RuntimeEvidence $(if ($runtimeRecord) { $runtimeRecord.Value } else { $null }) `
        -AuthorityManual $(if ($authorityManualRecord) { $authorityManualRecord.Value } else { $null })
}

$runtimeValue = if ($runtimeRecord) { $runtimeRecord.Value } else { $null }
$routeValue = Get-TbgObjectProperty $runtimeValue 'route'
$tradeValue = Get-TbgObjectProperty $runtimeValue 'tradeExecution'
$surfaceValue = Get-TbgObjectProperty $runtimeValue 'tradeSurface'
$evaluationPassed = $null -ne $evaluation -and $evaluation.pass -eq $true
$standardCertsPassed = $preflightChecks.standardRouteCertFresh -and $preflightChecks.standardTradeCertFresh
$pass = $certifyingMode -and [string]::IsNullOrWhiteSpace($failureDetail) -and $evaluationPassed -and $standardCertsPassed
$terminalState = if ($diagnosticOnly) {
    'DIAGNOSTIC_ONLY'
} elseif ($pass) {
    'PASS_visible_trade_cycle'
} elseif (-not [string]::IsNullOrWhiteSpace($failureDetail)) {
    Get-FailureTerminalState -Detail $failureDetail
} elseif ($null -ne $evaluation) {
    $evaluation.terminalState
} else {
    'FAILED_runtime'
}

$result = [ordered]@{
    schemaVersion = 'TbgVisibleTradeCycleResult.v1'
    runId = $runId
    correlationId = $runId
    startedAtUtc = $startedAtUtc.ToString('o')
    endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    repo = 'EndeavorEverlasting/BlacksmithGuild'
    branch = $branch
    headSha = $head
    mode = if ($certifyingMode) { 'certify' } else { 'diagnostic_only' }
    passFail = if ($pass) { 'PASS' } elseif ($diagnosticOnly) { 'DIAGNOSTIC' } else { 'FAIL' }
    terminalState = $terminalState
    failureDetail = $failureDetail
    preflight = $preflightChecks
    launch = [ordered]@{
        attemptedAtUtc = if ($launchAttemptUtc) { $launchAttemptUtc.ToString('o') } else { $null }
        runtimeDetection = $runtimeDetection
    }
    request = if ($request) { $request } else { [ordered]@{ requestedSaveId = $null } }
    dll = [ordered]@{
        localPath = $localDllPath
        installedPath = $installedDllPath
        localSha256 = $localDllHash
        installedSha256 = $installedDllHash
    }
    evidence = [ordered]@{
        saveIdentity = New-EvidenceReference $saveIdentityRecord
        authorityBefore = New-EvidenceReference $authorityBeforeRecord
        authorityAutomation = New-EvidenceReference $authorityAutomationRecord
        runtime = New-EvidenceReference $runtimeRecord
        routeCert = New-EvidenceReference $routeCertRecord
        tradeCert = New-EvidenceReference $tradeCertRecord
        authorityManual = New-EvidenceReference $authorityManualRecord
    }
    checks = if ($evaluation) { $evaluation.checks } else { [ordered]@{} }
    failures = if ($evaluation) { @($evaluation.failures) } else { @() }
    evidenceSummary = [ordered]@{
        saveIdentityVerified = $null -ne $evaluation -and $evaluation.checks.saveIdentityVerified -eq $true
        routeStarted = $null -ne $evaluation -and $evaluation.checks.routeStarted -eq $true
        movementObserved = $null -ne $evaluation -and $evaluation.checks.movementObserved -eq $true
        arrivalObserved = $null -ne $evaluation -and $evaluation.checks.arrivalObserved -eq $true
        arrivedSettlement = [string](Get-TbgObjectProperty $routeValue 'arrivedSettlement' '')
        realBuyDelta = $null -ne $evaluation -and $evaluation.checks.realBuyDelta -eq $true
        itemId = [string](Get-TbgObjectProperty $tradeValue 'itemId' '')
        goldDelta = [int](Get-TbgObjectProperty $tradeValue 'goldDelta' 0)
        inventoryDelta = [int](Get-TbgObjectProperty $tradeValue 'inventoryDelta' 0)
        tradeSurfaceVisible = $null -ne $evaluation -and $evaluation.checks.tradeSurfaceVisible -eq $true
        tradeSurface = [string](Get-TbgObjectProperty $surfaceValue 'surface' '')
        manualCleanupProven = $null -ne $evaluation -and $evaluation.checks.manualCleanupProven -eq $true
    }
    allowedClaims = if ($pass) {
        @('This exact committed DLL/head loaded the pinned save, moved through Bannerlord, arrived, bought one real item, exposed a visible trade surface, and returned only MapTrade to Manual.')
    } else {
        @('The runner produced a bounded terminal diagnosis; inspect terminalState and failed checks.')
    }
    forbiddenClaims = @(
        'A command acknowledgement is not terminal workflow proof.',
        'Diagnostic and skip modes can never certify gameplay.',
        'The runner does not grant gold, inventory, movement, or other gameplay outcomes.'
    )
}
Write-AtomicUtf8Json -Value $result -Path $resultPath
Write-EnglishReport -Result ([PSCustomObject]$result)

Write-Host "Visible trade cycle: $($result.passFail) ($terminalState)"
Write-Host "result: $resultPath"
Write-Host "report: $reportPath"
if ($pass) { exit 0 }
if ($diagnosticOnly) { exit 3 }
exit 2
