@echo off
setlocal
pwsh -NoLogo -NoProfile -File "%~dp0scripts\tbg\Publish-TbgVersionUpgradeSprintPacket.ps1" %*
exit /b %ERRORLEVEL%
