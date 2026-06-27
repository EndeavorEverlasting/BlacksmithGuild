@echo off
setlocal
echo.
echo The Blacksmith Guild - Governor disposable smoke (attach to existing game)
echo Outputs stay local under .local\governor-smoke\ and are not committed.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-governor-disposable-smoke.ps1" -SkipLaunch -NoBuild -NoInstall
echo.
pause