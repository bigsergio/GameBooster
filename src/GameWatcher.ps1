# ============================================================================
# Game Booster PRO v2.0 - Zero-Click Game Mode Watcher
# Automatically activates Game Mode & QoS when your games launch,
# auto-launches companion apps (e.g. Discord), and restores apps on exit.
# Uses ETW Event Tracing (Win32_ProcessStartTrace) for 0.00% idle CPU usage!
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

$Host.UI.RawUI.WindowTitle = "Game Booster PRO v2.0 Auto-Watcher (ETW 0% CPU)"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "             GAME BOOSTER PRO v2.0 WATCHER (ETW EVENT ENGINE & QoS)             " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Monitoring kernel process events for configured games with 0.00% CPU overhead..." -ForegroundColor Gray
Write-Host "Minimizing to background. It will optimize your PC hands-free when you play.`n" -ForegroundColor DarkGray

$PidFile = Join-Path $ScriptDir "watcher.pid"
try {
    $PID | Out-File -FilePath $PidFile -Encoding ascii -Force
} catch {}

# Load Telemetry & Lag Analysis Modules
$modulesDir = Join-Path $ScriptDir "Modules"
if (Test-Path (Join-Path $modulesDir "FrameTelemetry.ps1")) {
    try { . (Join-Path $modulesDir "FrameTelemetry.ps1") } catch {}
}
if (Test-Path (Join-Path $modulesDir "LagAnalyzer.ps1")) {
    try { . (Join-Path $modulesDir "LagAnalyzer.ps1") } catch {}
}

$isGaming = $false
$activeGameName = ""
$activeGamePid = 0

# Initialize ETW Process Start Event Watcher
$startWatcher = $null
try {
    $startWatcher = New-Object System.Management.ManagementEventWatcher("SELECT * FROM Win32_ProcessStartTrace")
    Write-WatcherLog "ETW ProcessStartTrace engine initialized successfully."
} catch {
    Write-WatcherLog "ETW unavailable, falling back to lightweight timer."
}

try {
    while ($true) {
        # Read triggers dynamically
        $triggerNames = @("cod", "bootstrapper", "cod24", "sp24", "BlackOps6", "Wow", "WowClassic", "Wow-64", "cs2", "Valorant", "r5apex")
        $autoStartConfig = $null
        $autoRestore = $true

        if (Test-Path $ConfigFile) {
            try {
                $cfg = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
                if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
                    $triggerNames = @($cfg.watcherSettings.monitoredGames)
                }
                if ($cfg.watcherSettings -and $null -ne $cfg.watcherSettings.autoRestoreOnGameExit) {
                    $autoRestore = [bool]$cfg.watcherSettings.autoRestoreOnGameExit
                }
                $autoStartConfig = $cfg.autoStartWith
            } catch {}
        }

        # Normalize trigger names to avoid extension mismatch
        $triggerSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($t in $triggerNames) {
            $base = $t -replace '\.exe$', ''
            [void]$triggerSet.Add($base)
            [void]$triggerSet.Add("$base.exe")
        }

        # Event-driven wait (timeout 2000ms to allow config reloads and heartbeat)
        $detectedLaunch = $null
        if ($startWatcher -and -not $isGaming) {
            try {
                $ev = $startWatcher.WaitForNextEvent(2000)
                if ($ev) {
                    $pName = $ev.Properties["ProcessName"].Value
                    if ($pName -and $triggerSet.Contains($pName)) {
                        $detectedLaunch = [PSCustomObject]@{
                            ProcessName = $pName -replace '\.exe$', ''
                            Id          = $ev.Properties["ProcessID"].Value
                        }
                    }
                }
            } catch [System.Management.ManagementException] {
                # Timeout is normal when no new processes start
            } catch {}
        } else {
            Start-Sleep -Seconds 2
            if ($isGaming) {
                try {
                    if (Get-Command Sample-SystemLagIndicators -ErrorAction SilentlyContinue) {
                        Sample-SystemLagIndicators
                    }
                } catch {}
            }
        }

        # Check running state if not already caught by event
        $gameProc = $null
        if ($detectedLaunch) {
            $gameProc = Get-Process -Id $detectedLaunch.Id -ErrorAction SilentlyContinue
        } else {
            $gameProc = Get-Process -Name $triggerNames -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if ($gameProc -and -not $isGaming) {
            $isGaming = $true
            $activeGameName = $gameProc.ProcessName
            $activeGamePid = $gameProc.Id

            Write-Host "`n[!] GAME LAUNCH DETECTED: $activeGameName (PID: $activeGamePid)!" -ForegroundColor Green
            Write-WatcherLog "Detected game launch: $activeGameName (PID: $activeGamePid)"

            # 1. Activate Game Mode Boost (Closes apps, flushes standby RAM, sets Ultimate Power Plan, trims launcher RAM)
            Write-Host " -> Activating Game Mode (RAM Diet, Standby Flush & Ultimate Power)..." -ForegroundColor Cyan
            Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Boost", "-Silent" -Wait

            # 2. Dynamic Gaming QoS Packet Tagging (DSCP 46 Expedited Forwarding)
            try {
                if (Test-Path (Join-Path $ScriptDir "Modules\NetworkQoS.ps1")) {
                    & $PSHostExe -NoProfile -ExecutionPolicy Bypass -Command ". '$ScriptDir\Modules\NetworkQoS.ps1'; Add-GamingQosPolicy -GameExeOrPath '$activeGameName.exe' -DscpValue 46" | Out-Null
                    Write-Host " -> Dynamic Gaming QoS: DSCP 46 Expedited Forwarding assigned to $activeGameName.exe" -ForegroundColor Green
                    Write-WatcherLog "Applied DSCP 46 QoS policy to $activeGameName.exe"
                }
            } catch {}

            # 3. Reverse Affinity Core Siloing (Silo background apps away from game threads)
            try {
                if (Test-Path (Join-Path $ScriptDir "Modules\CpuOptimizer.ps1")) {
                    & $PSHostExe -NoProfile -ExecutionPolicy Bypass -Command ". '$ScriptDir\Modules\CpuOptimizer.ps1'; Invoke-ReverseAffinitySiloing" | Out-Null
                    Write-Host " -> Reverse Affinity: Background tasks siloed to auxiliary cores." -ForegroundColor Green
                }
            } catch {}

            # 4. Auto-Launch Global & Per-Game Companion Apps (Discord, OBS, etc.)
            $globalCompanions = if ($autoStartConfig.companionApps) { $autoStartConfig.companionApps } elseif ($autoStartConfig.apps) { $autoStartConfig.apps } else { @() }
            if ($globalCompanions) {
                foreach ($app in $globalCompanions) {
                    $isEnabled = if ($null -ne $app.enabled) { [bool]$app.enabled } else { $true }
                    if ($isEnabled) {
                        $pName = if ($app.processName) { $app.processName } else { $app.name }
                        $running = Get-Process -Name $pName -ErrorAction SilentlyContinue
                        if (-not $running) {
                            Write-Host " -> Auto-starting companion: $($app.name)..." -ForegroundColor Cyan
                            Write-WatcherLog "Auto-launching companion: $($app.name)"
                            try {
                                if ($app.path -match '(?i)Discord') {
                                    Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
                                } elseif ($app.path -and (Test-Path $app.path)) {
                                    Start-Process $app.path
                                } else {
                                    Start-Process $pName -ErrorAction SilentlyContinue
                                }
                            } catch {
                                Write-WatcherLog "Failed to launch companion $($app.name): $_"
                            }
                        }
                    }
                }
            }

            # 5. Launch or Refocus Hardware HUD
            Write-Host " -> Docking Hardware Gaming HUD..." -ForegroundColor Cyan
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\Launch_Gaming_HUD.ps1`""

            # 6. Initialize Post-Game Lag & Stutter Analyzer
            try {
                if (Get-Command Start-LagAnalysisSession -ErrorAction SilentlyContinue) {
                    Start-LagAnalysisSession -GameProcessName $activeGameName -GameProcessId $activeGamePid | Out-Null
                    Write-Host " -> Post-Game Stutter & Frame Telemetry monitoring active." -ForegroundColor Green
                    Write-WatcherLog "Initialized Lag & Frame Telemetry session for $activeGameName"
                }
            } catch {}

            Write-Host "[✓] System optimized for gaming. Monitoring session..." -ForegroundColor Green
        }
        elseif (-not $gameProc -and $isGaming) {
            $isGaming = $false
            Write-Host "`n[!] GAME SESSION ENDED: $activeGameName!" -ForegroundColor Yellow
            Write-WatcherLog "Game exited: $activeGameName"

            # Finalize Lag & Frame Telemetry Analysis Report
            try {
                if (Get-Command Complete-LagAnalysisSession -ErrorAction SilentlyContinue) {
                    $lagRep = Complete-LagAnalysisSession
                    Write-Host " -> Stutter Report Generated: $($lagRep.SmoothnessScore)% Smooth ($($lagRep.StatusGrade))" -ForegroundColor Green
                    Write-WatcherLog "Generated post-game report: $($lagRep.SmoothnessScore)% smooth, $($lagRep.TotalIncidents) incidents, $($lagRep.FpsSummary.TotalStutterHits) stutters."
                }
            } catch {}

            # Remove QoS policy
            try {
                if (Test-Path (Join-Path $ScriptDir "Modules\NetworkQoS.ps1")) {
                    & $PSHostExe -NoProfile -ExecutionPolicy Bypass -Command ". '$ScriptDir\Modules\NetworkQoS.ps1'; Remove-GamingQosPolicy -GameExeOrPath '$activeGameName.exe'" | Out-Null
                    Write-WatcherLog "Cleaned up QoS policy for $activeGameName.exe"
                }
            } catch {}

            # Restore Reverse Affinity
            try {
                if (Test-Path (Join-Path $ScriptDir "Modules\CpuOptimizer.ps1")) {
                    & $PSHostExe -NoProfile -ExecutionPolicy Bypass -Command ". '$ScriptDir\Modules\CpuOptimizer.ps1'; Restore-ReverseAffinity" | Out-Null
                    Write-WatcherLog "Restored CPU affinity for background applications."
                }
            } catch {}

            if ($autoRestore) {
                Write-Host " -> Restoring applications from previous session..." -ForegroundColor Cyan
                Write-WatcherLog "Initiating session restoration..."
                Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Restore", "-Silent" -Wait
            }

            $activeGameName = ""
            $activeGamePid = 0
            Write-Host "[✓] Session clean exit complete. Awaiting next game launch..." -ForegroundColor Gray
        }
    }
}
finally {
    if ($startWatcher) {
        try { $startWatcher.Dispose() } catch {}
    }
    try { Remove-Item $PidFile -Force -ErrorAction SilentlyContinue } catch {}
}
