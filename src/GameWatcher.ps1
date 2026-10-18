# ============================================================================
# Zero-Click Game Mode Watcher
# Automatically activates Game Mode & HUD when Call of Duty launches,
# auto-launches companion apps (e.g. Discord), and restores apps on exit.
# ============================================================================

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
Set-Location -Path $RootDir

# Determine PowerShell Host Executable
$PSHostExe = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
if (-not $PSHostExe -or -not (Test-Path $PSHostExe)) {
    $PSHostExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
}

$ConfigFile = Join-Path $RootDir "config.json"
$LogFile = Join-Path $RootDir "gamebooster.log"

function Write-WatcherLog($msg) {
    $line = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [WATCHER] $msg"
    try { Add-Content -Path $LogFile -Value $line -Force -ErrorAction SilentlyContinue } catch {}
    Write-Host $msg
}

$Host.UI.RawUI.WindowTitle = "Game Mode Auto-Watcher (Zero-Click Gaming Daemon)"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "             GAME MODE ZERO-CLICK WATCHER (GAME MONITOR & COMPANIONS)           " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Monitoring background for your configured game executables..." -ForegroundColor Gray
Write-Host "You can minimize this window. It will optimize your PC hands-free when you play.`n" -ForegroundColor DarkGray

$PidFile = Join-Path $ScriptDir "watcher.pid"
try {
    $PID | Out-File -FilePath $PidFile -Encoding ascii -Force
} catch {}

$isGaming = $false

try {
    while ($true) {
        Start-Sleep -Seconds 3

        # Read triggers and companion settings dynamically
        $triggerNames = @("cod", "bootstrapper", "cod24", "sp24", "BlackOps6", "Wow", "WowClassic", "Wow-64")
        $autoStartConfig = $null
        if (Test-Path $ConfigFile) {
            try {
                $cfg = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
                if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
                    $triggerNames = @($cfg.watcherSettings.monitoredGames)
                } elseif ($cfg.autoStartWith -and $cfg.autoStartWith.triggerProcesses) {
                    $triggerNames = @($cfg.autoStartWith.triggerProcesses)
                }
                $autoStartConfig = $cfg.autoStartWith
            } catch {}
        }

        $gameProc = Get-Process -Name $triggerNames -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($gameProc -and -not $isGaming) {
            $isGaming = $true
            Write-Host "`n[!] GAME LAUNCH DETECTED: $($gameProc.ProcessName) (PID: $($gameProc.Id))!" -ForegroundColor Green
            Write-WatcherLog "Detected game launch: $($gameProc.ProcessName) (PID: $($gameProc.Id))"

            # 1. Activate Game Mode Boost
            Write-Host " -> Activating Game Mode (closing background apps, flushing standby RAM)..." -ForegroundColor Cyan
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Wait", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Boost", "-Silent"

            # 2. Auto-Launch Companion Apps (e.g. Discord)
            if ($autoStartConfig -and $autoStartConfig.enabled -and $autoStartConfig.apps) {
                foreach ($app in $autoStartConfig.apps) {
                    if ($app.enabled) {
                        $running = Get-Process -Name $app.processName -ErrorAction SilentlyContinue
                        if (-not $running) {
                            Write-Host " -> Auto-starting companion app: $($app.name)..." -ForegroundColor Cyan
                            Write-WatcherLog "Auto-launching companion app: $($app.name)"
                            try {
                                if ($app.path -match '(?i)Discord') {
                                    Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
                                } elseif ($app.path -and (Test-Path $app.path)) {
                                    Start-Process $app.path
                                } else {
                                    Start-Process $app.processName -ErrorAction SilentlyContinue
                                }
                            } catch {
                                Write-WatcherLog "Failed to launch $($app.name): $_"
                            }
                        } else {
                            Write-Host " -> Companion app $($app.name) is already running." -ForegroundColor DarkGray
                        }
                    }
                }
            }

            # 3. Launch or Refocus Hardware HUD
            Write-Host " -> Docking Hardware Gaming HUD..." -ForegroundColor Cyan
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\Launch_Gaming_HUD.ps1`""

            Write-Host "[V] System optimized for gaming. Monitoring session..." -ForegroundColor Green
        }
        elseif (-not $gameProc -and $isGaming) {
            $isGaming = $false
            Write-Host "`n[!] GAME SESSION ENDED ($($gameProc.ProcessName))!" -ForegroundColor Yellow
            Write-WatcherLog "Game exited. Initiating session restoration..."

            Write-Host " -> Restoring applications from previous session..." -ForegroundColor Cyan
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Wait", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Restore", "-Silent"

            Write-Host "[V] All applications restored! Waiting for next gaming session...`n" -ForegroundColor Green
        }
    }
}
finally {
    Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
}

