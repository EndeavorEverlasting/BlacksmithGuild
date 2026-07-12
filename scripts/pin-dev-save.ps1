# Bump dev save timestamp so launcher Continue prefers BlacksmithGuild_DevStart*.sav
param(
    [string]$SavePrefix = 'BlacksmithGuild_DevStart'
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$latest = if ($PSBoundParameters.ContainsKey('SavePrefix')) {
    @(Get-BannerlordExistingGameSaveRoots | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Filter "$SavePrefix*.sav" -File -ErrorAction SilentlyContinue
    }) | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
} else {
    Get-BannerlordDevSaveCandidates | Select-Object -First 1
}

if (-not $latest) {
    return
}

$now = Get-Date
$latest.LastWriteTime = $now
$latest.LastAccessTime = $now
Write-Host "Dev save pinned for Continue: $($latest.Name)" -ForegroundColor DarkGray
