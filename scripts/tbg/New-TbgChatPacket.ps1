<#
.SYNOPSIS
    Writes a compact local status packet for agent handoff.

.DESCRIPTION
    Captures safe repository state, open PR metadata, selected latest artifacts, and one
    copy/paste-ready Markdown packet. Optionally copies the packet to the clipboard and
    posts it as a GitHub PR comment through the GitHub CLI.

    This script is intentionally static/read-only. It does not launch Bannerlord, run
    ForgeReboot, write command inbox files, mutate saves, delete branches, or clean worktrees.
#>
param(
    [string]$RepoRoot = '.',
    [string]$OutPath = 'artifacts/latest/tbg-chat-packet.md',
    [string]$JsonOutPath = 'artifacts/latest/tbg-chat-packet.json',
    [int]$PrNumber = 0,
    [switch]$PostPrComment,
    [switch]$NoClipboard,
    [int]$MaxCommandChars = 12000,
    [int]$MaxArtifactChars = 8000
)

$ErrorActionPreference = 'Continue'

function Resolve-RepoRoot {
    param([string]$Path)

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    Push-Location -LiteralPath $resolved
    try {
        $root = (& git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
            throw "Path is not inside a Git repository: $Path"
        }
        return $root.Trim()
    }
    finally {
        Pop-Location
    }
}

function Limit-Text {
    param(
        [AllowNull()][string]$Text,
        [int]$MaxChars
    )

    if ($null -eq $Text) { return '' }
    if ($Text.Length -le $MaxChars) { return $Text }
    return $Text.Substring(0, $MaxChars) + "`n...TRUNCATED after $MaxChars characters..."
}

function Invoke-CapturedCommand {
    param(
        [string]$Label,
        [string]$Command,
        [int]$MaxChars = $MaxCommandChars
    )

    $output = ''
    $exitCode = $null

    try {
        $output = (& cmd.exe /d /s /c $Command 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = $_.Exception.Message
        $exitCode = -1
    }

    return [pscustomobject]@{
        label = $Label
        command = $Command
        exitCode = $exitCode
        output = (Limit-Text -Text $output.TrimEnd() -MaxChars $MaxChars)
    }
}

function Add-MarkdownSection {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Title,
        [string]$Text
    )

    $Lines.Add('') | Out-Null
    $Lines.Add("## $Title") | Out-Null
    $Lines.Add('') | Out-Null
    $Lines.Add('````text') | Out-Null
    $Lines.Add(($Text | Out-String).TrimEnd()) | Out-Null
    $Lines.Add('````') | Out-Null
}

function Read-ArtifactText {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Limit-Text -Text (Get-Content -LiteralPath $Path -Raw) -MaxChars $MaxArtifactChars
    }
    catch {
        return "Unable to read artifact: $($_.Exception.Message)"
    }
}

try {
    $repoRootResolved = Resolve-RepoRoot -Path $RepoRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

Set-Location -LiteralPath $repoRootResolved

$outDir = Split-Path -Parent $OutPath
$jsonOutDir = Split-Path -Parent $JsonOutPath
if (-not [string]::IsNullOrWhiteSpace($outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
if (-not [string]::IsNullOrWhiteSpace($jsonOutDir)) { New-Item -ItemType Directory -Force -Path $jsonOutDir | Out-Null }

$commands = New-Object System.Collections.Generic.List[object]
$commands.Add((Invoke-CapturedCommand -Label 'repoRoot' -Command 'git rev-parse --show-toplevel')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'branch' -Command 'git branch --show-current')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'head' -Command 'git log --oneline --decorate -8')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'status' -Command 'git status --short')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'statusIgnored' -Command 'git status --short --ignored')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'unmergedFiles' -Command 'git diff --name-only --diff-filter=U')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'worktrees' -Command 'git worktree list')) | Out-Null
$commands.Add((Invoke-CapturedCommand -Label 'remotes' -Command 'git remote -v')) | Out-Null

$hasGh = $false
try {
    $null = Get-Command gh -ErrorAction Stop
    $hasGh = $true
}
catch {
    $hasGh = $false
}

if ($hasGh) {
    $commands.Add((Invoke-CapturedCommand -Label 'openPRs' -Command 'gh pr list --state open --limit 20')) | Out-Null
    if ($PrNumber -gt 0) {
        $commands.Add((Invoke-CapturedCommand -Label "pr$PrNumber" -Command "gh pr view $PrNumber --json number,title,state,isDraft,baseRefName,headRefName,mergeable,url,headRefOid")) | Out-Null
    }
}
else {
    $commands.Add([pscustomobject]@{
        label = 'openPRs'
        command = 'gh pr list --state open --limit 20'
        exitCode = $null
        output = 'SKIPPED: GitHub CLI not found on PATH.'
    }) | Out-Null
}

$artifactCandidates = @(
    'artifacts/latest/agent-status.md',
    'artifacts/latest/agent-status.json',
    'artifacts/latest/route-visible-start.result.json',
    'artifacts/latest/harness-readiness.result.json',
    'artifacts/latest/project-ai-layer.result.json',
    'artifacts/latest/done-gate.result.json',
    'artifacts/latest/mcp-readiness.result.json',
    'artifacts/latest/mcp-symbol-smoke.result.json',
    'artifacts/latest/command-safety.result.json',
    'artifacts/latest/claude-rules-update.proposal.md'
)

$artifacts = New-Object System.Collections.Generic.List[object]
foreach ($candidate in $artifactCandidates) {
    $text = Read-ArtifactText -Path $candidate
    if ($null -ne $text) {
        $artifacts.Add([pscustomobject]@{ path = $candidate; content = $text }) | Out-Null
    }
}

$unmergedOutput = (($commands | Where-Object { $_.label -eq 'unmergedFiles' } | Select-Object -First 1).output).Trim()
$statusOutput = (($commands | Where-Object { $_.label -eq 'status' } | Select-Object -First 1).output).Trim()
$branchOutput = (($commands | Where-Object { $_.label -eq 'branch' } | Select-Object -First 1).output).Trim()

$verdict = 'INFO'
$blockedReason = ''
$nextCommand = '.\ForgeAgentStatus.cmd'

if (-not [string]::IsNullOrWhiteSpace($unmergedOutput)) {
    $verdict = 'BLOCKED'
    $blockedReason = 'repository has unmerged files'
    $nextCommand = 'git diff --name-only --diff-filter=U'
}
elseif (-not [string]::IsNullOrWhiteSpace($statusOutput)) {
    $verdict = 'ATTENTION'
    $blockedReason = 'repository has tracked or untracked changes'
    $nextCommand = 'git status --short'
}

$packetObject = [pscustomobject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    repoRoot = [string]$repoRootResolved
    branch = [string]$branchOutput
    prNumber = [int]$PrNumber
    verdict = [string]$verdict
    blockedReason = [string]$blockedReason
    nextCommand = [string]$nextCommand
    commands = @($commands.ToArray())
    artifacts = @($artifacts.ToArray())
    boundaries = [pscustomobject]@{
        launchesBannerlord = $false
        runsForgeReboot = $false
        writesCommandInbox = $false
        mutatesSaves = $false
        deletesBranches = $false
        cleansWorktrees = $false
    }
}

$packetObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonOutPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# TBG Local Agent Packet') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("Generated: $($packetObject.generatedAt)") | Out-Null
$lines.Add("Repo: $repoRootResolved") | Out-Null
$lines.Add("Branch: $branchOutput") | Out-Null
if ($PrNumber -gt 0) { $lines.Add("PR: #$PrNumber") | Out-Null }
$lines.Add("Verdict: $verdict") | Out-Null
if (-not [string]::IsNullOrWhiteSpace($blockedReason)) { $lines.Add("Blocked reason: $blockedReason") | Out-Null }
$lines.Add("Next command: $nextCommand") | Out-Null
$lines.Add('') | Out-Null
$lines.Add('Boundaries: no Bannerlord launch, no ForgeReboot, no command inbox write, no save mutation, no branch deletion, no worktree cleanup.') | Out-Null

foreach ($commandResult in $commands) {
    $sectionText = "command: $($commandResult.command)`nexitCode: $($commandResult.exitCode)`n`n$($commandResult.output)"
    Add-MarkdownSection -Lines $lines -Title $commandResult.label -Text $sectionText
}

foreach ($artifact in $artifacts) {
    Add-MarkdownSection -Lines $lines -Title $artifact.path -Text $artifact.content
}

$packetText = ($lines -join "`n") + "`n"
$packetText | Set-Content -LiteralPath $OutPath -Encoding UTF8

if (-not $NoClipboard) {
    try {
        $packetText | Set-Clipboard
        Write-Host "Copied packet to clipboard."
    }
    catch {
        Write-Host "Clipboard copy skipped: $($_.Exception.Message)"
    }
}

if ($PostPrComment) {
    if (-not $hasGh) {
        Write-Warning 'Cannot post PR comment because GitHub CLI is not available.'
    }
    elseif ($PrNumber -le 0) {
        Write-Warning 'Cannot post PR comment because -PrNumber was not provided.'
    }
    else {
        & gh pr comment $PrNumber --body-file $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "gh pr comment failed with exit code $LASTEXITCODE."
        }
    }
}

Write-Host "Packet written: $OutPath"
Write-Host "JSON written:   $JsonOutPath"
Write-Host "Verdict:        $verdict"
if (-not [string]::IsNullOrWhiteSpace($blockedReason)) { Write-Host "Blocked reason: $blockedReason" }
Write-Host "Next command:   $nextCommand"
