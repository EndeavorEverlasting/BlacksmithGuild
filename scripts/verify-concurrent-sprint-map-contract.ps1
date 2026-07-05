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

Need $readme 'PR34 Concurrent Sprint Map'
Need $readme 'docs/concurrent-sprints/pr34-concurrent-sprint-map/'
Need $readme 'Branch: docs-concurrent-sprint-map'
Need $readme 'Base: agent-default-guardrail-implementation'
Need $readme 'runtime proof'
Need $readme 'merge readiness'

Need $laneMap 'Lane A: Agent feedback and guardrail stack'
Need $laneMap 'Lane B: Launcher / route-owned clock / runtime proof'
Need $laneMap 'Lane C: Governor / campaign handoff'
Need $laneMap 'Lane D: Route/profile command contracts'
Need $laneMap 'Lane E: Economic loop / sell loop legacy branches'
Need $laneMap 'Default concurrent sprint rule'

Need $stack '#28 docs(agent): add feedback harness doctrine'
Need $stack '#33 feat(guardrails): add default guardrail implementation scripts'
Need $stack '#34 docs(concurrent): add PR-numbered sprint map'
Need $stack 'Stack rule'
Need $stack 'Older open lanes observed'

Need $worktree 'BlacksmithGuild-pr34-concurrent-sprint-map'
Need $worktree 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord'
Need $worktree 'git worktree add'
Need $worktree 'docs-concurrent-sprint-map'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: concurrent sprint map contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: concurrent sprint map contract verified.' -ForegroundColor Green
