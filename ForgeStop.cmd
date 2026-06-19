@echo off
setlocal
echo.
echo The Blacksmith Guild - ForgeStop (emergency kill)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\forge-stop.ps1"
echo.
pause
