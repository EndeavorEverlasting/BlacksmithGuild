# Verifies scripts do not use ASCII-hyphen lookalikes for TBG ready-line greps.
# The canonical ready text uses an em dash (U+2014): "Blacksmith Guild — Ready".
# PowerShell 5.1 can corrupt non-ASCII strings when .ps1 files lack a UTF-8 BOM,
# so scripts should prefer helper constants/functions and avoid hard-coded grep text.
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$goldenPattern = Get-TbgReadyGoldenPathPattern
$badPatterns = @(
    ('Blacksmith Guild ' + '-' + ' Ready'),
    ('Blacksmith Guild ' + '-' + ' Ready:')
)
$scriptFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts') -Recurse -File -Include *.ps1,*.cmd,*.bat
$hits = @()

foreach ($file in $scriptFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($badPattern in $badPatterns) {
        if ($text.Contains($badPattern)) {
            $relative = Resolve-Path -LiteralPath $file.FullName -Relative
            $hits += [pscustomobject]@{ Path = $relative; Pattern = $badPattern; Prefer = $goldenPattern }
        }
    }
}

if ($hits.Count -gt 0) {
    Write-Host 'FAIL: ASCII hyphen ready-line grep patterns found. Use U+2014 em dash or shared helpers instead.' -ForegroundColor Red
    $hits | Format-Table -AutoSize | Out-String | Write-Host
    exit 1
}

if (-not $Quiet) {
    Write-Host 'PASS: no unsafe ASCII-hyphen Blacksmith Guild ready-line grep patterns found.' -ForegroundColor Green
}
