# Run read-only clan intel cert (009A T1).
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$commands = @(
    'AnalyzeClanContext',
    'AnalyzeClanRoles',
    'AnalyzeNobleNetwork',
    'AnalyzeMarriageCandidates',
    'ShowCourtshipPlan',
    'ProbeCourtshipApi'
)

$expectedFiles = @(
    'BlacksmithGuild_ClanContext.json',
    'BlacksmithGuild_ClanRoles.json',
    'BlacksmithGuild_NobleNetwork.json',
    'BlacksmithGuild_MarriageCandidates.json',
    'BlacksmithGuild_CourtshipPlan.json',
    'BlacksmithGuild_CourtshipProbe.json'
)

Write-Host ''
Write-Host '=== 009A Clan Intel Cert ===' -ForegroundColor Cyan

foreach ($cmd in $commands) {
    Write-Host "Sending: $cmd"
    if ($WhatIf) { continue }
    & (Join-Path $repoRoot 'forge.ps1') -Command $cmd -Wait
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed: $cmd (exit $LASTEXITCODE)"
    }
}

if ($WhatIf) {
    Write-Host '[WhatIf] Skipped file verification.'
    exit 0
}

$bannerlordRoot = & {
    $csproj = Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        return ($Matches[1] -replace '&amp;', '&')
    }
    return 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
}

$missing = @()
foreach ($file in $expectedFiles) {
    $path = Join-Path $bannerlordRoot $file
    if (-not (Test-Path -LiteralPath $path)) {
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing evidence files: $($missing -join ', ')"
}

Write-Host 'PASS: all clan intel JSON files present.' -ForegroundColor Green
exit 0
