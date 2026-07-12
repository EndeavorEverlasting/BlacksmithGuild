@echo off
setlocal
echo.
echo The Blacksmith Guild - ForgeStop
echo Default: soft stop after a five-second change-mind window.
echo Press F for emergency force kill or C to cancel.
echo.
if /I "%~1"=="soft" goto soft
if /I "%~1"=="force" goto force
if /I "%FORGE_STOP_CHOICE%"=="S" goto soft
if /I "%FORGE_STOP_CHOICE%"=="F" goto force
if /I "%FORGE_STOP_CHOICE%"=="C" goto cancelled
choice /C SFC /N /T 5 /D S /M "Soft stop in 5 seconds; Force kill or Cancel? [S/F/C] "
if errorlevel 3 goto cancelled
if errorlevel 2 goto force
:soft
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\forge-stop.ps1"
goto done
:force
echo Emergency force kill selected.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\forge-stop.ps1" -ForceKill
goto done
:cancelled
echo Cancelled. Automation context remains unchanged.
:done
echo.
if not defined FORGE_NO_PAUSE pause
