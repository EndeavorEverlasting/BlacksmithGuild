# Persistent multimodal supervisor for the launcher-validation workhorse.
# It treats dirty, ahead, diverged, or wrong-branch worktrees as mode-selection inputs,
# not immediate terminal failures. It never discards local work.

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [string]$ExpectedBranch = 'agent/route-automation-operator-plan',
    [ValidateSet('auto', 'current-first', 'remote-first', 'local-snapshot')]
    [string]$WorkspaceStrategy = 'auto',
    [ValidateRange(1, 4)]
    [int]$MaxWorkspaceModes = 4,
    [ValidateRange(1, 3)]
    [int]$FetchAttempts = 2,
    [switch]$SkipValidators,
    [switch]$SkipStop,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$runId = $startedAt.ToString('yyyyMMdd-HHmmss')
$originRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$runRoot = Join-Path $originRoot (Join-Path 'artifacts\latest\launcher-validation-supervisor' $runId)
$progressPath = Join-Path $runRoot 'progress.log'
$eventsPath = Join-Path $runRoot 'events.jsonl'
$handoffPath = Join-Path $runRoot 'handoff.md'
$resultPath = Join-Path $runRoot 'result.json'
$latestProgressPath = Join-Path $originRoot 'artifacts\latest\launcher-validation-supervisor.progress.log'
$latestHandoffPath = Join-Path $originRoot 'artifacts\latest\launcher-validation-supervisor.handoff.md'
$latestResultPath = Join-Path $originRoot 'artifacts\latest\launcher-validation-supervisor.result.json'
$stepRoot = Join-Path $runRoot 'steps'
New-Item -ItemType Directory -Force -Path $stepRoot | Out-Null

$sequence = 0
$modeAttempts = [System.Collections.Generic.List[object]]::new()
$artifacts = [System.Collections.Generic.List[string]]::new()
$risks = [System.Collections.Generic.List[string]]::new()
$selectedMode = ''
$executionRoot = ''
$executionBranch = ''
$executionHead = ''
$childState = ''
$childResultPath = ''
$terminalState = 'running'
$terminalReason = 'The supervisor has not reached a terminal state.'
$currentBranch = ''
$currentHead = ''
$dirtyEntries = @()
$ahead = 0
$behind = 0
$fetchSucceeded = $false
$remoteRef = 'origin/' + $ExpectedBranch
$remoteExists = $false

function Write-SupervisorEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Step,
        [Parameter(Mandatory = $true)][ValidateSet('STARTED', 'PASSED', 'FAILED', 'BLOCKED', 'SKIPPED', 'INFO', 'ADJUSTED')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Sentence,
        [string]$Evidence = ''
    )
    $script:sequence++
    $timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $line = '[{0}] {1}: {2}' -f $timestamp, $Status, $Sentence
    Add-Content -LiteralPath $progressPath -Value $line -Encoding UTF8
    Write-Host $line
    $event = [ordered]@{
        schema = 'TbgLauncherValidationSupervisorEvent.v1'
        timestampUtc = $timestamp
        sequence = $script:sequence
        step = $Step
        status = $Status.ToLowerInvariant()
        sentence = $Sentence
        evidence = $Evidence
    }
    Add-Content -LiteralPath $eventsPath -Value ($event | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}

function Invoke-GitRaw {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingRoot = $originRoot,
        [switch]$AllowFailure
    )
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        $output = & git -C $WorkingRoot @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw ('git -C "{0}" {1} returned exit code {2}: {3}' -f $WorkingRoot, ($Arguments -join ' '), $exitCode, (($output | Out-String).Trim()))
    }
    return [pscustomobject][ordered]@{
        exitCode = $exitCode
        output = @($output)
    }
}

function Write-TextArtifact {
    param([string]$Name, [object[]]$Content)
    $path = Join-Path $stepRoot $Name
    @($Content) | Set-Content -LiteralPath $path -Encoding UTF8
    $artifacts.Add($path) | Out-Null
    return $path
}

function Test-RemoteRef {
    $probe = Invoke-GitRaw -Arguments @('rev-parse', '--verify', $remoteRef) -AllowFailure
    return $probe.exitCode -eq 0
}

function Invoke-FetchWithRetry {
    if ($FetchAttempts -lt 1) { return $false }
    for ($attempt = 1; $attempt -le $FetchAttempts; $attempt++) {
        $logPath = Join-Path $stepRoot ('git-fetch-attempt-{0}.log' -f $attempt)
        Write-SupervisorEvent -Step 'git-fetch' -Status STARTED -Sentence ('The supervisor started remote fetch attempt {0} of {1}.' -f $attempt, $FetchAttempts) -Evidence $logPath
        $result = Invoke-GitRaw -Arguments @('fetch', 'origin', '--prune') -AllowFailure
        $result.output | Set-Content -LiteralPath $logPath -Encoding UTF8
        $artifacts.Add($logPath) | Out-Null
        if ($result.exitCode -eq 0) {
            Write-SupervisorEvent -Step 'git-fetch' -Status PASSED -Sentence ('The supervisor completed remote fetch attempt {0} successfully.' -f $attempt) -Evidence $logPath
            return $true
        }
        Write-SupervisorEvent -Step 'git-fetch' -Status FAILED -Sentence ('The supervisor could not complete remote fetch attempt {0}; it will adjust instead of stopping immediately.' -f $attempt) -Evidence $logPath
        if ($attempt -lt $FetchAttempts) { Start-Sleep -Seconds 1 }
    }
    return $false
}

function Get-RepoState {
    $inside = Invoke-GitRaw -Arguments @('rev-parse', '--is-inside-work-tree')
    if ((($inside.output -join '').Trim()) -ne 'true') { throw 'The supplied repository root is not a Git worktree.' }
    $script:currentBranch = (((Invoke-GitRaw -Arguments @('branch', '--show-current')).output -join '').Trim())
    $script:currentHead = (((Invoke-GitRaw -Arguments @('rev-parse', 'HEAD')).output -join '').Trim())
    $script:dirtyEntries = @((Invoke-GitRaw -Arguments @('status', '--porcelain=v1', '--untracked-files=all')).output)
    $dirtyPath = Write-TextArtifact -Name 'origin-worktree-status.txt' -Content $dirtyEntries
    Write-SupervisorEvent -Step 'repo-state' -Status INFO -Sentence ('The supervisor found branch "{0}" at commit {1} with {2} local status entry or entries.' -f $currentBranch, $currentHead, $dirtyEntries.Count) -Evidence $dirtyPath

    $script:remoteExists = Test-RemoteRef
    if ($remoteExists) {
        $counts = (((Invoke-GitRaw -Arguments @('rev-list', '--left-right', '--count', ('HEAD...' + $remoteRef))).output -join ' ').Trim()) -split '\s+'
        if ($counts.Count -ge 2) {
            $script:ahead = [int]$counts[0]
            $script:behind = [int]$counts[1]
        }
        Write-SupervisorEvent -Step 'git-comparison' -Status INFO -Sentence ('The current committed state is {0} commit or commits ahead and {1} commit or commits behind {2}.' -f $ahead, $behind, $remoteRef) -Evidence $remoteRef
    } else {
        $risks.Add(('The remote reference {0} was unavailable; the supervisor may use a local committed snapshot.' -f $remoteRef)) | Out-Null
        Write-SupervisorEvent -Step 'git-comparison' -Status ADJUSTED -Sentence ('The supervisor could not resolve {0}, so it retained the local committed snapshot as a fallback mode.' -f $remoteRef) -Evidence $currentHead
    }
}

function New-ModeCandidate {
    param(
        [string]$Mode,
        [string]$Reason,
        [string]$Ref = '',
        [string]$Root = '',
        [string]$Branch = ''
    )
    return [pscustomobject][ordered]@{
        mode = $Mode
        reason = $Reason
        ref = $Ref
        root = $Root
        branch = $Branch
    }
}

function Add-CandidateUnique {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$List,
        [Parameter(Mandatory = $true)]$Candidate
    )
    if (-not ($List | Where-Object { $_.mode -eq $Candidate.mode -and $_.ref -eq $Candidate.ref })) {
        $List.Add($Candidate) | Out-Null
    }
}

function Get-WorkspaceCandidates {
    $candidates = [System.Collections.Generic.List[object]]::new()
    $isCorrectBranch = $currentBranch -eq $ExpectedBranch
    $isClean = $dirtyEntries.Count -eq 0

    if ($WorkspaceStrategy -in @('auto', 'current-first')) {
        if ($isCorrectBranch -and $isClean -and $remoteExists -and $ahead -eq 0 -and $behind -eq 0) {
            Add-CandidateUnique -List $candidates -Candidate (New-ModeCandidate -Mode 'current_synced' -Reason 'The current worktree is clean and matches the remote sprint branch.' -Root $originRoot -Branch $ExpectedBranch)
        }
        if ($isCorrectBranch -and $isClean -and $ahead -gt 0 -and $behind -eq 0) {
            Add-CandidateUnique -List $candidates -Candidate (New-ModeCandidate -Mode 'current_local_commits' -Reason 'The current worktree is clean and contains unpublished committed work, so the supervisor will test it without rewriting it.' -Root $originRoot -Branch $ExpectedBranch)
        }
        if ($isCorrectBranch -and $isClean -and $remoteExists -and $ahead -eq 0 -and $behind -gt 0) {
            $ff = Invoke-GitRaw -Arguments @('merge', '--ff-only', $remoteRef) -AllowFailure
            $ffPath = Write-TextArtifact -Name 'git-fast-forward.log' -Content $ff.output
            if ($ff.exitCode -eq 0) {
                $script:currentHead = (((Invoke-GitRaw -Arguments @('rev-parse', 'HEAD')).output -join '').Trim())
                $script:behind = 0
                Write-SupervisorEvent -Step 'git-fast-forward' -Status PASSED -Sentence 'The supervisor fast-forwarded the clean current worktree without rewriting history.' -Evidence $ffPath
                Add-CandidateUnique -List $candidates -Candidate (New-ModeCandidate -Mode 'current_synced' -Reason 'The clean current worktree was safely fast-forwarded to the remote sprint branch.' -Root $originRoot -Branch $ExpectedBranch)
            } else {
                Write-SupervisorEvent -Step 'git-fast-forward' -Status ADJUSTED -Sentence 'The current worktree could not fast-forward safely, so the supervisor will try an isolated mode instead of stopping.' -Evidence $ffPath
            }
        }
    }

    if ($WorkspaceStrategy -in @('auto', 'remote-first', 'current-first') -and $remoteExists) {
        $reason = if ($dirtyEntries.Count -gt 0) {
            'The source worktree has local changes, so the supervisor will preserve them and use an isolated remote worktree.'
        } elseif ($currentBranch -ne $ExpectedBranch) {
            'The source worktree is on another branch, so the supervisor will use an isolated remote worktree.'
        } elseif ($ahead -gt 0 -and $behind -gt 0) {
            'The source branch has diverged, so the supervisor will use the remote head in an isolated worktree.'
        } else {
            'The isolated remote mode is available as a persistent fallback.'
        }
        Add-CandidateUnique -List $candidates -Candidate (New-ModeCandidate -Mode 'isolated_remote' -Reason $reason -Ref $remoteRef)
    }

    if ($WorkspaceStrategy -in @('auto', 'current-first', 'remote-first', 'local-snapshot') -and $currentHead) {
        Add-CandidateUnique -List $candidates -Candidate (New-ModeCandidate -Mode 'isolated_local_snapshot' -Reason 'The supervisor retained the current committed snapshot as a final non-destructive fallback.' -Ref $currentHead)
    }

    return @($candidates.ToArray() | Select-Object -First $MaxWorkspaceModes)
}

function New-IsolatedWorkspace {
    param(
        [Parameter(Mandatory = $true)][string]$Ref,
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][int]$Ordinal
    )
    $parent = Split-Path -Parent $originRoot
    $leaf = Split-Path -Leaf $originRoot
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $suffix = if ($attempt -eq 1) { '' } else { '-retry' }
        $path = Join-Path $parent ('{0}-launcher-worker-{1}-{2}{3}' -f $leaf, $runId, $Ordinal, $suffix)
        $workerBranch = 'tbg/launcher-worker/{0}-{1}-{2}' -f $runId, $Ordinal, $attempt
        Write-SupervisorEvent -Step 'workspace-create' -Status STARTED -Sentence ('The supervisor started isolated workspace creation attempt {0} for mode "{1}".' -f $attempt, $Mode) -Evidence $path
        $result = Invoke-GitRaw -Arguments @('worktree', 'add', '-b', $workerBranch, $path, $Ref) -AllowFailure
        $logPath = Write-TextArtifact -Name ('workspace-create-{0}-{1}.log' -f $Ordinal, $attempt) -Content $result.output
        if ($result.exitCode -eq 0) {
            Write-SupervisorEvent -Step 'workspace-create' -Status PASSED -Sentence ('The supervisor created isolated worktree "{0}" on local worker branch "{1}".' -f $path, $workerBranch) -Evidence $logPath
            return [pscustomobject][ordered]@{
                root = $path
                branch = $workerBranch
                head = (((Invoke-GitRaw -WorkingRoot $path -Arguments @('rev-parse', 'HEAD')).output -join '').Trim())
            }
        }
        Write-SupervisorEvent -Step 'workspace-create' -Status ADJUSTED -Sentence ('The supervisor could not create the first isolated path for mode "{0}" and will prune stale worktree metadata before one adjusted retry.' -f $Mode) -Evidence $logPath
        [void](Invoke-GitRaw -Arguments @('worktree', 'prune') -AllowFailure)
    }
    return $null
}

function Read-ChildResult {
    param([Parameter(Mandatory = $true)][string]$ChildRoot)
    $path = Join-Path $ChildRoot 'artifacts\latest\launcher-validation-workhorse.result.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Copy-ChildArtifacts {
    param([Parameter(Mandatory = $true)][string]$ChildRoot)
    foreach ($name in @(
        'launcher-validation-workhorse.progress.log',
        'launcher-validation-workhorse.handoff.md',
        'launcher-validation-workhorse.result.json'
    )) {
        $source = Join-Path $ChildRoot ('artifacts\latest\' + $name)
        if (Test-Path -LiteralPath $source) {
            $destination = Join-Path $runRoot $name
            Copy-Item -LiteralPath $source -Destination $destination -Force
            $artifacts.Add($destination) | Out-Null
        }
    }
}

function Invoke-LeafWorkhorse {
    param(
        [Parameter(Mandatory = $true)][string]$ChildRoot,
        [Parameter(Mandatory = $true)][string]$ChildBranch,
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][int]$Ordinal
    )
    $leafScript = Join-Path $ChildRoot 'scripts\run-launcher-validation-workhorse.ps1'
    if (-not (Test-Path -LiteralPath $leafScript)) {
        return [pscustomobject][ordered]@{ exitCode = 91; state = 'missing_leaf_workhorse'; result = $null; logPath = '' }
    }
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $leafScript,
        '-RepoRoot', $ChildRoot,
        '-LaunchIntent', $LaunchIntent,
        '-ExpectedBranch', $ChildBranch,
        '-SkipSync'
    )
    if ($SkipValidators) { $arguments += '-SkipValidators' }
    if ($SkipStop) { $arguments += '-SkipStop' }
    if ($NoLaunch) { $arguments += '-NoLaunch' }
    $logPath = Join-Path $stepRoot ('leaf-{0}-{1}.log' -f $Ordinal, $Mode)
    Write-SupervisorEvent -Step 'leaf-workhorse' -Status STARTED -Sentence ('The supervisor started the leaf launcher workhorse in workspace mode "{0}".' -f $Mode) -Evidence $logPath
    $global:LASTEXITCODE = 0
    $output = & powershell.exe @arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    @($output) | Set-Content -LiteralPath $logPath -Encoding UTF8
    $artifacts.Add($logPath) | Out-Null
    $output | ForEach-Object { Write-Host $_ }
    Copy-ChildArtifacts -ChildRoot $ChildRoot
    $child = Read-ChildResult -ChildRoot $ChildRoot
    $state = if ($child) { [string]$child.terminalState } elseif ($exitCode -eq 0) { 'leaf_exit_zero_without_result' } else { 'leaf_result_missing' }
    $status = if ($exitCode -eq 0) { 'PASSED' } else { 'FAILED' }
    Write-SupervisorEvent -Step 'leaf-workhorse' -Status $status -Sentence ('The leaf workhorse ended in state "{0}" with exit code {1} while using workspace mode "{2}".' -f $state, $exitCode, $Mode) -Evidence $logPath
    return [pscustomobject][ordered]@{
        exitCode = $exitCode
        state = $state
        result = $child
        logPath = $logPath
    }
}

function Test-WorkspaceRecoverableFailure {
    param([string]$State)
    return $State -like 'blocked_*' -or $State -in @('workhorse_exception', 'leaf_result_missing', 'missing_leaf_workhorse')
}

function Write-SupervisorResult {
    param([int]$ExitCode)
    $endedAt = Get-Date
    $durationSec = [Math]::Round(($endedAt - $startedAt).TotalSeconds, 2)
    $result = [ordered]@{
        schema = 'TbgLauncherValidationSupervisor.v1'
        runId = $runId
        startedAtUtc = $startedAt.ToUniversalTime().ToString('o')
        endedAtUtc = $endedAt.ToUniversalTime().ToString('o')
        durationSec = $durationSec
        originRoot = $originRoot
        expectedBranch = $ExpectedBranch
        observedBranch = $currentBranch
        observedHead = $currentHead
        dirtyEntryCount = $dirtyEntries.Count
        ahead = $ahead
        behind = $behind
        fetchSucceeded = $fetchSucceeded
        remoteRef = $remoteRef
        remoteExists = $remoteExists
        workspaceStrategy = $WorkspaceStrategy
        selectedMode = $selectedMode
        executionRoot = $executionRoot
        executionBranch = $executionBranch
        executionHead = $executionHead
        childState = $childState
        childResultPath = $childResultPath
        terminalState = $terminalState
        terminalReason = $terminalReason
        exitCode = $ExitCode
        progressLog = $progressPath
        eventsJsonl = $eventsPath
        handoff = $handoffPath
        modeAttempts = @($modeAttempts.ToArray())
        artifacts = @($artifacts.ToArray() | Select-Object -Unique)
        risks = @($risks.ToArray())
        proof = [ordered]@{
            contractProof = $true
            harnessProof = $true
            staticTestProof = ($childState -notin @('failed_static_validation', 'missing_leaf_workhorse'))
            launcherProof = ($childState -eq 'launcher_handoff_observed')
            commandAckProof = $false
            behaviorObservedProof = $false
            liveRuntimeProof = $false
        }
    }
    $result | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $resultPath -Encoding UTF8

    $attemptLines = [System.Collections.Generic.List[string]]::new()
    foreach ($attempt in $modeAttempts) {
        $attemptLines.Add(('- **{0}:** state `{1}`, exit {2}, root `{3}`.' -f $attempt.mode, $attempt.state, $attempt.exitCode, $attempt.root)) | Out-Null
    }
    if ($attemptLines.Count -eq 0) { $attemptLines.Add('- No workspace mode reached the leaf workhorse.') | Out-Null }
    $riskLines = [System.Collections.Generic.List[string]]::new()
    foreach ($risk in $risks) { $riskLines.Add(('- {0}' -f $risk)) | Out-Null }
    if ($riskLines.Count -eq 0) { $riskLines.Add('- No additional supervisor risk was recorded.') | Out-Null }

    @(
        '# TBG Multimodal Launcher Validation Supervisor Handoff',
        '',
        '## Context',
        '',
        ('- **Origin root:** `{0}`' -f $originRoot),
        ('- **Observed branch:** `{0}`' -f $currentBranch),
        ('- **Observed head:** `{0}`' -f $currentHead),
        ('- **Dirty entries preserved:** {0}' -f $dirtyEntries.Count),
        ('- **Ahead / behind:** {0} / {1}' -f $ahead, $behind),
        ('- **Workspace strategy:** `{0}`' -f $WorkspaceStrategy),
        ('- **Selected workspace mode:** `{0}`' -f $selectedMode),
        ('- **Execution root:** `{0}`' -f $executionRoot),
        ('- **Execution branch:** `{0}`' -f $executionBranch),
        ('- **Execution head:** `{0}`' -f $executionHead),
        ('- **Child state:** `{0}`' -f $childState),
        ('- **Terminal state:** `{0}`' -f $terminalState),
        ('- **Terminal reason:** {0}' -f $terminalReason),
        ('- **Duration:** {0} seconds' -f $durationSec),
        '',
        '## Workspace modes attempted',
        ''
    ) + @($attemptLines.ToArray()) + @(
        '',
        '## Persistence doctrine',
        '',
        '- A dirty worktree triggers isolated-remote mode instead of an immediate stop.',
        '- Clean unpublished commits trigger current-local-commits mode instead of an immediate stop.',
        '- Divergence or a wrong branch triggers isolated-remote mode.',
        '- Remote unavailability retains isolated-local-snapshot as a final committed-state fallback.',
        '- The supervisor never resets, cleans, stashes, force-pushes, deletes saves, deletes branches, or merges a pull request.',
        '',
        '## Risks and proof boundary',
        ''
    ) + @($riskLines.ToArray()) + @(
        '- Launcher handoff does not prove campaign readiness, command acknowledgement, movement, arrival, trading, or live gameplay success.',
        '',
        '## Artifacts to inspect first',
        '',
        ('1. `{0}`' -f $progressPath),
        ('2. `{0}`' -f $eventsPath),
        ('3. `{0}`' -f $resultPath),
        ('4. `{0}`' -f $childResultPath),
        '',
        '## Exact rerun command',
        '',
        '```powershell',
        '.\Run-LauncherValidationWorkhorse.cmd',
        '```'
    ) | Set-Content -LiteralPath $handoffPath -Encoding UTF8

    Copy-Item -LiteralPath $progressPath -Destination $latestProgressPath -Force
    Copy-Item -LiteralPath $handoffPath -Destination $latestHandoffPath -Force
    Copy-Item -LiteralPath $resultPath -Destination $latestResultPath -Force
}

try {
    Set-Location -LiteralPath $originRoot
    Write-SupervisorEvent -Step 'supervisor' -Status STARTED -Sentence 'The multimodal launcher-validation supervisor started and will adapt workspace modes instead of treating common concurrency states as terminal failures.' -Evidence $runRoot
    $fetchSucceeded = Invoke-FetchWithRetry
    if (-not $fetchSucceeded) {
        Write-SupervisorEvent -Step 'git-fetch' -Status ADJUSTED -Sentence 'The supervisor exhausted its bounded fetch retries and will continue with cached or local committed references when possible.' -Evidence $runRoot
    }
    Get-RepoState
    $candidates = @(Get-WorkspaceCandidates)
    if ($candidates.Count -eq 0) {
        throw 'The supervisor could not construct any safe workspace mode.'
    }

    $ordinal = 0
    foreach ($candidate in $candidates) {
        $ordinal++
        Write-SupervisorEvent -Step 'workspace-mode' -Status ADJUSTED -Sentence ('The supervisor selected workspace mode candidate "{0}" because {1}' -f $candidate.mode, $candidate.reason) -Evidence $candidate.ref
        $modeRoot = [string]$candidate.root
        $modeBranch = [string]$candidate.branch
        $modeHead = ''
        if ($candidate.mode -like 'isolated_*') {
            $workspace = New-IsolatedWorkspace -Ref $candidate.ref -Mode $candidate.mode -Ordinal $ordinal
            if (-not $workspace) {
                $modeAttempts.Add([pscustomobject][ordered]@{ mode = $candidate.mode; root = ''; branch = ''; head = ''; exitCode = 92; state = 'workspace_creation_failed'; reason = $candidate.reason }) | Out-Null
                Write-SupervisorEvent -Step 'workspace-mode' -Status FAILED -Sentence ('The supervisor could not create workspace mode "{0}" and will try the next safe mode.' -f $candidate.mode) -Evidence $runRoot
                continue
            }
            $modeRoot = [string]$workspace.root
            $modeBranch = [string]$workspace.branch
            $modeHead = [string]$workspace.head
        } else {
            $modeHead = (((Invoke-GitRaw -WorkingRoot $modeRoot -Arguments @('rev-parse', 'HEAD')).output -join '').Trim())
        }

        $leaf = Invoke-LeafWorkhorse -ChildRoot $modeRoot -ChildBranch $modeBranch -Mode $candidate.mode -Ordinal $ordinal
        $modeAttempts.Add([pscustomobject][ordered]@{
            mode = $candidate.mode
            root = $modeRoot
            branch = $modeBranch
            head = $modeHead
            exitCode = $leaf.exitCode
            state = $leaf.state
            reason = $candidate.reason
        }) | Out-Null
        if ($leaf.result) {
            $childResultPath = Join-Path $modeRoot 'artifacts\latest\launcher-validation-workhorse.result.json'
        }
        if ($leaf.exitCode -eq 0) {
            $selectedMode = $candidate.mode
            $executionRoot = $modeRoot
            $executionBranch = $modeBranch
            $executionHead = $modeHead
            $childState = $leaf.state
            $terminalState = 'supervisor_complete'
            $terminalReason = ('The supervisor completed the launcher-validation cycle using workspace mode "{0}".' -f $candidate.mode)
            Write-SupervisorResult -ExitCode 0
            exit 0
        }

        if (-not (Test-WorkspaceRecoverableFailure -State $leaf.state)) {
            $selectedMode = $candidate.mode
            $executionRoot = $modeRoot
            $executionBranch = $modeBranch
            $executionHead = $modeHead
            $childState = $leaf.state
            $terminalState = 'clear_semantic_dead_end'
            $terminalReason = ('The leaf workhorse reached the non-workspace dead end "{0}" after its own bounded retries.' -f $leaf.state)
            Write-SupervisorResult -ExitCode $leaf.exitCode
            exit $leaf.exitCode
        }

        Write-SupervisorEvent -Step 'workspace-mode' -Status ADJUSTED -Sentence ('Workspace mode "{0}" ended in recoverable state "{1}", so the supervisor will persist and try another safe mode.' -f $candidate.mode, $leaf.state) -Evidence $leaf.logPath
    }

    $terminalState = 'workspace_modes_exhausted'
    $terminalReason = 'The supervisor exhausted all safe workspace modes without discarding local work.'
    if ($modeAttempts.Count -gt 0) {
        $last = $modeAttempts[$modeAttempts.Count - 1]
        $selectedMode = [string]$last.mode
        $executionRoot = [string]$last.root
        $executionBranch = [string]$last.branch
        $executionHead = [string]$last.head
        $childState = [string]$last.state
    }
    Write-SupervisorResult -ExitCode 93
    exit 93
} catch {
    $risks.Add($_.Exception.Message) | Out-Null
    try {
        Write-SupervisorEvent -Step 'supervisor-exception' -Status FAILED -Sentence ('The supervisor stopped after an unhandled exception: {0}' -f $_.Exception.Message) -Evidence $runRoot
        $terminalState = 'supervisor_exception'
        $terminalReason = 'The supervisor preserved its evidence after an unhandled exception.'
        Write-SupervisorResult -ExitCode 99
    } catch { }
    exit 99
}
