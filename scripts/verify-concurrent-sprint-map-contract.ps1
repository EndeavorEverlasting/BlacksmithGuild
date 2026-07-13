# Offline verifier for the PR34 concurrent sprint map.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]
$dir = 'docs\concurrent-sprints\pr34-concurrent-sprint-map'

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Need {
    param([string]$Rel, [string]$Needle)
    $text = Read-RepoText -RelativePath $Rel
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$Rel missing '$Needle'") | Out-Null
    }
}

$readme = Join-Path $dir 'README.md'
$laneMap = Join-Path $dir 'lane-map.md'
$stack = Join-Path $dir 'active-pr-stack.md'
$worktree = Join-Path $dir 'agent-worktree-naming.md'
$localPath = Join-Path $dir 'local-path-contract.md'

Need $readme 'PR34 Concurrent Sprint Map'
Need $readme 'docs/concurrent-sprints/pr34-concurrent-sprint-map/'
Need $readme 'Branch: docs-concurrent-sprint-map'
Need $readme 'Base: agent-default-guardrail-implementation'
Need $readme 'runtime proof'
Need $readme 'merge readiness'
Need $readme 'local path role'
Need $readme 'intended worktree path'
Need $readme 'protected local main checkout status'
Need $readme 'BlacksmithGuild-prNN-short-description'
Need $readme 'local-path-contract.md'
Need $readme 'protected local main checkout is not a branch-work scratchpad'

Need $laneMap 'Lane A: Agent feedback and guardrail stack'
Need $laneMap 'Lane B: Launcher / route-owned clock / runtime proof'
Need $laneMap 'Lane C: Governor / campaign handoff'
Need $laneMap 'Lane D: Route/profile command contracts'
Need $laneMap 'Lane E: Economic loop / sell loop legacy branches'
Need $laneMap 'Default concurrent sprint rule'
Need $laneMap 'Local worktree rule'
Need $laneMap 'BlacksmithGuild = protected local main checkout'
Need $laneMap 'BlacksmithGuild-prNN-short-description = PR/lane worktree'
Need $laneMap 'branch switching inside the protected local main checkout'

Need $stack '#28 docs(agent): add feedback harness doctrine'
Need $stack '#33 feat(guardrails): add default guardrail implementation scripts'
Need $stack '#34 docs(concurrent): add PR-numbered sprint map'
Need $stack 'Stack rule'
Need $stack 'Local checkout collision rule'
Need $stack 'A stacked branch must not be validated by switching the protected local main checkout to that branch.'
Need $stack 'Wrong checkout can contaminate concurrent work'
Need $stack 'whether the protected local main checkout is untouched'
Need $stack 'Older open lanes observed'

Need $worktree 'BlacksmithGuild-pr34-concurrent-sprint-map'
Need $worktree 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord'
Need $worktree 'git worktree add'
Need $worktree 'docs-concurrent-sprint-map'
Need $worktree 'protected local main checkout'
Need $worktree 'local path role'
Need $worktree 'intended worktree path'
Need $worktree 'protected local main checkout untouched: yes/no'
Need $worktree 'should not provide destructive or branch-mutating commands'

Need $localPath '# Local Path Contract'
Need $localPath '<bannerlord-mods-parent>'
Need $localPath 'BlacksmithGuild\                         protected local main checkout'
Need $localPath 'BlacksmithGuild-prNN-short-description\  PR-specific worktree checkout'
Need $localPath 'Protected local main rule'
Need $localPath 'Agents must not tell the operator to run `git checkout`, `git switch`, patch commands, verifier runs, or generated apply scripts inside:'
Need $localPath 'PR worktrees must be siblings of the protected local main checkout'
Need $localPath 'Validation commands belong in the PR-specific worktree'
Need $localPath 'They are not interchangeable. Confusing them risks contaminating concurrent work.'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: concurrent sprint map contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: concurrent sprint map contract verified.' -ForegroundColor Green
