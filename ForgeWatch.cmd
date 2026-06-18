@echo off
setlocal

echo.
echo The Blacksmith Guild - Forge Watch
echo.
echo Watches source files and rebuilds + installs on change (debounced).
echo Press Ctrl+C to stop. Restart Bannerlord after each install to load the new DLL.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -Watch
if errorlevel 1 (
    echo.
    echo Watch session ended with an error. See messages above.
    pause
    exit /b 1
)

echo.
pause
