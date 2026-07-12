# Static contract for the persistent multimodal launcher-validation supervisor.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Need {
    param([string]$Path, [string]$Needle)
    $text = Read-RepoText $Path
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$Path missing '$Needle'") | Out-Null
    }
}

function Forbid {
    param([string]$Path, [string]$Needle)
    $text = Read-RepoText $Path
    if ($text.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $failures.Add("$Path contains forbidden '$Needle'") | Out-Null
    }
}

$supervisor = 'scripts\run-launcher-validation-supervisor.ps1'
$leaf = 'scripts\run-launcher-validation-workhorse.ps1'
$cmd = 'Run-LauncherValidationWorkhorse.cmd'
$doc = 'docs\handoff\launcher-validation-workhorse.md'

foreach ($needle in @(
    'TbgLauncherValidationSupervisorEvent.v1',
    'TbgLauncherValidationSupervisor.v1',
    "[ValidateSet('auto', 'current-first', 'remote-first', 'local-snapshot')]",
    'MaxWorkspaceModes = 4',
    'FetchAttempts = 2',
    "Mode 'current_synced'",
    "Mode 'current_local_commits'",
    "Mode 'isolated_remote'",
    "Mode 'isolated_local_snapshot'",
    'git-comparison',
    "@('fetch', 'origin', '--prune')",
    "@('merge', '--ff-only', `$remoteRef)",
    "@('worktree', 'add', '-b', `$workerBranch, `$path, `$Ref)",
    "@('worktree', 'prune')",
    'workspace_creation_failed',
    'Test-WorkspaceRecoverableFailure',
    'recoverable state',
    'clear_semantic_dead_end',
    'workspace_modes_exhausted',
    'current worktree is clean and contains unpublished committed work',
    'source worktree has local changes',
    'source branch has diverged',
    'remote reference',
    'local committed snapshot',
    'run-launcher-validation-workhorse.ps1',
    '-SkipSync',
    'launcher-validation-supervisor.progress.log',
    'launcher-validation-supervisor.handoff.md',
    'launcher-validation-supervisor.result.json',
    'The supervisor never resets, cleans, stashes, force-pushes, deletes saves, deletes branches, or merges a pull request.'
)) { Need $supervisor $needle }

foreach ($needle in @(
    'git reset --hard',
    'git clean -',
    'git stash',
    'git push --force',
    'gh pr merge',
    'Remove-Item *sav',
    'worktree remove --force',
    'branch -D'
)) { Forbid $supervisor $needle }

Need $leaf 'blocked_dirty_worktree'
Need $leaf 'blocked_local_commits'
Need $leaf "@('merge', '--ff-only', `$remoteRef)"

foreach ($needle in @(
    'run-launcher-validation-supervisor.ps1',
    'Workspace modes: current synced, current local commits, isolated remote, and isolated local snapshot.',
    'launcher-validation-supervisor.progress.log',
    'launcher-validation-supervisor.handoff.md',
    'launcher-validation-supervisor.result.json',
    'resolves RepoRoot from its own tracked location'
)) { Need $cmd $needle }
Forbid $cmd 'run-launcher-validation-workhorse.ps1" %*'

foreach ($needle in @(
    '# Launcher Validation Workhorse',
    'Multimodal persistence',
    'current_synced',
    'current_local_commits',
    'isolated_remote',
    'isolated_local_snapshot',
    'Dirty does not mean stop',
    'Unpublished commits do not mean stop',
    'Divergence does not mean stop',
    'safe fast-forward',
    'concurrent worktrees',
    'does not reset or discard local work',
    'does not prove movement or trading',
    'TbgLauncherValidationSupervisor.v1'
)) { Need $doc $needle }

$supervisorText = Read-RepoText $supervisor
$modeCount = [regex]::Matches($supervisorText, "Mode '?(current_synced|current_local_commits|isolated_remote|isolated_local_snapshot)'?").Count
if ($modeCount -lt 4) {
    $failures.Add('multimodal supervisor must expose all four workspace modes explicitly') | Out-Null
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher validation supervisor contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher validation supervisor persists across dirty, ahead, diverged, wrong-branch, remote, and local-snapshot workspace states.' -ForegroundColor Green
exit 0
