param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $RepoRoot 'scripts\bannerlord-paths.ps1')

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tbg-save-layout-' + [guid]::NewGuid().ToString('N'))
try {
    $flatRoot = Join-Path $fixtureRoot 'Game Saves'
    $nativeRoot = Join-Path $flatRoot 'Native'
    New-Item -ItemType Directory -Path $nativeRoot -Force | Out-Null

    $flatSave = Join-Path $flatRoot 'BlacksmithGuildDevStart.sav'
    $nativeSave = Join-Path $nativeRoot 'BlacksmithGuild_DevStart_20260712.sav'
    $nestedSave = Join-Path (Join-Path $flatRoot 'Unexpected') 'BlacksmithGuild_DevStart.sav'
    New-Item -ItemType Directory -Path (Split-Path -Parent $nestedSave) -Force | Out-Null
    [System.IO.File]::WriteAllText($flatSave, 'flat')
    [System.IO.File]::WriteAllText($nativeSave, 'native')
    [System.IO.File]::WriteAllText($nestedSave, 'nested')
    (Get-Item -LiteralPath $nativeSave).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddMinutes(1)

    $roots = @(Get-BannerlordGameSaveRoots -DocsRoot $fixtureRoot)
    Assert-True ($roots.Count -eq 2) 'Save resolver must expose flat and legacy Native roots'
    Assert-True ($roots[0] -eq $flatRoot) 'Flat Game Saves root must be considered first'
    Assert-True ($roots[1] -eq $nativeRoot) 'Legacy Native root must remain supported'

    $candidates = @(Get-BannerlordDevSaveCandidates -DocsRoot $fixtureRoot)
    Assert-True ($candidates.Count -eq 2) 'Only explicit dev saves directly under recognized roots may be candidates'
    Assert-True ($candidates[0].FullName -eq $nativeSave) 'Candidates must be sorted newest first across layouts'
    Assert-True (Test-BannerlordDevSaveName -Name 'BlacksmithGuildDevStart.sav') 'Flat-layout dev-save spelling must be approved'
    Assert-True (Test-BannerlordDevSaveName -Name 'BlacksmithGuild_DevStart_20260712.sav') 'Historical dev-save spelling must be approved'
    Assert-True (-not (Test-BannerlordDevSaveName -Name 'saveauto3.sav')) 'Generic personal saves must not become approved dev saves'
    Assert-True (Test-BannerlordRecognizedSavePath -Path $flatSave -DocsRoot $fixtureRoot) 'Flat save path must be recognized'
    Assert-True (Test-BannerlordRecognizedSavePath -Path $nativeSave -DocsRoot $fixtureRoot) 'Native save path must be recognized'
    Assert-True (-not (Test-BannerlordRecognizedSavePath -Path $nestedSave -DocsRoot $fixtureRoot)) 'Nested/unrecognized save paths must be rejected'
    $flatHash = Get-TbgFileSha256 -LiteralPath $flatSave
    Assert-True ($flatHash -match '^[A-F0-9]{64}$') '.NET SHA-256 helper must return a stable uppercase hex digest'
    [System.IO.File]::AppendAllText($flatSave, '-changed')
    Assert-True ((Get-TbgFileSha256 -LiteralPath $flatSave) -ne $flatHash) 'SHA-256 helper must detect changed file content'
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host 'Bannerlord save-layout contract: PASS (flat + legacy Native)'
