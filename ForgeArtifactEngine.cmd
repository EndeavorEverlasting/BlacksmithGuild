@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "POWERSHELL_EXE=powershell.exe"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "POWERSHELL_EXE=pwsh.exe"

%POWERSHELL_EXE% -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgArtifactEngine.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%
