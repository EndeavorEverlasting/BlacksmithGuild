@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge
echo.
echo Build + install + fast modal-aware PLAY until game handoff.
echo Timing: 5-second phases, 30-second total cap, one bounded full-close retry.
echo Evidence: artifacts\latest\launcher-frontdoor\ and launcher-frontdoor.result.json
echo Emergency stop ^(no taskbar icon^): ForgeStop.cmd
echo Daily dev loop: ForgeContinue.cmd
echo Watch mode: ForgeWatch.cmd or .\forge.ps1 -Watch
echo In-game: F7 status, F8-F11 dev commands, Ctrl+Alt+S progression test.
echo Surfaces: docs\in-game-surfaces.md
echo.

rem LaunchManual deliberately stops forge.ps1 before UI navigation.
rem The repo-owned fast frontdoor below owns PLAY/CONTINUE, CAUTION Confirm, retry, and evidence.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent play -LaunchManual -SessionAuthorityMode FreshTestLaunch
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build or launcher-open phase failed. See Forge.log and Launch.log.
    pause
    exit /b %FORGE_EXIT%
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launcher-fast-frontdoor.ps1" -LaunchIntent play -RepoRoot "%~dp0" -TotalBudgetSec 30 -PhaseBudgetSec 5 -MaxAttempts 2
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Forge PLAY reached a bounded launcher dead end.
    echo Local evidence: %~dp0artifacts\latest\launcher-frontdoor\
    echo Latest result: %~dp0artifacts\latest\launcher-frontdoor.result.json
    echo Run CollectDiagnostics.cmd only when a full diagnostic zip is also needed.
    pause
    exit /b %FORGE_EXIT%
)

echo.
echo Launcher handoff observed. Runtime readiness remains a separate proof level.
echo Local evidence: %~dp0artifacts\latest\launcher-frontdoor\
pause
