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
set "PRODUCER_EXIT=%ERRORLEVEL%"
if not "%PRODUCER_EXIT%"=="0" exit /b %PRODUCER_EXIT%

call "%~dp0ForgeArtifactEngine.cmd" trigger repo-hygiene
set "ENGINE_EXIT=%ERRORLEVEL%"
exit /b %ENGINE_EXIT%
