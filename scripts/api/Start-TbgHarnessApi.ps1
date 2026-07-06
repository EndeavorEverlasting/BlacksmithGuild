param(
    [int]$Port = 8737
)

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
$prefix = "http://127.0.0.1:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "TBG Harness API listening at $prefix"
Write-Host "Read-only endpoints: /context, /contract, /artifact/harness-readiness, /health"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.AbsolutePath.TrimEnd('/')
        $payload = $null
        $statusCode = 200

        try {
            switch ($path) {
                "" { $payload = @{ schema = "tbg.harness.api.v1"; endpoints = @("/health", "/context", "/contract", "/artifact/harness-readiness") } }
                "/health" { $payload = @{ ok = $true; mode = "readonly"; repoRoot = $repoRoot } }
                "/context" {
                    $payload = Get-Content -LiteralPath (Join-Path $repoRoot ".tbg/harness/manifest.json") -Raw | ConvertFrom-Json
                }
                "/contract" {
                    $payload = Get-Content -LiteralPath (Join-Path $repoRoot ".tbg/workflows/local-mcp-code-intelligence.contract.json") -Raw | ConvertFrom-Json
                }
                "/artifact/harness-readiness" {
                    $artifact = Join-Path $repoRoot "artifacts/latest/harness-readiness.result.json"
                    if (Test-Path -LiteralPath $artifact) { $payload = Get-Content -LiteralPath $artifact -Raw | ConvertFrom-Json } else { $statusCode = 404; $payload = @{ error = "artifact_missing" } }
                }
                default { $statusCode = 404; $payload = @{ error = "not_found"; path = $path } }
            }
        } catch {
            $statusCode = 500
            $payload = @{ error = "api_error"; message = $_.Exception.Message }
        }

        $json = $payload | ConvertTo-Json -Depth 20
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $ctx.Response.StatusCode = $statusCode
        $ctx.Response.ContentType = "application/json"
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
