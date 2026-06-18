@echo off
setlocal

echo.
echo The Blacksmith Guild - Diagnostic Collector
echo.
echo Collects Bannerlord logs, crash evidence, module state, and mod logs
echo into one timestamped folder under Documents.
echo.
echo Status file: Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
echo Forge log:    Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Forge.log
echo.
echo Engine ASSERT dialogs are not mod-controlled. After a crash, errors are in logs.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -CollectDiagnostics
if errorlevel 1 (
    echo.
    echo Diagnostic collection failed. See messages above.
    pause
    exit /b 1
)

echo.
pause
