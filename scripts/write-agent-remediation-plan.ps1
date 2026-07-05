# Generate BlacksmithGuild_AgentRemediationPlan.json and optional apply/verify scripts.
# This script is read-only except for generated remediation artifacts.

param(
    [string]$FeedbackPath = $null,
    [string]$OutputPath = $null,
    [string]$ArtifactRoot = $null,
    [switch]$NoScripts
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $FeedbackPath) {
    $FeedbackPath = Join-Path $repoRoot 'BlacksmithGuild_AgentFeedback.json'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'BlacksmithGuild_AgentRemediationPlan.json'
}
if (-not $ArtifactRoot) {
    $ArtifactRoot = Join-Path $repoRoot 'artifacts\agent-remediation'
}

function Read-JsonFileSafe {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function New-RemediationScriptSet {
    param(
        [Parameter(Mandatory = $true)][string]$PlanId,
        [Parameter(Mandatory = $true)][string]$PatchId,
        [Parameter(Mandatory = $true)][string]$TargetFile,
        [Parameter(Mandatory = $true)][string]$OldText,
        [Parameter(Mandatory = $true)][string]$NewText,
        [string[]]$ForbiddenNeedles = @()
    )

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dir = Join-Path $ArtifactRoot $stamp
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $applyPath = Join-Path $dir 'apply-remediation.ps1'
    $verifyPath = Join-Path $dir 'verify-remediation.ps1'

    $forbiddenArray = if ($ForbiddenNeedles.Count -gt 0) {
        '@(' + (($ForbiddenNeedles | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', ') + ')'
    } else {
        '@()'
    }

    $apply = @"
﻿# Generated remediation apply script.
# Plan: $PlanId
# Patch: $PatchId
# Target: $TargetFile

param([switch]`$CleanReapply)
`$ErrorActionPreference = 'Stop'
`$repoRoot = Split-Path -Parent `$PSScriptRoot
while (`$repoRoot -and -not (Test-Path -LiteralPath (Join-Path `$repoRoot '.git'))) {
    `$repoRoot = Split-Path -Parent `$repoRoot
}
if (-not `$repoRoot) { throw 'Could not find repo root from remediation artifact directory.' }
Set-Location `$repoRoot

`$rel = '$TargetFile'
`$path = Join-Path `$repoRoot `$rel
if (-not (Test-Path -LiteralPath `$path)) { throw "Target file not found: `$rel" }

if (`$CleanReapply) {
    git checkout -- `$rel
}

`$bytes = [System.IO.File]::ReadAllBytes(`$path)
`$hasBom = `$bytes.Length -ge 3 -and `$bytes[0] -eq 0xEF -and `$bytes[1] -eq 0xBB -and `$bytes[2] -eq 0xBF
`$reader = New-Object System.IO.StreamReader(`$path, [System.Text.UTF8Encoding]::new(`$false, `$true), `$true)
`$text = `$reader.ReadToEnd()
`$reader.Close()

`$old = @'
$OldText
'@
`$new = @'
$NewText
'@

`$count = ([regex]::Matches(`$text, [regex]::Escape(`$old))).Count
if (`$count -ne 1) {
    throw "Expected exactly one match in `$rel; found `$count. No patch applied."
}

`$text = `$text.Replace(`$old, `$new)
`$outEncoding = [System.Text.UTF8Encoding]::new(`$hasBom)
[System.IO.File]::WriteAllText(`$path, `$text, `$outEncoding)

Write-Host "`n== REMEDIATION DIFF =="
git diff -- `$rel
"@

    $verify = @"
﻿# Generated remediation verifier.
# Plan: $PlanId
# Patch: $PatchId
# Target: $TargetFile

`$ErrorActionPreference = 'Stop'
`$repoRoot = Split-Path -Parent `$PSScriptRoot
while (`$repoRoot -and -not (Test-Path -LiteralPath (Join-Path `$repoRoot '.git'))) {
    `$repoRoot = Split-Path -Parent `$repoRoot
}
if (-not `$repoRoot) { throw 'Could not find repo root from remediation artifact directory.' }
Set-Location `$repoRoot

`$rel = '$TargetFile'
`$path = Join-Path `$repoRoot `$rel
if (-not (Test-Path -LiteralPath `$path)) { throw "Target file not found: `$rel" }

Write-Host "`n== TARGETED TEXT CHECK =="
`$text = Get-Content -LiteralPath `$path -Raw
`$needle = @'
$NewText
'@
if (`$text.IndexOf(`$needle, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Expected patched text not found in `$rel."
}
Write-Host 'PASS targeted text present'

`$forbiddenNeedles = $forbiddenArray
foreach (`$forbidden in `$forbiddenNeedles) {
    if (`$text.IndexOf(`$forbidden, [System.StringComparison]::Ordinal) -ge 0) {
        Write-Host "NOTE forbidden-scope token appears in file text: `$forbidden"
    }
}

Write-Host "`n== POWERSHELL PARSE CHECK =="
`$tokens = `$null
`$errors = `$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path `$path), [ref]`$tokens, [ref]`$errors) | Out-Null
if (`$errors.Count -gt 0) {
    `$errors | Format-List *
    throw "Parse errors in `$rel"
}
Write-Host 'PASS parse'

Write-Host "`n== DIFF CHECK =="
git diff --check

Write-Host "`n== STATUS =="
git status --short
"@

    Set-Content -LiteralPath $applyPath -Value $apply -Encoding UTF8
    Set-Content -LiteralPath $verifyPath -Value $verify -Encoding UTF8

    return [pscustomobject][ordered]@{
        artifactDir = $dir
        applyScript = $applyPath
        verifyScript = $verifyPath
    }
}

$feedback = Read-JsonFileSafe -Path $FeedbackPath
$patchCandidates = New-Object System.Collections.Generic.List[object]
$generatedScripts = New-Object System.Collections.Generic.List[string]
$notes = New-Object System.Collections.Generic.List[string]
$blockerText = ''

if ($feedback) {
    $parts = New-Object System.Collections.Generic.List[string]
    if ($feedback.classification -and $feedback.classification.reason) { $parts.Add([string]$feedback.classification.reason) | Out-Null }
    foreach ($blocker in @($feedback.blockers)) {
        if ($blocker.summary) { $parts.Add([string]$blocker.summary) | Out-Null }
        if ($blocker.recommendedFix) { $parts.Add([string]$blocker.recommendedFix) | Out-Null }
        if ($blocker.evidencePath) { $parts.Add([string]$blocker.evidencePath) | Out-Null }
    }
    foreach ($note in @($feedback.notes)) { $parts.Add([string]$note) | Out-Null }
    $blockerText = ($parts -join "`n")
} else {
    $notes.Add("Feedback file not found or invalid: $FeedbackPath") | Out-Null
}

$launchIntentPattern = $blockerText -match 'LaunchIntent|Supply values for the following parameters|open-bannerlord-launcher|run-autonomous-assist-session'
$patchHygienePattern = $blockerText -match 'invisible churn|EOF-only|LF will be replaced by CRLF|UTF-8 BOM|diff --check|patch hygiene'

if ($launchIntentPattern) {
    $candidate = [pscustomobject][ordered]@{
        id = 'launch-intent-propagation'
        kind = 'byte_safe_text_replacement'
        classification = 'runtime_blocked'
        targetFile = 'scripts/run-autonomous-assist-session.ps1'
        oldText = "            & (Join-Path `$PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot `$bannerlordRoot"
        newText = "            & (Join-Path `$PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot `$bannerlordRoot -LaunchIntent `$LaunchIntent"
        matchCountRequired = 1
        patchHygiene = 'byte-aware UTF-8/BOM preserving replacement'
        nonGoals = @('routeClockEvidence changes', 'MapTradeAutonomousService changes', 'AgentAutoMapTradeRoute changes', 'runtimeProofClaim changes', 'movement detection changes')
    }
    $patchCandidates.Add($candidate) | Out-Null

    if (-not $NoScripts) {
        $scripts = New-RemediationScriptSet -PlanId 'launch-intent-interactive-prompt' -PatchId $candidate.id -TargetFile $candidate.targetFile -OldText $candidate.oldText -NewText $candidate.newText -ForbiddenNeedles $candidate.nonGoals
        $generatedScripts.Add($scripts.applyScript) | Out-Null
        $generatedScripts.Add($scripts.verifyScript) | Out-Null
    }
}

if ($patchHygienePattern) {
    $notes.Add('Patch hygiene signal detected. Prefer generated byte-aware apply scripts over Set-Content one-liners. Use git diff --check and parse checks before commit.') | Out-Null
}

if ($patchCandidates.Count -eq 0) {
    $notes.Add('No known remediation pattern matched. Add a new pattern to write-agent-remediation-plan.ps1 rather than asking the operator to manually translate this blocker again.') | Out-Null
}

$plan = [pscustomobject][ordered]@{
    schema = 'TbgAgentRemediationPlan.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    sourceFeedback = $FeedbackPath
    classification = if ($feedback -and $feedback.classification) { $feedback.classification.state } else { 'unclassified' }
    blockerSummary = if ($feedback -and $feedback.classification) { $feedback.classification.reason } else { 'Feedback file missing or invalid.' }
    patchCandidates = @($patchCandidates)
    generatedScripts = @($generatedScripts)
    notes = @($notes)
    validation = @(
        'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-agent-remediation-planner-contract.ps1',
        'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-agent-feedback-writer-contract.ps1',
        'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-agent-feedback-harness-contract.ps1',
        'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1',
        'git diff --check',
        'git status --short'
    )
    safety = [ordered]@{
        appliesPatchesAutomatically = $false
        mutatesSaves = $false
        runsLiveCerts = $false
        claimsRuntimeProof = $false
    }
}

$json = $plan | ConvertTo-Json -Depth 12
Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8

Write-Host ('Remediation candidates: {0}' -f $patchCandidates.Count) -ForegroundColor Cyan
Write-Host ('Wrote: {0}' -f $OutputPath) -ForegroundColor Green
foreach ($script in $generatedScripts) {
    Write-Host ('Generated: {0}' -f $script) -ForegroundColor Green
}
