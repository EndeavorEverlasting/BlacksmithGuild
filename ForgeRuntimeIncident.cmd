@echo off
setlocal
set "ROOT=%~dp0"
if /I "%~1"=="test" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Test-TbgRuntimeIncidentAssembler.ps1"
  exit /b %ERRORLEVEL%
)
if /I "%~1"=="capsule" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\New-TbgRuntimeIncidentCapsule.ps1" -RunRoot "%~2" -OutputPath "%~3" -RemoteReviewNeeded
  exit /b %ERRORLEVEL%
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Resolve-TbgRuntimeIncident.ps1" -RunRoot "%~1"
exit /b %ERRORLEVEL%
