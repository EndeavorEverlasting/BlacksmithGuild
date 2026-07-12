@echo off
setlocal
set "REPO_ROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\tbg\Invoke-TbgStalePrRecovery.ps1" %*
set "PRODUCER_EXIT=%ERRORLEVEL%"
if not "%PRODUCER_EXIT%"=="0" endlocal & exit /b %PRODUCER_EXIT%

call "%REPO_ROOT%ForgeArtifactEngine.cmd" trigger stale-pr-recovery
set "ENGINE_EXIT=%ERRORLEVEL%"
endlocal & exit /b %ENGINE_EXIT%
