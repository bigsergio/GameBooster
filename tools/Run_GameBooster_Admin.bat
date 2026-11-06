@echo off
:: ============================================================================
:: Game Booster PRO v2.0 - Elevated Fallback Launcher
:: Use this only if GameBooster.exe does not trigger UAC elevation automatically
:: ============================================================================
set "ROOT_DIR=%~dp0..\"
cd /d "%ROOT_DIR%"

net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

if exist "%ROOT_DIR%GameBooster.exe" (
    start "" "%ROOT_DIR%GameBooster.exe"
    exit /b
)

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_EXE=pwsh.exe"
) else (
    set "PS_EXE=powershell.exe"
)

start "" %PS_EXE% -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT_DIR%src\GameBooster.ps1" -Gui
exit /b
