param(
    [string]$ContractId = "local-mcp-code-intelligence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        $marker = Join-Path $cursor ".tbg/harness/manifest.json"
        if (Test-Path -LiteralPath $marker) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

function Has-Tool {
    param([string]$Name)
    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

$repoRoot = Find-TbgRepoRoot
$findings = @()
$missing = @()

foreach ($tool in @("node", "dotnet", "go")) {
    if (Has-Tool -Name $tool) { $findings += "tool-ok:$tool" } else { $missing += "tool-missing:$tool" }
}

foreach ($relative in @(".mcp.example.json", ".cursor/mcp.example.json")) {
    $full = Join-Path $repoRoot $relative
    if (Test-Path -LiteralPath $full) {
        Get-Content -LiteralPath $full -Raw | ConvertFrom-Json | Out-Null
        $findings += "config-json-ok:$relative"
    } else {
        $missing += "config-missing:$relative"
    }
}

$project = Join-Path $repoRoot "src/BlacksmithGuild/BlacksmithGuild.csproj"
if (Test-Path -LiteralPath $project) { $findings += "project-ok" } else { $missing += "project-missing" }

$status = "ready"
$verdict = "mcp_readiness_ready"
if ($missing.Count -gt 0) {
    $status = "missing_prereqs"
    $verdict = "mcp_readiness_missing_prereqs"
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$result = New-Object psobject -Property @{
    schema = "tbg.harness.result.v1"
    action = "TestMcpReadiness"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = "unknown"
    contractId = $ContractId
    status = $status
    verdict = $verdict
    findings = @($findings)
    missingPrereqs = @($missing)
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/mcp-readiness.result.json")
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactDir "mcp-readiness.result.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 20
