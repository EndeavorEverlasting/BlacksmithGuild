@echo off
setlocal

echo.
echo The Blacksmith Guild - Latest Visible Trade Proof Status
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\show-latest-visible-trade-proof.ps1" %*
set "EXIT=%ERRORLEVEL%"

if not defined TBG_NO_PAUSE pause
exit /b %EXIT%
