@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Guild Loop Advisory - read-only market + forge + crew plan
echo Requires: Bannerlord campaign map ready, mod loaded, command inbox polling.
echo Output: BlacksmithGuild_GuildLoopReport.json
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Command RunGuildLoopNow -Wait
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Guild Loop Advisory wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
