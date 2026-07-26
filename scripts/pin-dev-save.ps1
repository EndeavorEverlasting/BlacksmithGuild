# Pin only the approved disposable save pair used by exact in-game Continue.
param(
    [string]$GameSavesRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Mount and Blade II Bannerlord\Game Saves'),
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

function Get-TbgSaveSha256 {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $stream = [IO.File]::OpenRead($LiteralPath)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

$logicalAliasPath = Join-Path $GameSavesRoot 'BlacksmithGuildDevStart.sav'
$nativeApprovedPath = Join-Path $GameSavesRoot 'Native\BlacksmithGuild_DevStart.sav'
$logicalAliasExists = Test-Path -LiteralPath $logicalAliasPath -PathType Leaf
$nativeApprovedExists = Test-Path -LiteralPath $nativeApprovedPath -PathType Leaf

if (-not $logicalAliasExists -and -not $nativeApprovedExists) {
    Write-Host 'Approved disposable save pair is not configured; nothing was pinned.' -ForegroundColor DarkGray
    return
}

if (-not $logicalAliasExists -or -not $nativeApprovedExists) {
    $missingLeaf = if (-not $logicalAliasExists) {
        'BlacksmithGuildDevStart.sav'
    }
    else {
        'Native\BlacksmithGuild_DevStart.sav'
    }
    throw "Approved disposable save pair is incomplete; missing $missingLeaf. Refusing to pin any other save."
}

$logicalAlias = Get-Item -LiteralPath $logicalAliasPath
$nativeApproved = Get-Item -LiteralPath $nativeApprovedPath
$logicalHash = Get-TbgSaveSha256 -LiteralPath $logicalAliasPath
$nativeHash = Get-TbgSaveSha256 -LiteralPath $nativeApprovedPath
if ($logicalAlias.Length -ne $nativeApproved.Length -or $logicalHash -ne $nativeHash) {
    throw 'Approved disposable save pair is not byte-identical. Refusing to choose or pin either file.'
}

$now = Get-Date
foreach ($approvedSave in @($logicalAlias, $nativeApproved)) {
    $approvedSave.LastWriteTime = $now
    $approvedSave.LastAccessTime = $now
}

Write-Host (
    "Approved disposable save pair pinned: BlacksmithGuildDevStart.sav <=> " +
    "Native\BlacksmithGuild_DevStart.sav sha256=$logicalHash"
) -ForegroundColor DarkGray

if ($PassThru) {
    [pscustomobject][ordered]@{
        schema = 'TbgApprovedDisposableSavePin.v1'
        logicalAliasPath = $logicalAliasPath
        nativeApprovedPath = $nativeApprovedPath
        length = [long]$logicalAlias.Length
        sha256 = $logicalHash
        pinnedAt = $now.ToString('o')
        byteIdentical = $true
    }
}
