@echo off
setlocal

echo.
echo The Blacksmith Guild - Visible Trade One-Click Proof
echo.
echo This coordinator validates source, builds, installs, launches Bannerlord,
echo issues a correlated route command, observes campaign time and movement,
echo attempts the visible buy/travel/sell cycle, and publishes a sanitized
echo evidence capsule to a remote branch.
echo.
echo Workspace modes: current synced, current local commits, isolated remote.
echo The supervisor never resets, cleans, stashes, force-pushes, or deletes work.
echo.

rem The PowerShell coordinator resolves RepoRoot from its own tracked location.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-visible-trade-proof.ps1" %*
set "VTP_EXIT=%ERRORLEVEL%"

echo.
if %VTP_EXIT% EQU 0 (
    echo The visible trade one-click proof coordinator completed successfully.
) else if %VTP_EXIT% EQU 3 (
    echo The visible trade proof ran in diagnostic-only mode and did not launch Bannerlord.
) else (
    echo The visible trade proof coordinator stopped with exit code %VTP_EXIT%.
)
echo.
echo Artifacts:
echo   Progress:   %~dp0artifacts\latest\visible-trade-proof.progress.log
echo   Events:     %~dp0artifacts\latest\visible-trade-proof.events.jsonl
echo   Handoff:    %~dp0artifacts\latest\visible-trade-proof.handoff.md
echo   Result:     %~dp0artifacts\latest\visible-trade-proof.result.json
echo   Proof:      %~dp0artifacts\latest\visible-trade-proof.proof.json
echo   Capsule:    %~dp0artifacts\latest\visible-trade-proof.capsule.json

if not defined TBG_NO_PAUSE pause
exit /b %VTP_EXIT%
