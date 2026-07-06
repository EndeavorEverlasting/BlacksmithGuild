param(
    [Parameter(Mandatory=$true)][string]$AppId,
    [Parameter(Mandatory=$true)][string]$AppSlug,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [switch]$WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $AppSlug.StartsWith(".")) {
    throw "AppSlug should start with a dot, for example .myapp."
}

$plan = @(
    "$AppSlug/harness/manifest.json",
    "$AppSlug/harness/policies/command-safety.policy.json",
    "$AppSlug/harness/policies/file-safety.policy.json",
    "$AppSlug/workflows/example.contract.json",
    "scripts/harness/Invoke-$AppId`Harness.ps1",
    "scripts/harness/Test-$AppId`HarnessReadiness.ps1",
    ".mcp.example.json",
    ".claude/settings.example.json",
    "docs/architecture/local-agent-harness.md"
)

if ($WhatIfOnly) {
    $plan | ForEach-Object { Write-Output $_ }
    return
}

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
foreach ($relative in $plan) {
    $target = Join-Path $OutputPath $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    if (-not (Test-Path -LiteralPath $target)) {
        Set-Content -LiteralPath $target -Encoding UTF8 -Value "TODO: scaffold for $AppId local agent harness."
    }
}

$result = New-Object psobject -Property @{
    schema = "tbg.harness.template-result.v1"
    appId = $AppId
    appSlug = $AppSlug
    outputPath = $OutputPath
    files = @($plan)
}
$result | ConvertTo-Json -Depth 20
