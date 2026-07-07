param(
    [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectDir = Join-Path $RepoRoot "src/BlacksmithGuild"
$projectFile = Join-Path $projectDir "BlacksmithGuild.csproj"

@(
    [pscustomobject][ordered]@{
        role = "csharp_project_directory"
        path = $projectDir
        exists = (Test-Path -LiteralPath $projectDir -PathType Container)
        projectFile = $projectFile
        projectFileExists = (Test-Path -LiteralPath $projectFile -PathType Leaf)
        preferred = $true
    },
    [pscustomobject][ordered]@{
        role = "repo_root_fallback"
        path = $RepoRoot
        exists = (Test-Path -LiteralPath $RepoRoot -PathType Container)
        projectFile = $projectFile
        projectFileExists = (Test-Path -LiteralPath $projectFile -PathType Leaf)
        preferred = $false
    }
) | ConvertTo-Json -Depth 8
