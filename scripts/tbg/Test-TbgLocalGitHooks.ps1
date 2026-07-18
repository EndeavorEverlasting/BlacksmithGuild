<#
.SYNOPSIS
    Integration tests for the local Git pre-commit hook and installer.

.DESCRIPTION
    Creates an isolated temp repository, installs the local hooks, and
    verifies via git commit (the real hook invocation path):
    - The installer configures core.hooksPath
    - The pre-commit hook blocks generated/runtime evidence
    - Remediation guidance appears on block
    - Sanitized fixtures are allowed through
    - Docs and code changes are not broadly blocked
    - The hook does not execute runtime, launcher, or network activity
    - The hook does not print sensitive file contents
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [string]$HookScript = 'scripts/Install-LocalGitHooks.ps1',
    [string]$PreCommitHook = '.githooks/pre-commit'
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Haystack,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Haystack -notmatch [regex]::Escape($Needle)) {
        throw "$Message  Expected to contain [$Needle] but got: $Haystack"
    }
}

function Invoke-TestCommit {
    param(
        [string]$FilePath,
        [string]$FileContent,
        [string]$TestName
    )
    Set-Content -LiteralPath (Join-Path $tempRoot $FilePath) -Value $FileContent -Encoding UTF8 -Force
    & git add $FilePath 2>$null

    $commitTemp = Join-Path $tempRoot '.test-commit-output.txt'
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $null = & git commit -m "test: $TestName" 2>&1 | Out-File -LiteralPath $commitTemp -Encoding UTF8
    } finally {
        $ErrorActionPreference = $prevEAP
    }
    $exitCode = $LASTEXITCODE
    $output = if (Test-Path -LiteralPath $commitTemp) {
        Get-Content -LiteralPath $commitTemp -Raw
    } else { '' }

    # If commit succeeded, soft-reset to undo it; if blocked, just unstage
    if ($exitCode -eq 0) {
        & git reset HEAD~1 --soft 2>$null | Out-Null
    }
    & git reset HEAD $FilePath 2>$null | Out-Null
    Remove-Item -LiteralPath (Join-Path $tempRoot $FilePath) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $commitTemp -Force -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        Output = $output
        ExitCode = $exitCode
    }
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$hookSource = Join-Path $resolvedRoot $PreCommitHook
$installerSource = Join-Path $resolvedRoot $HookScript

if (-not (Test-Path -LiteralPath $hookSource)) {
    throw "Missing pre-commit hook: $hookSource"
}
if (-not (Test-Path -LiteralPath $installerSource)) {
    throw "Missing installer script: $installerSource"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tbg-git-hook-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

Push-Location -LiteralPath $tempRoot
try {
    Write-Host "=== Test repo: $tempRoot ==="

    # --- Init repo ---
    & git init | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git init failed." }
    & git config user.email 'hook-test@example.invalid'
    & git config user.name 'TBG Hook Test'

    'initial' | Set-Content -LiteralPath 'README.md' -Encoding UTF8
    & git add README.md
    & git commit -m 'test: seed fixture' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "seed commit failed." }

    # --- Copy hook and installer into temp repo ---
    $hooksDir = Join-Path $tempRoot '.githooks'
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
    Copy-Item -LiteralPath $hookSource -Destination (Join-Path $hooksDir 'pre-commit') -Force

    $tempInstaller = Join-Path $tempRoot 'Install-LocalGitHooks.ps1'
    Copy-Item -LiteralPath $installerSource -Destination $tempInstaller -Force

    # ===========================================================
    # TEST 1: Installer configures core.hooksPath
    # ===========================================================
    Write-Host "TEST 1: Installer configures core.hooksPath"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $tempInstaller -RepoRoot $tempRoot
    if ($LASTEXITCODE -ne 0) { throw "Installer failed." }

    $configuredPath = & git config core.hooksPath
    Assert-True -Condition ($configuredPath -eq '.githooks') -Message "core.hooksPath should be .githooks but got: $configuredPath"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 2: Pre-commit blocks generated runtime JSON
    # ===========================================================
    Write-Host "TEST 2: Pre-commit blocks generated runtime JSON"
    $r = Invoke-TestCommit -FilePath 'BlacksmithGuild_Status.json' -FileContent '{}' -TestName 'block status json'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block BlacksmithGuild_Status.json (exit $($r.ExitCode))"
    Assert-Contains -Haystack $r.Output -Needle '[harness]' -Message "Block output should mention [harness]"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 3: Pre-commit blocks crash dumps
    # ===========================================================
    Write-Host "TEST 3: Pre-commit blocks crash dumps"
    $r = Invoke-TestCommit -FilePath 'crash.dmp' -FileContent 'dumpdata' -TestName 'block crash dump'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block crash.dmp (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 4: Pre-commit blocks temp files
    # ===========================================================
    Write-Host "TEST 4: Pre-commit blocks temp files"
    $r = Invoke-TestCommit -FilePath 'draft.tmp' -FileContent 'tempdata' -TestName 'block tmp'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block .tmp files (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 5: Pre-commit blocks .env secrets
    # ===========================================================
    Write-Host "TEST 5: Pre-commit blocks .env files"
    $r = Invoke-TestCommit -FilePath '.env' -FileContent 'SECRET_KEY=test' -TestName 'block env'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block .env (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 6: Remediation guidance appears on block
    # ===========================================================
    Write-Host "TEST 6: Remediation guidance appears"
    $r = Invoke-TestCommit -FilePath 'BlacksmithGuild_Launch.log' -FileContent 'logdata' -TestName 'block launch log'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block runtime log"
    $hasGuidance = ($r.Output -match 'unstage') -or ($r.Output -match 'git restore') -or ($r.Output -match 'gitignore')
    Assert-True -Condition $hasGuidance -Message "Block output should contain remediation guidance: $($r.Output)"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 7: Sanitized fixtures under docs/evidence are allowed
    # ===========================================================
    Write-Host "TEST 7: Sanitized fixtures pass through"
    $fixtureDir = Join-Path $tempRoot 'docs\evidence\latest\sanitized'
    New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
    $r = Invoke-TestCommit -FilePath 'docs\evidence\latest\sanitized\manifest.json' -FileContent '{"schema":"test","data":"safe"}' -TestName 'allow sanitized fixture'
    Assert-True -Condition ($r.ExitCode -eq 0) -Message "Hook should allow sanitized fixture (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 8: Docs and code are not broadly blocked
    # ===========================================================
    Write-Host "TEST 8: Docs and code pass through"
    New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot 'docs') | Out-Null
    $r = Invoke-TestCommit -FilePath 'docs\README.md' -FileContent '# Updated docs' -TestName 'allow docs'
    Assert-True -Condition ($r.ExitCode -eq 0) -Message "Hook should not block docs (exit $($r.ExitCode))"

    New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot 'src') | Out-Null
    $r = Invoke-TestCommit -FilePath 'src\Program.cs' -FileContent 'using System;' -TestName 'allow code'
    Assert-True -Condition ($r.ExitCode -eq 0) -Message "Hook should not block code (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 9: Hook does not execute runtime/launcher/network activity
    # ===========================================================
    Write-Host "TEST 9: Hook does not execute runtime or network activity"
    $hookContent = Get-Content -LiteralPath (Join-Path $hooksDir 'pre-commit') -Raw
    $noRuntime = ($hookContent -notmatch 'Bannerlord') -and
                 ($hookContent -notmatch 'ForgeReboot') -and
                 ($hookContent -notmatch 'ForgeContinue') -and
                 ($hookContent -notmatch 'curl ') -and
                 ($hookContent -notmatch 'wget ') -and
                 ($hookContent -notmatch 'Invoke-WebRequest') -and
                 ($hookContent -notmatch 'http://') -and
                 ($hookContent -notmatch 'https://')
    Assert-True -Condition $noRuntime -Message "Hook must not execute runtime, launcher, or network activity"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 10: Hook does not print sensitive file contents
    # ===========================================================
    Write-Host "TEST 10: Hook does not print file contents"
    $hookContent = Get-Content -LiteralPath (Join-Path $hooksDir 'pre-commit') -Raw
    $noCat = ($hookContent -notmatch '(?<![a-z])cat ') -and
             ($hookContent -notmatch 'Get-Content') -and
             ($hookContent -notmatch '(?<![a-z])head ') -and
             ($hookContent -notmatch '(?<![a-z])tail ') -and
             ($hookContent -notmatch '(?<![a-z])less ')
    Assert-True -Condition $noCat -Message "Hook must not read or print file contents"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 11: node_modules blocked
    # ===========================================================
    Write-Host "TEST 11: node_modules blocked"
    $nmDir = Join-Path $tempRoot 'tools\my-tool\node_modules\pkg'
    New-Item -ItemType Directory -Force -Path $nmDir | Out-Null
    Set-Content -LiteralPath (Join-Path $nmDir 'index.js') -Value '{}' -Encoding UTF8
    $r = Invoke-TestCommit -FilePath 'tools\my-tool\node_modules\pkg\index.js' -FileContent '{}' -TestName 'block node_modules'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block node_modules (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 12: Pem/key files blocked
    # ===========================================================
    Write-Host "TEST 12: .pem and .key files blocked"
    $r = Invoke-TestCommit -FilePath 'server.pem' -FileContent 'PRIVATE KEY DATA' -TestName 'block pem'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block .pem (exit $($r.ExitCode))"
    $r = Invoke-TestCommit -FilePath 'server.key' -FileContent 'PRIVATE KEY DATA' -TestName 'block key'
    Assert-True -Condition ($r.ExitCode -ne 0) -Message "Hook should block .key (exit $($r.ExitCode))"
    Write-Host "  PASS"

    # ===========================================================
    # TEST 13: .tbg/state/generated/ files are allowed
    # ===========================================================
    Write-Host "TEST 13: .tbg/state/generated/ fixtures allowed"
    $genDir = Join-Path $tempRoot '.tbg\state\generated'
    New-Item -ItemType Directory -Force -Path $genDir | Out-Null
    $r = Invoke-TestCommit -FilePath '.tbg\state\generated\capabilities.registry.json' -FileContent '{"test":true}' -TestName 'allow generated state'
    Assert-True -Condition ($r.ExitCode -eq 0) -Message "Hook should allow .tbg/state/generated/ (exit $($r.ExitCode))"
    Write-Host "  PASS"

    Write-Host ""
    Write-Host "=== ALL 13 TESTS PASSED ==="
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
