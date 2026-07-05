# Offline contract verifier for the agent remediation planner.
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

$doc = 'docs\handoff\agent-remediation-planner.md'
$planner = 'scripts\write-agent-remediation-plan.ps1'

Assert-TextContains -RelativePath $doc -Needle '# Agent Remediation Planner Doctrine' -Why 'remediation doctrine must exist'
Assert-TextContains -RelativePath $doc -Needle 'BlacksmithGuild_AgentRemediationPlan.json' -Why 'planned output must be documented'
Assert-TextContains -RelativePath $doc -Needle 'apply-remediation.ps1' -Why 'apply script must be documented'
Assert-TextContains -RelativePath $doc -Needle 'verify-remediation.ps1' -Why 'verify script must be documented'
Assert-TextContains -RelativePath $doc -Needle 'LaunchIntent interactive prompt' -Why 'known LaunchIntent blocker must be documented'
Assert-TextContains -RelativePath $doc -Needle 'Invisible churn / patch hygiene' -Why 'patch hygiene blocker must be documented'
Assert-TextContains -RelativePath $doc -Needle 'byte-safe patch recipe' -Why 'byte-safe remediation must be doctrine'
Assert-TextContains -RelativePath $doc -Needle 'must not silently apply them' -Why 'planner must not auto-apply patches'
Assert-TextContains -RelativePath $doc -Needle 'Every generated patch script must have a paired verifier script.' -Why 'patch/verifier pairing must be doctrine'

Assert-TextContains -RelativePath $planner -Needle 'BlacksmithGuild_AgentRemediationPlan.json' -Why 'planner must write remediation output'
Assert-TextContains -RelativePath $planner -Needle 'TbgAgentRemediationPlan.v1' -Why 'planner must emit schema version'
Assert-TextContains -RelativePath $planner -Needle 'BlacksmithGuild_AgentFeedback.json' -Why 'planner must read feedback output'
Assert-TextContains -RelativePath $planner -Needle 'patchCandidates' -Why 'planner must emit patch candidates'
Assert-TextContains -RelativePath $planner -Needle 'generatedScripts' -Why 'planner must emit generated scripts'
Assert-TextContains -RelativePath $planner -Needle 'apply-remediation.ps1' -Why 'planner must generate apply script'
Assert-TextContains -RelativePath $planner -Needle 'verify-remediation.ps1' -Why 'planner must generate verify script'
Assert-TextContains -RelativePath $planner -Needle 'LaunchIntent' -Why 'planner must recognize LaunchIntent blocker'
Assert-TextContains -RelativePath $planner -Needle 'run-autonomous-assist-session.ps1' -Why 'planner must target known handoff seam'
Assert-TextContains -RelativePath $planner -Needle 'open-bannerlord-launcher.ps1' -Why 'planner must identify nested launcher opener'
Assert-TextContains -RelativePath $planner -Needle '-LaunchIntent `$LaunchIntent' -Why 'planner must generate the boring parameter propagation patch'
Assert-TextContains -RelativePath $planner -Needle 'routeClockEvidence changes' -Why 'planner must encode forbidden scope'
Assert-TextContains -RelativePath $planner -Needle 'MapTradeAutonomousService changes' -Why 'planner must encode forbidden scope'
Assert-TextContains -RelativePath $planner -Needle 'movement detection changes' -Why 'planner must encode forbidden scope'
Assert-TextContains -RelativePath $planner -Needle '[System.IO.File]::ReadAllBytes' -Why 'generated apply script must be byte-aware'
Assert-TextContains -RelativePath $planner -Needle 'UTF8Encoding' -Why 'generated apply script must preserve UTF-8/BOM behavior'
Assert-TextContains -RelativePath $planner -Needle 'git diff --check' -Why 'generated verifier must run diff hygiene'
Assert-TextContains -RelativePath $planner -Needle 'System.Management.Automation.Language.Parser' -Why 'generated verifier must parse-check PowerShell'
Assert-TextContains -RelativePath $planner -Needle 'No known remediation pattern matched' -Why 'planner must fail safe when no pattern exists'
Assert-TextContains -RelativePath $planner -Needle 'appliesPatchesAutomatically = $false' -Why 'planner must state it does not auto-apply patches'
Assert-TextContains -RelativePath $planner -Needle 'claimsRuntimeProof = $false' -Why 'planner must not claim runtime proof'
Assert-TextContains -RelativePath $planner -Needle 'scripts\verify-agent-remediation-planner-contract.ps1' -Why 'planner must emit self-validation command'

Assert-TextMatches -RelativePath $planner -Pattern '(?m)^\s*param\(' -Label 'param block' -Why 'planner must be callable with parameters'
Assert-TextMatches -RelativePath $planner -Pattern '(?m)^\s*\[string\]\$FeedbackPath' -Label 'FeedbackPath parameter' -Why 'feedback input must be overrideable'
Assert-TextMatches -RelativePath $planner -Pattern '(?m)^\s*\[string\]\$OutputPath' -Label 'OutputPath parameter' -Why 'output path must be overrideable'
Assert-TextMatches -RelativePath $planner -Pattern '(?m)^\s*\[switch\]\$NoScripts' -Label 'NoScripts parameter' -Why 'script generation must be optional'

if ($failures.Count -gt 0) {
    Write-Host "FAIL: agent remediation planner contract has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'PASS: agent remediation planner contract verified.' -ForegroundColor Green
