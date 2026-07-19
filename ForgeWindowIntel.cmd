@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "POWERSHELL_EXE=powershell.exe"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "POWERSHELL_EXE=pwsh.exe"

if "%~1"=="" (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgWindowIntelligence.ps1" -Command scan -Mode observe
) else (
  rem listen is a bounded read-only SetWinEventHook observation command.
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgWindowIntelligence.ps1" -Command %*
)
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%
