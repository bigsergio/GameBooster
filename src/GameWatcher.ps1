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
            Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Boost", "-Silent" -Wait

            # 2. Auto-Launch Companion Apps
            # 2a. Global Companion Apps (from Tab 5)
            $globalCompanions = if ($autoStartConfig.companionApps) { $autoStartConfig.companionApps } elseif ($autoStartConfig.apps) { $autoStartConfig.apps } else { @() }
            if ($globalCompanions) {
                foreach ($app in $globalCompanions) {
                    $isEnabled = if ($null -ne $app.enabled) { [bool]$app.enabled } else { $true }
                    if ($isEnabled) {
                        $pName = if ($app.processName) { $app.processName } else { $app.name }
                        $running = Get-Process -Name $pName -ErrorAction SilentlyContinue
                        if (-not $running) {
                            Write-Host " -> Auto-starting global companion: $($app.name)..." -ForegroundColor Cyan
                            Write-WatcherLog "Auto-launching global companion: $($app.name)"
                            try {
                                if ($app.path -match '(?i)Discord') {
                                    Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
                                } elseif ($app.path -and (Test-Path $app.path)) {
                                    Start-Process $app.path
                                } else {
                                    Start-Process $pName -ErrorAction SilentlyContinue
                                }
                            } catch {
                                Write-WatcherLog "Failed to launch global companion $($app.name): $_"
                            }
                        } else {
                            Write-Host " -> Global companion $($app.name) is already running." -ForegroundColor DarkGray
                        }
                    }
                }
            }

            # 2b. Per-Game Custom Companions (from Tab 2 Profile - supports multiple programs separated by commas/semicolons)
            try {
                if (Test-Path $ConfigFile) {
                    $rawCfg = Get-Content -Raw -Path $ConfigFile -Encoding UTF8 | ConvertFrom-Json
                    $gameKey = $gameProc.ProcessName -replace '\.exe$', ''
                    if ($rawCfg.gameProfiles -and $rawCfg.gameProfiles.$gameKey) {
                        $prof = $rawCfg.gameProfiles.$gameKey
                        $customStr = if ($prof.Companion) { $prof.Companion } elseif ($prof.CompanionApps) { ($prof.CompanionApps -join ', ') } else { "" }
                        if ($customStr) {
                            $targets = $customStr -split '[,;\|]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                            foreach ($prog in $targets) {
                                Write-Host " -> Auto-starting per-game companion: $prog..." -ForegroundColor Cyan
                                Write-WatcherLog "Auto-launching per-game companion: $prog"
                                try {
                                    if ($prog -match '(?i)Discord') {
                                        $dPath = "$env:LOCALAPPDATA\Discord\Update.exe"
                                        if (Test-Path $dPath) { Start-Process $dPath -ArgumentList "--processStart Discord.exe" }
                                    } elseif (Test-Path $prog) {
                                        Start-Process $prog
                                    } else {
                                        $pClean = $prog -replace '\.exe$', ''
                                        $isRun = Get-Process -Name $pClean -ErrorAction SilentlyContinue
                                        if (-not $isRun) { Start-Process $prog -ErrorAction SilentlyContinue }
                                    }
                                } catch {
                                    Write-WatcherLog "Failed to launch per-game companion '$prog': $_"
                                }
                            }
                        }
                    }
                }
            } catch {
                Write-WatcherLog "Error reading per-game companion: $_"
            }

            # 3. Launch or Refocus Hardware HUD
            Write-Host " -> Docking Hardware Gaming HUD..." -ForegroundColor Cyan
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\Launch_Gaming_HUD.ps1`""

            Write-Host "[V] System optimized for gaming. Monitoring session..." -ForegroundColor Green
        }
        elseif (-not $gameProc -and $isGaming) {
            $isGaming = $false
            Write-Host "`n[!] GAME SESSION ENDED!" -ForegroundColor Yellow
            Write-WatcherLog "Game exited."

            $shouldRestore = $true
            try {
                if (Test-Path $ConfigFile) {
                    $rawCfg = Get-Content -Raw -Path $ConfigFile -Encoding UTF8 | ConvertFrom-Json
                    if ($rawCfg.watcherSettings -and $null -ne $rawCfg.watcherSettings.autoRestoreOnGameExit) {
                        $shouldRestore = [bool]$rawCfg.watcherSettings.autoRestoreOnGameExit
                    }
                }
            } catch {}

            if ($shouldRestore) {
                Write-Host " -> Restoring applications from previous session..." -ForegroundColor Cyan
                Write-WatcherLog "Initiating session restoration..."
                Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Restore", "-Silent" -Wait
                Write-Host "[V] All applications restored! Waiting for next gaming session...`n" -ForegroundColor Green
            } else {
                Write-Host " -> Auto-restore disabled in settings. Closed apps will remain closed." -ForegroundColor DarkGray
                Write-WatcherLog "Auto-restore disabled in settings. Closed apps remain closed."
                Write-Host "[V] Game session closed. Waiting for next gaming session...`n" -ForegroundColor Green
            }
        }
    }
}
finally {
    Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
}

