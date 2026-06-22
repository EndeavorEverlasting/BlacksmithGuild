@echo off
setlocal
echo.
echo The Blacksmith Guild - F7 Autonomous Loop (build + gate + bisect)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-f7-autonomous-loop.ps1" %*
set EXIT=%ERRORLEVEL%
exit /b %EXIT%
