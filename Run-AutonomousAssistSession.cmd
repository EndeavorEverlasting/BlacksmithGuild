@echo off
setlocal
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-autonomous-assist-session.ps1 %*
exit /b %ERRORLEVEL%
