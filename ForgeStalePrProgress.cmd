@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "POWERSHELL_EXE=powershell.exe"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "POWERSHELL_EXE=pwsh.exe"

%POWERSHELL_EXE% -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Write-TbgStalePrRecoveryProgress.ps1" %*
set "PROGRESS_EXIT=%ERRORLEVEL%"
endlocal & exit /b %PROGRESS_EXIT%
