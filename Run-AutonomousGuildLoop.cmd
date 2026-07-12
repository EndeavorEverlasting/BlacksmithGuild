@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Autonomous Guild Loop - one bounded operator cycle
echo WARNING: May move the party and may attempt supported vanilla actions.
echo Use any save only if you accept campaign-state changes.
echo Requires: Bannerlord loaded, mod ON, command inbox polling, game foreground/unpaused for movement.
echo Output: BlacksmithGuild_AutonomousGuildLoop.json and artifacts\latest\autonomous-guild-loop-operator.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-autonomous-guild-loop-operator.ps1" -TimeoutSec 60
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Autonomous Guild Loop wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
