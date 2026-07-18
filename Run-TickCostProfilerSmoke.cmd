@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Tick Cost Profiler Smoke
echo The profiler runs automatically during campaign ticks when TickCostProfilerEnabled=true.
echo This wrapper sends ShowForgeStatus to confirm inbox polling, then exports evidence.
echo Inspect runtime output: BlacksmithGuild_TickCostProfiler.json after slow tick segments occur.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command ShowForgeStatus -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Exporting evidence snapshot so agents can inspect profiler/status files if present.
call "%~dp0ExportTbgEvidence.cmd"
echo.
echo [TBG] Tick Cost Profiler Smoke wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
