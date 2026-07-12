@echo off
setlocal

echo.
echo The Blacksmith Guild - Launcher Validation Workhorse
echo.
echo This supervisor persists across ordinary concurrency states instead of stopping at the first busy worktree.
echo Workspace modes: current synced, current local commits, isolated remote, and isolated local snapshot.
echo It retries fetch and isolated-worktree creation, runs the strict leaf worker, and writes English handoffs.
echo.

rem The PowerShell supervisor resolves RepoRoot from its own tracked location.
rem It never resets, cleans, stashes, deletes, force-pushes, or merges the operator's work.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-launcher-validation-supervisor.ps1" %*
set WORKHORSE_EXIT=%ERRORLEVEL%

echo.
if %WORKHORSE_EXIT% EQU 0 (
    echo The multimodal launcher validation supervisor completed successfully.
) else (
    echo The multimodal launcher validation supervisor stopped with exit code %WORKHORSE_EXIT% after exhausting its safe modes or reaching a clear semantic dead end.
)
echo Supervisor progress: %~dp0artifacts\latest\launcher-validation-supervisor.progress.log
echo Supervisor handoff:  %~dp0artifacts\latest\launcher-validation-supervisor.handoff.md
echo Supervisor result:   %~dp0artifacts\latest\launcher-validation-supervisor.result.json
echo Leaf progress:       %~dp0artifacts\latest\launcher-validation-workhorse.progress.log
echo Leaf handoff:        %~dp0artifacts\latest\launcher-validation-workhorse.handoff.md
echo Leaf result:         %~dp0artifacts\latest\launcher-validation-workhorse.result.json

if not defined TBG_NO_PAUSE pause
exit /b %WORKHORSE_EXIT%
