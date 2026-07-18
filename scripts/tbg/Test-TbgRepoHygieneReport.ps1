<#
.SYNOPSIS
    Runs an isolated integration test for Get-TbgRepoHygieneReport.ps1.
#>
[CmdletBinding()]
param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot 'Get-TbgRepoHygieneReport.ps1')
)

$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]
        $Actual,
        [Parameter(Mandatory = $true)]
        $Expected,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message Expected=[$Expected] Actual=[$Actual]"
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Missing script under test: $ScriptPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-repo-hygiene-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

Push-Location -LiteralPath $tempRoot
try {
    & git init | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'git init failed.'
    }

    & git config user.email 'repo-hygiene-test@example.invalid'
    & git config user.name 'TBG Repo Hygiene Test'

    'clean' | Set-Content -LiteralPath 'README.md' -Encoding UTF8
    & git add README.md
    & git commit -m 'test: seed hygiene fixture' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create the fixture commit.'
    }

    $cleanMarkdown = Join-Path $tempRoot 'clean-report.md'
    $cleanJson = Join-Path $tempRoot 'clean-report.json'
    & $ScriptPath -RepoRoot $tempRoot -OutPath $cleanMarkdown -JsonOutPath $cleanJson -NoGitHub
    if ($LASTEXITCODE -ne 0) {
        throw "Clean report command failed with exit code $LASTEXITCODE."
    }

    $cleanReport = Get-Content -LiteralPath $cleanJson -Raw | ConvertFrom-Json
    Assert-Equal -Actual $cleanReport.schema -Expected 'TbgRepoHygieneReport.v1' -Message 'Unexpected schema.'
    Assert-Equal -Actual $cleanReport.verdict -Expected 'CLEAN' -Message 'Clean fixture should be CLEAN.'
    Assert-Equal -Actual @($cleanReport.dirtyPaths).Count -Expected 0 -Message 'Clean fixture should have no dirty paths.'
    Assert-Equal -Actual @($cleanReport.conflictedFiles).Count -Expected 0 -Message 'Clean fixture should have no conflicts.'
    Assert-True -Condition (-not $cleanReport.boundaries.deletesBranches) -Message 'Report must not delete branches.'
    Assert-True -Condition (-not $cleanReport.boundaries.cleansRepository) -Message 'Report must not clean the repository.'

    'dirty' | Add-Content -LiteralPath 'README.md' -Encoding UTF8

    $dirtyMarkdown = Join-Path $tempRoot 'dirty-report.md'
    $dirtyJson = Join-Path $tempRoot 'dirty-report.json'
    & $ScriptPath -RepoRoot $tempRoot -OutPath $dirtyMarkdown -JsonOutPath $dirtyJson -NoGitHub
    if ($LASTEXITCODE -ne 0) {
        throw "Dirty report command failed with exit code $LASTEXITCODE."
    }

    $dirtyReport = Get-Content -LiteralPath $dirtyJson -Raw | ConvertFrom-Json
    Assert-Equal -Actual $dirtyReport.verdict -Expected 'ATTENTION' -Message 'Dirty fixture should require attention.'
    Assert-True -Condition (@($dirtyReport.dirtyPaths).Count -gt 0) -Message 'Dirty fixture should list dirty paths.'
    Assert-Equal -Actual $dirtyReport.nextCommand -Expected 'git status --short' -Message 'Dirty fixture should recommend status inspection.'

    Write-Host 'PASS: repository hygiene report integration test'
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
