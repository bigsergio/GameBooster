@echo off
title Game Booster - Export Debug Report
echo ========================================================
echo Game Booster - Generating Debug & Crash Report...
echo ========================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Export-DebugReport.ps1"
echo.
echo Report opened in Notepad and saved to your Desktop!
pause
