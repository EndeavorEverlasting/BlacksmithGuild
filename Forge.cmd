@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge
echo.
echo Build + install + frozen-context PLAY until map (see docs\forge-zero-click-contract.md).
echo Emergency stop (no taskbar icon): ForgeStop.cmd
echo Daily dev loop: ForgeContinue.cmd
echo Watch mode: ForgeWatch.cmd or .\forge.ps1 -Watch
echo In-game: F7 status, F8-F11 dev commands, Ctrl+Alt+S progression test.
echo Surfaces: docs\in-game-surfaces.md
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Launch -LaunchIntent play -LaunchManual -SessionAuthorityMode FreshTestLaunch
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Build failed. See messages above.
    pause
    exit /b %FORGE_EXIT%
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0scripts\bannerlord-paths.ps1'; $root = Get-BannerlordRootFromRepo -RepoRoot '%~dp0'; & '%~dp0scripts\write-launch-intent.ps1' -LaunchIntent play -BannerlordRoot $root; & '%~dp0scripts\launcher-frozen-context-nav.ps1' -LaunchIntent play -BannerlordRoot $root -LauncherContextPath (Join-Path $root 'launcher-window-context.json') -TimeoutSec 120 -PollMs 250 -LaunchSetup"
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Frozen PLAY failed or needs operator action. See Launch.log.
    pause
    exit /b %FORGE_EXIT%
)

echo.
echo Log tails: see paths printed above (Forge.log + Phase1 Documents and Steam root + Launch.log).
echo If install was blocked, close Bannerlord and run Forge.cmd again.
pause
