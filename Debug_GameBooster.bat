@echo off
:: ============================================================================
:: Game Booster PRO v2.0 - Debug Console Launcher
:: Keeps console window open to display real-time engine initialization & logs
:: ============================================================================
set "APP_DIR=%~dp0"
cd /d "%APP_DIR%"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_EXE=pwsh.exe"
) else (
    set "PS_EXE=powershell.exe"
)

echo Starting Game Booster PRO v2.0 in Debug Mode...
%PS_EXE% -NoProfile -ExecutionPolicy Bypass -NoExit -File "%APP_DIR%src\GameBooster.ps1" -Gui
