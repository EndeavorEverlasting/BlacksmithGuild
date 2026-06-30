@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Autonomous Guild Loop - one bounded cycle
echo WARNING: May move the party and may attempt supported vanilla actions.
echo Use a disposable save unless you explicitly accept campaign-state changes.
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: BlacksmithGuild_AutonomousGuildLoop.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command RunAutonomousGuildLoopNow -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Autonomous Guild Loop wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
