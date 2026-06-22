# Agent A F7 bisect coordinator. Keeps invocation Unicode-safe and avoids forge-stop child kills.
param(
    [string[]]$HookMasks = @('0x01'),
    [int]$StabilitySeconds = 60
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$results = New-Object System.Collections.Generic.List[object]
foreach ($mask in $HookMasks) {
    Write-Host ("Running F7 gate mask {0}" -f $mask)
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run-f7-gate-continue.ps1') -HookMask $mask -StabilitySeconds $StabilitySeconds -SkipLaunch
    $results.Add([pscustomobject]@{ HookMask = $mask; ExitCode = $LASTEXITCODE }) | Out-Null
}
Write-Host ("F7 bisect completed results.Count={0}" -f $results.Count)
$results
