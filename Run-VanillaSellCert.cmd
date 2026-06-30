@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-vanilla-sell-cert.ps1" %*
set EXIT=%ERRORLEVEL%
exit /b %EXIT%
