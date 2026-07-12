# Compatibility entry point for CollectDiagnostics.cmd.
# Windows PowerShell on some operator machines cannot autoload Get-FileHash.
# This process-local fallback preserves real SHA-256 behavior through the repo's .NET helper.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

if (-not (Get-Command Get-FileHash -ErrorAction SilentlyContinue)) {
    function global:Get-FileHash {
        param(
            [Parameter(Mandatory = $true)][string]$LiteralPath,
            [ValidateSet('SHA256')][string]$Algorithm = 'SHA256'
        )
        [pscustomobject][ordered]@{
            Algorithm = $Algorithm
            Hash = Get-TbgFileSha256 -LiteralPath $LiteralPath
            Path = [System.IO.Path]::GetFullPath($LiteralPath)
        }
    }
    Write-Host '[TBG] Get-FileHash unavailable; using the repo .NET SHA-256 compatibility helper.' -ForegroundColor Yellow
}

& (Join-Path $repoRoot 'forge.ps1') -CollectDiagnostics
exit $LASTEXITCODE
