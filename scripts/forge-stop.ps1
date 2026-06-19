# Emergency stop for Forge / launcher UI automation (no taskbar icon — kills by command line).
$ErrorActionPreference = 'SilentlyContinue'

$killed = @()

foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher')) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.Id -Force
        $killed += "$name (PID $($_.Id))"
    }
}

Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | Where-Object {
    $_.CommandLine -match 'BlacksmithGuild|forge\.ps1|Forge\.cmd|launcher-auto-nav|ForgeWatch|ForgeContinue|forge-stop'
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
    $killed += "shell PID $($_.ProcessId)"
}

if ($killed.Count -eq 0) {
    Write-Host 'ForgeStop: no matching Forge, Bannerlord, or launcher-auto-nav processes found.' -ForegroundColor Yellow
} else {
    Write-Host 'ForgeStop: terminated:' -ForegroundColor Green
    $killed | ForEach-Object { Write-Host "  $_" }
}

Write-Host ''
Write-Host 'Safe to close any stray windows Forge may have opened (Excel, games, etc.) manually.' -ForegroundColor DarkGray
Write-Host 'Re-run Forge only after the launcher window is visible and in front.' -ForegroundColor DarkGray
