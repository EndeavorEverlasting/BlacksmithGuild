@echo off
setlocal
cd /d "%~dp0"

set "TBG_COMMAND=%~1"
if "%TBG_COMMAND%"=="" set "TBG_COMMAND=check"

echo [TBG] Bannerlord Game Compatibility Updater
echo [TBG] Mode: metadata-only; this command does not launch or update the game.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tbg\Invoke-TbgGameCompatibility.ps1" -Command "%TBG_COMMAND%"
set "TBG_EXIT=%ERRORLEVEL%"

echo.
echo [TBG] Result: artifacts\latest\game-compatibility\game-compatibility.result.json
echo [TBG] Report: artifacts\latest\game-compatibility\game-compatibility.report.md
echo [TBG] Exit code: %TBG_EXIT%
if not defined TBG_GAME_UPDATE_NO_PAUSE pause
exit /b %TBG_EXIT%
