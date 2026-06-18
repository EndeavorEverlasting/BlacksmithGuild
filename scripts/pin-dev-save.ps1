# Bump dev save timestamp so launcher Continue prefers BlacksmithGuild_DevStart*.sav
param(
    [string]$SavePrefix = 'BlacksmithGuild_DevStart'
)

$ErrorActionPreference = 'SilentlyContinue'

$saveRoot = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\Game Saves\Native'
if (-not (Test-Path -LiteralPath $saveRoot)) {
    return
}

$latest = Get-ChildItem -LiteralPath $saveRoot -Filter "$SavePrefix*.sav" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latest) {
    return
}

$now = Get-Date
$latest.LastWriteTime = $now
$latest.LastAccessTime = $now
Write-Host "Dev save pinned for Continue: $($latest.Name)" -ForegroundColor DarkGray
