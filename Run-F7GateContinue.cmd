@echo off
REM Compatibility wrapper only. For reliable F7 bisects, prefer direct PowerShell:
REM powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x01
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-f7-gate-continue.ps1" %*
