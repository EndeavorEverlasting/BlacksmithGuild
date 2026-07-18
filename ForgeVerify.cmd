@echo off
setlocal
echo The Blacksmith Guild - ForgeVerify
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-offline-validation-bundle.ps1" %*
set FORGE_EXIT=%ERRORLEVEL%
echo.
if %FORGE_EXIT% NEQ 0 (
    echo ForgeVerify failed.
    if not defined FORGE_NO_PAUSE pause
    exit /b %FORGE_EXIT%
)
echo ForgeVerify complete.
if not defined FORGE_NO_PAUSE pause
exit /b 0