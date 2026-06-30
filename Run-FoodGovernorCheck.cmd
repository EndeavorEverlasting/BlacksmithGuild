@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Food Governor Check - read-only/proposal analysis
echo This does NOT buy food. It runs the campaign governor cycle and writes the decision JSON.
echo Food data appears in foodStatus, foodDiversityStatus, foodForecastStatus, and latestActivityResult when Food is selected.
echo Output: BlacksmithGuild_CampaignGovernorDecision.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command RunCampaignGovernorCycleNow -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Food Governor Check wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
