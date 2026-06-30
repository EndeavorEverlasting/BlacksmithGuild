@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Cohesion Analyze - read-only opportunity scan
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: BlacksmithGuild_CohesionOpportunities.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command AnalyzeCohesionOpportunities -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Cohesion Analyze wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
