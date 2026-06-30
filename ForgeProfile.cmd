@echo off
setlocal
set PROFILE_CMD=%~1
if "%PROFILE_CMD%"=="" set PROFILE_CMD=status

echo.
echo The Blacksmith Guild - ForgeProfile
echo Shared automation profile: default or economic_loop
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . '%~dp0scripts\automation-profile.ps1'; $cmd = '%PROFILE_CMD%'.ToLowerInvariant(); if ($cmd -eq 'status') { $state = Read-TbgAutomationProfile; $resolved = Resolve-TbgAutomationProfile; Write-Host ('profile=' + $resolved.profile + ' source=' + $resolved.source + ' path=' + $resolved.path); exit 0 }; if ($cmd -eq 'toggle') { $current = Resolve-TbgAutomationProfile; $next = if ($current.profile -eq 'economic_loop') { 'default' } else { 'economic_loop' }; $path = Write-TbgAutomationProfile -Profile $next -RequestedBy 'ForgeProfile.cmd' -Reason 'toggle'; Write-Host ('profile=' + $next + ' path=' + $path); exit 0 }; if ($cmd -in @('default','economic_loop')) { $path = Write-TbgAutomationProfile -Profile $cmd -RequestedBy 'ForgeProfile.cmd' -Reason 'operator_requested'; Write-Host ('profile=' + $cmd + ' path=' + $path); exit 0 }; Write-Error 'Usage: ForgeProfile.cmd status ^| default ^| economic_loop ^| toggle'; exit 64 }"
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 echo ForgeProfile failed with exit %FORGE_EXIT%.
if not defined FORGE_NO_PAUSE pause
exit /b %FORGE_EXIT%
