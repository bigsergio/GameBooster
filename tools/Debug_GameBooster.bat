@echo off
:: ============================================================================
:: Game Booster PRO v2.0 - Debug Console Launcher
:: Keeps console window open to display real-time engine initialization & logs
:: ============================================================================
set "ROOT_DIR=%~dp0..\"
cd /d "%ROOT_DIR%"

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_EXE=pwsh.exe"
) else (
    set "PS_EXE=powershell.exe"
)

echo ========================================================
echo Game Booster PRO v2.0 - Launching in Console Debug Mode
echo ========================================================
%PS_EXE% -NoProfile -ExecutionPolicy Bypass -NoExit -File "%ROOT_DIR%src\GameBooster.ps1" -Gui
