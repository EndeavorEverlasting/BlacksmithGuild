# Byte-safe UTF-8 text replacement helper.

param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [Parameter(Mandatory = $true)][string]$OldText,
    [Parameter(Mandatory = $true)][string]$NewText,
    [int]$ExpectedCount = 1,
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LiteralPath)) {
    throw "File not found: $LiteralPath"
}

$item = Get-Item -LiteralPath $LiteralPath
$bytes = [System.IO.File]::ReadAllBytes($item.FullName)
$hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

$reader = New-Object System.IO.StreamReader($item.FullName, [System.Text.UTF8Encoding]::new($false, $true), $true)
$text = $reader.ReadToEnd()
$reader.Close()

$count = ([regex]::Matches($text, [regex]::Escape($OldText))).Count
if ($count -ne $ExpectedCount) {
    throw "Expected $ExpectedCount occurrence(s); found $count. No replacement written."
}

$updated = $text.Replace($OldText, $NewText)
if ($updated -eq $text) {
    throw 'Replacement produced no text change.'
}

$result = [pscustomobject][ordered]@{
    schema = 'TbgByteSafeReplacement.v1'
    path = $item.FullName
    hadBom = $hasBom
    expectedCount = $ExpectedCount
    actualCount = $count
    preview = [bool]$Preview
    changed = $true
}

if (-not $Preview) {
    $encoding = [System.Text.UTF8Encoding]::new($hasBom)
    [System.IO.File]::WriteAllText($item.FullName, $updated, $encoding)
}

$result | ConvertTo-Json -Depth 4
