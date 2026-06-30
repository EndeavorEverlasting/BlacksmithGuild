# Regression wrapper for shared automation profile CMD/state contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-automation-profile-contract.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$helperText = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\automation-profile.ps1') -Raw
foreach ($needle in @('explicit_CertProfile', 'shared_json', 'safe_default', 'BlacksmithGuild_AutomationProfile.json')) {
    if ($helperText.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) { throw "automation helper missing $needle" }
}

$cmdText = Get-Content -LiteralPath (Join-Path $repoRoot 'ForgeProfile.cmd') -Raw
foreach ($surface in @('status', 'default', 'economic_loop', 'toggle')) {
    if ($cmdText.IndexOf($surface, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "ForgeProfile.cmd missing $surface" }
}

Write-Host 'PASS automation profile regression' -ForegroundColor Green
exit 0
