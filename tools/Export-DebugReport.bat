@echo off
title Game Booster - Export Debug Report
echo ========================================================
echo Game Booster - Generating Debug & Crash Report...
echo ========================================================
set "ROOT_DIR=%~dp0..\"
cd /d "%ROOT_DIR%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT_DIR%src\Export-DebugReport.ps1"
echo.
echo Report opened in Notepad and saved to your Desktop!
pause
