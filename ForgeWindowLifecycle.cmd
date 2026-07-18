@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "POWERSHELL_EXE=powershell.exe"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% EQU 0 set "POWERSHELL_EXE=pwsh.exe"

if /I "%~1"=="validate" (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Test-TbgWindowLifecycle.ps1"
  if errorlevel 1 exit /b %ERRORLEVEL%
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Test-TbgWindowLifecycleRuntime.ps1"
  set "EXIT_CODE=%ERRORLEVEL%"
  endlocal & exit /b %EXIT_CODE%
)

if /I "%~1"=="replay" (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgWindowLifecycleRuntime.ps1" -Command replay %2 %3 %4 %5 %6 %7 %8 %9
  set "EXIT_CODE=%ERRORLEVEL%"
  endlocal & exit /b %EXIT_CODE%
)

if /I "%~1"=="status" (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgWindowLifecycleRuntime.ps1" -Command status
  set "EXIT_CODE=%ERRORLEVEL%"
  endlocal & exit /b %EXIT_CODE%
)

if /I "%~1"=="reduce" (
  "%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgWindowLifecycleRuntime.ps1" -Command reduce %2 %3 %4 %5 %6 %7 %8 %9
  set "EXIT_CODE=%ERRORLEVEL%"
  endlocal & exit /b %EXIT_CODE%
)

if "%~1"=="" (
  echo ForgeWindowLifecycle.cmd exposes validation, fixture replay, and latest status only.
  echo It does not launch Bannerlord.
  echo.
  echo Usage:
  echo   ForgeWindowLifecycle.cmd validate
  echo   ForgeWindowLifecycle.cmd replay
  echo   ForgeWindowLifecycle.cmd status
  echo.
  echo Proof ceiling: launcher_lifecycle_harness
  echo Proof level for fixture replay: runtime_adapter_harness
  endlocal & exit /b 0
)

echo Unknown ForgeWindowLifecycle command '%~1'.
echo Use validate, replay, status, or reduce.
endlocal & exit /b 2
