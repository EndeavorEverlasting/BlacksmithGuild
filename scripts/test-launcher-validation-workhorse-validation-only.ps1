# Windows PowerShell 5.1 regression for the real workhorse validation-only result path.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedBranch = 'agent/route-automation-operator-plan'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('tbg-launcher-workhorse-test-' + [Guid]::NewGuid().ToString('N'))
$fixtureRoot = Join-Path $tempRoot 'fixture'
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
    $workhorseSource = Join-Path $repoRoot 'scripts\run-launcher-validation-workhorse.ps1'
    Assert-Condition -Condition (Test-Path -LiteralPath $workhorseSource) -Message 'The launcher validation workhorse source is missing.'

    New-Item -ItemType Directory -Force -Path $tempRoot, $fixtureRoot | Out-Null
    [void](Invoke-FixtureGit -Arguments @('init', $fixtureRoot))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('config', 'user.email', 'tbg-workhorse-test@example.invalid'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('config', 'user.name', 'TBG Workhorse Regression'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('checkout', '-b', $expectedBranch))

    $fixtureScripts = Join-Path $fixtureRoot 'scripts'
    New-Item -ItemType Directory -Force -Path $fixtureScripts | Out-Null
    Copy-Item -LiteralPath $workhorseSource -Destination (Join-Path $fixtureScripts 'run-launcher-validation-workhorse.ps1')
    'artifacts/' | Set-Content -LiteralPath (Join-Path $fixtureRoot '.gitignore') -Encoding UTF8
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('add', '.gitignore', 'scripts/run-launcher-validation-workhorse.ps1'))
    [void](Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('commit', '-m', 'test: seed validation-only workhorse fixture'))

    $beforeHead = ((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    $workhorsePath = Join-Path $fixtureScripts 'run-launcher-validation-workhorse.ps1'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $workhorsePath,
        '-RepoRoot', $fixtureRoot,
        '-ExpectedBranch', $expectedBranch,
        '-NoLaunch',
        '-SkipSync',
        '-SkipValidators',
        '-SkipStop'
    )
    $global:LASTEXITCODE = 0
    $output = & powershell.exe @arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $outputText = ($output | Out-String)

    Assert-Condition -Condition ($outputText -notmatch "The property 'Count' cannot be found on this object") `
        -Message 'The real validation-only workhorse reproduced the strict-mode Count failure.'
    Assert-Condition -Condition ($exitCode -eq 0) -Message ('The validation-only workhorse returned exit code {0}: {1}' -f $exitCode, $outputText.Trim())

    $latestRoot = Join-Path $fixtureRoot 'artifacts\latest'
    $resultPath = Join-Path $latestRoot 'launcher-validation-workhorse.result.json'
    $handoffPath = Join-Path $latestRoot 'launcher-validation-workhorse.handoff.md'
    $progressPath = Join-Path $latestRoot 'launcher-validation-workhorse.progress.log'
    Assert-Condition -Condition (Test-Path -LiteralPath $resultPath) -Message 'The workhorse did not write its latest result.'
    Assert-Condition -Condition (Test-Path -LiteralPath $handoffPath) -Message 'The workhorse did not write its latest handoff.'
    Assert-Condition -Condition (Test-Path -LiteralPath $progressPath) -Message 'The workhorse did not write its latest progress log.'

    $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Condition -Condition ($result.schema -eq 'TbgLauncherValidationWorkhorse.v1') -Message 'The workhorse result schema is incorrect.'
    Assert-Condition -Condition ($result.terminalState -eq 'validation_only_complete') -Message ('Expected validation_only_complete but observed {0}.' -f $result.terminalState)
    Assert-Condition -Condition ([int]$result.exitCode -eq 0) -Message 'The workhorse result did not record exit code zero.'
    Assert-Condition -Condition (-not [bool]$result.proof.contractProof) -Message 'Skipped validators must not produce contract proof.'
    Assert-Condition -Condition ([bool]$result.proof.staticTestProof) -Message 'Skipped validators with no failures must retain a non-failure static-test result.'
    Assert-Condition -Condition (@($result.steps).Count -eq 0) -Message 'The validation-only fixture unexpectedly recorded executable validator or stop steps.'

    $afterHead = ((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    $afterStatus = @((Invoke-FixtureGit -WorkingRoot $fixtureRoot -Arguments @('status', '--porcelain=v1', '--untracked-files=all')))
    Assert-Condition -Condition ($afterHead -eq $beforeHead) -Message 'The workhorse changed the fixture HEAD.'
    Assert-Condition -Condition ($afterStatus.Count -eq 0) -Message 'The workhorse left tracked or unignored changes in the fixture.'

    Write-Host 'PASS: Windows PowerShell 5.1 completed the real validation-only workhorse path and wrote a stable zero-step result.' -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('FAIL: launcher validation workhorse validation-only regression: {0}' -f $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
