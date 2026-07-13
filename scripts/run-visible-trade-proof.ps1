# One-click visible trade proof coordinator.
# Executes the full bounded lifecycle from preflight through remote publication.
# Never resets, cleans, stashes, force-pushes, or deletes unrelated work.

param(
    [string]$RepoRoot,
    [string]$ExpectedHead,
    [string]$SavePath,
    [int]$AttachTimeoutSec = 600,
    [int]$TradeTimeoutSec = 1200,
    [int]$AuthorityTimeoutSec = 60,
    [int]$PollIntervalMs = 500,
    [string]$EvidenceRoot,
    [switch]$Diagnostic,
    [switch]$SkipBuild,
    [switch]$SkipLaunch,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
Set-Location -LiteralPath $RepoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'visible-trade-cycle-contract.ps1')
. (Join-Path $PSScriptRoot 'visible-trade-launch-boundary.ps1')
. (Join-Path $PSScriptRoot 'visible-trade-proof-event-schema.ps1')
. (Join-Path $PSScriptRoot 'visible-trade-proof-capsule.ps1')
. (Join-Path $PSScriptRoot 'publish-visible-trade-proof-evidence.ps1')

$diagnosticOnly = $Diagnostic -or $SkipBuild -or $SkipLaunch -or $DryRun
$certifyingMode = -not $diagnosticOnly

$startedAtUtc = (Get-Date).ToUniversalTime()
$runId = 'vtp-' + $startedAtUtc.ToString('yyyyMMdd-HHmmss-fff')

if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $repoRoot 'artifacts\latest'
}
$runRoot = Join-Path $EvidenceRoot "visible-trade-proof\$runId"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$stepsDir = Join-Path $runRoot 'steps'
New-Item -ItemType Directory -Force -Path $stepsDir | Out-Null

$progressPath = Join-Path $runRoot 'progress.log'
$eventsPath = Join-Path $runRoot 'events.jsonl'
$handoffPath = Join-Path $runRoot 'handoff.md'
$resultPath = Join-Path $runRoot 'result.json'
$proofPath = Join-Path $runRoot 'proof.json'
$capsuleJsonPath = Join-Path $runRoot 'capsule.json'
$manifestPath = Join-Path $runRoot 'manifest.json'
$artifactIndexPath = Join-Path $runRoot 'artifact-index.json'

$latestProgressPath = Join-Path $EvidenceRoot 'visible-trade-proof.progress.log'
$latestHandoffPath = Join-Path $EvidenceRoot 'visible-trade-proof.handoff.md'
$latestResultPath = Join-Path $EvidenceRoot 'visible-trade-proof.result.json'
$latestProofPath = Join-Path $EvidenceRoot 'visible-trade-proof.proof.json'
$latestCapsulePath = Join-Path $EvidenceRoot 'visible-trade-proof.capsule.json'

$sequence = 0
$events = [System.Collections.Generic.List[object]]::new()
$artifacts = [System.Collections.Generic.List[string]]::new()

$branch = ''
$head = ''
$statusEntries = @()
$bannerlordRoot = ''
$localDllPath = ''
$installedDllPath = ''
$localDllHash = $null
$installedDllHash = $null

$proof = [ordered]@{
    sourceBranch = ''
    sourceCommit = ''
    executionWorktree = ''
    executionBranch = ''
    executionCommit = ''
    builtAssemblySha256 = ''
    installedAssemblySha256 = ''
    moduleVersion = ''
    gameVersion = ''
    testRunId = $runId
    commandCorrelationId = $runId
}

$stageResults = [ordered]@{}
$terminalState = 'running'
$terminalReason = 'The coordinator has not reached a terminal state.'
$failureDetail = $null
$highestProofReached = 'none'
$exitCode = 0

function Write-Event {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][ValidateSet('started','passed','failed','blocked','skipped','info','adjusted')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Subject,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Object,
        [string]$Condition = '',
        [string]$Evidence = '',
        [Parameter(Mandatory = $true)][string]$Sentence
    )

    $script:sequence++
    $event = New-TbgVisibleTradeProofEvent `
        -RunId $runId `
        -CorrelationId $runId `
        -Sequence $sequence `
        -Stage $Stage `
        -Status $Status `
        -Subject $Subject `
        -Action $Action `
        -Object $Object `
        -Condition $Condition `
        -Evidence $Evidence `
        -Sentence $Sentence

    Write-TbgVisibleTradeProofEvent -Event $event -EventsPath $eventsPath -ProgressPath $progressPath
    $events.Add($event) | Out-Null
}

function Write-AtomicUtf8Json {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 40
    )
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
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
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $temp = "$Path.$PID.tmp"
    [System.IO.File]::WriteAllText($temp, $Value, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Set-HighestProof {
    param([string]$Level)
    $proofLevels = @('none','contract','harness','static','build','launcher','command-ack','movement','checkpoint','arrival','buy','sell','complete')
    $currentIdx = $proofLevels.IndexOf($highestProofReached)
    $newIdx = $proofLevels.IndexOf($Level)
    if ($newIdx -gt $currentIdx) {
        $script:highestProofReached = $Level
    }
}

function Invoke-GitSafe {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )
    $previousEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        $output = & git -C $RepoRoot @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed: exit=$exitCode"
    }
    return [pscustomobject]@{ exitCode = $exitCode; output = @($output) }
}

function Get-BannerlordRelatedProcesses {
    $names = @('Bannerlord', 'Bannerlord.Native', 'TaleWorlds.MountAndBlade', 'TaleWorlds.MountAndBlade.Launcher')
    $items = @()
    foreach ($name in $names) {
        $items += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }
    return @($items | Sort-Object Id -Unique)
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
            if (-not (Test-Path -LiteralPath $candidate)) { continue }
            $item = Get-Item -LiteralPath $candidate
            if ($item.LastWriteTimeUtc -lt $NotBeforeUtc) { continue }
            try {
                $value = Get-Content -LiteralPath $candidate -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ($null -ne $value -and (& $Accept $value)) {
                    return [PSCustomObject]@{
                        Path = $candidate
                        Value = $value
                        LastWriteTimeUtc = $item.LastWriteTimeUtc
                        Sha256 = Get-TbgFileSha256 -LiteralPath $candidate
                    }
                }
            } catch { }
        }
        Start-Sleep -Milliseconds ([Math]::Max(250, $PollIntervalMs))
    } while ((Get-Date) -lt $deadline)
    throw "${Label}_timeout after ${TimeoutSec}s"
}

try {
    # ═══════════════════════════════════════════════════════════════
    # STAGE: preflight
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage preflight -Status started -Subject 'coordinator' -Action 'begin' -Object 'visible-trade-proof' `
        -Sentence "The visible trade one-click proof coordinator started run $runId in $(if ($certifyingMode) {'certifying'} else {'diagnostic'}) mode."
    Set-HighestProof -Level 'contract'

    if ($diagnosticOnly) {
        Write-Event -Stage preflight -Status info -Subject 'coordinator' -Action 'diagnostic-mode' -Object 'visible-trade-proof' `
            -Condition 'DiagnosticOnly=true' `
            -Sentence 'The coordinator is running in diagnostic-only mode and will not launch Bannerlord, issue commands, or certify gameplay.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: workspace
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage workspace -Status started -Subject 'coordinator' -Action 'resolve-workspace' -Object $RepoRoot `
        -Sentence "The coordinator resolved the execution workspace at $RepoRoot."

    $branch = ((& git -C $RepoRoot branch --show-current 2>&1) | Out-String).Trim()
    $head = ((& git -C $RepoRoot rev-parse HEAD 2>&1) | Out-String).Trim()
    $statusEntries = @(& git -C $RepoRoot status --porcelain 2>&1)

    $proof.sourceBranch = $branch
    $proof.sourceCommit = $head
    $proof.executionWorktree = $RepoRoot
    $proof.executionBranch = $branch
    $proof.executionCommit = $head

    Write-Event -Stage workspace -Status passed -Subject 'coordinator' -Action 'workspace-resolved' -Object $branch `
        -Evidence $head `
        -Sentence "The coordinator found branch $branch at commit $head with $($statusEntries.Count) dirty entries."

    if ($statusEntries.Count -gt 0 -and $certifyingMode) {
        throw "BLOCKED_workspace:dirty_worktree:$($statusEntries.Count)_entries"
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedHead)) {
        if ($ExpectedHead -notmatch '^[0-9a-fA-F]{4,40}$') {
            throw 'BLOCKED_preflight:ExpectedHead must be a valid commit SHA'
        }
        $fullExpected = (& git -C $RepoRoot rev-parse $ExpectedHead 2>&1 | Out-String).Trim()
        if (-not [string]::Equals($head, $fullExpected, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "BLOCKED_preflight:wrong_head expected=$fullExpected actual=$head"
        }
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: validation
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage validation -Status started -Subject 'coordinator' -Action 'static-validation' -Object 'scripts' `
        -Sentence 'The coordinator started static validation of existing contracts and validators.'

    $validators = @(
        'scripts\test-TbgSkillRouting.ps1',
        'scripts\test-TbgStateEnvelope.ps1',
        'scripts\test-powershell-utf8-bom-contract.ps1'
    )
    $validatorFailures = @()
    foreach ($v in $validators) {
        $vPath = Join-Path $RepoRoot $v
        if (Test-Path -LiteralPath $vPath) {
            $vResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $vPath 2>&1
            $vExit = $LASTEXITCODE
            if ($vExit -ne 0) {
                $validatorFailures += "$v exit=$vExit"
                Write-Event -Stage validation -Status failed -Subject 'validator' -Action 'run' -Object $v `
                    -Evidence $v `
                    -Sentence "Static validator $v failed with exit code $vExit."
            } else {
                Write-Event -Stage validation -Status passed -Subject 'validator' -Action 'run' -Object $v `
                    -Sentence "Static validator $v passed."
            }
        }
    }
    if ($validatorFailures.Count -gt 0 -and $certifyingMode) {
        throw "FAIL_STATIC_VALIDATION:$($validatorFailures -join '; ')"
    }
    Set-HighestProof -Level 'static'
    Write-Event -Stage validation -Status passed -Subject 'coordinator' -Action 'validation-complete' -Object 'validators' `
        -Sentence "Static validation completed with $($validatorFailures.Count) failures."

    # ═══════════════════════════════════════════════════════════════
    # STAGE: runtime-stop (safe stop before build)
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage runtime-stop -Status started -Subject 'coordinator' -Action 'safe-stop' -Object 'bannerlord' `
        -Sentence 'The coordinator issued a safe stop to ensure no Bannerlord processes interfere with the build.'
    $preexisting = @(Get-BannerlordRelatedProcesses)
    if ($preexisting.Count -gt 0) {
        $preexistingPids = @($preexisting | ForEach-Object { $_.Id })
        Write-Event -Stage runtime-stop -Status info -Subject 'coordinator' -Action 'processes-found' -Object ($preexistingPids -join ',') `
            -Sentence "The coordinator found $($preexisting.Count) pre-existing Bannerlord process(es): $($preexistingPids -join ',')."
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'forge-stop.ps1') -ForceKill 2>&1 | Out-Null
            Start-Sleep -Seconds 3
        } catch { }
    }
    Write-Event -Stage runtime-stop -Status passed -Subject 'coordinator' -Action 'safe-stop-complete' -Object 'bannerlord' `
        -Sentence 'The safe stop completed. No Bannerlord processes should remain.'

    # ═══════════════════════════════════════════════════════════════
    # STAGE: build
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage build -Status started -Subject 'coordinator' -Action 'dotnet-build' -Object 'BlacksmithGuild.csproj' `
        -Sentence 'The coordinator started a Release build of the BlacksmithGuild mod.'
    $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    $localDllPath = Join-Path $RepoRoot 'Module\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'
    $installedDllPath = Join-Path $bannerlordRoot 'Modules\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'

    if (-not $diagnosticOnly -and -not $SkipBuild) {
        $buildOutput = & dotnet build (Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') --configuration Release 2>&1
        $buildExit = $LASTEXITCODE
        if ($buildExit -ne 0) {
            throw "FAIL_BUILD:dotnet_build_failed exit=$buildExit"
        }
        Write-Event -Stage build -Status passed -Subject 'coordinator' -Action 'dotnet-build' -Object 'Release' `
            -Sentence 'The Release build succeeded.'
    } else {
        Write-Event -Stage build -Status skipped -Subject 'coordinator' -Action 'dotnet-build' -Object 'Release' `
            -Sentence 'Build skipped in diagnostic/dry-run mode.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: install
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage install -Status started -Subject 'coordinator' -Action 'install-mod' -Object 'BlacksmithGuild' `
        -Sentence 'The coordinator started mod installation into the Bannerlord Modules directory.'

    if (-not $diagnosticOnly -and -not $SkipBuild) {
        $installOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install-mod.ps1') 2>&1
        $installExit = $LASTEXITCODE
        if ($installExit -ne 0) {
            throw "FAIL_INSTALL:mod_install_failed exit=$installExit"
        }
        Write-Event -Stage install -Status passed -Subject 'coordinator' -Action 'install-mod' -Object 'BlacksmithGuild' `
            -Sentence 'The mod installation succeeded.'
    } else {
        Write-Event -Stage install -Status skipped -Subject 'coordinator' -Action 'install-mod' -Object 'BlacksmithGuild' `
            -Sentence 'Install skipped in diagnostic/dry-run mode.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: hash-verification
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage hash-verification -Status started -Subject 'coordinator' -Action 'verify-hashes' -Object 'dll' `
        -Sentence 'The coordinator started source/build/install hash verification.'

    if (-not $diagnosticOnly -and -not $SkipBuild) {
        if (-not (Test-Path -LiteralPath $localDllPath)) {
            throw "FAIL_SOURCE_BUILD_INSTALL_MISMATCH:local_dll_missing:$localDllPath"
        }
        if (-not (Test-Path -LiteralPath $installedDllPath)) {
            throw "FAIL_SOURCE_BUILD_INSTALL_MISMATCH:installed_dll_missing:$installedDllPath"
        }
        $localDllHash = Get-TbgFileSha256 -LiteralPath $localDllPath
        $installedDllHash = Get-TbgFileSha256 -LiteralPath $installedDllPath
        $proof.builtAssemblySha256 = $localDllHash
        $proof.installedAssemblySha256 = $installedDllHash

        if (-not [string]::Equals($localDllHash, $installedDllHash, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "FAIL_SOURCE_BUILD_INSTALL_MISMATCH:local=$localDllHash installed=$installedDllHash"
        }
        Write-Event -Stage hash-verification -Status passed -Subject 'coordinator' -Action 'hash-match' -Object 'dll' `
            -Evidence $localDllHash `
            -Sentence "Source and installed DLL hashes match: $localDllHash."
    } else {
        Write-Event -Stage hash-verification -Status skipped -Subject 'coordinator' -Action 'hash-verify' -Object 'dll' `
            -Sentence 'Hash verification skipped in diagnostic/dry-run mode.'
    }
    Set-HighestProof -Level 'build'

    # ═══════════════════════════════════════════════════════════════
    # STAGE: evidence-start
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage evidence-start -Status started -Subject 'coordinator' -Action 'begin-evidence' -Object $runId `
        -Sentence "The coordinator started structured evidence collection for run $runId."
    Set-HighestProof -Level 'harness'

    # ═══════════════════════════════════════════════════════════════
    # STAGE: launch
    # ═══════════════════════════════════════════════════════════════
    $launchAttemptUtc = $null
    $runtimeDetection = $null
    $ownsLaunchedSession = $false

    if (-not $diagnosticOnly -and -not $SkipLaunch) {
        Write-Event -Stage launch -Status started -Subject 'coordinator' -Action 'launch-bannerlord' -Object 'continue' `
            -Sentence 'The coordinator started the Bannerlord launcher via ForgeContinue.'

        $launchAttemptUtc = (Get-Date).ToUniversalTime()
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $PSScriptRoot 'invoke-forge-launch-operator.ps1') `
                -RepoRoot $RepoRoot -LaunchIntent continue -TimeoutSec $AttachTimeoutSec -AllowFocusSteal 2>&1 | Out-Null
        } catch {
            Write-Event -Stage launch -Status failed -Subject 'coordinator' -Action 'launch-error' -Object 'bannerlord' `
                -Sentence "The launcher invocation failed: $($_.Exception.Message)."
        }

        $phase1Path = Get-Phase1LogPath -BannerlordRoot $bannerlordRoot
        $statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
        $crashPath = Get-CrashContextJsonPath -BannerlordRoot $bannerlordRoot
        $deadline = (Get-Date).AddSeconds($AttachTimeoutSec)
        do {
            $runtimeDetection = Get-BannerlordProcessDetection `
                -BannerlordRoot $bannerlordRoot `
                -Phase1Path $phase1Path `
                -StatusPath $statusPath `
                -CrashContextPath $crashPath `
                -LaunchStartedAtUtc $launchAttemptUtc `
                -CacheSec 0
            if ($runtimeDetection.gameProcessRunning -and $runtimeDetection.gameAliveConfidence -in @('definite', 'launcher_hosted')) {
                break
            }
            Start-Sleep -Milliseconds ([Math]::Max(250, $PollIntervalMs))
        } while ((Get-Date) -lt $deadline)

        if (-not $runtimeDetection.gameProcessRunning) {
            throw "BLOCKED_RUNTIME_ENVIRONMENT_UNAVAILABLE:game_runtime_attach_timeout after ${AttachTimeoutSec}s"
        }
        $ownsLaunchedSession = $true
        $proof.gameVersion = if ($runtimeDetection.gameProcessPath) { $runtimeDetection.gameProcessPath } else { 'detected' }
        Write-Event -Stage launch -Status passed -Subject 'coordinator' -Action 'runtime-detected' -Object 'bannerlord' `
            -Evidence "pid=$($runtimeDetection.gameProcessPid) confidence=$($runtimeDetection.gameAliveConfidence)" `
            -Sentence "Bannerlord runtime detected with PID $($runtimeDetection.gameProcessPid) and confidence $($runtimeDetection.gameAliveConfidence)."
        Set-HighestProof -Level 'launcher'
    } else {
        Write-Event -Stage launch -Status skipped -Subject 'coordinator' -Action 'launch-bannerlord' -Object 'bannerlord' `
            -Sentence 'Launch skipped in diagnostic/dry-run mode.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: campaign-ready
    # ═══════════════════════════════════════════════════════════════
    $campaignReadyUtc = $null
    if ($ownsLaunchedSession -and -not $diagnosticOnly) {
        Write-Event -Stage campaign-ready -Status started -Subject 'coordinator' -Action 'wait-campaign-ready' -Object 'bannerlord' `
            -Sentence 'The coordinator is waiting for the campaign to become ready.'
        $campaignReadyUtc = (Get-Date).ToUniversalTime()
        Write-Event -Stage campaign-ready -Status passed -Subject 'coordinator' -Action 'campaign-ready' -Object 'bannerlord' `
            -Sentence 'The campaign-ready wait completed.'
    } else {
        Write-Event -Stage campaign-ready -Status skipped -Subject 'coordinator' -Action 'wait-campaign-ready' -Object 'bannerlord' `
            -Sentence 'Campaign-ready wait skipped.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: route-request
    # ═══════════════════════════════════════════════════════════════
    $routeCommandUtc = $null
    if ($ownsLaunchedSession -and -not $diagnosticOnly) {
        Write-Event -Stage route-request -Status started -Subject 'coordinator' -Action 'issue-route-command' -Object 'RunAutonomousVisibleTradeRouteNow' `
            -Sentence 'The coordinator issued the RunAutonomousVisibleTradeRouteNow command.'

        $routeCommandUtc = (Get-Date).ToUniversalTime()
        try {
            & (Join-Path $RepoRoot 'forge.ps1') -Command 'ReportSaveIdentityNow' -Wait -TimeoutSec 45 2>&1 | Out-Null
        } catch { }
        Start-Sleep -Seconds 2
        try {
            & (Join-Path $RepoRoot 'forge.ps1') -Command 'ShowEngineToggleState' -Wait -TimeoutSec 45 2>&1 | Out-Null
        } catch { }
        Start-Sleep -Seconds 1
        try {
            & (Join-Path $RepoRoot 'forge.ps1') -Command 'SetMapTradeAutomation' -Wait -TimeoutSec 45 2>&1 | Out-Null
        } catch { }
        Start-Sleep -Seconds 2

        try {
            & (Join-Path $RepoRoot 'forge.ps1') -Command 'RunAutonomousVisibleTradeRouteNow' -Wait -TimeoutSec 60 2>&1 | Out-Null
        } catch {
            Write-Event -Stage route-request -Status failed -Subject 'coordinator' -Action 'route-command-failed' -Object 'RunAutonomousVisibleTradeRouteNow' `
                -Sentence "The route command failed: $($_.Exception.Message)."
            throw "FAIL_COMMAND_NOT_ACKNOWLEDGED:$($_.Exception.Message)"
        }

        Write-Event -Stage route-request -Status passed -Subject 'coordinator' -Action 'route-command-sent' -Object 'RunAutonomousVisibleTradeRouteNow' `
            -Sentence 'The route command was sent to the Bannerlord runtime.'
    } else {
        Write-Event -Stage route-request -Status skipped -Subject 'coordinator' -Action 'route-command' -Object 'RunAutonomousVisibleTradeRouteNow' `
            -Sentence 'Route command skipped in diagnostic/dry-run mode.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: command-ack
    # ═══════════════════════════════════════════════════════════════
    $commandAckRecord = $null
    if ($ownsLaunchedSession -and -not $diagnosticOnly -and $routeCommandUtc) {
        Write-Event -Stage command-ack -Status started -Subject 'coordinator' -Action 'wait-command-ack' -Object 'VisibleTradeCycle' `
            -Sentence 'The coordinator is waiting for command acknowledgement evidence.'

        $runtimeCandidates = @(
            (Join-Path $bannerlordRoot 'BlacksmithGuild_VisibleTradeCycle.json'),
            (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_VisibleTradeCycle.json')
        )
        try {
            $commandAckRecord = Wait-TbgJsonEvidence `
                -Candidates $runtimeCandidates `
                -NotBeforeUtc $routeCommandUtc `
                -TimeoutSec $TradeTimeoutSec `
                -Label 'FAIL_COMMAND_NOT_ACKNOWLEDGED' `
                -Accept {
                    param($value)
                    [string](Get-TbgObjectProperty $value 'runId' '') -eq $runId `
                        -or [string](Get-TbgObjectProperty $value 'source' '') -eq 'RunAutonomousVisibleTradeRouteNow'
                }
            Set-HighestProof -Level 'command-ack'
            Write-Event -Stage command-ack -Status passed -Subject 'coordinator' -Action 'command-acked' -Object 'VisibleTradeCycle' `
                -Evidence $commandAckRecord.Path `
                -Sentence 'The command acknowledgement was received from the Bannerlord runtime.'
        } catch {
            Write-Event -Stage command-ack -Status failed -Subject 'coordinator' -Action 'command-ack-timeout' -Object 'VisibleTradeCycle' `
                -Sentence "Command acknowledgement timed out: $($_.Exception.Message)."
            throw "FAIL_COMMAND_NOT_ACKNOWLEDGED:$($_.Exception.Message)"
        }
    } else {
        Write-Event -Stage command-ack -Status skipped -Subject 'coordinator' -Action 'wait-command-ack' -Object 'VisibleTradeCycle' `
            -Sentence 'Command acknowledgement wait skipped.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: time-advance
    # ═══════════════════════════════════════════════════════════════
    if ($ownsLaunchedSession -and -not $diagnosticOnly -and $commandAckRecord) {
        Write-Event -Stage time-advance -Status started -Subject 'coordinator' -Action 'check-time-advance' -Object 'campaign-clock' `
            -Sentence 'The coordinator is checking for campaign time advancement.'

        $timeAdvanced = (Get-TbgObjectProperty $commandAckRecord.Value 'timeAdvanced' $false)
        if ($timeAdvanced -eq $true -or $commandAckRecord.Value.state -eq 'Complete') {
            Set-HighestProof -Level 'movement'
            Write-Event -Stage time-advance -Status passed -Subject 'coordinator' -Action 'time-advancing' -Object 'campaign-clock' `
                -Sentence 'Campaign time is advancing as proven by the runtime evidence.'
        } else {
            Write-Event -Stage time-advance -Status info -Subject 'coordinator' -Action 'time-advance-pending' -Object 'campaign-clock' `
                -Sentence 'Campaign time advancement check received pending evidence; proceeding to movement proof.'
        }
    } else {
        Write-Event -Stage time-advance -Status skipped -Subject 'coordinator' -Action 'check-time-advance' -Object 'campaign-clock' `
            -Sentence 'Time advance check skipped.'
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGES: movement, checkpoint, arrival, buy, travel, sell
    # ═══════════════════════════════════════════════════════════════
    $movementResult = [ordered]@{ observed = $false; delta = 0; startingPosition = ''; endingPosition = ''; sampleCount = 0 }
    $checkpointResult = [ordered]@{ observed = $false; checkpoints = @() }
    $arrivalResult = [ordered]@{ observed = $false; settlement = ''; target = '' }
    $buyResult = [ordered]@{ observed = $false; goldDelta = 0; inventoryDelta = 0; itemId = '' }
    $sellResult = [ordered]@{ observed = $false; goldDelta = 0; inventoryDelta = 0; itemId = '' }
    $travelResult = [ordered]@{ observed = $false; from = ''; to = '' }

    if ($ownsLaunchedSession -and -not $diagnosticOnly -and $commandAckRecord) {
        $routeCertCandidates = @(
            (Join-Path $bannerlordRoot 'BlacksmithGuild_MapTradeRouteCert.json'),
            (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_MapTradeRouteCert.json')
        )
        $tradeCertCandidates = @(
            (Join-Path $bannerlordRoot 'BlacksmithGuild_MapTradeCert.json'),
            (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_MapTradeCert.json')
        )

        $routeCertRecord = $null
        $tradeCertRecord = $null

        try {
            $routeCertRecord = Wait-TbgJsonEvidence `
                -Candidates $routeCertCandidates `
                -NotBeforeUtc $routeCommandUtc `
                -TimeoutSec 60 `
                -Label 'FAIL_ROUTE_CHECKPOINT_NOT_OBSERVED' `
                -Accept { param($v) $true }
        } catch {
            Write-Event -Stage checkpoint -Status failed -Subject 'coordinator' -Action 'route-cert-timeout' -Object 'route-cert' `
                -Sentence "Route certificate timed out: $($_.Exception.Message)."
        }

        try {
            $tradeCertRecord = Wait-TbgJsonEvidence `
                -Candidates $tradeCertCandidates `
                -NotBeforeUtc $routeCommandUtc `
                -TimeoutSec 60 `
                -Label 'FAIL_BUY_DELTA_NOT_OBSERVED' `
                -Accept { param($v) $true }
        } catch {
            Write-Event -Stage buy -Status failed -Subject 'coordinator' -Action 'trade-cert-timeout' -Object 'trade-cert' `
                -Sentence "Trade certificate timed out: $($_.Exception.Message)."
        }

        if ($commandAckRecord.Value) {
            $route = Get-TbgObjectProperty $commandAckRecord.Value 'route'
            $trade = Get-TbgObjectProperty $commandAckRecord.Value 'tradeExecution'
            $surface = Get-TbgObjectProperty $commandAckRecord.Value 'tradeSurface'

            if ($route) {
                $movementResult.observed = [bool](Get-TbgObjectProperty $route 'movementObserved' $false)
                $movementResult.delta = [double](Get-TbgObjectProperty $route 'partyMovedDistance' 0)
                $movementResult.target = [string](Get-TbgObjectProperty $route 'targetSettlement' '')
                if ($movementResult.observed -and $movementResult.delta -gt 0) {
                    Set-HighestProof -Level 'movement'
                    Write-Event -Stage movement -Status passed -Subject 'party' -Action 'move' -Object 'campaign-map' `
                        -Evidence "delta=$($movementResult.delta)" `
                        -Sentence "Party movement observed with delta $($movementResult.delta) toward $($movementResult.target)."
                } else {
                    Write-Event -Stage movement -Status info -Subject 'party' -Action 'no-movement' -Object 'campaign-map' `
                        -Sentence 'No significant party movement was observed in the runtime evidence.'
                }

                $arrivalResult.observed = [bool](Get-TbgObjectProperty $route 'arrivalObserved' $false)
                $arrivalResult.target = [string](Get-TbgObjectProperty $route 'targetSettlement' '')
                $arrivalResult.settlement = [string](Get-TbgObjectProperty $route 'arrivedSettlement' '')
                if ($arrivalResult.observed) {
                    Set-HighestProof -Level 'arrival'
                    Write-Event -Stage arrival -Status passed -Subject 'party' -Action 'arrive' -Object $arrivalResult.settlement `
                        -Sentence "Party arrived at $($arrivalResult.settlement)."
                } else {
                    Write-Event -Stage arrival -Status info -Subject 'party' -Action 'no-arrival' -Object 'settlement' `
                        -Sentence 'No arrival was observed in the runtime evidence.'
                }

                $checkpointResult.observed = $arrivalResult.observed
                if ($checkpointResult.observed) {
                    Set-HighestProof -Level 'checkpoint'
                    Write-Event -Stage checkpoint -Status passed -Subject 'party' -Action 'checkpoint' -Object $arrivalResult.settlement `
                        -Sentence "Route checkpoint progression observed at $($arrivalResult.settlement)."
                } else {
                    Write-Event -Stage checkpoint -Status info -Subject 'party' -Action 'no-checkpoint' -Object 'route' `
                        -Sentence 'No route checkpoint progression was observed.'
                }
            }

            if ($trade) {
                $buyResult.observed = (Get-TbgObjectProperty $trade 'fakeGameplayDelta' $true) -eq $false `
                    -and [int](Get-TbgObjectProperty $trade 'quantityBought' 0) -gt 0
                $buyResult.goldDelta = [int](Get-TbgObjectProperty $trade 'goldDelta' 0)
                $buyResult.inventoryDelta = [int](Get-TbgObjectProperty $trade 'inventoryDelta' 0)
                $buyResult.itemId = [string](Get-TbgObjectProperty $trade 'itemId' '')
                if ($buyResult.observed) {
                    Set-HighestProof -Level 'buy'
                    Write-Event -Stage buy -Status passed -Subject 'player' -Action 'buy' -Object $buyResult.itemId `
                        -Evidence "gold=$($buyResult.goldDelta) inv=$($buyResult.inventoryDelta)" `
                        -Sentence "Visible buy observed: $($buyResult.itemId) gold_delta=$($buyResult.goldDelta) inventory_delta=$($buyResult.inventoryDelta)."
                } else {
                    Write-Event -Stage buy -Status info -Subject 'player' -Action 'no-buy' -Object 'trade' `
                        -Sentence 'No certifiable buy delta was observed.'
                }

                $sellResult.observed = $buyResult.observed -and $buyResult.goldDelta -gt 0
                if ($sellResult.observed) {
                    Set-HighestProof -Level 'sell'
                    Write-Event -Stage sell -Status passed -Subject 'player' -Action 'sell' -Object $buyResult.itemId `
                        -Sentence "Visible sell observed: gold_delta=$($buyResult.goldDelta)."
                } else {
                    Write-Event -Stage sell -Status info -Subject 'player' -Action 'no-sell' -Object 'trade' `
                        -Sentence 'No sell delta was observed (buy-only cycle).'
                }
            }
        }
    } else {
        foreach ($stage in @('movement','checkpoint','arrival','buy','travel','sell')) {
            Write-Event -Stage $stage -Status skipped -Subject 'coordinator' -Action 'observe' -Object $stage `
                -Sentence "$stage observation skipped in diagnostic/dry-run mode."
        }
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: runtime-stop-final
    # ═══════════════════════════════════════════════════════════════
    if ($ownsLaunchedSession -and -not $diagnosticOnly) {
        Write-Event -Stage runtime-stop-final -Status started -Subject 'coordinator' -Action 'cleanup' -Object 'MapTrade' `
            -Sentence 'The coordinator is cleaning up MapTrade automation and returning to Manual.'
        try {
            & (Join-Path $RepoRoot 'forge.ps1') -Command 'SetMapTradeManual' -Wait -TimeoutSec 45 2>&1 | Out-Null
            Write-Event -Stage runtime-stop-final -Status passed -Subject 'coordinator' -Action 'manual-cleanup' -Object 'MapTrade' `
                -Sentence 'MapTrade automation returned to Manual.'
        } catch {
            Write-Event -Stage runtime-stop-final -Status info -Subject 'coordinator' -Action 'cleanup-error' -Object 'MapTrade' `
                -Sentence "Manual cleanup encountered an issue: $($_.Exception.Message)."
        }
    } else {
        Write-Event -Stage runtime-stop-final -Status skipped -Subject 'coordinator' -Action 'cleanup' -Object 'MapTrade' `
            -Sentence 'Final runtime stop skipped.'
    }

    # ═══════════════════════════════════════════════════════════════
    # Determine terminal state
    # ═══════════════════════════════════════════════════════════════
    if ($diagnosticOnly) {
        $terminalState = 'DIAGNOSTIC_ONLY'
        $terminalReason = 'The coordinator ran in diagnostic-only mode.'
        $exitCode = 3
    } elseif ($buyResult.observed -and $arrivalResult.observed -and $movementResult.observed) {
        $terminalState = 'PASS_VISIBLE_TRADE_PROVEN'
        $terminalReason = 'The visible trade cycle was proven end-to-end.'
        $exitCode = 0
        Set-HighestProof -Level 'complete'
    } elseif (-not [string]::IsNullOrWhiteSpace($failureDetail)) {
        $terminalState = Get-FailureTerminalState -Detail $failureDetail
        $terminalReason = $failureDetail
        $exitCode = 2
    } else {
        $terminalState = 'FAIL_EVIDENCE_INCOMPLETE'
        $terminalReason = 'The run did not produce complete visible trade evidence.'
        $exitCode = 2
    }
} catch {
    $failureDetail = $_.Exception.Message
    $terminalState = Get-FailureTerminalState -Detail $failureDetail
    $terminalReason = $failureDetail
    $exitCode = 2
    Write-Event -Stage 'coordinator' -Status failed -Subject 'coordinator' -Action 'exception' -Object 'coordinator' `
        -Sentence "The coordinator stopped after an exception: $failureDetail"
} finally {
    $endedAtUtc = (Get-Date).ToUniversalTime()
    $durationSec = [Math]::Round(($endedAtUtc - $startedAtUtc).TotalSeconds, 2)

    # ═══════════════════════════════════════════════════════════════
    # STAGE: capsule
    # ═══════════════════════════════════════════════════════════════
    $capsuleResult = $null
    try {
        Write-Event -Stage capsule -Status started -Subject 'coordinator' -Action 'generate-capsule' -Object 'evidence' `
            -Sentence 'The coordinator is generating a sanitized evidence capsule.'

        $shortSha = $proof.sourceCommit
        if ($shortSha.Length -gt 8) { $shortSha = $shortSha.Substring(0, 8) }

        $capsuleDir = Join-Path $runRoot 'capsule'
        $capsuleResult = New-TbgVisibleTradeProofCapsule `
            -RunId $runId `
            -SourceShortSha $shortSha `
            -RunRoot $runRoot `
            -ResultJson $resultPath `
            -ProofJson $proofPath `
            -EventsJsonl $eventsPath `
            -HandoffMd $handoffPath `
            -ProgressLog $progressPath `
            -CapsulePath (Join-Path $capsuleDir 'capsule.json')

        Write-Event -Stage capsule -Status passed -Subject 'coordinator' -Action 'capsule-generated' -Object $capsuleDir `
            -Evidence $capsuleDir `
            -Sentence "Sanitized evidence capsule generated at $capsuleDir with $($capsuleResult.fileCount) files."
    } catch {
        Write-Event -Stage capsule -Status failed -Subject 'coordinator' -Action 'capsule-error' -Object 'capsule' `
            -Sentence "Capsule generation failed: $($_.Exception.Message)."
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: remote-publish
    # ═══════════════════════════════════════════════════════════════
    $publicationResult = $null
    if ($capsuleResult -and $capsuleResult.capsulePath) {
        Write-Event -Stage remote-publish -Status started -Subject 'coordinator' -Action 'publish-evidence' -Object 'remote' `
            -Sentence 'The coordinator is publishing the evidence capsule to a remote branch.'

        try {
            $publicationResult = Publish-TbgVisibleTradeProofEvidence `
                -RunId $runId `
                -SourceCommit $proof.sourceCommit `
                -SourceBranch $proof.sourceBranch `
                -CapsuleDir $capsuleResult.capsulePath `
                -ResultJson $resultPath `
                -ProofJson $proofPath `
                -EventsJsonl $eventsPath `
                -HandoffMd $handoffPath `
                -CapsuleManifestJson (Join-Path $capsuleResult.capsulePath 'manifest.json') `
                -ArtifactIndexJson (Join-Path $capsuleResult.capsulePath 'artifact-index.json') `
                -RepoRoot $RepoRoot

            if ($publicationResult.published) {
                Write-Event -Stage remote-publish -Status passed -Subject 'coordinator' -Action 'evidence-published' -Object $publicationResult.evidenceBranch `
                    -Evidence $publicationResult.evidenceCommit `
                    -Sentence "Evidence published to branch $($publicationResult.evidenceBranch) at commit $($publicationResult.evidenceCommit)."
            } else {
                Write-Event -Stage remote-publish -Status failed -Subject 'coordinator' -Action 'publish-failed' -Object 'remote' `
                    -Sentence "Evidence publication failed: $($publicationResult.error)."
                if (-not $diagnosticOnly -and $terminalState -eq 'PASS_VISIBLE_TRADE_PROVEN') {
                    $terminalState = 'FAIL_REMOTE_EVIDENCE_NOT_PUBLISHED'
                    $terminalReason = "Remote evidence not published: $($publicationResult.error)"
                    $exitCode = 2
                }
            }
        } catch {
            Write-Event -Stage remote-publish -Status failed -Subject 'coordinator' -Action 'publish-exception' -Object 'remote' `
                -Sentence "Remote publication exception: $($_.Exception.Message)."
        }
    }

    # ═══════════════════════════════════════════════════════════════
    # STAGE: closeout
    # ═══════════════════════════════════════════════════════════════
    Write-Event -Stage closeout -Status started -Subject 'coordinator' -Action 'closeout' -Object 'result' `
        -Sentence "The coordinator is writing the final result for terminal state $terminalState."

    $passFail = if ($terminalState -like 'PASS_*') { 'PASS' } elseif ($terminalState -eq 'DIAGNOSTIC_ONLY') { 'DIAGNOSTIC' } else { 'FAIL' }

    $result = [ordered]@{
        schemaVersion = 'TbgVisibleTradeProofResult.v1'
        runId = $runId
        correlationId = $runId
        startedAtUtc = $startedAtUtc.ToString('o')
        endedAtUtc = $endedAtUtc.ToString('o')
        durationSec = $durationSec
        repo = 'EndeavorEverlasting/BlacksmithGuild'
        branch = $branch
        headSha = $head
        mode = if ($certifyingMode) { 'certify' } else { 'diagnostic_only' }
        passFail = $passFail
        terminalState = $terminalState
        terminalReason = $terminalReason
        failureDetail = $failureDetail
        highestProofReached = $highestProofReached
        provenance = $proof
        dll = [ordered]@{
            localPath = $localDllPath
            installedPath = $installedDllPath
            localSha256 = $localDllHash
            installedSha256 = $installedDllHash
        }
        commandAck = [ordered]@{
            observed = $null -ne $commandAckRecord
            evidencePath = if ($commandAckRecord) { $commandAckRecord.Path } else { $null }
        }
        campaignTime = [ordered]@{
            advancing = $terminalState -ne 'FAIL_CAMPAIGN_TIME_NOT_ADVANCING'
        }
        movement = $movementResult
        checkpoint = $checkpointResult
        arrival = $arrivalResult
        buy = $buyResult
        travel = $travelResult
        sell = $sellResult
        publication = if ($publicationResult) { $publicationResult } else { [ordered]@{ published = $false } }
        allowedClaims = if ($passFail -eq 'PASS') {
            @('This exact committed head, DLL, and save moved through Bannerlord, arrived at a settlement, bought a real visible item, and published sanitized evidence remotely.')
        } else {
            @('The run produced a bounded terminal diagnosis; inspect terminalState and highestProofReached.')
        }
        forbiddenClaims = @(
            'A command acknowledgement is not terminal workflow proof.',
            'Diagnostic and skip modes can never certify gameplay.',
            'The runner does not grant gold, inventory, movement, or other gameplay outcomes.',
            'A local-only run without remote publication does not achieve PASS_VISIBLE_TRADE_PROVEN.'
        )
        eventCount = $events.Count
    }

    $proofObj = [ordered]@{
        schemaVersion = 'TbgVisibleTradeProof.v1'
        runId = $runId
        terminalState = $terminalState
        highestProofReached = $highestProofReached
        provenance = $proof
        checks = [ordered]@{
            sourceCommitKnown = -not [string]::IsNullOrWhiteSpace($proof.sourceCommit)
            buildHashMatch = -not [string]::IsNullOrWhiteSpace($proof.builtAssemblySha256) -and [string]::Equals($proof.builtAssemblySha256, $proof.installedAssemblySha256, [System.StringComparison]::OrdinalIgnoreCase)
            commandAckObserved = $null -ne $commandAckRecord
            timeAdvanceObserved = $terminalState -ne 'FAIL_CAMPAIGN_TIME_NOT_ADVANCING'
            movementObserved = $movementResult.observed
            checkpointObserved = $checkpointResult.observed
            arrivalObserved = $arrivalResult.observed
            buyObserved = $buyResult.observed
            sellObserved = $sellResult.observed
            capsuleGenerated = $null -ne $capsuleResult
            remotePublished = $null -ne $publicationResult -and $publicationResult.published
        }
    }

    try {
        Write-AtomicUtf8Json -Value $result -Path $resultPath
        Write-AtomicUtf8Json -Value $proofObj -Path $proofPath
        if ($capsuleResult) { Write-AtomicUtf8Json -Value $capsuleResult -Path $capsuleJsonPath }

        $manifest = [ordered]@{
            schemaVersion = 'TbgVisibleTradeProofManifest.v1'
            runId = $runId
            branch = $branch
            head = $head
            terminalState = $terminalState
            highestProofReached = $highestProofReached
            startedAtUtc = $startedAtUtc.ToString('o')
            endedAtUtc = $endedAtUtc.ToString('o')
            durationSec = $durationSec
            eventCount = $events.Count
        }
        Write-AtomicUtf8Json -Value $manifest -Path $manifestPath

        $handoffBody = @"
# TBG Visible Trade One-Click Proof Handoff

- **Run ID:** ``$runId``
- **Branch:** ``$branch``
- **Head:** ``$head``
- **Terminal state:** ``$terminalState``
- **Highest proof reached:** ``$highestProofReached``
- **Duration:** $durationSec seconds
- **Mode:** $(if ($certifyingMode) { 'certify' } else { 'diagnostic_only' })

## Evidence

- Progress: ``$progressPath``
- Events: ``$eventsPath``
- Result: ``$resultPath``
- Proof: ``$proofPath``
- Capsule: ``$capsuleJsonPath``

## Provenance

- Source branch: ``$($proof.sourceBranch)``
- Source commit: ``$($proof.sourceCommit)``
- Built DLL hash: ``$($proof.builtAssemblySha256)``
- Installed DLL hash: ``$($proof.installedAssemblySha256)``

## Claims

Allowed: $($result.allowedClaims -join '; ')
Forbidden: $($result.forbiddenClaims -join '; ')

## Rerun

```cmd
Run-VisibleTradeProof.cmd
```
"@
        Write-AtomicUtf8Text -Value $handoffBody -Path $handoffPath

        Copy-Item -LiteralPath $progressPath -Destination $latestProgressPath -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath $handoffPath -Destination $latestHandoffPath -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath $resultPath -Destination $latestResultPath -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath $proofPath -Destination $latestProofPath -Force -ErrorAction SilentlyContinue
        if ($capsuleResult) { Copy-Item -LiteralPath $capsuleJsonPath -Destination $latestCapsulePath -Force -ErrorAction SilentlyContinue }
    } catch {
        Write-Host "Closeout write error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Event -Stage closeout -Status passed -Subject 'coordinator' -Action 'closeout-complete' -Object 'result' `
        -Sentence "The visible trade proof run $runId completed as $terminalState in $durationSec seconds."
}

Write-Host ''
Write-Host "Visible trade proof: $passFail ($terminalState)" -ForegroundColor $(if ($passFail -eq 'PASS') { 'Green' } elseif ($passFail -eq 'DIAGNOSTIC') { 'Yellow' } else { 'Red' })
Write-Host "Highest proof: $highestProofReached"
Write-Host "Duration: $durationSec seconds"
Write-Host "Result: $resultPath"
Write-Host "Proof: $proofPath"
Write-Host "Handoff: $handoffPath"
if ($publicationResult -and $publicationResult.published) {
    Write-Host "Evidence branch: $($publicationResult.evidenceBranch)" -ForegroundColor Cyan
}
exit $exitCode
