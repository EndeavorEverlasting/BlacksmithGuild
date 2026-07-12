# Static contract for the local launcher validation workhorse.
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

$cmd = 'Run-LauncherValidationWorkhorse.cmd'
$workhorse = 'scripts\run-launcher-validation-workhorse.ps1'
$doc = 'docs\handoff\launcher-validation-workhorse.md'

foreach ($needle in @(
    'Launcher Validation Workhorse',
    'run-launcher-validation-workhorse.ps1',
    'launcher-validation-workhorse.progress.log',
    'launcher-validation-workhorse.handoff.md',
    'launcher-validation-workhorse.result.json',
    'if not defined TBG_NO_PAUSE pause',
    'resolves RepoRoot from its own tracked location'
)) { Need $cmd $needle }
Forbid $cmd '-RepoRoot "%~dp0"'
Forbid $cmd 'git reset --hard'

foreach ($needle in @(
    'TbgSyntacticEnglishProgressEvent.v1',
    'TbgLauncherValidationWorkhorse.v1',
    'Write-EnglishEvent',
    'progress.log',
    'events.jsonl',
    'handoff.md',
    'result.json',
    'git',
    "@('fetch', 'origin', '--prune')",
    "@('merge', '--ff-only', `$remoteRef)",
    "@('status', '--porcelain=v1', '--untracked-files=all')",
    'blocked_dirty_worktree',
    'blocked_local_commits',
    'verify-fast-launcher-frontdoor.ps1',
    'verify-launcher-dependency-caution-doctrine.ps1',
    'verify-clickable-command-surface.ps1',
    'forge-stop.ps1',
    '-ForceKill',
    'TBG_NO_PAUSE',
    'ForgeContinue.cmd',
    'Forge.cmd',
    'Import-FrontdoorResult',
    'Write-ProcessSnapshot',
    'launcher_handoff_observed',
    'launcher_dead_end',
    'Launcher handoff does not prove campaign readiness, movement, arrival, trading, or live gameplay success.',
    'The workhorse never deletes saves, merges pull requests, resets the worktree, or discards local changes.'
)) { Need $workhorse $needle }

foreach ($needle in @(
    'git reset --hard',
    'git clean',
    'Remove-Item *sav',
    'gh pr merge',
    'git push --force',
    'runtimeProofClaim = $true',
    'liveRuntimeProof = $true'
)) { Forbid $workhorse $needle }

$workhorseText = Read-RepoText $workhorse
$eventMatches = [regex]::Matches($workhorseText, "Write-EnglishEvent[^\r\n]*-Sentence\s+('([^']|'')*'|\([^\r\n]+\))")
if ($eventMatches.Count -lt 12) {
    $failures.Add('launcher workhorse must emit a useful sequence of syntactic-English progress events') | Out-Null
}

foreach ($needle in @(
    '# Launcher Validation Workhorse',
    'Syntactic-English progress',
    'safe fast-forward',
    'concurrent worktrees',
    'progress.log',
    'events.jsonl',
    'handoff.md',
    'result.json',
    'Run-LauncherValidationWorkhorse.cmd',
    'does not reset or discard local work',
    'does not prove movement or trading'
)) { Need $doc $needle }

if ($failures.Count -gt 0) {
    Write-Host "FAIL: launcher validation workhorse contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: launcher validation workhorse, syntactic-English progress, safe concurrency, evidence, and handoff contract verified.' -ForegroundColor Green
exit 0
