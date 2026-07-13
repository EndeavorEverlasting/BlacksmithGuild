@echo off
setlocal

echo.
echo The Blacksmith Guild - Toggle Evidence Automation
echo Exposes the existing supported evidence/artifact automation toggle.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\toggle-tbg-evidence-automation-proof.ps1" %*
set "EXIT=%ERRORLEVEL%"

if not defined TBG_NO_PAUSE pause
exit /b %EXIT%
