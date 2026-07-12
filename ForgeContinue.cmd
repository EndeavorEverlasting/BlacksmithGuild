@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Continue
echo.
echo Build + install + modal-aware CONTINUE until map.
echo One bounded launcher-family force-close retry is automatic on a qualifying dead end.
echo Watch mode: ForgeWatch.cmd or .\forge.ps1 -Watch
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent continue
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Forge CONTINUE failed after modal handling and bounded recovery.
    echo Launch log: C:\Program Files ^(x86^)^\Steam\steamapps\common\Mount ^& Blade II Bannerlord\BlacksmithGuild_Launch.log
    echo Recovery: Documents\Mount and Blade II Bannerlord\BlacksmithGuild_LauncherRecovery.json
    pause
    exit /b %FORGE_EXIT%
)

echo.
echo Log tails: see paths printed above ^(Forge.log + Phase1 Documents and Steam root + Launch.log^).
echo If recovery reached a dead end, run CollectDiagnostics.cmd to retain BlacksmithGuild_LauncherRecovery.json.
pause
