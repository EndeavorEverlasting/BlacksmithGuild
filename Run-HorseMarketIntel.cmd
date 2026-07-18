@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Horse Market Intel - read-only advisory
echo Requires: campaign map at town gate or settlement interior with command inbox polling.
echo Output: BlacksmithGuild_HorseMarketIntel.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command AnalyzeHorseMarket -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Horse Market Intel wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
