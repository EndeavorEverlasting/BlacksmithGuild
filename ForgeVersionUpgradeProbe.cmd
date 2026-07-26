@echo off
setlocal
pwsh -NoLogo -NoProfile -File "%~dp0scripts\tbg\Invoke-TbgVersionUpgradeImpactProbe.ps1" %*
exit /b %ERRORLEVEL%
