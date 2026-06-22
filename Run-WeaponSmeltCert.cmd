@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-weapon-smelt-cert.ps1" %*
set EXIT=%ERRORLEVEL%
exit /b %EXIT%
