@echo off
setlocal
pwsh -NoLogo -NoProfile -File "%~dp0scripts\tbg\Invoke-TbgSaveCompatibility.ps1" %*
exit /b %ERRORLEVEL%
