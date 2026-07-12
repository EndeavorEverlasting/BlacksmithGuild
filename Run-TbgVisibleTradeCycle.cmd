@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-tbg-visible-trade-cycle.ps1" %*
exit /b %ERRORLEVEL%
