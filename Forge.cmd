@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge
echo.
echo Double-click build + install (no launcher). Daily dev loop after code changes.
echo First install or explicit launcher: use LaunchForge.cmd instead.
echo Watch mode (auto rebuild): ForgeWatch.cmd or .\forge.ps1 -Watch
echo In-game: F7 status, F8-F11 dev commands, Ctrl+Alt+S progression test.
echo Surfaces: docs\in-game-surfaces.md
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1"
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

echo.
echo If install was blocked, close Bannerlord and run Forge.cmd again.
pause
