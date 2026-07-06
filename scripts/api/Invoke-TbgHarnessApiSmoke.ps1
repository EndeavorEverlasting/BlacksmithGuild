param(
    [int]$Port = 8737
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$base = "http://127.0.0.1:$Port"
$endpoints = @("/health", "/context", "/contract")
$results = @()
foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-RestMethod -Method Get -Uri ($base + $endpoint)
        $results += New-Object psobject -Property @{ endpoint = $endpoint; status = "ok"; response = $response }
    } catch {
        $results += New-Object psobject -Property @{ endpoint = $endpoint; status = "error"; message = $_.Exception.Message }
    }
}

$results | ConvertTo-Json -Depth 20
