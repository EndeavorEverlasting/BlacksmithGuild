@echo off
setlocal
cd /d "%~dp0"
echo.
echo [TBG] Export Evidence
echo Wraps ExportTbgEvidence.cmd and leaves a paste-ready snapshot under docs\evidence\latest\.
echo.
call "%~dp0ExportTbgEvidence.cmd"
set "TBG_EXIT=%ERRORLEVEL%"
echo.
echo [TBG] Export Evidence wrapper finished with exit code %TBG_EXIT%.
echo.
pause
exit /b %TBG_EXIT%
