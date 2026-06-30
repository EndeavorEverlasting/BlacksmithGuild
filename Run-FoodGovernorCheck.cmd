@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Food Governor Check is now a compatibility alias.
echo Prefer Run-FoodAdvisory.cmd for the direct AnalyzeFood command.
echo This does NOT buy food.
echo.
call "%~dp0Run-FoodAdvisory.cmd"
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Food Governor Check alias finished with exit code %TBG_EXIT%.
echo.
exit /b %TBG_EXIT%
