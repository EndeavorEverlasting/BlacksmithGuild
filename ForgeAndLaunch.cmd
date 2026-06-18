@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge and Launch
echo.
echo Builds, installs, verifies, and opens the Bannerlord launcher only on clean PASS.
echo Daily dev loop without launcher: Forge.cmd
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\forge-and-launch.ps1"
set FORGE_EXIT=%ERRORLEVEL%

if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build or install failed. See messages above.
)

echo.
pause
exit /b %FORGE_EXIT%
