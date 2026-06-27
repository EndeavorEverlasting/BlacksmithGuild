param(
    [switch]$ApplyCommandBusPatch,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host "==> $Name"
    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

function Invoke-GitStatus {
    param([Parameter(Mandatory = $true)][string]$Label)

    Write-Host "==> git status --short ($Label)"
    git status --short
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed with exit code $LASTEXITCODE"
    }
}

function Invoke-GitDiffCheck {
    Write-Host '==> git diff --check'
    git diff --check
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed with exit code $LASTEXITCODE"
    }
}

function Show-CommandBusPatchDiff {
    Write-Host '==> command-bus patch diff'
    git diff -- src/BlacksmithGuild/DevTools/DevCommandRegistry.cs src/BlacksmithGuild/DevTools/DevCommandBus.cs
    if ($LASTEXITCODE -ne 0) {
        throw "git diff for command-bus patch failed with exit code $LASTEXITCODE"
    }
}

Push-Location $RepoRoot
try {
    Invoke-GitStatus -Label 'before validation'
    Invoke-GitDiffCheck

    if ($ApplyCommandBusPatch) {
        Invoke-Step -Name 'Apply campaign governor command-bus patch' -Action {
            & (Join-Path $RepoRoot 'scripts\patch-campaign-governor-commandbus-local.ps1') -RepoRoot $RepoRoot
        }

        Show-CommandBusPatchDiff
        Invoke-GitDiffCheck
    }

    Invoke-Step -Name 'Build BlacksmithGuild Release' -Action {
        dotnet build (Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
    }

    Invoke-Step -Name 'Verify log grep patterns' -Action {
        & (Join-Path $RepoRoot 'scripts\verify-log-grep-patterns.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify F7 runner contract' -Action {
        & (Join-Path $RepoRoot 'scripts\verify-f7-runner-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign governor contract' -Action {
        & (Join-Path $RepoRoot 'scripts\verify-campaign-governor-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign activity dispatcher contract' -Action {
        & (Join-Path $RepoRoot 'scripts\verify-campaign-activity-dispatcher-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign activity handoff contract' -Action {
        & (Join-Path $RepoRoot 'scripts\verify-campaign-activity-handoff-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign governor command-bus patch contract' -Action {
        & (Join-Path $RepoRoot 'scripts\verify-campaign-governor-commandbus-patch-contract.ps1') -RepoRoot $RepoRoot
    }

    if ($ApplyCommandBusPatch) {
        Invoke-Step -Name 'Verify campaign governor command-bus source contract' -Action {
            & (Join-Path $RepoRoot 'scripts\verify-campaign-governor-commandbus-source-contract.ps1') -RepoRoot $RepoRoot
        }
    } else {
        Write-Host 'Skipped command-bus source contract because -ApplyCommandBusPatch was not provided.'
    }

    Invoke-GitDiffCheck
    Invoke-GitStatus -Label 'after validation'

    if ($ApplyCommandBusPatch) {
        Write-Host 'Command-bus patch was applied locally. If validation passed, commit DevCommandRegistry.cs and DevCommandBus.cs before marking the PR ready.'
    }

    Write-Host 'Campaign governor local validation complete.'
}
finally {
    Pop-Location
}
