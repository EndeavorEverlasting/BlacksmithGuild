# One-command offline validation bundle for the current local harness/runtime contract surface.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Script
    )
    Write-Host "=== $Label ===" -ForegroundColor Cyan
    & $Script
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Invoke-Step 'Add-Utf8Bom' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tools\Add-Utf8Bom.ps1 -Fix }
Invoke-Step 'PR11 durable movement proof test' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-pr11-assistive-execute-contract.ps1 }
Invoke-Step 'Reboot classifier test' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-reboot-context-classifier.ps1 }
Invoke-Step 'Reboot iteration contract' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-reboot-iteration-contract.ps1 }
Invoke-Step 'Harness-engine wiring test' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-harness-engine-wiring-contract.ps1 }
Invoke-Step 'Harness-engine wiring verifier' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-harness-engine-wiring-contract.ps1 }
Invoke-Step 'Autonomous assist session regression' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-autonomous-assist-session.ps1 }
Invoke-Step 'Autonomous assist runner evidence regression' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-autonomous-assist-runner-evidence.ps1 }
Invoke-Step 'Post-attach actionability verifier' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-post-attach-actionability-contract.ps1 }
Invoke-Step 'dotnet build' { dotnet build src\BlacksmithGuild\BlacksmithGuild.csproj -c Release }
Invoke-Step 'PowerShell BOM contract' { powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1 }
Invoke-Step 'git diff --check' { git diff --check }

Write-Host 'PASS offline validation bundle' -ForegroundColor Green
exit 0