@echo off
setlocal
echo.
echo The Blacksmith Guild - Ensure disposable governor dev save
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\ensure-governor-dev-save-operator.ps1"
set TBG_EXIT=%ERRORLEVEL%
echo.
pause
exit /b %TBG_EXIT%
