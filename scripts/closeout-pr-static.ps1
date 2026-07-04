<#
.SYNOPSIS
Runs static PR closeout checks for a declared PR lane.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\closeout-pr-static.ps1 `
  -PrNumber 25 `
  -ExpectedBranch feat/launcher-window-context-helper `
  -Verifier scripts\verify-launcher-window-context-contract.ps1 `
  -Verifier scripts\verify-test-duration-policy-contract.ps1

.NOTES
This script intentionally performs static closeout only. It does not merge PRs, run live certs,
mutate saves, or claim runtime proof.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CloseoutArgs
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$options = [ordered]@{
    PrNumber = $null
    ExpectedBranch = $null
    RepoFullName = 'EndeavorEverlasting/BlacksmithGuild'
    Verifier = New-Object 'System.Collections.Generic.List[string]'
    RequireMergeable = $false
    AllowDraft = $false
    AllowDirty = $false
    SkipGitHub = $false
    PostComment = $false
    MarkReady = $false
}

function Write-TbgUsage {
    Write-Host 'Usage:' -ForegroundColor Cyan
    Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\closeout-pr-static.ps1 -PrNumber 25 -ExpectedBranch feat/example -Verifier scripts\verify-a.ps1 -Verifier scripts\verify-b.ps1'
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host '  -PrNumber <number>             Required. GitHub pull request number.'
    Write-Host '  -ExpectedBranch <branch>       Required. Local and PR head branch expected for this lane.'
    Write-Host '  -Verifier <path>               Required. Repeatable. One or more static verifier scripts.'
    Write-Host '  -RepoFullName <owner/repo>      Optional. Defaults to EndeavorEverlasting/BlacksmithGuild.'
    Write-Host '  -RequireMergeable              Optional. Fail unless GitHub reports MERGEABLE.'
    Write-Host '  -AllowDraft                    Optional. Permit draft PRs.'
    Write-Host '  -AllowDirty                    Optional. Permit dirty local status before/after checks.'
    Write-Host '  -SkipGitHub                    Optional. Skip gh CLI PR metadata checks.'
    Write-Host '  -PostComment                   Optional. Post a PASS comment to the PR after all checks pass.'
    Write-Host '  -MarkReady                     Optional. Mark a draft PR ready after all checks pass.'
}

function Fail-TbgCloseout {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host "FAIL: $Message" -ForegroundColor Red
    Write-Host ''
    Write-TbgUsage
    exit 1
}

function Read-TbgValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ref]$Index
    )

    if ($Index.Value + 1 -ge $CloseoutArgs.Count) {
        Fail-TbgCloseout "$Name requires a value."
    }

    $Index.Value++
    return $CloseoutArgs[$Index.Value]
}

function Read-TbgVerifierValues {
    param([Parameter(Mandatory = $true)][ref]$Index)

    $added = 0
    while ($Index.Value + 1 -lt $CloseoutArgs.Count) {
        if ($CloseoutArgs[$Index.Value + 1].StartsWith('-')) {
            break
        }

        $Index.Value++
        $raw = $CloseoutArgs[$Index.Value]
        foreach ($part in ($raw -split ',')) {
            $value = $part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $options.Verifier.Add($value) | Out-Null
                $added++
            }
        }
    }

    if ($added -eq 0) {
        Fail-TbgCloseout '-Verifier requires at least one script path.'
    }
}

for ($i = 0; $i -lt $CloseoutArgs.Count; $i++) {
    $token = $CloseoutArgs[$i]
    switch -Regex ($token) {
        '^-PrNumber$' {
            $value = Read-TbgValue -Name $token -Index ([ref]$i)
            $options.PrNumber = [int]$value
            continue
        }
        '^-ExpectedBranch$' {
            $options.ExpectedBranch = Read-TbgValue -Name $token -Index ([ref]$i)
            continue
        }
        '^-RepoFullName$' {
            $options.RepoFullName = Read-TbgValue -Name $token -Index ([ref]$i)
            continue
        }
        '^-Verifier$' {
            Read-TbgVerifierValues -Index ([ref]$i)
            continue
        }
        '^-RequireMergeable$' {
            $options.RequireMergeable = $true
            continue
        }
        '^-AllowDraft$' {
            $options.AllowDraft = $true
            continue
        }
        '^-AllowDirty$' {
            $options.AllowDirty = $true
            continue
        }
        '^-SkipGitHub$' {
            $options.SkipGitHub = $true
            continue
        }
        '^-PostComment$' {
            $options.PostComment = $true
            continue
        }
        '^-MarkReady$' {
            $options.MarkReady = $true
            continue
        }
        '^-Help$|^--help$|^/\?$' {
            Write-TbgUsage
            exit 0
        }
        default {
            Fail-TbgCloseout "Unknown argument: $token"
        }
    }
}

if ($null -eq $options.PrNumber) { Fail-TbgCloseout '-PrNumber is required.' }
if ([string]::IsNullOrWhiteSpace($options.ExpectedBranch)) { Fail-TbgCloseout '-ExpectedBranch is required.' }
if ($options.Verifier.Count -eq 0) { Fail-TbgCloseout 'At least one -Verifier is required.' }

function Invoke-TbgNative {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$CaptureOutput
    )

    Write-Host "RUN: $Label" -ForegroundColor Cyan
    if ($CaptureOutput) {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $output | ForEach-Object { Write-Host $_ }
            throw "$Label failed with exit code $exitCode."
        }

        return ($output -join "`n")
    }

    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode."
    }
}

function Get-TbgGitOutput {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & git @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "git $($Arguments -join ' ') failed with exit code $exitCode."
    }

    return ($output -join "`n").Trim()
}

function Assert-TbgCleanStatus {
    param([Parameter(Mandatory = $true)][string]$Stage)

    $status = Get-TbgGitOutput -Arguments @('status', '--short')
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        Write-Host "FAIL: working tree is dirty at $Stage." -ForegroundColor Red
        $status -split "`n" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }
}

Push-Location $repoRoot
try {
    Write-Host "Static closeout for PR #$($options.PrNumber) on $($options.ExpectedBranch)" -ForegroundColor Cyan
    Write-Host "Repo: $($options.RepoFullName)"
    Write-Host "Root: $repoRoot"
    Write-Host ''

    $topLevel = Get-TbgGitOutput -Arguments @('rev-parse', '--show-toplevel')
    if ([System.IO.Path]::GetFullPath($topLevel).TrimEnd('\', '/') -ne [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/')) {
        Fail-TbgCloseout "Git top-level '$topLevel' does not match script repo root '$repoRoot'."
    }

    $currentBranch = Get-TbgGitOutput -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
    if ($currentBranch -ne $options.ExpectedBranch) {
        Fail-TbgCloseout "Current branch '$currentBranch' does not match expected branch '$($options.ExpectedBranch)'."
    }

    if (-not $options.AllowDirty) {
        Assert-TbgCleanStatus -Stage 'start'
    }

    Invoke-TbgNative -Label 'git fetch origin --prune' -FilePath 'git' -Arguments @('fetch', 'origin', '--prune')

    $localHead = Get-TbgGitOutput -Arguments @('rev-parse', 'HEAD')
    $remoteHead = Get-TbgGitOutput -Arguments @('rev-parse', "origin/$($options.ExpectedBranch)")
    if ($localHead -ne $remoteHead) {
        Write-Host "FAIL: local HEAD does not match origin/$($options.ExpectedBranch)." -ForegroundColor Red
        Write-Host "  local : $localHead" -ForegroundColor Red
        Write-Host "  remote: $remoteHead" -ForegroundColor Red
        exit 1
    }

    $pr = $null
    if (-not $options.SkipGitHub) {
        $prJson = Invoke-TbgNative `
            -Label "gh pr view $($options.PrNumber)" `
            -FilePath 'gh' `
            -Arguments @('pr', 'view', [string]$options.PrNumber, '--repo', $options.RepoFullName, '--json', 'number,state,isDraft,headRefName,baseRefName,mergeable,url,title,headRefOid') `
            -CaptureOutput
        $pr = $prJson | ConvertFrom-Json

        if ($pr.state -ne 'OPEN') {
            Fail-TbgCloseout "PR #$($options.PrNumber) is not open. State: $($pr.state)."
        }

        if (($pr.headRefName -ne $options.ExpectedBranch)) {
            Fail-TbgCloseout "PR head '$($pr.headRefName)' does not match expected branch '$($options.ExpectedBranch)'."
        }

        if (($pr.headRefOid -ne $localHead)) {
            Write-Host "FAIL: PR head does not match local HEAD." -ForegroundColor Red
            Write-Host "  PR head: $($pr.headRefOid)" -ForegroundColor Red
            Write-Host "  local  : $localHead" -ForegroundColor Red
            exit 1
        }

        if ($pr.isDraft -and -not $options.AllowDraft -and -not $options.MarkReady) {
            Fail-TbgCloseout 'PR is draft. Use -AllowDraft to validate without readiness, or -MarkReady to mark ready after PASS.'
        }

        if ($options.RequireMergeable -and $pr.mergeable -ne 'MERGEABLE') {
            Fail-TbgCloseout "PR is not mergeable according to GitHub. mergeable=$($pr.mergeable)."
        }

        if (-not $options.RequireMergeable -and $pr.mergeable -ne 'MERGEABLE') {
            Write-Host "WARN: GitHub mergeability is $($pr.mergeable). Static verifiers will still run." -ForegroundColor Yellow
        }
    }

    foreach ($verifier in $options.Verifier) {
        $verifierPath = if ([System.IO.Path]::IsPathRooted($verifier)) {
            $verifier
        } else {
            Join-Path $repoRoot $verifier
        }

        if (-not (Test-Path -LiteralPath $verifierPath)) {
            Fail-TbgCloseout "Verifier missing: $verifier"
        }

        Invoke-TbgNative `
            -Label "powershell -File $verifier" `
            -FilePath 'powershell' `
            -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $verifierPath)
    }

    Invoke-TbgNative -Label 'git diff --check' -FilePath 'git' -Arguments @('diff', '--check')

    if (-not $options.AllowDirty) {
        Assert-TbgCleanStatus -Stage 'finish'
    }

    if ($options.MarkReady -and -not $options.SkipGitHub) {
        Invoke-TbgNative `
            -Label "gh pr ready $($options.PrNumber)" `
            -FilePath 'gh' `
            -Arguments @('pr', 'ready', [string]$options.PrNumber, '--repo', $options.RepoFullName)
    }

    if ($options.PostComment -and -not $options.SkipGitHub) {
        $verifierList = ($options.Verifier | ForEach-Object { "- ``$_``" }) -join "`n"
        $body = @"
Static closeout PASS.

- PR: #$($options.PrNumber)
- Branch: ``$($options.ExpectedBranch)``
- Head: ``$localHead``
- Verifiers:
$verifierList

No runtime proof claimed. No live cert run. No save mutation.
"@
        Invoke-TbgNative `
            -Label "gh pr comment $($options.PrNumber)" `
            -FilePath 'gh' `
            -Arguments @('pr', 'comment', [string]$options.PrNumber, '--repo', $options.RepoFullName, '--body', $body)
    }

    Write-Host ''
    Write-Host 'PASS: static PR closeout checks completed.' -ForegroundColor Green
    Write-Host "  PR: #$($options.PrNumber)"
    Write-Host "  Branch: $($options.ExpectedBranch)"
    Write-Host "  Head: $localHead"
    Write-Host '  Runtime proof: not claimed'
    Write-Host '  Save mutation: none requested'
    exit 0
} catch {
    Write-Host ''
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
