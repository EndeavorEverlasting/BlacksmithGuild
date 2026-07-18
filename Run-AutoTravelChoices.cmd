@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Auto-Travel Choices - read-only ranked destination list
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: Phase1 [TBG TRAVEL] lines and status JSON command result.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command ShowAutoTravelChoices -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Auto-Travel Choices wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
