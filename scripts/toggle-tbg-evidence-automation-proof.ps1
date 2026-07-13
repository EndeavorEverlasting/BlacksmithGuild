# Toggle evidence/artifact automation.
# Exposes the existing supported evidence/artifact automation toggle
# rather than inventing a second independent watcher.

param(
    [ValidateSet('on', 'off', 'status')]
    [string]$Action = 'status',
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot

$togglePaths = @(
    (Join-Path $bannerlordRoot 'BlacksmithGuild_EvidenceAutomation.json'),
    (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_EvidenceAutomation.json')
)

function Read-Toggle {
    foreach ($path in $togglePaths) {
        if (Test-Path -LiteralPath $path) {
            try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
        }
    }
    return $null
}

function Write-Toggle {
    param([bool]$Enabled)
    $payload = [ordered]@{
        schemaVersion = 'TbgEvidenceAutomationToggle.v1'
        enabled = [bool]$Enabled
        requestedBy = 'operator_toggle'
        updatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json -Depth 4
    foreach ($path in $togglePaths) {
        $dir = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $path -Value $payload -Encoding UTF8
    }
    return $payload
}

$current = Read-Toggle
$currentEnabled = if ($current -and $current.PSObject.Properties['enabled']) { [bool]$current.enabled } else { $false }

Write-Host ''
Write-Host 'TBG Evidence Automation Toggle' -ForegroundColor Cyan
Write-Host ''

switch ($Action) {
    'status' {
        Write-Host "Current state: $(if ($currentEnabled) {'ENABLED'} else {'DISABLED'})" -ForegroundColor $(if ($currentEnabled) { 'Green' } else { 'Yellow' })
        if ($current -and $current.PSObject.Properties['updatedAtUtc']) {
            Write-Host "Last updated:  $($current.updatedAtUtc)"
        }
    }
    'on' {
        Write-Toggle -Enabled $true | Out-Null
        Write-Host 'Evidence automation: ENABLED' -ForegroundColor Green
    }
    'off' {
        Write-Toggle -Enabled $false | Out-Null
        Write-Host 'Evidence automation: DISABLED' -ForegroundColor Yellow
    }
}

Write-Host ''
exit 0
