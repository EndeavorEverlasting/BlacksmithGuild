@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Food Advisory - direct read-only analysis
echo This does NOT buy food. It runs AnalyzeFood and writes the dedicated food advisory JSON.
echo Output: BlacksmithGuild_FoodAdvisory.json
echo Includes: food status, diversity, runway forecast, procurement plan, candidates, market stock, matches, and proof gate.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command AnalyzeFood -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Food Advisory wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
