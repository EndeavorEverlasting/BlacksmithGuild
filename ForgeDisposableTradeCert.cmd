@echo off
setlocal
set "TBG_REPO=%~dp0"

echo.
echo The Blacksmith Guild - Disposable Visible Trade Live Certificate
echo.
echo CERTIFYING MODE ONLY

echo Requirements:
echo   - current branch is main

echo   - worktree is clean

echo   - canonical version/save gates pass

echo   - Bannerlord launcher/runtime may be actuated

echo   - only an exact-version disposable save may be used

echo.

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%TBG_REPO%scripts\tbg\Invoke-TbgDisposableTradeLiveCert.ps1" -RepoRoot "%TBG_REPO%"
set "TBG_EXIT=%ERRORLEVEL%"

echo.
if %TBG_EXIT% EQU 0 (
    echo PASS_DISPOSABLE_VISIBLE_TRADE_LIVE_CERT
) else (
    echo Disposable visible trade live certificate stopped with exit code %TBG_EXIT%.
)
echo.
echo Result: %TBG_REPO%artifacts\latest\disposable-trade-live-cert\result.json
echo Report: %TBG_REPO%artifacts\latest\disposable-trade-live-cert\report.md
echo Visible trade: %TBG_REPO%artifacts\latest\visible-trade-proof.result.json

exit /b %TBG_EXIT%
