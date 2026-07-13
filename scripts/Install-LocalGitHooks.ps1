<#
.SYNOPSIS
    Installs BlacksmithGuild local Git hooks (opt-in, local only).

.DESCRIPTION
    Configures the local repository to use .githooks/ as the Git hooks
    directory via core.hooksPath. This is a local-only setting and does
    not affect CI, other clones, or other contributors.

    The pre-commit hook blocks generated evidence, crash dumps, secrets,
    runtime JSON/logs, and machine-local junk from entering commits.
    It does NOT execute runtime, launcher, or network activity.
    It does NOT print sensitive file contents.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$hooksDir = Join-Path $resolvedRoot '.githooks'
$preCommitHook = Join-Path $hooksDir 'pre-commit'

if (-not (Test-Path -LiteralPath $preCommitHook)) {
    throw "Missing pre-commit hook: $preCommitHook"
}

Push-Location -LiteralPath $resolvedRoot
try {
    & git config core.hooksPath '.githooks'
    if ($LASTEXITCODE -ne 0) {
        throw "git config core.hooksPath failed with exit code $LASTEXITCODE"
    }

    $configured = & git config core.hooksPath
    if ($configured -ne '.githooks') {
        throw "core.hooksPath was not set correctly: $configured"
    }

    # Ensure hook is executable (chmod on Git Bash / WSL / Linux / macOS)
    try {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            & chmod +x $preCommitHook 2>$null
        }
    } catch {
        # chmod not available; Windows Git handles this automatically
    }

    Write-Host "Local Git hooks installed."
    Write-Host "  core.hooksPath = .githooks"
    Write-Host "  pre-commit hook: $preCommitHook"
    Write-Host ""
    Write-Host "The pre-commit hook blocks generated/runtime evidence, crash dumps,"
    Write-Host "secrets, and machine-local junk from entering commits."
    Write-Host ""
    Write-Host "To uninstall: git config --unset core.hooksPath"
}
finally {
    Pop-Location
}
