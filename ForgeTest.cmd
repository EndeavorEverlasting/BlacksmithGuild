@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "POWERSHELL_EXE=powershell.exe"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "POWERSHELL_EXE=pwsh.exe"

set "SCRIPT=%REPO_ROOT%scripts\tbg\Invoke-TbgOneClickTest.ps1"

set "ARGS=%*"
set "ARGS=%ARGS:--no-pause=-NoPause%"
set "ARGS=%ARGS:--profile=-Profile%"
set "ARGS=%ARGS:--test=-Test%"
set "ARGS=%ARGS:--run=-Run%"

if "%ARGS%"=="" (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT%' run"
) else (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT%' %ARGS%"
)
set "EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %EXIT_CODE%
