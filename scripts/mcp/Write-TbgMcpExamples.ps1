Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $cursor ".tbg/harness/manifest.json")) { return $cursor }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { throw "Could not locate repo root." }
        $cursor = $parent
    }
}

$repoRoot = Find-TbgRepoRoot

$claude = @'
{
  "mcpServers": {
    "tbg-domain": {
      "type": "stdio",
      "command": "powershell",
      "args": ["-ExecutionPolicy", "Bypass", "-File", "scripts\\mcp\\Start-TbgDomainMcpServer.ps1"],
      "env": { "TBG_HARNESS_MODE": "readonly" }
    },
    "tbg-lsp": {
      "type": "stdio",
      "command": "mcp-language-server",
      "args": ["--workspace", "${CLAUDE_PROJECT_DIR}", "--lsp", "csharp-ls"]
    }
  }
}
'@

$cursor = @'
{
  "mcpServers": {
    "tbg-domain": {
      "command": "powershell",
      "args": ["-ExecutionPolicy", "Bypass", "-File", "scripts\\mcp\\Start-TbgDomainMcpServer.ps1"],
      "env": { "TBG_HARNESS_MODE": "readonly" }
    },
    "tbg-lsp": {
      "command": "mcp-language-server",
      "args": ["--workspace", ".", "--lsp", "csharp-ls"]
    }
  }
}
'@

Set-Content -LiteralPath (Join-Path $repoRoot ".mcp.example.json") -Encoding UTF8 -Value $claude
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot ".cursor") | Out-Null
Set-Content -LiteralPath (Join-Path $repoRoot ".cursor/mcp.example.json") -Encoding UTF8 -Value $cursor

$result = New-Object psobject -Property @{
    schema = "tbg.mcp.examples-result.v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    wrote = @(".mcp.example.json", ".cursor/mcp.example.json")
}
$result | ConvertTo-Json -Depth 10
