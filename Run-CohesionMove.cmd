@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Cohesion Move - visible player-party movement
echo WARNING: This can move the main party. Use a disposable save unless accepted.
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: BlacksmithGuild_CohesionMove.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command RunVisibleCohesionMoveNow -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Cohesion Move wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
