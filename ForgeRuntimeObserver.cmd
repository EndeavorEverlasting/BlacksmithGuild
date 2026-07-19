@echo off
setlocal
set "ROOT=%~dp0"
if /I "%~1"=="test" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Test-TbgGameRuntimeObserver.ps1"
  exit /b %ERRORLEVEL%
)
if /I "%~1"=="status" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Start-TbgGameRuntimeObserver.ps1" -Command status -RunId "%~2"
  exit /b %ERRORLEVEL%
)
if /I "%~1"=="stop" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Start-TbgGameRuntimeObserver.ps1" -Command stop -RunId "%~2" -LeaseId "%~3"
  exit /b %ERRORLEVEL%
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Start-TbgGameRuntimeObserver.ps1" -Command start
exit /b %ERRORLEVEL%
