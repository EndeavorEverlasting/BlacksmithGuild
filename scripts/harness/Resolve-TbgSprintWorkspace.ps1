param(
    [string]$PrimaryRepo = '',
    [string]$WorktreePath = '',
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TargetBranch,
    [int]$FoundationPr = 0,
    [string[]]$ForbiddenPaths = @(
        'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs',
        'src/BlacksmithGuild/MapTrade/MapTradeEvidenceWriter.cs',
        'src/BlacksmithGuild/MapTrade/MapTradeModels.cs'
    ),
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitCapture {
    param([string]$Repo, [string[]]$Arguments)
    $output = & git -C $Repo @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return ($output -join "`n").TrimEnd()
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifest = Get-Content -LiteralPath (Join-Path $repoRoot '.tbg/harness/manifest.json') -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($PrimaryRepo)) {
    $candidate = [string]$manifest.repo.protectedLocalPath
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Container)) {
        $PrimaryRepo = $candidate
    }
    else {
        $PrimaryRepo = $repoRoot
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $PrimaryRepo '.git'))) {
    $inside = Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('rev-parse', '--is-inside-work-tree')
    if ($inside -ne 'true') { throw "PrimaryRepo is not a Git worktree: $PrimaryRepo" }
}

$statusShort = Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('status', '--short')
$currentBranch = Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('branch', '--show-current')
$conflictedPaths = @((Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('diff', '--name-only', '--diff-filter=U')) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$originHead = Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('symbolic-ref', '--short', 'refs/remotes/origin/HEAD')
if ([string]::IsNullOrWhiteSpace($originHead)) { $originHead = 'origin/main' }

if ([string]::IsNullOrWhiteSpace($WorktreePath)) {
    $parent = Split-Path -Parent $PrimaryRepo
    $leaf = Split-Path -Leaf $PrimaryRepo
    $suffix = ($TargetBranch -replace '[^A-Za-z0-9_.-]', '-')
    $WorktreePath = Join-Path $parent "$leaf-$suffix"
}

$existingWorktreePath = ''
$worktreeLines = @((Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('worktree', 'list', '--porcelain')) -split "`r?`n")
$candidatePath = ''
foreach ($line in $worktreeLines) {
    if ($line -like 'worktree *') { $candidatePath = $line.Substring(9) }
    elseif ($line -eq "branch refs/heads/$TargetBranch" -and -not [string]::IsNullOrWhiteSpace($candidatePath)) {
        $existingWorktreePath = $candidatePath
    }
}

$prState = 'none'
$prHead = ''
$prBase = ''
$prUrl = ''
if ($FoundationPr -gt 0 -and $null -ne (Get-Command gh -ErrorAction SilentlyContinue)) {
    try {
        $remote = Invoke-GitCapture -Repo $PrimaryRepo -Arguments @('remote', 'get-url', 'origin')
        $repoName = $remote -replace '^https://github\.com/', '' -replace '^git@github\.com:', '' -replace '\.git$', ''
        $prJson = & gh pr view $FoundationPr --repo $repoName --json state,headRefName,baseRefName,url 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($prJson -join ''))) {
            $pr = ($prJson -join "`n") | ConvertFrom-Json
            $prState = [string]$pr.state
            $prHead = [string]$pr.headRefName
            $prBase = [string]$pr.baseRefName
            $prUrl = [string]$pr.url
        }
        else { $prState = 'UNKNOWN' }
    }
    catch { $prState = 'UNKNOWN' }
}

Import-Module (Join-Path $PSScriptRoot 'TbgSprintWorkspace.psm1') -Force
$decision = Resolve-TbgSprintWorkspaceDecision -StatusShort $statusShort -ConflictedPaths $conflictedPaths -CurrentBranch $currentBranch -DefaultRemoteBase $originHead -FoundationPrState $prState -FoundationHead $prHead -FoundationBase $prBase -FoundationPrUrl $prUrl -ExistingWorktreePath $existingWorktreePath -PrimaryRepo $PrimaryRepo -WorktreePath $WorktreePath -TargetBranch $TargetBranch -ForbiddenPaths $ForbiddenPaths

$artifactDir = Join-Path $repoRoot 'artifacts/latest'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $artifactDir 'sprint-workspace-decision.json' }
$reportPath = $OutputPath -replace '\.json$', '.report.md'
$json = $decision | ConvertTo-Json -Depth 20
Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
$markdown = @(
    '# Sprint workspace decision',
    '',
    $decision.englishSummary,
    '',
    '## Machine decision (secondary)',
    '',
    '```json',
    $json,
    '```'
) -join "`r`n"
Set-Content -LiteralPath $reportPath -Value $markdown -Encoding UTF8
Write-Output $json
