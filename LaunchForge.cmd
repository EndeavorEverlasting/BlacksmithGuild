@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Launcher
echo.
echo First install or explicit launcher open: builds, installs, opens Bannerlord launcher.
echo.
echo Daily play: Steam -^> Play (launcher uses your saved mod checkboxes).
echo After code changes: dotnet build -c Release (auto-installs), then Steam -^> Play.
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
