@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-tavern-hero-intel-cert.ps1" -Mode Manual %*
pause
