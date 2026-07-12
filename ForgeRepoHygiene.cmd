@echo off
setlocal

set "REPO_ROOT=%~dp0."
set "SCRIPT=%~dp0scripts\tbg\Get-TbgRepoHygieneReport.ps1"
set "POWERSHELL_EXE=powershell.exe"

if not exist "%SCRIPT%" (
  echo Missing script: %SCRIPT%
  exit /b 1
)

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "POWERSHELL_EXE=pwsh.exe"

%POWERSHELL_EXE% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -RepoRoot "%REPO_ROOT%" %*
exit /b %ERRORLEVEL%
