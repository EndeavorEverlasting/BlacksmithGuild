@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-autonomous-assist-session.ps1" %*
set EXIT=%ERRORLEVEL%
exit /b %EXIT%
