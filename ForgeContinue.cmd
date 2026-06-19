@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Continue
echo.
echo Build + install + auto CONTINUE until map (Sprint 006E).
echo Watch mode: ForgeWatch.cmd or .\forge.ps1 -Watch
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent continue
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

echo.
echo If install was blocked, close Bannerlord and run ForgeContinue.cmd again.
pause
