# ============================================================================
# Game Mode Booster - Unified System Tray Companion & Auto-Watcher
# Features:
#  - Global Hotkey (Ctrl+F11) to toggle/refocus Hardware HUD
#  - Zero-Click Background Auto-Watcher (Auto-Boost + Companion Auto-Launch)
#  - Windows System Tray Icon with instant controls
# ============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
Set-Location -Path $RootDir

# Determine PowerShell Host Executable
$PSHostExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }

$ConfigFile = Join-Path $RootDir "config.json"
$LogFile = Join-Path $RootDir "gamebooster.log"
$PidFile = Join-Path $RootDir "tray.pid"

function Write-TrayLog($msg, $level = "INFO") {
    $line = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [TRAY-$level] $msg"
    try { Add-Content -Path $LogFile -Value $line -Force -ErrorAction SilentlyContinue } catch {}
}

# Write PID file so GUI knows background watcher is active
try {
    $PID | Out-File -FilePath $PidFile -Encoding ascii -Force
} catch {}

# Hotkey Win32 API
$refAssemblies = @(
    ([System.Windows.Forms.NativeWindow].Assembly.Location),
    ([System.Windows.Forms.Message].Assembly.Location)
) | Select-Object -Unique

Add-Type -ReferencedAssemblies $refAssemblies @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class HotKeyHandler : NativeWindow {
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public event Action HotKeyPressed;
    private const int WM_HOTKEY = 0x0312;

    public HotKeyHandler() {
        CreateHandle(new CreateParams());
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            if (HotKeyPressed != null) {
                HotKeyPressed();
            }
        }
        base.WndProc(ref m);
    }
}
"@ -ErrorAction SilentlyContinue

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32WindowHelper {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpfn, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}
"@ -ErrorAction SilentlyContinue

function Focus-Or-OpenGui {
    $script:foundHwnd = [IntPtr]::Zero
    $guiProcs = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%GameBooster.ps1%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "-Gui" -and $_.ProcessId -ne $PID }

    if ($guiProcs) {
        $pids = @($guiProcs | ForEach-Object { $_.ProcessId })
        [Win32WindowHelper]::EnumWindows({
            param($hWnd, $lParam)
            $pOut = 0
            [Win32WindowHelper]::GetWindowThreadProcessId($hWnd, [ref]$pOut) | Out-Null
            if ($pids -contains $pOut) {
                $script:foundHwnd = $hWnd
                return $false
            }
            return $true
        }, [IntPtr]::Zero) | Out-Null
    }

    if ($script:foundHwnd -ne [IntPtr]::Zero) {
        [Win32WindowHelper]::ShowWindow($script:foundHwnd, 9) | Out-Null # 9 = SW_RESTORE
        [Win32WindowHelper]::SetForegroundWindow($script:foundHwnd) | Out-Null
        Write-TrayLog "Refocused existing Game Booster window (HWND: $($script:foundHwnd))."
    } else {
        $exeLauncher = Join-Path $RootDir "GameBooster.exe"
        if (Test-Path $exeLauncher) {
            Start-Process $exeLauncher
        } else {
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Gui"
        }
        Write-TrayLog "Launched new Game Booster GUI instance."
    }
}

$hotkey = New-Object HotKeyHandler
# MOD_CONTROL = 0x0002. VK_F11 = 0x7A. Hotkey ID = 1001
[HotKeyHandler]::RegisterHotKey($hotkey.Handle, 1001, 0x0002, 0x7A) | Out-Null

$hotkey.add_HotKeyPressed({
    # Toggle/Launch HUD on Ctrl+F11
    $hudPs = Join-Path $ScriptDir "Launch_Gaming_HUD.ps1"
    if (Test-Path $hudPs) {
        Write-TrayLog "Ctrl+F11 pressed: Toggling Hardware Telemetry HUD."
        $notifyIcon.ShowBalloonTip(1500, "Hardware HUD (Ctrl+F11)", "Toggling Gaming Telemetry HUD...", [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$hudPs`""
    }
})

# Setup NotifyIcon with custom gaming icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Text = "Game Mode Booster & Auto-Watcher (Ctrl+F11)"

$icoCandidate = @(
    (Join-Path $RootDir "assets\gamebooster.ico"),
    (Join-Path $RootDir "gamebooster.ico"),
    (Join-Path $ScriptDir "gamebooster.ico")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($icoCandidate) {
    try {
        $notifyIcon.Icon = New-Object System.Drawing.Icon $icoCandidate
    } catch {
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    }
} else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
}
$notifyIcon.Visible = $true

# Double-click tray icon to restore full dashboard
$notifyIcon.add_DoubleClick({
    Focus-Or-OpenGui
})

$cfgInit = $null
if (Test-Path $ConfigFile) {
    try { $cfgInit = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json } catch {}
}
$script:autoWatcherEnabled = if ($cfgInit -and $cfgInit.watcherSettings -and $null -ne $cfgInit.watcherSettings.enabled) { [bool]$cfgInit.watcherSettings.enabled } else { $false }

# Context Menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$itemHeader = $contextMenu.Items.Add("Game Mode Booster Suite")
$itemHeader.Enabled = $false
$itemHeader.Font = New-Object System.Drawing.Font($itemHeader.Font, [System.Drawing.FontStyle]::Bold)

$contextMenu.Items.Add("-") | Out-Null

# Auto-Watcher Toggle in Tray
$watcherLabel = if ($script:autoWatcherEnabled) { "Auto-Watcher: ACTIVE (Auto-Boost)" } else { "Auto-Watcher: PAUSED (Click to Enable)" }
$itemToggleWatcher = $contextMenu.Items.Add($watcherLabel)
$itemToggleWatcher.Checked = $script:autoWatcherEnabled
$itemToggleWatcher.add_Click({
    $script:autoWatcherEnabled = -not $script:autoWatcherEnabled
    $itemToggleWatcher.Checked = $script:autoWatcherEnabled
    if ($script:autoWatcherEnabled) {
        $itemToggleWatcher.Text = "Auto-Watcher: ACTIVE (Auto-Boost)"
        $notifyIcon.ShowBalloonTip(2000, "Auto-Watcher Enabled", "Will auto-boost when a monitored game launches.", [System.Windows.Forms.ToolTipIcon]::Info)
        Write-TrayLog "Auto-watcher enabled via tray menu."
    } else {
        $itemToggleWatcher.Text = "Auto-Watcher: PAUSED"
        $notifyIcon.ShowBalloonTip(2000, "Auto-Watcher Paused", "Automatic game detection suspended.", [System.Windows.Forms.ToolTipIcon]::Warning)
        Write-TrayLog "Auto-watcher paused via tray menu."
    }
})

$contextMenu.Items.Add("-") | Out-Null

$itemBoost = $contextMenu.Items.Add("Activate Game Mode Now (Close Bloat)")
$itemBoost.add_Click({
    Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Boost", "-Silent" -Wait
    $notifyIcon.ShowBalloonTip(3000, "Game Mode Activated", "Background bloat closed, RAM purged, Ultimate Power Plan set.", [System.Windows.Forms.ToolTipIcon]::Info)
})

$itemRestore = $contextMenu.Items.Add("Restore Closed Apps Now")
$itemRestore.add_Click({
    Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Restore", "-Silent" -Wait
    $notifyIcon.ShowBalloonTip(3000, "Apps Restored", "All previously closed apps have been relaunched.", [System.Windows.Forms.ToolTipIcon]::Info)
})

$contextMenu.Items.Add("-") | Out-Null

$itemHud = $contextMenu.Items.Add("Hardware Gaming HUD (Ctrl+F11)")
$itemHud.add_Click({
    Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\Launch_Gaming_HUD.ps1`""
})

$itemGui = $contextMenu.Items.Add("Open Full GUI Dashboard")
$itemGui.add_Click({
    Focus-Or-OpenGui
})

$contextMenu.Items.Add("-") | Out-Null

$itemCrash = $contextMenu.Items.Add("Diagnose Last Crash")
$itemCrash.add_Click({
    Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$ScriptDir\Diagnose_Crash.ps1`""
})

$itemHealth = $contextMenu.Items.Add("Check Gaming Readiness")
$itemHealth.add_Click({
    Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$ScriptDir\Check-GamingReadiness.ps1`""
})

$itemLogs = $contextMenu.Items.Add("View Logs")
$itemLogs.add_Click({
    if (Test-Path $LogFile) { Start-Process "notepad.exe" -ArgumentList "`"$LogFile`"" }
})

$contextMenu.Items.Add("-") | Out-Null

$itemExit = $contextMenu.Items.Add("Exit Tray Companion")
$itemExit.add_Click({
    [HotKeyHandler]::UnregisterHotKey($hotkey.Handle, 1001) | Out-Null
    Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$notifyIcon.ContextMenuStrip = $contextMenu

# ============================================================================
# INTEGRATED BACKGROUND AUTO-WATCHER TIMER (Checks every 3 seconds)
# ============================================================================
$watcherTimer = New-Object System.Windows.Forms.Timer
$watcherTimer.Interval = 3000
$watcherTimer.Add_Tick({
    if (-not $script:autoWatcherEnabled) { return }

    # Load dynamic trigger games and companion config
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

    $systemUtilities = @("explorer", "taskmgr", "pwsh", "powershell", "WindowsTerminal", "WidgetService", "PhoneExperienceHost", "conhost", "cmd", "GameBooster")
    $triggerNames = @($triggerNames | Where-Object { $systemUtilities -notcontains $_ })

    $gameProc = Get-Process -Name $triggerNames -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($gameProc -and -not $script:isGaming) {
        $script:isGaming = $true
        Write-TrayLog "Detected game launch: $($gameProc.ProcessName) (PID: $($gameProc.Id))"
        $notifyIcon.ShowBalloonTip(3000, "Game Detected ($($gameProc.ProcessName))", "Optimizing PC for gaming and docking Telemetry HUD...", [System.Windows.Forms.ToolTipIcon]::Info)

        # 1. Boost System
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
                        Write-TrayLog "Auto-starting global companion: $($app.name)"
                        try {
                            if ($app.path -match '(?i)Discord') {
                                Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"
                            } elseif ($app.path -and (Test-Path $app.path)) {
                                Start-Process $app.path
                            } else {
                                Start-Process $pName -ErrorAction SilentlyContinue
                            }
                        } catch {
                            Write-TrayLog "Failed to launch global companion $($app.name): $_" "WARN"
                        }
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
                            Write-TrayLog "Auto-starting per-game companion: $prog"
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
                                Write-TrayLog "Failed to launch per-game companion '$prog': $_" "WARN"
                            }
                        }
                    }
                }
            }
        } catch {
            Write-TrayLog "Error reading per-game companion: $_" "WARN"
        }

        # 3. Launch or Refocus Hardware HUD
        Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\Launch_Gaming_HUD.ps1`""

        $notifyIcon.ShowBalloonTip(3000, "Game Mode Active", "PC optimized! Standby RAM purged and HUD docked on secondary screen.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
    elseif (-not $gameProc -and $script:isGaming) {
        $script:isGaming = $false
        Write-TrayLog "Game session ended."

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
            Write-TrayLog "Initiating session restore..."
            $notifyIcon.ShowBalloonTip(3000, "Game Session Ended", "Restoring previous session applications...", [System.Windows.Forms.ToolTipIcon]::Info)
            Start-Process -FilePath $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptDir\GameBooster.ps1`"", "-Restore", "-Silent" -Wait
        } else {
            Write-TrayLog "Auto-restore disabled in settings. Closed apps remain closed."
            $notifyIcon.ShowBalloonTip(3000, "Game Session Ended", "Closed apps kept closed as configured.", [System.Windows.Forms.ToolTipIcon]::Info)
        }
    }
})

$watcherTimer.Start()

# Startup notification
$notifyIcon.ShowBalloonTip(3000, "Game Booster Companion Active", "Running in system tray. Auto-watcher active for configured games. Press Ctrl+F11 for HUD.", [System.Windows.Forms.ToolTipIcon]::Info)

# Run message loop
try {
    [System.Windows.Forms.Application]::Run()
} finally {
    Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
}

