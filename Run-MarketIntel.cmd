@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Market Intel - read-only advisory
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: BlacksmithGuild_MarketIntel.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command MarketSnapshotNow -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Market Intel wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
