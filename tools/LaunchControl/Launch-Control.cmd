@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-Control.ps1" %*
set TBG_LAUNCH_CONTROL_EXIT=%ERRORLEVEL%

if %TBG_LAUNCH_CONTROL_EXIT% NEQ 0 (
    echo.
    echo TBG Launch Control failed with exit code %TBG_LAUNCH_CONTROL_EXIT%.
    echo See the evidence files or messages above for details.
    pause
)

exit /b %TBG_LAUNCH_CONTROL_EXIT%
