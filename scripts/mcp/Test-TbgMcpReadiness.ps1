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

function Resolve-LocalTool {
    param(
        [string]$RepoRoot,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $cmd.Source }
    }

    foreach ($name in $Names) {
        $local = Join-Path $RepoRoot (".local/mcp-tools/" + $name)
        if (Test-Path -LiteralPath $local) { return $local }

        if (-not $name.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
            $localExe = Join-Path $RepoRoot (".local/mcp-tools/" + $name + ".exe")
            if (Test-Path -LiteralPath $localExe) { return $localExe }
        }
    }

    return $null
}

$repoRoot = Find-TbgRepoRoot
$branch = "unknown"
Push-Location $repoRoot
try {
    $branchRead = (& git rev-parse --abbrev-ref HEAD 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($branchRead)) { $branch = $branchRead.Trim() }
} finally {
    Pop-Location
}

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

$mcpBridge = Resolve-LocalTool -RepoRoot $repoRoot -Names @("csharp-lsp-mcp", "csharp-lsp-mcp.exe")
if ($mcpBridge) {
    $findings += "mcp-tool-ok:csharp-lsp-mcp"
} else {
    $missing += "mcp_tool_missing:csharp-lsp-mcp"
}

$csharpLs = Resolve-LocalTool -RepoRoot $repoRoot -Names @("csharp-ls", "csharp-ls.exe")
if ($csharpLs) {
    $findings += "lsp-tool-ok:csharp-ls"
} else {
    $missing += "lsp-tool-missing:csharp-ls"
}

$status = "ready"
$verdict = "mcp_readiness_ready"
if ($missing.Count -gt 0) {
    $status = "missing_prereqs"
    $verdict = "mcp_readiness_missing_prereqs"
}
if ($missing -contains "mcp_tool_missing:csharp-lsp-mcp") {
    $verdict = "mcp_tool_missing"
} elseif ($missing -contains "lsp-tool-missing:csharp-ls") {
    $verdict = "lsp_project_not_loaded"
}

$artifactDir = Join-Path $repoRoot "artifacts/latest"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$result = New-Object psobject -Property @{
    schema = "tbg.harness.result.v1"
    action = "TestMcpReadiness"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = $branch
    contractId = $ContractId
    status = $status
    verdict = $verdict
    findings = @($findings)
    missingPrereqs = @($missing)
    forbiddenScopeTouched = $false
    artifacts = @("artifacts/latest/mcp-readiness.result.json")
    tools = New-Object psobject -Property @{
        csharpLspMcp = $mcpBridge
        csharpLs = $csharpLs
    }
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactDir "mcp-readiness.result.json") -Encoding UTF8
$result | ConvertTo-Json -Depth 20
