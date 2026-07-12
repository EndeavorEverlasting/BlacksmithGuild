# Executable Windows PowerShell 5.1 regression for the supervisor's first empty-list insertion.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedBranch = 'agent/route-automation-operator-plan'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-launcher-supervisor-test-' + [Guid]::NewGuid().ToString('N'))
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
    $global:LASTEXITCODE = 0
    $output = & $gitPath @allArguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    if ($exitCode -ne 0) {
        throw ('git {0} returned exit code {1}: {2}' -f ($allArguments -join ' '), $exitCode, (($output | Out-String).Trim()))
    }
    return @($output)
}

try {
    Assert-Condition -Condition ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5) `
        -Message 'This regression must run under Windows PowerShell 5.1 through powershell.exe.'

    $gitCommand = Get-Command git.exe -ErrorAction Stop
    $gitPath = $gitCommand.Source
    $supervisorSource = Join-Path $repoRoot 'scripts\run-launcher-validation-supervisor.ps1'
    $workhorseSource = Join-Path $repoRoot 'scripts\run-launcher-validation-workhorse.ps1'
    Assert-Condition -Condition (Test-Path -LiteralPath $supervisorSource) -Message 'The launcher validation supervisor source is missing.'
    Assert-Condition -Condition (Test-Path -LiteralPath $workhorseSource) -Message 'The launcher validation workhorse source is missing.'

    New-Item -ItemType Directory -Force -Path $tempRoot, $fixtureRoot, $shimRoot | Out-Null
    [void](Invoke-FixtureGit -Arguments @('init', '--bare', $remoteRoot))
    [void](Invoke-FixtureGit -Arguments @('init', $fixtureRoot))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('config', 'user.email', 'tbg-supervisor-test@example.invalid'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('config', 'user.name', 'TBG Supervisor Regression'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('checkout', '-b', $expectedBranch))

    $fixtureScripts = Join-Path $fixtureRoot 'scripts'
    New-Item -ItemType Directory -Force -Path $fixtureScripts | Out-Null
    Copy-Item -LiteralPath $supervisorSource -Destination (Join-Path $fixtureScripts 'run-launcher-validation-supervisor.ps1')
    Copy-Item -LiteralPath $workhorseSource -Destination (Join-Path $fixtureScripts 'run-launcher-validation-workhorse.ps1')
    'artifacts/' | Set-Content -LiteralPath (Join-Path $fixtureRoot '.gitignore') -Encoding UTF8

    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('add', '.gitignore', 'scripts/run-launcher-validation-supervisor.ps1', 'scripts/run-launcher-validation-workhorse.ps1'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('commit', '-m', 'test: seed synchronized supervisor fixture'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('remote', 'add', 'origin', $remoteRoot))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('push', '-u', 'origin', $expectedBranch))

    $beforeHead = ((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    $beforeStatus = @((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')))
    $counts = (((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-list', '--left-right', '--count', ('HEAD...origin/' + $expectedBranch))) -join ' ').Trim()) -split '\s+'
    Assert-Condition -Condition ($beforeStatus.Count -eq 0) -Message 'The disposable fixture must be clean before the supervisor starts.'
    Assert-Condition -Condition ($counts.Count -ge 2 -and [int]$counts[0] -eq 0 -and [int]$counts[1] -eq 0) -Message 'The disposable fixture must exactly match its origin branch.'

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
        '-NoLaunch',
        '-SkipValidators',
        '-SkipStop'
    )
    $global:LASTEXITCODE = 0
    $output = & powershell.exe @arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $outputText = ($output | Out-String)

    Assert-Condition -Condition ($outputText -notmatch "Cannot bind argument to parameter 'List' because it is an empty collection") `
        -Message 'The supervisor reproduced the Windows PowerShell 5.1 empty-collection binding failure.'
    Assert-Condition -Condition ($exitCode -eq 0) -Message ('The supervisor returned exit code {0}: {1}' -f $exitCode, $outputText.Trim())

    $latestRoot = Join-Path $fixtureRoot 'artifacts\latest'
    $resultPath = Join-Path $latestRoot 'launcher-validation-supervisor.result.json'
    $handoffPath = Join-Path $latestRoot 'launcher-validation-supervisor.handoff.md'
    $progressPath = Join-Path $latestRoot 'launcher-validation-supervisor.progress.log'
    Assert-Condition -Condition (Test-Path -LiteralPath $resultPath) -Message 'The supervisor did not write its latest result schema.'
    Assert-Condition -Condition (Test-Path -LiteralPath $handoffPath) -Message 'The supervisor did not write its latest handoff.'
    Assert-Condition -Condition (Test-Path -LiteralPath $progressPath) -Message 'The supervisor did not write its latest progress log.'

    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $attempts = @($result.modeAttempts)
    Assert-Condition -Condition ($result.schema -eq 'TbgLauncherValidationSupervisor.v1') -Message 'The supervisor result schema is incorrect.'
    Assert-Condition -Condition ($result.selectedMode -eq 'current_synced') -Message ('Expected current_synced but observed {0}.' -f $result.selectedMode)
    Assert-Condition -Condition ($result.terminalState -eq 'supervisor_complete') -Message ('Expected supervisor_complete but observed {0}.' -f $result.terminalState)
    Assert-Condition -Condition ($result.childState -eq 'validation_only_complete') -Message ('Expected validation_only_complete but observed {0}.' -f $result.childState)
    Assert-Condition -Condition ($attempts.Count -gt 0 -and $attempts[0].mode -eq 'current_synced') -Message 'The first recorded workspace attempt was not current_synced.'

    $trace = if (Test-Path -LiteralPath $tracePath) { Get-Content -LiteralPath $tracePath -Raw } else { '' }
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($trace)) -Message 'The disposable Git shim did not record supervisor Git commands.'
    foreach ($forbidden in @(
        '(?im)\bgit\s+reset\s+--hard\b',
        '(?im)\bgit\s+clean(?:\s|$)',
        '(?im)\bgit\s+stash(?:\s|$)',
        '(?im)\bgit\s+push\s+--force\b',
        '(?im)\bgit\s+worktree\s+remove\s+--force\b',
        '(?im)\bgit\s+branch\s+-D\b'
    )) {
        Assert-Condition -Condition ($trace -notmatch $forbidden) -Message ('The supervisor executed a forbidden Git command matching {0}.' -f $forbidden)
    }

    $env:PATH = $oldPath
    $afterHead = ((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    $afterStatus = @((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')))
    Assert-Condition -Condition ($afterHead -eq $beforeHead) -Message 'The supervisor changed the fixture HEAD.'
    Assert-Condition -Condition ($afterStatus.Count -eq 0) -Message 'The supervisor left tracked or unignored changes in the fixture.'

    Write-Host 'PASS: Windows PowerShell 5.1 inserted the first empty supervisor candidate, selected current_synced, wrote evidence, and executed no destructive Git command.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: launcher validation supervisor workspace-selection regression: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    $env:PATH = $oldPath
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
