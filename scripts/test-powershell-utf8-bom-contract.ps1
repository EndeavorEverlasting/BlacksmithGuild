# Fail-closed: every tracked PowerShell script must have UTF-8 BOM for PS 5.1 parity.
# See docs/conventions/powershell-utf8-bom-doctrine.md
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$excludeDirNames = @('.git', 'node_modules', '__pycache__', 'Output', 'Archive', 'dist', 'bin', 'obj')
$extensions = @('*.ps1', '*.psm1', '*.psd1')
$bom = [byte[]](0xEF, 0xBB, 0xBF)
$failures = New-Object System.Collections.Generic.List[string]

function Test-FileHasUtf8Bom {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Test-FileHasNonAsciiBytes {
    param([byte[]]$Bytes)
    $start = 0
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $start = 3
    }
    for ($i = $start; $i -lt $Bytes.Length; $i++) {
        if ($Bytes[$i] -gt 0x7F) { return $true }
    }
    return $false
}

$files = foreach ($ext in $extensions) {
    Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
}
$files = $files | Where-Object {
    $rel = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
    $skip = $false
    foreach ($ex in $excludeDirNames) {
        if ($rel -match "(^|[\\/])$([regex]::Escape($ex))([\\/]|$)") { $skip = $true; break }
    }
    -not $skip
} | Sort-Object FullName

$missingBom = 0
$missingBomNonAscii = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
    if (Test-FileHasUtf8Bom -Path $f.FullName) { continue }

    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $nonAscii = Test-FileHasNonAsciiBytes -Bytes $bytes
    $missingBom++
    if ($nonAscii) { $missingBomNonAscii++ }

    $tag = if ($nonAscii) { 'NON-ASCII, NO BOM' } else { 'NO BOM' }
    $failures.Add("$tag : $rel") | Out-Null
}

if ($failures.Count -gt 0) {
    Write-Host "FAIL: $($failures.Count) PowerShell file(s) missing UTF-8 BOM ($missingBomNonAscii with non-ASCII bytes)." -ForegroundColor Red
    foreach ($line in $failures) {
        Write-Host "  $line" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Fix: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tools\Add-Utf8Bom.ps1 -Fix' -ForegroundColor Yellow
    Write-Host 'Doctrine: docs/conventions/powershell-utf8-bom-doctrine.md' -ForegroundColor Yellow
    exit 1
}

Write-Host "PASS: UTF-8 BOM present on $($files.Count) PowerShell script(s)." -ForegroundColor Green
exit 0
