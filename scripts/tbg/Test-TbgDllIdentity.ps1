<#
.SYNOPSIS
Validates built DLL identity matches installed DLL.
Fails when the running game may have loaded a stale DLL.
#>
param(
    [string]$RepoRoot,
    [string]$BannerlordRoot,
    [string]$LaunchId,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
if (-not $BannerlordRoot) {
    $default = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'
    $BannerlordRoot = if (Test-Path $default) { $default } else { throw 'Bannerlord root not found' }
}

$builtPath = Join-Path $RepoRoot 'Module\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'
$installedPath = Join-Path $BannerlordRoot 'Modules\BlacksmithGuild\bin\Win64_Shipping_Client\BlacksmithGuild.dll'

$checks = @()
$passed = 0; $failed = 0

# Check 1: built DLL exists
$builtExists = Test-Path -LiteralPath $builtPath -PathType Leaf
$checks += @{ name = 'Built DLL exists'; passed = $builtExists }
if ($builtExists) { $passed++ } else { $failed++ }

# Check 2: installed DLL exists
$installedExists = Test-Path -LiteralPath $installedPath -PathType Leaf
$checks += @{ name = 'Installed DLL exists'; passed = $installedExists }
if ($installedExists) { $passed++ } else { $failed++ }

$builtHash = $null; $installedHash = $null; $match = $false; $gameRunning = $false

if ($builtExists -and $installedExists) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $builtHash = [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($builtPath))).Replace('-','')
    $installedHash = [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($installedPath))).Replace('-','')
    $sha.Dispose()
    $match = $builtHash -eq $installedHash
    $checks += @{ name = "Built matches installed (sha256)"; passed = $match }
    if ($match) { $passed++ } else { $failed++ }

    $gameRunning = $null -ne (Get-Process -Name 'Bannerlord*' -ErrorAction SilentlyContinue)
    if ($match -and $gameRunning) {
        # Even if files match, the running game may have loaded a previous version.
        # Check if the installed DLL was written AFTER the game started.
        $installedTime = (Get-Item -LiteralPath $installedPath).LastWriteTimeUtc
        $gameProc = Get-Process -Name 'Bannerlord*' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gameProc -and $installedTime -gt $gameProc.StartTime.ToUniversalTime()) {
            $checks += @{ name = 'Installed DLL deployed after game start (loaded fresh)'; passed = $true }
            $passed++
        } else {
            $checks += @{ name = 'Installed DLL deployed before game start (may be stale)'; passed = $false }
            $failed++
        }
    }
} else {
    $checks += @{ name = 'DLL identity check skipped (missing files)'; passed = $false }
    $failed++
}

$verdict = if ($failed -eq 0) { 'PASS' } elseif ($gameRunning) { 'STALE_RUNTIME' } else { 'FAIL' }
$detail = if ($match -and $gameRunning) {
    'DLL files match but game may have loaded a previous version. Restart Bannerlord for fresh load.'
} elseif ($match) {
    'Built and installed DLLs are identical. No game running = fresh load guaranteed.'
} elseif (-not $match) {
    'Built DLL differs from installed DLL. Run Forge.cmd to deploy.'
} else { 'DLL files missing.' }

$result = [pscustomobject]@{
    schema = 'tbg.dll-identity.v1'
    timestamp = [DateTime]::UtcNow.ToString('o')
    launchId = $LaunchId
    verdict = $verdict
    passed = $passed; failed = $failed; total = $checks.Count
    builtHash = $builtHash; installedHash = $installedHash; match = $match
    gameRunning = $gameRunning
    detail = $detail
    checks = $checks
}

Write-Host "=== DLL Identity Check ===" -ForegroundColor Cyan
if ($LaunchId) { Write-Host "Launch: $LaunchId" -ForegroundColor Cyan }
Write-Host "Verdict: $verdict" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } else { 'Red' })
Write-Host "Built:    $(if ($builtHash) { $builtHash.Substring(0,16) } else { 'N/A' })..."
Write-Host "Installed: $(if ($installedHash) { $installedHash.Substring(0,16) } else { 'N/A' })..."
Write-Host "Match: $match | Game running: $gameRunning"
Write-Host "Passed: $passed/$($checks.Count)"
foreach ($c in $checks) {
    $mark = if ($c.passed) { "[PASS]" } else { "[FAIL]" }
    Write-Host "  $mark $($c.name)" -ForegroundColor $(if ($c.passed) { 'Green' } else { 'Red' })
}
Write-Host "Detail: $detail"

$outputPath = Join-Path $RepoRoot 'artifacts\latest\dll-identity.result.json'
$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outputPath -Encoding UTF8
Write-Host "Output: $outputPath"

if ($PassThru) { Write-Output $result }
exit $(if ($verdict -eq 'PASS') { 0 } elseif ($verdict -eq 'STALE_RUNTIME') { 2 } else { 1 })
