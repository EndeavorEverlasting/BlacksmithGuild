@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-stage-c-charcoal-cert.ps1"
set EXIT=%ERRORLEVEL%
pause
exit /b %EXIT%
