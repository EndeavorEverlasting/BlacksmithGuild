@echo off
setlocal
set "ROOT=%~dp0"
set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"

if /I "%~1"=="test" (
  "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Test-TbgOneClickCascade.ps1"
  exit /b %ERRORLEVEL%
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\tbg\Resolve-TbgOneClickCascade.ps1" -RunRoot "%~1"
exit /b %ERRORLEVEL%
