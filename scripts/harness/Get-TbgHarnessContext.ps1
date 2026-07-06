param(
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Find-TbgRepoRoot {
    $cursor = (Get-Location).Path
    while ($true) {
        $manifest = Join-Path $cursor ".tbg/harness/manifest.json"
        if (Test-Path -LiteralPath $manifest) {
            return $cursor
        }

        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) {
            throw "Could not locate .tbg/harness/manifest.json from current directory."
        }
        $cursor = $parent
    }
}

function Invoke-Capture {
    param([string]$FileName, [string[]]$Arguments)
    try {
        $output = & $FileName @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($output -join "`n").Trim()
    } catch {
        return $null
    }
}

$repoRoot = Find-TbgRepoRoot
$manifestPath = Join-Path $repoRoot ".tbg/harness/manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

Push-Location $repoRoot
try {
    $branch = Invoke-Capture -FileName "git" -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    $head = Invoke-Capture -FileName "git" -Arguments @("rev-parse", "HEAD")
    $statusShort = Invoke-Capture -FileName "git" -Arguments @("status", "--short")
} finally {
    Pop-Location
}

if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "unknown" }
if ([string]::IsNullOrWhiteSpace($head)) { $head = "unknown" }
if ($null -eq $statusShort) { $statusShort = "" }

$result = [pscustomobject]@{
    schema = "tbg.harness.context.v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    repoRoot = $repoRoot
    branch = $branch
    head = $head
    statusShort = $statusShort
    manifest = $manifest
    defaultContractId = $manifest.defaultContractId
    contextBanner = $manifest.contextBanner
}

if ($Json) {
    $result | ConvertTo-Json -Depth 20
} else {
    $result
}
