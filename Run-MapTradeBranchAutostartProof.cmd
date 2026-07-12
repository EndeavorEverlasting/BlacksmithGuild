@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-maptrade-branch-autostart-proof.ps1" %*
exit /b %ERRORLEVEL%
