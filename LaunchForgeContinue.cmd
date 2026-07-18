@echo off
setlocal

echo.
echo The Blacksmith Guild - Launch Forge Continue
echo.
echo Build + install + open launcher + auto CONTINUE intent (Sprint 006I-5).
echo Use when you need launcher mod checkboxes before continuing a save.
echo Daily dev loop: ForgeContinue.cmd (no launcher) or Forge.cmd (new game).
echo.

rem Phase 1: build, install, launch, navigate launcher (play/continue/safe mode/calibration)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent continue
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build or launch failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

echo.
echo Launcher nav complete. Waiting for campaign map readiness...

rem Phase 2: wait for campaign map, then dispatch trade route
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command ResumeCampaignClock -ReadyTimeoutSec 180 -AckTimeoutSec 60
set TRIGGER_EXIT=%ERRORLEVEL%

rem Phase 3: if clock resumed, dispatch trade route
if %TRIGGER_EXIT% EQU 0 (
    echo.
    echo Clock resumed. Dispatching visible trade route...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command RunAutonomousVisibleTradeRouteNow -ReadyTimeoutSec 10 -AckTimeoutSec 120
)

echo.
pause
