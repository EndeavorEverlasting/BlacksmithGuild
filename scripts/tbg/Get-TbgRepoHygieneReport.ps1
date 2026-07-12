<#
.SYNOPSIS
    Writes a read-only repository hygiene report.

.DESCRIPTION
    Captures branch, HEAD, dirty/conflicted state, in-progress Git operations,
    worktrees, local branch tracking state, remotes, and optional open pull
    requests. The command writes Markdown and JSON reports under artifacts/latest
    by default.

    This script does not reset, clean, delete, merge, rebase, launch Bannerlord,
    run ForgeReboot, write command inbox files, mutate saves, or claim runtime proof.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [string]$OutPath = 'artifacts/latest/repo-hygiene-report.md',
    [string]$JsonOutPath = 'artifacts/latest/repo-hygiene-report.json',
    [ValidateRange(1, 100)]
    [int]$PrLimit = 20,
    [switch]$NoGitHub,
    [switch]$FailOnBlocked
)

$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).TrimEnd()

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $rendered = "$FilePath $($Arguments -join ' ')"
        throw "Command failed with exit code $exitCode: $rendered`n$text"
    }

    return [pscustomobject]@{
        filePath = $FilePath
        arguments = @($Arguments)
        exitCode = $exitCode
        output = $text
    }
}

function Resolve-RepositoryRoot {
    param([string]$Path)

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    Push-Location -LiteralPath $resolvedPath
    try {
        $result = Invoke-NativeCommand -FilePath 'git' -Arguments @('rev-parse', '--show-toplevel')
        return $result.output.Trim()
    }
    finally {
        Pop-Location
    }
}

function Get-GitOperationState {
    $operationPaths = @(
        [pscustomobject]@{ name = 'merge'; gitPath = 'MERGE_HEAD' },
        [pscustomobject]@{ name = 'cherry-pick'; gitPath = 'CHERRY_PICK_HEAD' },
        [pscustomobject]@{ name = 'revert'; gitPath = 'REVERT_HEAD' },
        [pscustomobject]@{ name = 'bisect'; gitPath = 'BISECT_LOG' },
        [pscustomobject]@{ name = 'rebase-merge'; gitPath = 'rebase-merge' },
        [pscustomobject]@{ name = 'rebase-apply'; gitPath = 'rebase-apply' }
    )

    $active = New-Object System.Collections.Generic.List[object]
    foreach ($operation in $operationPaths) {
        $pathResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('rev-parse', '--git-path', $operation.gitPath) -AllowFailure
        if ($pathResult.exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($pathResult.output)) {
            $resolvedOperationPath = $pathResult.output.Trim()
            if (Test-Path -LiteralPath $resolvedOperationPath) {
                $active.Add([pscustomobject]@{
                    name = $operation.name
                    path = $resolvedOperationPath
                }) | Out-Null
            }
        }
    }

    return @($active.ToArray())
}

function ConvertFrom-WorktreePorcelain {
    param([string]$Text)

    $records = New-Object System.Collections.Generic.List[object]
    $current = $null

    foreach ($line in ($Text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($null -ne $current) {
                $records.Add([pscustomobject]$current) | Out-Null
                $current = $null
            }
            continue
        }

        if ($line.StartsWith('worktree ')) {
            if ($null -ne $current) {
                $records.Add([pscustomobject]$current) | Out-Null
            }
            $current = [ordered]@{
                path = $line.Substring(9)
                head = ''
                branch = ''
                detached = $false
                bare = $false
                locked = $false
                lockReason = ''
                prunable = $false
                pruneReason = ''
            }
            continue
        }

        if ($null -eq $current) {
            continue
        }

        if ($line.StartsWith('HEAD ')) {
            $current.head = $line.Substring(5)
        }
        elseif ($line.StartsWith('branch ')) {
            $current.branch = $line.Substring(7) -replace '^refs/heads/', ''
        }
        elseif ($line -eq 'detached') {
            $current.detached = $true
        }
        elseif ($line -eq 'bare') {
            $current.bare = $true
        }
        elseif ($line.StartsWith('locked')) {
            $current.locked = $true
            if ($line.Length -gt 6) {
                $current.lockReason = $line.Substring(7)
            }
        }
        elseif ($line.StartsWith('prunable')) {
            $current.prunable = $true
            if ($line.Length -gt 8) {
                $current.pruneReason = $line.Substring(9)
            }
        }
    }

    if ($null -ne $current) {
        $records.Add([pscustomobject]$current) | Out-Null
    }

    return @($records.ToArray())
}

function ConvertFrom-BranchRows {
    param([string]$Text)

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($line in ($Text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split '\|', 4
        while ($parts.Count -lt 4) {
            $parts += ''
        }

        $records.Add([pscustomobject]@{
            name = $parts[0]
            head = $parts[1]
            upstream = $parts[2]
            upstreamTrack = $parts[3]
            upstreamGone = ($parts[3] -match '\[gone\]')
        }) | Out-Null
    }

    return @($records.ToArray())
}

function Write-MarkdownCodeBlock {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Title,
        [AllowEmptyString()][string]$Text
    )

    $Lines.Add('') | Out-Null
    $Lines.Add("## $Title") | Out-Null
    $Lines.Add('') | Out-Null
    $Lines.Add('````text') | Out-Null
    $Lines.Add($Text) | Out-Null
    $Lines.Add('````') | Out-Null
}

$repoRootResolved = Resolve-RepositoryRoot -Path $RepoRoot
Set-Location -LiteralPath $repoRootResolved

$branchResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('branch', '--show-current')
$headResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('rev-parse', 'HEAD')
$logResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('log', '--oneline', '--decorate', '-5')
$statusResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('status', '--short')
$statusPorcelainResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('status', '--porcelain=v2', '--branch')
$conflictResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('diff', '--name-only', '--diff-filter=U')
$worktreeResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('worktree', 'list', '--porcelain')
$branchRowsResult = Invoke-NativeCommand -FilePath 'git' -Arguments @(
    'for-each-ref',
    '--format=%(refname:short)|%(objectname)|%(upstream:short)|%(upstream:track)',
    'refs/heads'
)
$remoteResult = Invoke-NativeCommand -FilePath 'git' -Arguments @('remote', '-v') -AllowFailure
$upstreamResult = Invoke-NativeCommand -FilePath 'git' -Arguments @(
    'rev-parse',
    '--abbrev-ref',
    '--symbolic-full-name',
    '@{upstream}'
) -AllowFailure

$upstream = ''
$ahead = $null
$behind = $null
if ($upstreamResult.exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstreamResult.output)) {
    $upstream = $upstreamResult.output.Trim()
    $aheadBehindResult = Invoke-NativeCommand -FilePath 'git' -Arguments @(
        'rev-list',
        '--left-right',
        '--count',
        "$upstream...HEAD"
    ) -AllowFailure

    if ($aheadBehindResult.exitCode -eq 0 -and $aheadBehindResult.output -match '^\s*(\d+)\s+(\d+)\s*$') {
        $behind = [int]$Matches[1]
        $ahead = [int]$Matches[2]
    }
}

$dirtyPaths = @(
    $statusResult.output -split "`r?`n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$conflictedFiles = @(
    $conflictResult.output -split "`r?`n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$operations = @(Get-GitOperationState)
$worktrees = @(ConvertFrom-WorktreePorcelain -Text $worktreeResult.output)
$branches = @(ConvertFrom-BranchRows -Text $branchRowsResult.output)
$goneUpstreams = @($branches | Where-Object { $_.upstreamGone })
$prunableWorktrees = @($worktrees | Where-Object { $_.prunable })

$github = [ordered]@{
    available = $false
    attempted = (-not $NoGitHub)
    error = ''
    openPullRequests = @()
}

if (-not $NoGitHub) {
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -ne $ghCommand) {
        $github.available = $true
        $prResult = Invoke-NativeCommand -FilePath 'gh' -Arguments @(
            'pr',
            'list',
            '--state',
            'open',
            '--limit',
            [string]$PrLimit,
            '--json',
            'number,title,state,isDraft,baseRefName,headRefName,mergeable,url,headRefOid'
        ) -AllowFailure

        if ($prResult.exitCode -eq 0) {
            try {
                $github.openPullRequests = @($prResult.output | ConvertFrom-Json)
            }
            catch {
                $github.error = "Unable to parse gh pr list JSON: $($_.Exception.Message)"
            }
        }
        else {
            $github.error = "gh pr list failed with exit code $($prResult.exitCode): $($prResult.output)"
        }
    }
    else {
        $github.error = 'GitHub CLI not found on PATH.'
    }
}

$verdict = 'CLEAN'
$blockedReason = ''
$nextCommand = 'git log --oneline --decorate -5'

if ($operations.Count -gt 0) {
    $verdict = 'BLOCKED'
    $blockedReason = "Git operation in progress: $((@($operations.name) -join ', '))"
    $nextCommand = 'git status --short --branch'
}
elseif ($conflictedFiles.Count -gt 0) {
    $verdict = 'BLOCKED'
    $blockedReason = 'Repository has unmerged files.'
    $nextCommand = 'git diff --name-only --diff-filter=U'
}
elseif ($dirtyPaths.Count -gt 0) {
    $verdict = 'ATTENTION'
    $blockedReason = 'Repository has tracked or untracked changes.'
    $nextCommand = 'git status --short'
}
elseif ($prunableWorktrees.Count -gt 0) {
    $verdict = 'ATTENTION'
    $blockedReason = 'One or more worktrees are marked prunable; inspect before pruning.'
    $nextCommand = 'git worktree list --porcelain'
}
elseif ($goneUpstreams.Count -gt 0) {
    $verdict = 'ATTENTION'
    $blockedReason = 'One or more local branches track deleted upstream refs; inspect reachability before deletion.'
    $nextCommand = 'git branch -vv'
}

$report = [ordered]@{
    schema = 'TbgRepoHygieneReport.v1'
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    repoRoot = $repoRootResolved
    branch = $branchResult.output.Trim()
    head = $headResult.output.Trim()
    upstream = $upstream
    ahead = $ahead
    behind = $behind
    verdict = $verdict
    blockedReason = $blockedReason
    nextCommand = $nextCommand
    dirtyPaths = @($dirtyPaths)
    conflictedFiles = @($conflictedFiles)
    operations = @($operations)
    worktrees = @($worktrees)
    localBranches = @($branches)
    goneUpstreams = @($goneUpstreams)
    prunableWorktrees = @($prunableWorktrees)
    openPullRequests = @($github.openPullRequests)
    github = [pscustomobject]$github
    raw = [ordered]@{
        log = $logResult.output
        statusShort = $statusResult.output
        statusPorcelainV2 = $statusPorcelainResult.output
        remotes = $remoteResult.output
        worktreePorcelain = $worktreeResult.output
    }
    boundaries = [ordered]@{
        modifiesTrackedFiles = $false
        resetsRepository = $false
        cleansRepository = $false
        deletesBranches = $false
        removesWorktrees = $false
        launchesBannerlord = $false
        runsForgeReboot = $false
        writesCommandInbox = $false
        mutatesSaves = $false
        claimsRuntimeProof = $false
    }
}

$outDirectory = Split-Path -Parent $OutPath
$jsonOutDirectory = Split-Path -Parent $JsonOutPath
if (-not [string]::IsNullOrWhiteSpace($outDirectory)) {
    New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
}
if (-not [string]::IsNullOrWhiteSpace($jsonOutDirectory)) {
    New-Item -ItemType Directory -Force -Path $jsonOutDirectory | Out-Null
}

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonOutPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# TBG Repository Hygiene Report') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("Generated: $($report.generatedAt)") | Out-Null
$lines.Add("Repo: $repoRootResolved") | Out-Null
$lines.Add("Branch: $($report.branch)") | Out-Null
$lines.Add("HEAD: $($report.head)") | Out-Null
if (-not [string]::IsNullOrWhiteSpace($upstream)) {
    $lines.Add("Upstream: $upstream (ahead=$ahead, behind=$behind)") | Out-Null
}
$lines.Add("Verdict: $verdict") | Out-Null
if (-not [string]::IsNullOrWhiteSpace($blockedReason)) {
    $lines.Add("Reason: $blockedReason") | Out-Null
}
$lines.Add("Next command: $nextCommand") | Out-Null
$lines.Add('') | Out-Null
$lines.Add('Boundaries: read-only repository inspection; no reset, clean, deletion, runtime launch, inbox/save mutation, or runtime proof claim.') | Out-Null

Write-MarkdownCodeBlock -Lines $lines -Title 'Recent commits' -Text $logResult.output
Write-MarkdownCodeBlock -Lines $lines -Title 'Status' -Text $statusResult.output
Write-MarkdownCodeBlock -Lines $lines -Title 'Conflicted files' -Text ($conflictedFiles -join "`n")
Write-MarkdownCodeBlock -Lines $lines -Title 'Operations in progress' -Text (($operations | ConvertTo-Json -Depth 5) | Out-String).TrimEnd()
Write-MarkdownCodeBlock -Lines $lines -Title 'Worktrees' -Text (($worktrees | ConvertTo-Json -Depth 5) | Out-String).TrimEnd()
Write-MarkdownCodeBlock -Lines $lines -Title 'Local branches' -Text (($branches | ConvertTo-Json -Depth 5) | Out-String).TrimEnd()
Write-MarkdownCodeBlock -Lines $lines -Title 'Open pull requests' -Text (($github.openPullRequests | ConvertTo-Json -Depth 6) | Out-String).TrimEnd()

(($lines -join "`n") + "`n") | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host "Repository hygiene report written: $OutPath"
Write-Host "Repository hygiene JSON written:   $JsonOutPath"
Write-Host "Verdict: $verdict"
if (-not [string]::IsNullOrWhiteSpace($blockedReason)) {
    Write-Host "Reason: $blockedReason"
}
Write-Host "Next command: $nextCommand"

if ($FailOnBlocked -and $verdict -eq 'BLOCKED') {
    exit 2
}
