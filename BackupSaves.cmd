@echo off
setlocal

echo.
echo The Blacksmith Guild - Save Backup
echo.
echo Incrementally backs up changed .sav files from Game Saves.
echo Original saves are never deleted or modified.
echo.
echo Backup root: Documents\Mount and Blade II Bannerlord\BlacksmithGuild_SaveBackups
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" -BackupSaves
if errorlevel 1 (
    echo.
    echo Save backup failed. See messages above.
    pause
    exit /b 1
)

echo.
pause
