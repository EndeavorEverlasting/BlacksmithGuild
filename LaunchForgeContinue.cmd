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

rem Crash guard: check engine heartbeat after launch
echo.
echo Checking engine heartbeat...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 120
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARN: Engine heartbeat check failed. Game may have crashed during launch.
    rem Continue anyway - readiness trigger will detect if game is dead
)

echo.
echo Launcher nav complete. Waiting for campaign map readiness...

rem Phase 2: wait for campaign map, resume clock
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command ResumeCampaignClock -ReadyTimeoutSec 180 -AckTimeoutSec 60
set TRIGGER_EXIT=%ERRORLEVEL%

rem Heartbeat check after clock resume
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 30 -PassThru 2>&1 | findstr /C:"Verdict" /C:"Log age"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo CRITICAL: Game likely crashed during map load. Phase1.log is stale.
    pause
    exit /b 3
)

rem Phase 3: if clock resumed, dispatch trade route
if %TRIGGER_EXIT% EQU 0 (
    echo.
    echo Clock resumed. Dispatching visible trade route...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command RunAutonomousVisibleTradeRouteNow -ReadyTimeoutSec 10 -AckTimeoutSec 120
    set TRADE_EXIT=%ERRORLEVEL%

    rem Final heartbeat check after trade
    echo.
    echo Checking post-trade engine heartbeat...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 30 -PassThru 2>&1 | findstr /C:"Verdict" /C:"Log age"
)

echo.
pause
