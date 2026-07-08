# Offline verifier for the repo-owned TBG sprint plan pack.
$ErrorActionPreference = 'Stop'

param(
    [switch]$WriteResult
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

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
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle
    )
    $text = Read-RepoText -RelativePath $RelativePath
    if ($text.IndexOf($Needle, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$RelativePath missing '$Needle'") | Out-Null
    }
}

function NeedAny {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string[]]$Needles,
        [Parameter(Mandatory = $true)][string]$Description
    )
    $text = Read-RepoText -RelativePath $RelativePath
    foreach ($needle in $Needles) {
        if ($text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return }
    }
    $failures.Add("$RelativePath missing $Description") | Out-Null
}

$planPath = 'docs\harness\TBG_SPRINT_PLAN_PACK.md'
$agentPromptPath = 'docs\harness\prompts\tbg-agent-b-repo-floor-hygiene.md'
$rulesPath = 'docs\harness\AGENT_RULES.md'
$evidencePath = 'docs\harness\RUNTIME_EVIDENCE_CONTRACT.md'
$handoffPath = 'docs\harness\HANDOFF_TEMPLATE.md'
$codebaseMapPath = 'docs\harness\CODEBASE_MAP.md'
$runtimeHarnessContractPath = '.tbg\workflows\blacksmith-runtime-harness.contract.json'

$plan = Read-RepoText -RelativePath $planPath

Need $planPath '# TBG Sprint Plan Pack'
Need $planPath 'Copy one block into one new chat.'
Need $planPath 'Do not paste multiple blocks into the same chat.'
Need $planPath '## Launch Order'
Need $planPath 'Wave 0'
Need $planPath 'Wave A'
Need $planPath 'Wave B'
Need $planPath 'Wave C'
Need $planPath 'Chat 00 — Repo / PR / Worktree Hygiene'
Need $planPath 'Chat 01 — 037B MCP/LSP Symbol Smoke Recovery'
Need $planPath 'Chat 02 — Canonical TBG Run Context + Artifact Registry'
Need $planPath 'Chat 03 — English Sprint Report Renderer'
Need $planPath 'Chat 04 — End-to-End Harness Validator'
Need $planPath 'Chat 05 — ForgeStop / Launcher / Focus Safety'
Need $planPath 'Chat 06 — Route-Owned Clock Live Proof'
Need $planPath 'Chat 07 — Read-Only MCP Code Intelligence Catalog'
Need $planPath 'Chat 08 — Local Hook and Artifact Hygiene'
Need $planPath 'Do not claim live runtime success from static/doc/test success.'
Need $planPath '.\ForgeStop.cmd soft'
Need $planPath 'Do not mutate personal saves.'
Need $planPath 'Do not commit runtime logs, personal saves, generated evidence, or ignored local tool installs.'
Need $planPath 'Do not let MCP symbol navigation claim success while csharp-ls/project-load remains missing.'
Need $planPath 'Final response must follow the x-style structure:'
Need $planPath 'Standard Final Response Template for Every TBG Sprint'
Need $planPath 'Exact Next Command'

foreach ($chat in @('TBG CHAT 00','TBG CHAT 01','TBG CHAT 02','TBG CHAT 03','TBG CHAT 04','TBG CHAT 05','TBG CHAT 06','TBG CHAT 07','TBG CHAT 08')) {
    Need $planPath $chat
}

foreach ($required in @('Repo:', 'Branch:', 'Lane:', 'Scope:', 'Forbidden scope:', 'Expected artifacts:', 'Validation:', 'Final response')) {
    if ($plan.IndexOf($required, [StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$planPath missing sprint prompt field '$required'") | Out-Null
    }
}

Need $agentPromptPath 'repo-floor'
Need $agentPromptPath 'Forbidden scope'
Need $agentPromptPath 'Do not edit src/BlacksmithGuild/MapTrade/*'
Need $rulesPath 'Clone references elsewhere.'
Need $rulesPath 'Validate-TbgRuntimeProof.ps1'
Need $evidencePath 'A script finishing means only that the script ran.'
Need $handoffPath 'Copy-paste next-agent prompt'
Need $codebaseMapPath 'Contract proof is not runtime proof.'
Need $codebaseMapPath 'scripts/tbg/Verify-TbgSprintPlanPack.ps1'
Need $runtimeHarnessContractPath 'tbg.blacksmithRuntimeHarnessContract.v1'
Need $runtimeHarnessContractPath 'route_assignment_is_not_movement_proof'

try {
    $contract = Get-Content -LiteralPath (Join-Path $repoRoot $runtimeHarnessContractPath) -Raw | ConvertFrom-Json
    if ($contract.runtime_stop_required -ne $true) {
        $failures.Add('blacksmith runtime harness contract must require runtime_stop_required') | Out-Null
    }
    if ($contract.forge_stop_first.force_is_default -eq $true) {
        $failures.Add('blacksmith runtime harness contract must not make force stop the default') | Out-Null
    }
    if (-not $contract.route_visible_start_requirements.ack_is_not_enough) {
        $failures.Add('blacksmith runtime harness contract must state ACK is not enough') | Out-Null
    }
} catch {
    $failures.Add("$runtimeHarnessContractPath is not valid JSON: $($_.Exception.Message)") | Out-Null
}

if ($plan.IndexOf('vendor Archon', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $plan.IndexOf('vendor helpline', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    $failures.Add('$planPath must not instruct agents to vendor Archon or helpline') | Out-Null
}

if ($plan.IndexOf('live runtime proof: reached', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    $failures.Add('$planPath must not claim live runtime proof') | Out-Null
}

if ($plan.IndexOf('C:\Users\Cheex', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    $warnings.Add('$planPath still contains historical C:\Users\Cheex examples; prefer current-user profile form in new prompts') | Out-Null
}

$result = [ordered]@{
    schema = 'tbg.sprintPlanPackValidation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    verdict = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
    planPath = $planPath
    checkedChats = @('Chat 00','Chat 01','Chat 02','Chat 03','Chat 04','Chat 05','Chat 06','Chat 07','Chat 08')
    checkedContracts = @($runtimeHarnessContractPath)
    warnings = @($warnings)
    failures = @($failures)
}

if ($WriteResult) {
    $latestDir = Join-Path $repoRoot 'artifacts\latest'
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
    $resultPath = Join-Path $latestDir 'tbg-sprint-plan-pack.validation.json'
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: sprint plan pack validation has $($failures.Count) issue(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    if ($warnings.Count -gt 0) {
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($warning in $warnings) { Write-Host "  - $warning" -ForegroundColor Yellow }
    }
    exit 1
}

Write-Host 'PASS: TBG sprint plan pack verified.' -ForegroundColor Green
if ($warnings.Count -gt 0) {
    Write-Host 'Warnings:' -ForegroundColor Yellow
    foreach ($warning in $warnings) { Write-Host "  - $warning" -ForegroundColor Yellow }
}
exit 0
