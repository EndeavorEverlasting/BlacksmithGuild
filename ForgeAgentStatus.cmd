@echo off
setlocal

set "SCRIPT=%~dp0scripts\tbg\New-TbgChatPacket.ps1"

if not exist "%SCRIPT%" (
  echo Missing script: %SCRIPT%
  exit /b 1
)

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -RepoRoot "%~dp0" %*
  exit /b %ERRORLEVEL%
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -RepoRoot "%~dp0" %*
exit /b %ERRORLEVEL%
