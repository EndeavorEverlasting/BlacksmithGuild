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
    & $Action
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

Push-Location $RepoRoot
try {
    if ($ApplyCommandBusPatch) {
        Invoke-Step -Name 'Apply campaign governor command-bus patch' -Action {
            powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\patch-campaign-governor-commandbus-local.ps1') -RepoRoot $RepoRoot
        }
    }

    Invoke-Step -Name 'Build BlacksmithGuild Release' -Action {
        dotnet build (Join-Path $RepoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
    }

    Invoke-Step -Name 'Verify log grep patterns' -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-log-grep-patterns.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify F7 runner contract' -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-f7-runner-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign governor contract' -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-campaign-governor-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign activity dispatcher contract' -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-campaign-activity-dispatcher-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign activity handoff contract' -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-campaign-activity-handoff-contract.ps1') -RepoRoot $RepoRoot
    }

    Invoke-Step -Name 'Verify campaign governor command-bus patch contract' -Action {
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-campaign-governor-commandbus-patch-contract.ps1') -RepoRoot $RepoRoot
    }

    if ($ApplyCommandBusPatch) {
        Invoke-Step -Name 'Verify campaign governor command-bus source contract' -Action {
            powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\verify-campaign-governor-commandbus-source-contract.ps1') -RepoRoot $RepoRoot
        }
    } else {
        Write-Host 'Skipped command-bus source contract because -ApplyCommandBusPatch was not provided.'
    }

    Write-Host 'Campaign governor local validation complete.'
}
finally {
    Pop-Location
}
