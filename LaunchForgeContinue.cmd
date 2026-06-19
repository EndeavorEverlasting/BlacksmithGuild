@echo off
setlocal

echo.
echo The Blacksmith Guild - Launch Forge Continue
echo.
echo Build + install + open launcher + auto CONTINUE intent (Sprint 006I-5).
echo Use when you need launcher mod checkboxes before continuing a save.
echo Daily dev loop: ForgeContinue.cmd (no launcher) or Forge.cmd (new game).
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent continue
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build or launch failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

echo.
pause
