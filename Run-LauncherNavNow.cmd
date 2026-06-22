@echo off
setlocal
set "ROOT=C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord"
set "SCRIPTS=%~dp0scripts"
tasklist /FI "IMAGENAME eq TaleWorlds.MountAndBlade.Launcher.exe" 2>nul | find /I "Launcher.exe" >nul
if errorlevel 1 (
  tasklist /FI "IMAGENAME eq Bannerlord.exe" 2>nul | find /I "Bannerlord.exe" >nul
  if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%\open-bannerlord-launcher.ps1" -BannerlordRoot "%ROOT%"
  )
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%\write-launch-intent.ps1" -LaunchIntent continue -BannerlordRoot "%ROOT%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS%\launcher-auto-nav.ps1" -LaunchIntent continue -BannerlordRoot "%ROOT%" -TimeoutSec 300
exit /b %ERRORLEVEL%
