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

$intentPath = Join-Path $BannerlordRoot 'BlacksmithGuild_LaunchIntent.json'
$payload = @{
    intent    = $LaunchIntent
    writtenAt = (Get-Date).ToString('o')
} | ConvertTo-Json -Compress

Set-Content -LiteralPath $intentPath -Value $payload -Encoding UTF8
Write-Host "Launch intent written: $LaunchIntent -> $intentPath" -ForegroundColor Cyan
