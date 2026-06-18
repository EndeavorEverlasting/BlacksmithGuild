@echo off
setlocal

echo.
echo The Blacksmith Guild - Diagnostic Collector
echo.
echo Collects Bannerlord logs, crash evidence, module state, and mod logs
echo into one timestamped folder under Documents.
echo.
echo Run this after a crash or failed test. Share diagnostic-summary.txt.
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
