param(
    [ValidateSet("readonly")][string]$Mode = "readonly"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Sprint 037A stub.
# Sprint 037C will replace this with a real stdio MCP server that exposes read-only
# tools for context, workflow contracts, latest artifacts, and bounded log tails.

$result = New-Object psobject -Property @{
    schema = "tbg.mcp-tool-result.v1"
    tool = "tbg-domain-server"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    status = "missing"
    verdict = "tbg_domain_mcp_server_stub_only"
    data = New-Object psobject -Property @{
        mode = $Mode
        nextSprint = "037C"
        allowedNow = @("readiness", "example config", "contract docs")
        notImplementedYet = @("stdio JSON-RPC loop", "tools/list", "tools/call", "resources/list")
    }
    findings = @("Stub is intentional in Sprint 037A.")
}

$result | ConvertTo-Json -Depth 20
