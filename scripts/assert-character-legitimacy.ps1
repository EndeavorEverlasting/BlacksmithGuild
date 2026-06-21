# Read-only verifier for personal TBGPersonalAserai001 legitimacy (008C-Fix).
param(
    [string]$BannerlordRoot,
    [switch]$PersonalCert
)

$ErrorActionPreference = 'Stop'

function Get-BannerlordRootLocal {
    param([string]$RepoRoot)

    $csproj = Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj'
    if ($csproj -match '<GameFolder>([^<]+)</GameFolder>') {
        $fromCsproj = $Matches[1] -replace '&amp;', '&'
        if (Test-Path -LiteralPath $fromCsproj) { return $fromCsproj }
    }

    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    if (Test-Path -LiteralPath $default) { return $default }

    throw 'Bannerlord install not found.'
}

function Get-CurrentSessionPhase1Window {
    param([string]$Phase1Path)

    if (-not (Test-Path -LiteralPath $Phase1Path)) {
        return $null
    }

    $fullText = Get-Content -LiteralPath $Phase1Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($fullText)) {
        return $null
    }

    $marker = 'TBG READY'
    $lastIndex = -1
    $searchStart = 0
    while ($true) {
        $index = $fullText.IndexOf($marker, $searchStart, [System.StringComparison]::OrdinalIgnoreCase)
        if ($index -lt 0) { break }
        $lastIndex = $index
        $searchStart = $index + $marker.Length
    }

    if ($lastIndex -lt 0) {
        return $fullText
    }

    $priorIndex = $fullText.LastIndexOf($marker, $lastIndex - 1, [System.StringComparison]::OrdinalIgnoreCase)
    $sessionStart = if ($priorIndex -ge 0) { $priorIndex + $marker.Length } else { 0 }
    return $fullText.Substring($sessionStart)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BannerlordRoot) {
    $BannerlordRoot = Get-BannerlordRootLocal -RepoRoot $repoRoot
}

$failures = @()
$warnings = @()

$provenancePath = Join-Path $BannerlordRoot 'BlacksmithGuild_CharacterBuildProvenance.json'
$configPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CharacterBuildVariantConfig.json'
$phase1Path = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'

if (-not (Test-Path -LiteralPath $provenancePath)) {
    $failures += 'Missing BlacksmithGuild_CharacterBuildProvenance.json'
} else {
    $provenance = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json

    $choiceCount = @($provenance.upbringingChoices).Count
    if ($choiceCount -eq 0) {
        $failures += 'Provenance lacks upbringingChoices'
    }

    if ($PersonalCert -and $provenance.visibleTraversalUsed -ne $true) {
        $failures += "visibleTraversalUsed is not true (got: $($provenance.visibleTraversalUsed))"
    }

    if ($provenance.postMapProfileApply.enabled -eq $true) {
        $failures += 'postMapProfileApply.enabled is true'
    }

    if ($provenance.mutationAuditSummary.postMapProfileApply -eq $true) {
        $failures += 'mutationAuditSummary.postMapProfileApply is true'
    }
}

if ($PersonalCert -and (Test-Path -LiteralPath $configPath)) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($config.visibleMode -ne $true) {
        $failures += "Variant config visibleMode is not true (got: $($config.visibleMode))"
    }
}

$sessionWindow = Get-CurrentSessionPhase1Window -Phase1Path $phase1Path
if ($null -eq $sessionWindow) {
    $warnings += 'Phase1 log missing — injection scan skipped'
} elseif ($sessionWindow -match 'ForgeQuartermasterWarlord applied=True trigger=quickstart-bootstrap') {
    $failures += 'Phase1 current session contains quickstart-bootstrap profile injection'
} elseif ($PersonalCert -and $sessionWindow -notmatch 'visible traversal: on') {
    $warnings += 'Phase1 current session lacks visible traversal: on line'
}

$verdict = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$result = [ordered]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    verdict      = $verdict
    personalCert = [bool]$PersonalCert
    failures     = @($failures)
    warnings     = @($warnings)
    legitimacyVerdict = if ($verdict -eq 'PASS') { 'VanillaLegit' } else { 'Failed' }
}

$result | ConvertTo-Json -Depth 6

if ($verdict -eq 'FAIL') {
    foreach ($failure in $failures) {
        Write-Host "FAIL: $failure" -ForegroundColor Red
    }
    exit 1
}

foreach ($warning in $warnings) {
    Write-Host "WARN: $warning" -ForegroundColor Yellow
}

Write-Host 'Legitimacy assert PASS' -ForegroundColor Green
exit 0
