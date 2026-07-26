[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$ResultPath = 'artifacts/latest/version-upgrade-impact/version-upgrade-impact.result.json',
    [switch]$PublishIssue,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
if (-not [IO.Path]::IsPathRooted($ResultPath)) { $ResultPath = Join-Path $RepoRoot $ResultPath }
if (-not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) { throw "Version upgrade result missing: $ResultPath" }

$result = Get-Content -LiteralPath $ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$issuePath = [string]$result.evidencePaths.issueDraft
if (-not [IO.Path]::IsPathRooted($issuePath)) { $issuePath = Join-Path $RepoRoot $issuePath }
if (-not (Test-Path -LiteralPath $issuePath -PathType Leaf)) {
    $latestIssue = Join-Path $RepoRoot 'artifacts/latest/version-upgrade-impact/version-upgrade-impact.issue.md'
    if (Test-Path -LiteralPath $latestIssue -PathType Leaf) { $issuePath = $latestIssue }
    else { throw 'Sanitized version-upgrade issue draft is missing.' }
}

$body = Get-Content -LiteralPath $issuePath -Raw -Encoding UTF8
if ($body -match '(?i)[A-Z]:\\Users\\|/home/[^/]+/|token\s*[:=]|password\s*[:=]') {
    throw 'Issue draft contains a personal-path or secret-like token; refusing remote publication.'
}
$title = 'Version upgrade probe: Bannerlord {0} -> {1}' -f [string]$result.baselineVersion,[string]$result.candidateVersion

$publication = [ordered]@{
    schema = 'TbgVersionUpgradeIssuePublication.v1'
    title = $title
    issueDraft = $issuePath
    publishRequested = [bool]$PublishIssue
    published = $false
    existing = $false
    url = $null
}

if (-not $PublishIssue) {
    Write-Host 'Remote publication not requested. Sanitized issue draft:' -ForegroundColor Cyan
    Write-Host $issuePath
    Write-Host $body
    if ($PassThru) { [pscustomobject]$publication }
    return
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($null -eq $gh) { throw 'GitHub CLI (gh) is required for explicit issue publication.' }
& $gh.Source auth status 1>$null 2>$null
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated; no issue was published.' }

$manifestPath = Join-Path $RepoRoot '.tbg/harness/manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$repo = [string]$manifest.repo.remote
if ([string]::IsNullOrWhiteSpace($repo)) { throw 'Harness manifest repo.remote is missing.' }

$searchJson = @(& $gh.Source issue list --repo $repo --state open --search ('in:title "{0}"' -f $title) --json number,title,url 2>$null) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Unable to query GitHub issues for deduplication.' }
$existing = @()
if (-not [string]::IsNullOrWhiteSpace($searchJson)) { $existing = @($searchJson | ConvertFrom-Json -ErrorAction Stop | Where-Object { [string]$_.title -eq $title }) }
if ($existing.Count -gt 0) {
    $publication.existing = $true
    $publication.url = [string]$existing[0].url
    Write-Host ('Existing open upgrade issue: {0}' -f $publication.url) -ForegroundColor Yellow
    if ($PassThru) { [pscustomobject]$publication }
    return
}

$url = @(& $gh.Source issue create --repo $repo --title $title --body-file $issuePath 2>$null | Select-Object -Last 1) -join ''
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($url)) { throw 'GitHub issue creation failed.' }
$publication.published = $true
$publication.url = $url.Trim()
Write-Host ('Published version-upgrade sprint issue: {0}' -f $publication.url) -ForegroundColor Green
if ($PassThru) { [pscustomobject]$publication }
