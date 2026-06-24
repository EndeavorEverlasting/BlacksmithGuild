@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-pr11-town-travel-launch-attach-execute.ps1" %*
set EXIT=%ERRORLEVEL%
exit /b %EXIT%
