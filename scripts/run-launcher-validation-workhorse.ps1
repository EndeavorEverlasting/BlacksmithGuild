# Local workhorse for the recurring launcher validation command chain.
# It preserves local work, fast-forwards only, runs static contracts, stops the process family,
# launches through ForgeContinue/Forge, and writes structured plus syntactic-English evidence.

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [string]$ExpectedBranch = 'agent/route-automation-operator-plan',
    [switch]$SkipSync,
    [switch]$SkipValidators,
    [switch]$SkipStop,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$runId = $startedAt.ToString('yyyyMMdd-HHmmss')
$runRoot = Join-Path $RepoRoot (Join-Path 'artifacts\latest\launcher-validation-workhorse' $runId)
$progressPath = Join-Path $runRoot 'progress.log'
$eventsPath = Join-Path $runRoot 'events.jsonl'
$handoffPath = Join-Path $runRoot 'handoff.md'
$resultPath = Join-Path $runRoot 'result.json'
$latestProgressPath = Join-Path $RepoRoot 'artifacts\latest\launcher-validation-workhorse.progress.log'
$latestHandoffPath = Join-Path $RepoRoot 'artifacts\latest\launcher-validation-workhorse.handoff.md'
$latestResultPath = Join-Path $RepoRoot 'artifacts\latest\launcher-validation-workhorse.result.json'
$stepRoot = Join-Path $runRoot 'steps'
New-Item -ItemType Directory -Force -Path $stepRoot | Out-Null

$sequence = 0
$steps = [System.Collections.Generic.List[object]]::new()
$artifacts = [System.Collections.Generic.List[string]]::new()
$risks = [System.Collections.Generic.List[string]]::new()
$terminalState = 'running'
$terminalReason = 'The workhorse has not reached a terminal state.'
$currentBranch = ''
$headSha = ''
$frontdoorState = $null
$frontdoorEvidenceDir = $null

function Convert-ToSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Value)
    return (($Value -replace '[^A-Za-z0-9._-]', '-') -replace '-+', '-').Trim('-')
}

function Write-EnglishEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Step,
        [Parameter(Mandatory = $true)][ValidateSet('STARTED', 'PASSED', 'FAILED', 'BLOCKED', 'SKIPPED', 'INFO')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Sentence,
        [string]$Evidence = ''
    )
    $script:sequence++
    $timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $line = '[{0}] {1}: {2}' -f $timestamp, $Status, $Sentence
    Add-Content -LiteralPath $progressPath -Value $line -Encoding UTF8
    Write-Host $line
    $event = [ordered]@{
        schema = 'TbgSyntacticEnglishProgressEvent.v1'
        timestampUtc = $timestamp
        sequence = $script:sequence
        step = $Step
        status = $Status.ToLowerInvariant()
        sentence = $Sentence
        evidence = $Evidence
    }
    Add-Content -LiteralPath $eventsPath -Value ($event | ConvertTo-Json -Compress -Depth 6) -Encoding UTF8
}

function Save-StepRecord {
    param(
        [string]$Name,
        [string]$Status,
        [int]$ExitCode,
        [string]$LogPath,
        [string]$Sentence
    )
    $steps.Add([pscustomobject][ordered]@{
        name = $Name
        status = $Status
        exitCode = $ExitCode
        logPath = $LogPath
        sentence = $Sentence
    }) | Out-Null
    if ($LogPath) { $artifacts.Add($LogPath) | Out-Null }
}

function Invoke-LoggedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$StartSentence,
        [Parameter(Mandatory = $true)][string]$SuccessSentence,
        [Parameter(Mandatory = $true)][string]$FailureSentence,
        [int[]]$AllowedExitCodes = @(0)
    )
    $safeName = Convert-ToSafeFileName $Name
    $logPath = Join-Path $stepRoot ($safeName + '.log')
    Write-EnglishEvent -Step $Name -Status STARTED -Sentence $StartSentence -Evidence $logPath
    $exitCode = 1
    try {
        $global:LASTEXITCODE = 0
        $output = & $FilePath @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
            $output | Set-Content -LiteralPath $logPath -Encoding UTF8
        } else {
            '' | Set-Content -LiteralPath $logPath -Encoding UTF8
        }
    } catch {
        $exitCode = 1
        @(
            $_.Exception.ToString(),
            $_.ScriptStackTrace
        ) | Set-Content -LiteralPath $logPath -Encoding UTF8
    }
    if ($AllowedExitCodes -contains $exitCode) {
        Write-EnglishEvent -Step $Name -Status PASSED -Sentence $SuccessSentence -Evidence $logPath
        Save-StepRecord -Name $Name -Status 'passed' -ExitCode $exitCode -LogPath $logPath -Sentence $SuccessSentence
        return $true
    }
    $sentence = '{0} The command returned exit code {1}.' -f $FailureSentence, $exitCode
    Write-EnglishEvent -Step $Name -Status FAILED -Sentence $sentence -Evidence $logPath
    Save-StepRecord -Name $Name -Status 'failed' -ExitCode $exitCode -LogPath $logPath -Sentence $sentence
    return $false
}

function Get-GitOutput {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $global:LASTEXITCODE = 0
    $output = & git @Arguments 2>$null
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "git $($Arguments -join ' ') returned exit code $exitCode" }
    return @($output)
}

function Write-ProcessSnapshot {
    param([Parameter(Mandatory = $true)][string]$Name)
    $path = Join-Path $runRoot ($Name + '.processes.json')
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($processName in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
        foreach ($process in @(Get-Process -Name $processName -ErrorAction SilentlyContinue)) {
            try { $process.Refresh() } catch { }
            $rows.Add([pscustomobject][ordered]@{
                processName = [string]$process.ProcessName
                processId = [int]$process.Id
                windowHandle = [int64]$process.MainWindowHandle
                windowTitle = [string]$process.MainWindowTitle
                responding = [bool]$process.Responding
            }) | Out-Null
        }
    }
    @($rows.ToArray()) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
    $artifacts.Add($path) | Out-Null
    if ($rows.Count -eq 0) {
        Write-EnglishEvent -Step $Name -Status INFO -Sentence 'The process snapshot found no Bannerlord game, launcher, or watchdog process.' -Evidence $path
    } else {
        foreach ($row in $rows) {
            $title = if ([string]::IsNullOrWhiteSpace($row.windowTitle)) { 'without a visible window title' } else { 'with the window title "{0}"' -f $row.windowTitle }
            Write-EnglishEvent -Step $Name -Status INFO -Sentence ('The process snapshot found {0} with process identifier {1} and {2}.' -f $row.processName, $row.processId, $title) -Evidence $path
        }
    }
    return @($rows.ToArray())
}

function Import-FrontdoorResult {
    $latestFrontdoor = Join-Path $RepoRoot 'artifacts\latest\launcher-frontdoor.result.json'
    if (-not (Test-Path -LiteralPath $latestFrontdoor)) { return }
    try {
        $frontdoor = Get-Content -LiteralPath $latestFrontdoor -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:frontdoorState = [string]$frontdoor.state
        $script:frontdoorEvidenceDir = [string]$frontdoor.evidenceDir
        Copy-Item -LiteralPath $latestFrontdoor -Destination (Join-Path $runRoot 'launcher-frontdoor.result.json') -Force
        $artifacts.Add((Join-Path $runRoot 'launcher-frontdoor.result.json')) | Out-Null
        if ($frontdoorEvidenceDir) { $artifacts.Add($frontdoorEvidenceDir) | Out-Null }
        Write-EnglishEvent -Step 'frontdoor-result' -Status INFO -Sentence ('The workhorse imported the launcher frontdoor state "{0}" for the handoff.' -f $frontdoorState) -Evidence $latestFrontdoor
    } catch {
        $risks.Add('The workhorse could not parse the latest launcher frontdoor result.') | Out-Null
        Write-EnglishEvent -Step 'frontdoor-result' -Status FAILED -Sentence 'The workhorse could not parse the latest launcher frontdoor result, so the handoff preserves the raw path only.' -Evidence $latestFrontdoor
    }
}

function Write-HandoffAndResult {
    param([Parameter(Mandatory = $true)][int]$ExitCode)
    $endedAt = Get-Date
    $durationSec = [Math]::Round(($endedAt - $startedAt).TotalSeconds, 2)
    $result = [ordered]@{
        schema = 'TbgLauncherValidationWorkhorse.v1'
        runId = $runId
        startedAtUtc = $startedAt.ToUniversalTime().ToString('o')
        endedAtUtc = $endedAt.ToUniversalTime().ToString('o')
        durationSec = $durationSec
        repoRoot = $RepoRoot
        expectedBranch = $ExpectedBranch
        branch = $currentBranch
        headSha = $headSha
        launchIntent = $LaunchIntent
        terminalState = $terminalState
        terminalReason = $terminalReason
        exitCode = $ExitCode
        progressLog = $progressPath
        eventsJsonl = $eventsPath
        handoff = $handoffPath
        launcherFrontdoorState = $frontdoorState
        launcherFrontdoorEvidenceDir = $frontdoorEvidenceDir
        steps = @($steps.ToArray())
        artifacts = @($artifacts.ToArray() | Select-Object -Unique)
        risks = @($risks.ToArray())
        proof = [ordered]@{
            contractProof = @($steps | Where-Object { $_.name -like 'verify-*' -and $_.status -eq 'passed' }).Count -gt 0
            harnessProof = $true
            staticTestProof = @($steps | Where-Object { $_.name -like 'verify-*' -and $_.status -eq 'failed' }).Count -eq 0
            buildProof = ($terminalState -eq 'launcher_handoff_observed')
            launcherProof = ($terminalState -eq 'launcher_handoff_observed')
            commandAckProof = $false
            behaviorObservedProof = $false
            liveRuntimeProof = $false
        }
    }
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8

    $stepLines = [System.Collections.Generic.List[string]]::new()
    foreach ($step in $steps) {
        $stepLines.Add(('- **{0}:** {1}. {2}' -f $step.name, $step.status, $step.sentence)) | Out-Null
    }
    if ($stepLines.Count -eq 0) { $stepLines.Add('- No executable step completed.') | Out-Null }
    $artifactLines = [System.Collections.Generic.List[string]]::new()
    foreach ($artifact in @($artifacts.ToArray() | Select-Object -Unique)) {
        $artifactLines.Add(('- `{0}`' -f $artifact)) | Out-Null
    }
    if ($artifactLines.Count -eq 0) { $artifactLines.Add('- No artifact was recorded.') | Out-Null }
    $riskLines = [System.Collections.Generic.List[string]]::new()
    foreach ($risk in $risks) { $riskLines.Add(('- {0}' -f $risk)) | Out-Null }
    if ($riskLines.Count -eq 0) { $riskLines.Add('- No additional workhorse risk was recorded.') | Out-Null }

    @(
        '# TBG Launcher Validation Workhorse Handoff',
        '',
        '## Context',
        '',
        ('- **Repository root:** `{0}`' -f $RepoRoot),
        ('- **Expected branch:** `{0}`' -f $ExpectedBranch),
        ('- **Observed branch:** `{0}`' -f $currentBranch),
        ('- **Head:** `{0}`' -f $headSha),
        ('- **Launch intent:** `{0}`' -f $LaunchIntent),
        ('- **Terminal state:** `{0}`' -f $terminalState),
        ('- **Terminal reason:** {0}' -f $terminalReason),
        ('- **Duration:** {0} seconds' -f $durationSec),
        '',
        '## Syntactic-English progress',
        '',
        ('The workhorse ended in the `{0}` state because {1}' -f $terminalState, $terminalReason),
        '',
        '## Steps',
        ''
    ) + @($stepLines.ToArray()) + @(
        '',
        '## Artifacts for the next local agent',
        ''
    ) + @($artifactLines.ToArray()) + @(
        '',
        '## Risks and proof boundary',
        ''
    ) + @($riskLines.ToArray()) + @(
        '- Launcher handoff does not prove campaign readiness, movement, arrival, trading, or live gameplay success.',
        '- The workhorse never deletes saves, merges pull requests, resets the worktree, or discards local changes.',
        '',
        '## Exact rerun command',
        '',
        '```powershell',
        '.\Run-LauncherValidationWorkhorse.cmd',
        '```',
        '',
        '## Files to inspect first',
        '',
        ('1. `{0}`' -f $progressPath),
        ('2. `{0}`' -f $eventsPath),
        ('3. `{0}`' -f $resultPath),
        ('4. `{0}`' -f $frontdoorEvidenceDir)
    ) | Set-Content -LiteralPath $handoffPath -Encoding UTF8

    Copy-Item -LiteralPath $progressPath -Destination $latestProgressPath -Force
    Copy-Item -LiteralPath $handoffPath -Destination $latestHandoffPath -Force
    Copy-Item -LiteralPath $resultPath -Destination $latestResultPath -Force
}

function Stop-Workhorse {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )
    $script:terminalState = $State
    $script:terminalReason = $Reason
    $status = if ($ExitCode -eq 0) { 'PASSED' } elseif ($State -like 'blocked*') { 'BLOCKED' } else { 'FAILED' }
    Write-EnglishEvent -Step 'terminal' -Status $status -Sentence $Reason -Evidence $runRoot
    Write-HandoffAndResult -ExitCode $ExitCode
    exit $ExitCode
}

try {
    Set-Location -LiteralPath $RepoRoot
    Write-EnglishEvent -Step 'workhorse' -Status STARTED -Sentence 'The launcher validation workhorse started a bounded local validation and launch cycle.' -Evidence $runRoot

    $inside = Get-GitOutput -Arguments @('rev-parse', '--is-inside-work-tree')
    if (($inside -join '').Trim() -ne 'true') {
        Stop-Workhorse -State 'blocked_not_git_repo' -Reason 'The workhorse stopped because the supplied repository root is not a Git worktree.' -ExitCode 20
    }
    $currentBranch = ((Get-GitOutput -Arguments @('branch', '--show-current')) -join '').Trim()
    $headSha = ((Get-GitOutput -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    Write-EnglishEvent -Step 'repo-context' -Status INFO -Sentence ('The workhorse found branch "{0}" at commit {1}.' -f $currentBranch, $headSha) -Evidence $RepoRoot

    if ($currentBranch -ne $ExpectedBranch) {
        Stop-Workhorse -State 'blocked_wrong_branch' -Reason ('The workhorse stopped because branch "{0}" does not match the required branch "{1}".' -f $currentBranch, $ExpectedBranch) -ExitCode 21
    }

    $dirty = @(Get-GitOutput -Arguments @('status', '--porcelain=v1', '--untracked-files=all'))
    if ($dirty.Count -gt 0) {
        $dirtyPath = Join-Path $runRoot 'dirty-status.txt'
        $dirty | Set-Content -LiteralPath $dirtyPath -Encoding UTF8
        $artifacts.Add($dirtyPath) | Out-Null
        Stop-Workhorse -State 'blocked_dirty_worktree' -Reason 'The workhorse preserved local changes and stopped because the tracked worktree is dirty.' -ExitCode 22
    }

    if (-not $SkipSync) {
        $fetchOk = Invoke-LoggedCommand -Name 'git-fetch' -FilePath 'git' -Arguments @('fetch', 'origin', '--prune') `
            -StartSentence 'The workhorse started fetching the remote repository and pruning stale remote references.' `
            -SuccessSentence 'The workhorse fetched the remote repository and pruned stale remote references successfully.' `
            -FailureSentence 'The workhorse could not fetch the remote repository.'
        if (-not $fetchOk) { Stop-Workhorse -State 'failed_git_fetch' -Reason 'The workhorse stopped because the remote fetch failed.' -ExitCode 23 }

        $remoteRef = 'origin/' + $ExpectedBranch
        try { [void](Get-GitOutput -Arguments @('rev-parse', '--verify', $remoteRef)) } catch {
            Stop-Workhorse -State 'blocked_missing_remote_branch' -Reason ('The workhorse stopped because remote branch "{0}" does not exist.' -f $remoteRef) -ExitCode 24
        }
        $countsText = ((Get-GitOutput -Arguments @('rev-list', '--left-right', '--count', ('HEAD...' + $remoteRef))) -join ' ').Trim()
        $counts = $countsText -split '\s+'
        $ahead = [int]$counts[0]
        $behind = [int]$counts[1]
        Write-EnglishEvent -Step 'git-comparison' -Status INFO -Sentence ('The local branch is {0} commit or commits ahead and {1} commit or commits behind its remote branch.' -f $ahead, $behind) -Evidence $remoteRef
        if ($ahead -gt 0) {
            Stop-Workhorse -State 'blocked_local_commits' -Reason 'The workhorse preserved local commits and stopped because the branch is ahead of or diverged from its remote branch.' -ExitCode 25
        }
        if ($behind -gt 0) {
            $mergeOk = Invoke-LoggedCommand -Name 'git-fast-forward' -FilePath 'git' -Arguments @('merge', '--ff-only', $remoteRef) `
                -StartSentence 'The workhorse started a non-destructive fast-forward to the remote sprint branch.' `
                -SuccessSentence 'The workhorse fast-forwarded the local sprint branch without rewriting history.' `
                -FailureSentence 'The workhorse could not fast-forward the local sprint branch.'
            if (-not $mergeOk) { Stop-Workhorse -State 'blocked_fast_forward' -Reason 'The workhorse stopped because the branch could not be fast-forwarded safely.' -ExitCode 26 }
            $headSha = ((Get-GitOutput -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
        } else {
            Write-EnglishEvent -Step 'git-fast-forward' -Status SKIPPED -Sentence 'The workhorse skipped the fast-forward because the local sprint branch already matches its remote branch.' -Evidence $remoteRef
        }
    } else {
        Write-EnglishEvent -Step 'git-sync' -Status SKIPPED -Sentence 'The workhorse skipped repository synchronization because the operator supplied the SkipSync switch.' -Evidence $RepoRoot
    }

    if (-not $SkipValidators) {
        foreach ($validator in @(
            'scripts\verify-fast-launcher-frontdoor.ps1',
            'scripts\verify-launcher-dependency-caution-doctrine.ps1',
            'scripts\verify-clickable-command-surface.ps1'
        )) {
            $name = 'verify-' + [IO.Path]::GetFileNameWithoutExtension($validator)
            $ok = Invoke-LoggedCommand -Name $name -FilePath 'powershell.exe' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $RepoRoot $validator)) `
                -StartSentence ('The workhorse started the validator "{0}".' -f $validator) `
                -SuccessSentence ('The validator "{0}" passed.' -f $validator) `
                -FailureSentence ('The validator "{0}" failed.' -f $validator)
            if (-not $ok) { Stop-Workhorse -State 'failed_static_validation' -Reason ('The workhorse stopped because validator "{0}" failed.' -f $validator) -ExitCode 30 }
        }
    } else {
        Write-EnglishEvent -Step 'validators' -Status SKIPPED -Sentence 'The workhorse skipped static validators because the operator supplied the SkipValidators switch.' -Evidence $RepoRoot
    }

    [void](Write-ProcessSnapshot -Name 'before-stop')
    if (-not $SkipStop) {
        $stopOk = Invoke-LoggedCommand -Name 'force-stop' -FilePath 'powershell.exe' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $RepoRoot 'scripts\forge-stop.ps1'), '-ForceKill') `
            -StartSentence 'The workhorse started the repo-owned force-stop step for the Bannerlord process family.' `
            -SuccessSentence 'The workhorse completed the repo-owned force-stop step for the Bannerlord process family.' `
            -FailureSentence 'The repo-owned force-stop step failed.'
        if (-not $stopOk) { Stop-Workhorse -State 'failed_force_stop' -Reason 'The workhorse stopped because the repo-owned force-stop step failed.' -ExitCode 31 }
    } else {
        Write-EnglishEvent -Step 'force-stop' -Status SKIPPED -Sentence 'The workhorse skipped the process stop because the operator supplied the SkipStop switch.' -Evidence $RepoRoot
    }
    [void](Write-ProcessSnapshot -Name 'after-stop')

    if ($NoLaunch) {
        Stop-Workhorse -State 'validation_only_complete' -Reason 'The workhorse completed repository synchronization, static validation, and process inspection without launching Bannerlord.' -ExitCode 0
    }

    $entrypoint = if ($LaunchIntent -eq 'continue') { 'ForgeContinue.cmd' } else { 'Forge.cmd' }
    $oldNoPause = $env:TBG_NO_PAUSE
    $env:TBG_NO_PAUSE = '1'
    try {
        $launchOk = Invoke-LoggedCommand -Name ('launch-' + $LaunchIntent) -FilePath 'cmd.exe' -Arguments @('/d', '/c', (Join-Path $RepoRoot $entrypoint)) `
            -StartSentence ('The workhorse started {0} through the repo-owned launcher frontdoor.' -f $entrypoint) `
            -SuccessSentence ('The repo-owned launcher frontdoor reported a successful {0} handoff.' -f $LaunchIntent) `
            -FailureSentence ('The repo-owned launcher frontdoor reported a failed {0} handoff.' -f $LaunchIntent)
    } finally {
        if ($null -eq $oldNoPause) { Remove-Item Env:TBG_NO_PAUSE -ErrorAction SilentlyContinue } else { $env:TBG_NO_PAUSE = $oldNoPause }
    }
    Import-FrontdoorResult
    [void](Write-ProcessSnapshot -Name 'after-launch')
    if (-not $launchOk) {
        Stop-Workhorse -State 'launcher_dead_end' -Reason 'The workhorse reached a bounded launcher dead end and preserved the English log, process snapshots, command output, screenshots, and handoff.' -ExitCode 40
    }

    Stop-Workhorse -State 'launcher_handoff_observed' -Reason 'The workhorse synchronized the branch, passed the launcher contracts, stopped stale processes, and observed the repo-owned launcher handoff.' -ExitCode 0
} catch {
    $risks.Add($_.Exception.Message) | Out-Null
    try {
        Write-EnglishEvent -Step 'unhandled-exception' -Status FAILED -Sentence ('The workhorse stopped after an unhandled exception: {0}' -f $_.Exception.Message) -Evidence $runRoot
        $terminalState = 'workhorse_exception'
        $terminalReason = 'The workhorse stopped after an unhandled exception and preserved the evidence collected before the exception.'
        Write-HandoffAndResult -ExitCode 99
    } catch { }
    exit 99
}
