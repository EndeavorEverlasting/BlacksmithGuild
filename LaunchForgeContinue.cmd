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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent continue
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build or launch failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

rem Read launch ID from file written by forge
set LAUNCH_ID=unknown
if exist "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_LaunchId.txt" (
    set /p LAUNCH_ID=<"C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_LaunchId.txt"
)
echo Launch ID: %LAUNCH_ID%

rem Phase 2: check DLL identity before trusting runtime
echo.
echo Checking DLL identity...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgDllIdentity.ps1" -LaunchId %LAUNCH_ID%
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARN: DLL identity check failed. Runtime proof may be from stale DLL.
)

echo.
echo Launcher nav complete. Waiting for campaign map readiness...

rem Phase 3: wait for campaign map, resume clock (session-aware)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command ResumeCampaignClock -RequiredSurface map_surface -SessionMode %TBG_SESSION_MODE% -LaunchId %LAUNCH_ID% -ReadyTimeoutSec 180 -AckTimeoutSec 60
set TRIGGER_EXIT=%ERRORLEVEL%

rem Phase 5: if clock resumed, dispatch trade route (session-aware)
if %TRIGGER_EXIT% EQU 0 (
    echo.
    echo Dispatch: RunAutonomousVisibleTradeRouteNow...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Test-TbgReadinessTrigger.ps1" -Command RunAutonomousVisibleTradeRouteNow -RequiredSurface map_surface -SessionMode %TBG_SESSION_MODE% -LaunchId %LAUNCH_ID% -ReadyTimeoutSec 10 -AckTimeoutSec 120
    set TRADE_EXIT=%ERRORLEVEL%
)

echo.
pause

