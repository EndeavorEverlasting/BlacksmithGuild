# Presents the repo-owned TBG sprint plan pack location and launch order.
$ErrorActionPreference = 'Stop'

param(
    [ValidateSet('summary','path','full')]
    [string]$Format = 'summary',

    [switch]$WriteResult
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$planPath = 'docs\harness\TBG_SPRINT_PLAN_PACK.md'
$fullPath = Join-Path $repoRoot $planPath
if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "Missing sprint plan pack: $planPath"
}

$result = [ordered]@{
    schema = 'tbg.sprintPlanPackPresentation.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    format = $Format
    path = $planPath
    immediateMove = 'Launch Chat 00 first.'
    parallelAfterChat00 = @(
        'Chat 01 - MCP/LSP Symbol Smoke Recovery',
        'Chat 02 - Run Context + Artifact Registry',
        'Chat 08 - Hook and Artifact Hygiene'
    )
    heldUntilReady = @(
        'Chat 03 waits for Chat 02',
        'Chat 04 waits for Chat 01/02/03',
        'Chat 05 waits for Chat 00',
        'Chat 06 waits for Chat 00 and ideally Chat 05',
        'Chat 07 waits for Chat 01 or runs with missing-prereq behavior'
    )
}

if ($WriteResult) {
    $latestDir = Join-Path $repoRoot 'artifacts\latest'
    New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
    $resultPath = Join-Path $latestDir 'tbg-sprint-plan-pack.result.json'
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}

if ($Format -eq 'path') {
    Write-Host $planPath
    exit 0
}

if ($Format -eq 'full') {
    Get-Content -LiteralPath $fullPath -Raw
    exit 0
}

Write-Host 'TBG Sprint Plan Pack'
Write-Host "Path: $planPath"
Write-Host ''
Write-Host 'Immediate move:'
Write-Host '- Launch Chat 00 first.'
Write-Host ''
Write-Host 'Then, after Chat 00 confirms safe bases:'
foreach ($item in $result.parallelAfterChat00) { Write-Host "- $item" }
Write-Host ''
Write-Host 'Held until ready:'
foreach ($item in $result.heldUntilReady) { Write-Host "- $item" }

exit 0
