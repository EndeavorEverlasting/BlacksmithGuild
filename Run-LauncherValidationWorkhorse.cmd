@echo off
setlocal

echo.
echo The Blacksmith Guild - Launcher Validation Workhorse
echo.
echo This workhorse synchronizes the current sprint branch safely, validates the launcher harness,
echo force-stops the Bannerlord process family, runs Forge Continue, and writes an English handoff.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-launcher-validation-workhorse.ps1" -RepoRoot "%~dp0" %*
set WORKHORSE_EXIT=%ERRORLEVEL%

echo.
if %WORKHORSE_EXIT% EQU 0 (
    echo The launcher validation workhorse completed successfully.
) else (
    echo The launcher validation workhorse stopped with exit code %WORKHORSE_EXIT%.
)
echo Latest progress: %~dp0artifacts\latest\launcher-validation-workhorse.progress.log
echo Latest handoff:  %~dp0artifacts\latest\launcher-validation-workhorse.handoff.md
echo Latest result:   %~dp0artifacts\latest\launcher-validation-workhorse.result.json

if not defined TBG_NO_PAUSE pause
exit /b %WORKHORSE_EXIT%
