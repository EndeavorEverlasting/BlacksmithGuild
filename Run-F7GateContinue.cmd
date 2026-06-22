@echo off
setlocal
REM Primary F7 invocation (Unicode-safe): powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0xNN
REM This wrapper forwards %* to the PS script; bisect uses direct PowerShell.

echo.
echo The Blacksmith Guild - F7 Continue Gate (no-click)
echo.
echo Autonomous Continue launch + refocus + 60s stability checkpoint.
echo Usage: Run-F7GateContinue.cmd -HookMask 0x0F [-TimeoutSeconds 300] [-StableSeconds 60]
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-f7-gate-continue.ps1" %*
set GATE_EXIT=%ERRORLEVEL%
if %GATE_EXIT% NEQ 0 (
    echo.
    if %GATE_EXIT% EQU 1 (
        echo F7 gate LAUNCH/TOOLING FAIL - exit code 1. See docs/evidence/live-cert/ for manifest.
    ) else (
        echo F7 gate GAME FAIL - exit code %GATE_EXIT%. See docs/evidence/live-cert/ for manifest.
    )
    exit /b %GATE_EXIT%
)

echo.
echo F7 gate PASS.
exit /b 0
