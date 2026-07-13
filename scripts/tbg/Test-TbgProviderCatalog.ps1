[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot = 'artifacts/latest/provider-catalog'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$errors = [System.Collections.Generic.List[string]]::new()

$catalogPath = Resolve-TbgRepoPath '.tbg/state/provider-catalog.json'
$manifestPath = Resolve-TbgRepoPath '.tbg/skills/manifest.json'
$capabilitiesPath = Resolve-TbgRepoPath '.tbg/state/capabilities.registry.json'
$generatedDir = Resolve-TbgRepoPath '.tbg/state/generated'

foreach ($p in @($catalogPath, $manifestPath, $capabilitiesPath)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        $errors.Add("Required file missing: $p")
    }
}

if ($errors.Count -gt 0) {
    $outputPath = Resolve-TbgRepoPath $OutputRoot
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
    @{ schema = 'TbgProviderCatalogResult.v1'; status = 'FAIL'; errors = @($errors) } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'provider-catalog.result.json') -Encoding UTF8
    Write-Host "Provider catalog validation: FAIL (missing files)"
    exit 1
}

& (Join-Path $PSScriptRoot 'Build-TbgProviderCatalog.ps1') -RepoRoot $RepoRoot -CheckDrift

$outputPath = Resolve-TbgRepoPath $OutputRoot
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
@{
    schema = 'TbgProviderCatalogResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = 'PASS_ZERO_REMAINDERS'
    errors = @()
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'provider-catalog.result.json') -Encoding UTF8

Write-Host "Provider catalog validation: PASS_ZERO_REMAINDERS"
