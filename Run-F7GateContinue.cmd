@echo off
setlocal

echo.
echo The Blacksmith Guild - F7 Continue Gate
echo.
echo Detached Continue launch + sustained refocus + 60s stability checkpoint.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-f7-gate-continue.ps1"
set GATE_EXIT=%ERRORLEVEL%
if %GATE_EXIT% NEQ 0 (
    echo.
    echo F7 gate FAIL or script error - exit code %GATE_EXIT%. See docs/evidence/live-cert/ for manifest.
    exit /b %GATE_EXIT%
)

echo.
echo F7 gate PASS.
exit /b 0
