@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Reboot
echo.
echo Local reboot iteration harness: build/deploy, continue/attach, run assist,
echo collect evidence, compare normalized context, and write a next-gap handoff.
echo AI tokens are for patches, not babysitting repeated retries.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-reboot-iteration.ps1" %*
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% EQU 2 (
    echo.
    echo Forge Reboot found a stable gap and wrote a local handoff.
    echo See latest docs\evidence\reboot*-reboot-session\stable-gap-handoff.md.
    if not defined FORGE_NO_PAUSE pause
    exit /b %FORGE_EXIT%
)
if %FORGE_EXIT% NEQ 0 (
    echo.
    echo Forge Reboot stopped or failed. See latest docs\evidence\reboot*-reboot-session output.
    if not defined FORGE_NO_PAUSE pause
    exit /b %FORGE_EXIT%
)

echo.
echo Forge Reboot complete. See latest docs\evidence\reboot*-reboot-session\reboot-summary.md.
if not defined FORGE_NO_PAUSE pause