@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-stage-b-smithing-advisory-cert.ps1"
set EXIT=%ERRORLEVEL%
pause
exit /b %EXIT%
