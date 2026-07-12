# Compatibility entry point for CollectDiagnostics.cmd.
# Windows PowerShell on some operator machines cannot autoload Get-FileHash.
# This process-local fallback preserves real SHA-256 behavior through the repo's .NET helper.
# After the normal collector finishes, append the structured launcher-recovery artifact to the
# newest diagnostic bundle so a repeated launcher dead end is not stranded outside the bundle.

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
$collectorExit = $LASTEXITCODE

try {
    $docsRoot = Get-BannerlordDocsRoot
    $diagnosticsRoot = Join-Path $docsRoot 'BlacksmithGuild_Diagnostics'
    $latestBundle = Get-ChildItem -LiteralPath $diagnosticsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    $bannerlordRoot = $null
    try { $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot } catch { }
    $recoveryCandidates = @(
        (Join-Path $docsRoot 'BlacksmithGuild_LauncherRecovery.json')
    )
    if ($bannerlordRoot) {
        $recoveryCandidates += Join-Path $bannerlordRoot 'BlacksmithGuild_LauncherRecovery.json'
    }
    $recoverySource = $recoveryCandidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Sort-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } -Descending |
        Select-Object -First 1

    if ($latestBundle -and $recoverySource) {
        $statusDir = Join-Path $latestBundle.FullName 'status'
        New-Item -ItemType Directory -Force -Path $statusDir | Out-Null
        $destination = Join-Path $statusDir 'BlacksmithGuild_LauncherRecovery.json'
        Copy-Item -LiteralPath $recoverySource -Destination $destination -Force
        Write-Host "[TBG] Added launcher recovery evidence: $destination" -ForegroundColor Green
    } elseif (-not $recoverySource) {
        Write-Host '[TBG] No BlacksmithGuild_LauncherRecovery.json exists for this diagnostic bundle.' -ForegroundColor DarkGray
    }
} catch {
    Write-Host "[TBG] WARN: could not append launcher recovery evidence: $($_.Exception.Message)" -ForegroundColor Yellow
}

exit $collectorExit
