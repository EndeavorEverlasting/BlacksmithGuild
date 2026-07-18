@echo off
setlocal

echo.
echo The Blacksmith Guild - Launch Forge Continue
echo.
echo Build + install + open launcher + auto CONTINUE intent (Sprint 006I-5).

rem Session mode: Runner (AI agent) or Human (manual click). Default Human.
if not defined TBG_SESSION_MODE (
    set "TBG_SESSION_MODE=Human"
)
echo Session: %TBG_SESSION_MODE%

rem Phase 1: build, install, launch, navigate launcher (play/continue/safe mode/calibration)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent continue
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build or launch failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

rem Read launch ID for traceability across concurrent runs
set LAUNCH_ID=unknown
if exist "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_LaunchId.json" (
    for /f "tokens=2 delims=:," %%a in ('powershell -NoProfile -Command "(Get-Content 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_LaunchId.json' -Raw | ConvertFrom-Json).launchId"') do set "LAUNCH_ID=%%~a"
)
echo Launch ID: %LAUNCH_ID%

rem Crash guard: check engine heartbeat after launch
echo.
echo Checking engine heartbeat...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 120
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARN: Engine heartbeat check failed. Game may have crashed during launch.
    rem Continue anyway - readiness trigger will detect if game is dead
)

rem Phase 2: check DLL identity before trusting runtime
echo.
echo Checking DLL identity...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgDllIdentity.ps1" -LaunchId %LAUNCH_ID%
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARN: DLL identity check failed. Runtime proof may be from stale DLL.
)

rem Crash guard: check engine heartbeat after launch
echo.
echo Checking engine heartbeat...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 120 -LaunchId %LAUNCH_ID%
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARN: Engine heartbeat check failed. Game may have crashed during launch.
    rem Continue anyway - readiness trigger will detect if game is dead
)

echo.
echo Launcher nav complete. Waiting for campaign map readiness...

rem Phase 3: wait for campaign map, resume clock (session-aware)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command ResumeCampaignClock -RequiredSurface map_surface -SessionMode %TBG_SESSION_MODE% -LaunchId %LAUNCH_ID% -ReadyTimeoutSec 180 -AckTimeoutSec 60
set TRIGGER_EXIT=%ERRORLEVEL%

rem Heartbeat check after clock resume
echo.
echo Checking engine heartbeat after clock resume...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 30 -LaunchId %LAUNCH_ID% -PassThru 2>&1 | findstr /C:"Verdict" /C:"Log age"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo CRITICAL: Game likely crashed during map load. Phase1.log is stale.
    pause
    exit /b 3
)

rem Phase 5: if clock resumed, dispatch trade route (session-aware)
if %TRIGGER_EXIT% EQU 0 (
    echo.
    echo Clock resumed. Dispatching visible trade route...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command RunAutonomousVisibleTradeRouteNow -RequiredSurface map_surface -SessionMode %TBG_SESSION_MODE% -LaunchId %LAUNCH_ID% -ReadyTimeoutSec 10 -AckTimeoutSec 120
    set TRADE_EXIT=%ERRORLEVEL%

    rem Final heartbeat check after trade
    echo.
    echo Checking post-trade engine heartbeat...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgEngineHeartbeat.ps1" -StaleSeconds 30 -LaunchId %LAUNCH_ID% -PassThru 2>&1 | findstr /C:"Verdict" /C:"Log age"
)

echo.
pause
