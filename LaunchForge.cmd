@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Launcher
echo.
echo This script builds and installs the Bannerlord module, then opens the Bannerlord launcher.
echo.
echo Normal startup:
echo 1. Confirm The Blacksmith Guild is checked in the Bannerlord launcher.
echo 2. Click Play.
echo 3. Load a campaign.
echo 4. The mod loads automatically because it is checked.
echo.
echo No separate mod-start command is required.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch
if errorlevel 1 (
    echo.
    echo Build or install failed. See messages above.
    pause
    exit /b 1
)

echo.
pause
