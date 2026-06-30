@echo off
setlocal
set ROUTE_MODE_CMD=%~1
if "%ROUTE_MODE_CMD%"=="" set ROUTE_MODE_CMD=status

echo.
echo The Blacksmith Guild - ForgeRouteMode
echo Shared route mode: direct or exploring
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . '%~dp0scripts\route-opportunity-mode.ps1'; $cmd = '%ROUTE_MODE_CMD%'.ToLowerInvariant(); if ($cmd -eq 'status') { $resolved = Resolve-TbgRouteOpportunityMode; Write-Host ('mode=' + $resolved.mode + ' source=' + $resolved.source + ' allowVillageStops=' + $resolved.allowVillageStops + ' path=' + $resolved.path); exit 0 }; if ($cmd -eq 'toggle') { $current = Resolve-TbgRouteOpportunityMode; $next = if ($current.mode -eq 'exploring') { 'direct' } else { 'exploring' }; $path = Write-TbgRouteOpportunityMode -Mode $next -RequestedBy 'ForgeRouteMode.cmd' -Reason 'toggle'; Write-Host ('mode=' + $next + ' path=' + $path); exit 0 }; if ($cmd -in @('direct','exploring')) { $path = Write-TbgRouteOpportunityMode -Mode $cmd -RequestedBy 'ForgeRouteMode.cmd' -Reason 'operator_requested'; Write-Host ('mode=' + $cmd + ' path=' + $path); exit 0 }; Write-Error 'Usage: ForgeRouteMode.cmd status ^| direct ^| exploring ^| toggle'; exit 64 }"
set FORGE_EXIT=%ERRORLEVEL%
if %FORGE_EXIT% NEQ 0 echo ForgeRouteMode failed with exit %FORGE_EXIT%.
if not defined FORGE_NO_PAUSE pause
exit /b %FORGE_EXIT%
