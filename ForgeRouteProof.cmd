@echo off
setlocal

echo.
echo The Blacksmith Guild - Route Proof Focus Harness
echo.
echo Uses ForgeReboot with the focused route proof wrapper enabled.
echo Pass -StopBeforeLaunch to stop the game first through ForgeStop.cmd soft.
echo.

call "%~dp0ForgeReboot.cmd" -FocusKeeperMode SyntheticFocusPulse -ActionTimeoutClass long_distance_travel %*
exit /b %ERRORLEVEL%
