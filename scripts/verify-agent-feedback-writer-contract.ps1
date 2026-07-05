# Offline contract verifier for the agent feedback writer.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("missing file: $RelativePath") | Out-Null
        return ''
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing '$Needle'$suffix") | Out-Null
    }
}

function Assert-TextMatches {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$Why = ''
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text -notmatch $Pattern) {
        $suffix = if ($Why) { " ($Why)" } else { '' }
        $failures.Add("$RelativePath missing $Label$suffix") | Out-Null
    }
}

$writer = 'scripts\write-agent-feedback-summary.ps1'
$harnessVerifier = 'scripts\verify-agent-feedback-harness-contract.ps1'
$gapRegister = 'docs\handoff\agent-feedback-gap-register.md'

Assert-TextContains -RelativePath $writer -Needle 'BlacksmithGuild_AgentFeedback.json' -Why 'writer must name the output file'
Assert-TextContains -RelativePath $writer -Needle 'TbgAgentFeedback.v1' -Why 'writer must emit schema version'
Assert-TextContains -RelativePath $writer -Needle 'repoState' -Why 'writer must emit repo state'
Assert-TextContains -RelativePath $writer -Needle 'runtimeState' -Why 'writer must emit runtime state when known'
Assert-TextContains -RelativePath $writer -Needle 'classification' -Why 'writer must emit classification'
Assert-TextContains -RelativePath $writer -Needle 'evidence' -Why 'writer must emit evidence list'
Assert-TextContains -RelativePath $writer -Needle 'allowedClaims' -Why 'writer must emit allowed claims'
Assert-TextContains -RelativePath $writer -Needle 'forbiddenClaims' -Why 'writer must emit forbidden claims'
Assert-TextContains -RelativePath $writer -Needle 'blockers' -Why 'writer must emit blockers'
Assert-TextContains -RelativePath $writer -Needle 'nextSprint' -Why 'writer must emit next sprint'
Assert-TextContains -RelativePath $writer -Needle 'validation' -Why 'writer must emit validation commands'
Assert-TextContains -RelativePath $writer -Needle 'git diff --check' -Why 'writer must inspect patch hygiene'
Assert-TextContains -RelativePath $writer -Needle 'rev-parse' -Why 'writer must capture branch/head from git'
Assert-TextContains -RelativePath $writer -Needle 'CommandAck' -Why 'writer must inspect command ack artifacts'
Assert-TextContains -RelativePath $writer -Needle 'SmithingAudit' -Why 'writer must inspect smithing audit artifacts'
Assert-TextContains -RelativePath $writer -Needle 'safe_mode_detected' -Why 'writer must classify known launcher blocker pattern'
Assert-TextContains -RelativePath $writer -Needle 'stale_evidence' -Why 'writer must classify stale evidence'
Assert-TextContains -RelativePath $writer -Needle 'checkpoint_reached' -Why 'writer must classify successful checkpoints'
Assert-TextContains -RelativePath $writer -Needle 'runtime_blocked' -Why 'writer must classify runtime blockers'
Assert-TextContains -RelativePath $writer -Needle 'CommandInbox.json missing after a fresh ACK is not a blocker' -Why 'writer must encode consumed-inbox interpretation'
Assert-TextContains -RelativePath $writer -Needle 'This does not prove autonomous campaign loop completion.' -Why 'writer must emit forbidden claims for command ACKs'
Assert-TextContains -RelativePath $writer -Needle 'scripts\verify-agent-feedback-writer-contract.ps1' -Why 'writer must output self-validation command'
Assert-TextContains -RelativePath $writer -Needle 'scripts\verify-agent-feedback-harness-contract.ps1' -Why 'writer must preserve harness validation command'
Assert-TextContains -RelativePath $writer -Needle 'ConvertTo-Json -Depth 12' -Why 'writer must write structured JSON deeply enough'
Assert-TextContains -RelativePath $writer -Needle 'Set-Content -LiteralPath $OutputPath' -Why 'writer must write output through explicit path'

Assert-TextMatches -RelativePath $writer -Pattern '(?m)^\s*param\(' -Label 'param block' -Why 'writer must be callable with parameters'
Assert-TextMatches -RelativePath $writer -Pattern '(?m)^\s*\[string\]\$BannerlordRoot' -Label 'BannerlordRoot parameter' -Why 'runtime root must be overrideable'
Assert-TextMatches -RelativePath $writer -Pattern '(?m)^\s*\[string\]\$DocumentsRoot' -Label 'DocumentsRoot parameter' -Why 'documents root must be overrideable'
Assert-TextMatches -RelativePath $writer -Pattern '(?m)^\s*\[string\]\$OutputPath' -Label 'OutputPath parameter' -Why 'output path must be overrideable'
Assert-TextMatches -RelativePath $writer -Pattern '(?m)^\s*\[int\]\$FreshMinutes' -Label 'FreshMinutes parameter' -Why 'freshness window must be explicit'
Assert-TextMatches -RelativePath $writer -Pattern '(?m)^\s*\[switch\]\$NoWrite' -Label 'NoWrite parameter' -Why 'dry-run/no-write execution must be possible'

Assert-TextContains -RelativePath $harnessVerifier -Needle 'docs\handoff\agent-feedback-gap-register.md' -Why 'harness verifier must know the gap register'
Assert-TextContains -RelativePath $gapRegister -Needle 'scripts/write-agent-feedback-summary.ps1' -Why 'gap register must point to the implemented writer'
Assert-TextContains -RelativePath $gapRegister -Needle 'scripts/verify-agent-feedback-writer-contract.ps1' -Why 'gap register must point to the writer verifier'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: agent feedback writer contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: agent feedback writer contract verified.' -ForegroundColor Green
