@echo off
setlocal

echo.
echo The Blacksmith Guild - One-Click Continue Campaign
echo.
echo Build and install the exact head, pass known launcher windows, load the pinned dev save,
echo travel to a town, prove one real visible trade, then hand off to forge, horse, governor,
echo and autonomous guild-loop engines with correlated JSON and English logs.
echo.
echo Latest result:   %~dp0artifacts\latest\forge-continue-campaign.result.json
echo Latest report:   %~dp0artifacts\latest\forge-continue-campaign.report.md
echo Latest progress: %~dp0artifacts\latest\forge-continue-campaign.progress.log
echo.

rem The PowerShell coordinator resolves the repo root from its own tracked location.
rem It delegates launcher/save/travel/trade proof to run-tbg-visible-trade-cycle.ps1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-forge-continue-campaign.ps1" %*
set FORGE_EXIT=%ERRORLEVEL%

echo.
if %FORGE_EXIT% EQU 0 (
    echo Forge Continue completed the visible trade and downstream handoff pipeline.
) else (
    echo Forge Continue stopped at a bounded stage with exit code %FORGE_EXIT%.
)
echo Result:   %~dp0artifacts\latest\forge-continue-campaign.result.json
echo Report:   %~dp0artifacts\latest\forge-continue-campaign.report.md
echo Progress: %~dp0artifacts\latest\forge-continue-campaign.progress.log
if not defined TBG_NO_PAUSE pause
exit /b %FORGE_EXIT%
