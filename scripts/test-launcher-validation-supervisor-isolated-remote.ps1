# Windows PowerShell 5.1 regression for informational Git stderr during isolated-remote selection.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedBranch = 'agent/route-automation-operator-plan'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-launcher-supervisor-isolated-test-' + [Guid]::NewGuid().ToString('N'))
$remoteRoot = Join-Path $tempRoot 'origin.git'
$fixtureRoot = Join-Path $tempRoot 'fixture'
$shimRoot = Join-Path $tempRoot 'bin'
$tracePath = Join-Path $tempRoot 'git-commands.log'
$oldPath = $env:PATH
$gitPath = $null

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Invoke-FixtureGit {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingRoot = ''
    )
    $allArguments = if ([string]::IsNullOrWhiteSpace($WorkingRoot)) {
        $Arguments
    } else {
        @('-C', $WorkingRoot) + $Arguments
    }
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        $output = & $gitPath @allArguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw ('git {0} returned exit code {1}: {2}' -f ($allArguments -join ' '), $exitCode, (($output | Out-String).Trim()))
    }
    return @($output)
}

try {
    Assert-Condition -Condition ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5) `
        -Message 'This regression must run under Windows PowerShell 5.1 through powershell.exe.'

    $gitPath = (Get-Command git.exe -ErrorAction Stop).Source
    $supervisorSource = Join-Path $repoRoot 'scripts\run-launcher-validation-supervisor.ps1'
    Assert-Condition -Condition (Test-Path -LiteralPath $supervisorSource) -Message 'The launcher validation supervisor source is missing.'

    New-Item -ItemType Directory -Force -Path $tempRoot, $fixtureRoot, $shimRoot | Out-Null
    [void](Invoke-FixtureGit -Arguments @('init', '--bare', $remoteRoot))
    [void](Invoke-FixtureGit -Arguments @('init', $fixtureRoot))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('config', 'user.email', 'tbg-supervisor-isolated-test@example.invalid'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('config', 'user.name', 'TBG Supervisor Isolated Regression'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('checkout', '-b', $expectedBranch))

    $fixtureScripts = Join-Path $fixtureRoot 'scripts'
    New-Item -ItemType Directory -Force -Path $fixtureScripts | Out-Null
    Copy-Item -LiteralPath $supervisorSource -Destination (Join-Path $fixtureScripts 'run-launcher-validation-supervisor.ps1')
    @'
param(
    [string]$RepoRoot,
    [string]$LaunchIntent,
    [string]$ExpectedBranch,
    [switch]$SkipSync,
    [switch]$SkipValidators,
    [switch]$SkipStop,
    [switch]$NoLaunch
)
$latestRoot = Join-Path $RepoRoot 'artifacts\latest'
New-Item -ItemType Directory -Force -Path $latestRoot | Out-Null
'PASSED: The isolated synthetic leaf accepted the supervisor handoff.' | Set-Content -LiteralPath (Join-Path $latestRoot 'launcher-validation-workhorse.progress.log') -Encoding UTF8
'# Synthetic isolated launcher-validation leaf handoff' | Set-Content -LiteralPath (Join-Path $latestRoot 'launcher-validation-workhorse.handoff.md') -Encoding UTF8
[ordered]@{
    schema = 'TbgLauncherValidationWorkhorse.v1'
    terminalState = 'validation_only_complete'
    exitCode = 0
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $latestRoot 'launcher-validation-workhorse.result.json') -Encoding UTF8
exit 0
'@ | Set-Content -LiteralPath (Join-Path $fixtureScripts 'run-launcher-validation-workhorse.ps1') -Encoding UTF8
    'artifacts/' | Set-Content -LiteralPath (Join-Path $fixtureRoot '.gitignore') -Encoding UTF8

    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('add', '.gitignore', 'scripts/run-launcher-validation-supervisor.ps1', 'scripts/run-launcher-validation-workhorse.ps1'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('commit', '-m', 'test: seed isolated supervisor fixture'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('remote', 'add', 'origin', $remoteRoot))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('push', '-u', 'origin', $expectedBranch))

    $beforeHead = ((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    'preserve this local operator file' | Set-Content -LiteralPath (Join-Path $fixtureRoot 'operator-local.txt') -Encoding UTF8
    $beforeStatus = @((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')))
    Assert-Condition -Condition ($beforeStatus.Count -eq 1) -Message 'The source fixture must contain exactly one preserved local status entry.'

    @(
        '@echo off',
        ('echo git %*>>"{0}"' -f $tracePath),
        ('"{0}" %*' -f $gitPath),
        'exit /b %ERRORLEVEL%'
    ) | Set-Content -LiteralPath (Join-Path $shimRoot 'git.cmd') -Encoding ASCII
    $env:PATH = $shimRoot + [IO.Path]::PathSeparator + $oldPath

    $supervisorPath = Join-Path $fixtureScripts 'run-launcher-validation-supervisor.ps1'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $supervisorPath,
        '-RepoRoot', $fixtureRoot,
        '-ExpectedBranch', $expectedBranch,
        '-WorkspaceStrategy', 'remote-first',
        '-MaxWorkspaceModes', '1',
        '-NoLaunch',
        '-SkipValidators',
        '-SkipStop'
    )
    $global:LASTEXITCODE = 0
    $output = & powershell.exe @arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $outputText = ($output | Out-String)

    Assert-Condition -Condition ($outputText -notmatch 'Preparing worktree.*unhandled exception') `
        -Message 'Informational git worktree stderr still terminated the supervisor.'
    Assert-Condition -Condition ($exitCode -eq 0) -Message ('The isolated supervisor returned exit code {0}: {1}' -f $exitCode, $outputText.Trim())

    $latestRoot = Join-Path $fixtureRoot 'artifacts\latest'
    $resultPath = Join-Path $latestRoot 'launcher-validation-supervisor.result.json'
    Assert-Condition -Condition (Test-Path -LiteralPath $resultPath) -Message 'The supervisor did not write its isolated-mode result.'
    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $attempts = @($result.modeAttempts)
    Assert-Condition -Condition ($result.selectedMode -eq 'isolated_remote') -Message ('Expected isolated_remote but observed {0}.' -f $result.selectedMode)
    Assert-Condition -Condition ($result.terminalState -eq 'supervisor_complete') -Message ('Expected supervisor_complete but observed {0}.' -f $result.terminalState)
    Assert-Condition -Condition ($result.childState -eq 'validation_only_complete') -Message ('Expected validation_only_complete but observed {0}.' -f $result.childState)
    Assert-Condition -Condition ($attempts.Count -eq 1 -and $attempts[0].mode -eq 'isolated_remote') -Message 'The isolated_remote mode was not the sole recorded attempt.'
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$result.executionRoot)) -Message 'The supervisor did not record its isolated execution root.'
    Assert-Condition -Condition ([IO.Path]::GetFullPath([string]$result.executionRoot) -ne [IO.Path]::GetFullPath($fixtureRoot)) -Message 'The supervisor reused the dirty source worktree instead of isolating execution.'

    $trace = if (Test-Path -LiteralPath $tracePath) { Get-Content -LiteralPath $tracePath -Raw } else { '' }
    Assert-Condition -Condition ($trace -match '(?im)\bgit\s+-C\s+.*\sworktree\s+add\s+-b\s+') -Message 'The Git trace did not record isolated worktree creation.'
    foreach ($forbidden in @(
        '(?im)\bgit\s+.*\sreset\s+--hard\b',
        '(?im)\bgit\s+.*\sclean(?:\s|$)',
        '(?im)\bgit\s+.*\sstash(?:\s|$)',
        '(?im)\bgit\s+.*\spush\s+--force\b',
        '(?im)\bgit\s+.*\sworktree\s+remove\s+--force\b',
        '(?im)\bgit\s+.*\sbranch\s+-D\b'
    )) {
        Assert-Condition -Condition ($trace -notmatch $forbidden) -Message ('The supervisor executed a forbidden Git command matching {0}.' -f $forbidden)
    }

    $env:PATH = $oldPath
    $afterHead = ((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    $afterStatus = @((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')))
    Assert-Condition -Condition ($afterHead -eq $beforeHead) -Message 'The supervisor changed the dirty source fixture HEAD.'
    Assert-Condition -Condition ($afterStatus.Count -eq 1) -Message 'The supervisor did not preserve the source fixture status exactly.'
    Assert-Condition -Condition (Test-Path -LiteralPath (Join-Path $fixtureRoot 'operator-local.txt')) -Message 'The supervisor removed the preserved local operator file.'

    Write-Host 'PASS: Windows PowerShell 5.1 created isolated_remote despite informational Git stderr and preserved the dirty source worktree.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: launcher validation supervisor isolated-remote regression: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    $env:PATH = $oldPath
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
