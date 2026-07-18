@echo off
setlocal
echo.
echo The Blacksmith Guild - ForgeStop
echo Default: soft stop request, governor pause/abort, and automation shell cleanup.
echo.
if /I "%~1"=="soft" goto soft
if /I "%~1"=="force" goto force
if /I "%FORGE_STOP_CHOICE%"=="S" goto soft
if /I "%FORGE_STOP_CHOICE%"=="F" goto force
if /I "%FORGE_STOP_CHOICE%"=="C" goto cancelled
choice /C SFC /N /M "Soft stop, Force kill, or Cancel? [S/F/C] "
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
echo Cancelled.
:done
echo.
if not defined FORGE_NO_PAUSE pause
