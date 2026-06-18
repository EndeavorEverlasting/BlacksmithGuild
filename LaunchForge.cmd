@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Launcher
echo.
echo First install or explicit launcher open: builds, installs, opens Bannerlord launcher.
echo Daily dev loop: double-click Forge.cmd (build + install, no launcher).
echo Watch mode: ForgeWatch.cmd or .\forge.ps1 -Watch
echo.
echo Daily play: Steam -^> Play (launcher uses your saved mod checkboxes).
echo After code changes: Forge.cmd, dotnet build -c Release, or Ctrl+Shift+B — then restart Bannerlord.
echo In-game: F7 status, F8-F11 dev commands, Ctrl+Alt+S progression test.
echo Surfaces: docs\in-game-surfaces.md
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
