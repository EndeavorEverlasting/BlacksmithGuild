@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Autonomous Guild Loop - context-aware operator cycle
echo Command: RunAutonomousGuildLoopNow
echo Automation intent: foreground Bannerlord, set Automation, resume time, and run one bounded cycle.
echo Quit intent: press Q or Escape during the five-second startup grace window.
echo Stop later: click ForgeStop.cmd; it defaults to soft stop after five seconds unless cancelled.
echo Output: BlacksmithGuild_AutonomousGuildLoop.json and artifacts\latest\autonomous-guild-loop-operator.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-autonomous-guild-loop-operator.ps1" -TimeoutSec 60 -QuitGraceSec 5
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Autonomous Guild Loop wrapper finished with exit code %TBG_EXIT%.
if "%TBG_EXIT%"=="0" goto done
echo [TBG] A non-success result was written. Press any key after reading it.
pause
:done
exit /b %TBG_EXIT%
