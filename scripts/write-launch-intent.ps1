# Writes BlacksmithGuild_LaunchIntent.json before launcher automation (Sprint 006E).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $BannerlordRoot)) {
    throw "Bannerlord root not found: $BannerlordRoot"
}

$payload = @{
    intent    = $LaunchIntent
    writtenAt = (Get-Date).ToString('o')
} | ConvertTo-Json -Compress

$intentPaths = @(
    (Join-Path $BannerlordRoot 'BlacksmithGuild_LaunchIntent.json'),
    (Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\BlacksmithGuild_LaunchIntent.json')
)

foreach ($intentPath in $intentPaths) {
    $parent = Split-Path -Parent $intentPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Set-Content -LiteralPath $intentPath -Value $payload -Encoding UTF8
    Write-Host "Launch intent written: $LaunchIntent -> $intentPath" -ForegroundColor Cyan
}
