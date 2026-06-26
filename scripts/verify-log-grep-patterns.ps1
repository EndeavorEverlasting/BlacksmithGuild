# Verifies automation scripts do not use ASCII-hyphen lookalikes for TBG ready-line greps.
# Canonical ready text uses em dash (U+2014): "Blacksmith Guild — Ready:".
# Scans scripts/** and repo-root *.ps1|*.cmd|*.bat (not docs/).
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$selfPath = $PSCommandPath
$goldenPattern = Get-TbgReadyGoldenPathPattern
$badPatterns = @(
    ('Blacksmith Guild ' + '-' + ' Ready'),
    ('Blacksmith Guild ' + '-' + ' Ready:')
)

function Get-GrepGuardScanFiles {
    param([string]$Root)

    $extensions = @('*.ps1', '*.cmd', '*.bat')
    $paths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $scriptDir = Join-Path $Root 'scripts'
    if (Test-Path -LiteralPath $scriptDir) {
        foreach ($ext in $extensions) {
            Get-ChildItem -LiteralPath $scriptDir -Recurse -File -Filter $ext |
                ForEach-Object { [void]$paths.Add($_.FullName) }
        }
    }

    foreach ($ext in $extensions) {
        Get-ChildItem -LiteralPath $Root -File -Filter $ext |
            ForEach-Object { [void]$paths.Add($_.FullName) }
    }

    return @($paths) | Sort-Object
}

$scriptFiles = Get-GrepGuardScanFiles -Root $repoRoot
$hits = @()

foreach ($file in $scriptFiles) {
    if ($file -eq $selfPath) { continue }

    $text = Get-Content -LiteralPath $file -Raw
    foreach ($badPattern in $badPatterns) {
        if ($text.Contains($badPattern)) {
            $relative = Resolve-Path -LiteralPath $file -Relative
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
    Write-Host "PASS: no unsafe ASCII-hyphen Blacksmith Guild ready-line grep patterns in $($scriptFiles.Count) automation files." -ForegroundColor Green
}
