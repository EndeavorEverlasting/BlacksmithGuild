@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\export-tbg-evidence.ps1" %*
if errorlevel 1 exit /b 1
pause
