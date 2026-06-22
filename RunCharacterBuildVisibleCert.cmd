@echo off
setlocal
set NOPAUSE=
if /I "%~1"=="-NoPause" set NOPAUSE=1
echo.
echo The Blacksmith Guild - RunCharacterBuildVisibleCert (008C-Fix)
echo Personal baseline cert - UserVisible doctrine path (NOT AgentHeadless).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-character-build-visible-cert.ps1" %*
set EXITCODE=%ERRORLEVEL%
if defined NOPAUSE exit /b %EXITCODE%
echo.
pause
exit /b %EXITCODE%
