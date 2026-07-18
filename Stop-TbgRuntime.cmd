@echo off
setlocal

echo.
echo The Blacksmith Guild - Stop TBG Runtime
echo Sends a correlated cancellation/stop event through the safe stop path.
echo Default: soft stop after a five-second change-mind window.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop-tbg-runtime-proof.ps1" %*
set "EXIT=%ERRORLEVEL%"

if not defined TBG_NO_PAUSE pause
exit /b %EXIT%
