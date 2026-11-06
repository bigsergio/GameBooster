@echo off
:: ============================================================================
:: Game Booster PRO v2.0 - Elevated Administrator Launcher
:: Automatically requests Administrator UAC elevation
:: ============================================================================
set "APP_DIR=%~dp0"
cd /d "%APP_DIR%"

:: Check for Administrator privileges; if not elevated, prompt with UAC RunAs
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

if exist "%APP_DIR%GameBooster.exe" (
    start "" "%APP_DIR%GameBooster.exe"
    exit /b
)

where pwsh.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_EXE=pwsh.exe"
) else (
    set "PS_EXE=powershell.exe"
)

start "" %PS_EXE% -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%APP_DIR%src\GameBooster.ps1" -Gui
exit /b
