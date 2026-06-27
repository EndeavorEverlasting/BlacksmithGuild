param(
    [switch]$ForceKill,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

# Operator stop for Forge / launcher UI automation. Default is soft; -ForceKill is emergency.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')

. (Join-Path $PSScriptRoot 'write-launch-log.ps1') -Message "ForgeStop: invoked forceKill=$($ForceKill.IsPresent)"
Write-GovernorStopSentinel -RepoRoot $RepoRoot -Reason 'operator invoked ForgeStop' | Out-Null

try {
    . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    . (Join-Path $PSScriptRoot 'forge-status.ps1')
    $bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
    foreach ($cmd in @('PauseCampaignGovernorAutomation', 'AbortCohesionMoveNow', 'AbortMapTradeRouteNow', 'AbortAutonomousGuildLoopNow')) {
        try { Send-ForgeCommand -CommandName $cmd -BannerlordRoot $bannerlordRoot | Out-Null } catch { }
    }
} catch { }

$callerPid = $PID
$killed = @()

if ($ForceKill) {
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Stop-Process -Id $_.Id -Force
            $killed += "$name (PID $($_.Id))"
            . (Join-Path $PSScriptRoot 'write-launch-log.ps1') -Message "ForgeStop: force killed $name PID $($_.Id)"
        }
    }
}

Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | Where-Object {
    $_.ProcessId -ne $callerPid -and
    $_.CommandLine -match 'run-governor-disposable-smoke|ensure-dev-save|invoke-forge-launch-operator|launcher-auto-nav|ForgeWatch|ForgeContinue'
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
    $killed += "shell PID $($_.ProcessId)"
    . (Join-Path $PSScriptRoot 'write-launch-log.ps1') -Message "ForgeStop: killed forge shell PID $($_.ProcessId)"
}

if ($killed.Count -eq 0) {
    Write-Host 'ForgeStop: stop sentinel written; no matching automation processes found.' -ForegroundColor Yellow
} else {
    Write-Host 'ForgeStop: terminated:' -ForegroundColor Green
    $killed | ForEach-Object { Write-Host "  $_" }
}

Write-Host ''
Write-Host 'Audit trail: see BlacksmithGuild_Launch.log lines tagged ForgeStop: or UIA:' -ForegroundColor DarkGray
Write-Host 'Default stop is soft. Re-run with -ForceKill only for emergency process termination.' -ForegroundColor DarkGray
