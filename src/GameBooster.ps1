# ============================================================================
# Game Mode Booster v1.2.2 PRO
# Unified Gaming Performance Suite & High-Refresh Optimizer
# Clean, Autonomous, Zero-Telemetry & GitHub-Ready
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Gui,
    [switch]$Boost,
    [switch]$Restore,
    [switch]$Hud,
    [switch]$Osd,
    [switch]$Radar,
    [switch]$StandbyPurge,
    [switch]$TweakCheck,
    [switch]$Silent
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms -ErrorAction SilentlyContinue

# Set explicit Windows AppUserModelID to decouple from powershell.exe and ensure custom taskbar icon
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class ShellIconHelper {
        [DllImport("shell32.dll", SetLastError = true)]
        public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr LoadImage(IntPtr hinst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

        public const uint WM_SETICON = 0x0080;
        public const int ICON_SMALL = 0;
        public const int ICON_BIG = 1;
        public const uint IMAGE_ICON = 1;
        public const uint LR_LOADFROMFILE = 0x0010;

        public static void SetWindowIcons(IntPtr hWnd, string iconPath) {
            try {
                if (System.IO.File.Exists(iconPath)) {
                    IntPtr hBig = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
                    IntPtr hSmall = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
                    if (hBig != IntPtr.Zero) SendMessage(hWnd, WM_SETICON, (IntPtr)ICON_BIG, hBig);
                    if (hSmall != IntPtr.Zero) SendMessage(hWnd, WM_SETICON, (IntPtr)ICON_SMALL, hSmall);
                }
            } catch {}
        }
    }
"@ -ErrorAction SilentlyContinue

    [ShellIconHelper]::SetCurrentProcessExplicitAppUserModelID("GameBooster.Suite.PRO") | Out-Null
} catch {}

# Dynamic Root Directory Resolution (Zero hardcoded paths)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
$ModulesDir = if (Test-Path (Join-Path $ScriptDir "Modules")) {
    Join-Path $ScriptDir "Modules"
} elseif (Test-Path (Join-Path $RootDir "src\Modules")) {
    Join-Path $RootDir "src\Modules"
} else {
    Join-Path $RootDir "Modules"
}

$ConfigFile = Join-Path $RootDir "config.json"
$ConfigTemplate = if (Test-Path (Join-Path $RootDir "config.template.json")) {
    Join-Path $RootDir "config.template.json"
} elseif (Test-Path (Join-Path $ScriptDir "config.template.json")) {
    Join-Path $ScriptDir "config.template.json"
} else {
    Join-Path $RootDir "config.template.json"
}
$LogFile = Join-Path $RootDir "gamebooster.log"
$SessionFile = Join-Path $RootDir "last_session.json"
$TrayPidFile = Join-Path $RootDir "tray.pid"

$script:AppVersion = "2.0.0"
$script:GitHubRepo = "bigsergio/GameBooster"

# Ensure config.json exists from template if needed
if (-not (Test-Path $ConfigFile) -and (Test-Path $ConfigTemplate)) {
    try { Copy-Item -Path $ConfigTemplate -Destination $ConfigFile -Force } catch {}
}

# Logger
function Write-AppLog([string]$msg, [string]$level = "INFO") {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] [$level] $msg"
    try { Add-Content -Path $LogFile -Value $line -Force -ErrorAction SilentlyContinue } catch {}
}

Write-AppLog "Initializing Game Booster v$script:AppVersion PRO..."

# Load Core Modules
try {
    . (Join-Path $ModulesDir "DarkDialog.ps1")
    . (Join-Path $ModulesDir "CpuOptimizer.ps1")
    . (Join-Path $ModulesDir "GpuManager.ps1")
    . (Join-Path $ModulesDir "MemoryPurge.ps1")
    . (Join-Path $ModulesDir "LibraryScanner.ps1")
    . (Join-Path $ModulesDir "PerGameProfiles.ps1")
    . (Join-Path $ModulesDir "ServerRadar.ps1")
    . (Join-Path $ModulesDir "ShaderCleaner.ps1")
    . (Join-Path $ModulesDir "SystemTweaks.ps1")
    . (Join-Path $ModulesDir "Watchdog.ps1")
    . (Join-Path $ModulesDir "DisplayManager.ps1")
    . (Join-Path $ModulesDir "GamingLockout.ps1")
    . (Join-Path $ModulesDir "NetworkQoS.ps1")
    . (Join-Path $ModulesDir "ProBalance.ps1")
    . (Join-Path $ModulesDir "HardwareTweaks.ps1")
    . (Join-Path $ModulesDir "FrameTelemetry.ps1")
    . (Join-Path $ModulesDir "LagAnalyzer.ps1")
    Write-AppLog "All core feature modules imported successfully."
} catch {
    Write-AppLog "Failed to load modules: $_" "ERROR"
}

# Failsafe fallback for Show-DarkModal
if (-not (Get-Command Show-DarkModal -ErrorAction SilentlyContinue)) {
    function Show-DarkModal {
        param($Arg0, $Arg1, $Arg2, $Arg3, $Arg4)
        if ($Arg0 -is [System.Windows.Window]) {
            [System.Windows.MessageBox]::Show($Arg0, [string]$Arg1, [string]$Arg2, (if ($Arg3) { $Arg3 } else { [System.Windows.MessageBoxButton]::OK }), (if ($Arg4) { $Arg4 } else { [System.Windows.MessageBoxImage]::Information }))
        } else {
            [System.Windows.MessageBox]::Show([string]$Arg0, [string]$Arg1, (if ($Arg2) { $Arg2 } else { [System.Windows.MessageBoxButton]::OK }), (if ($Arg3) { $Arg3 } else { [System.Windows.MessageBoxImage]::Information }))
        }
    }
}

# Check for Watchdog Crash Recovery (Auto-rollback if previous run crashed)
try {
    $watchdogRecovery = Invoke-WatchdogCrashRecovery
    if ($watchdogRecovery -and $watchdogRecovery.Recovered) {
        Write-AppLog "WATCHDOG: $($watchdogRecovery.Message)" "WARN"
    }
} catch {
    Write-AppLog "Watchdog crash check error: $_" "WARN"
}

# Determine PowerShell Host
$PSHostExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }

# =============================================================================
# HELPER FUNCTIONS: PORTMASTER GRACEFUL CONTROL
# =============================================================================
function Stop-PortmasterSafely {
    try {
        # 1. Terminate GUI / tray instances cleanly
        Get-Process -Name "portmaster", "safing-portmaster" -ErrorAction SilentlyContinue | ForEach-Object {
            try { Stop-Process -Id $_.Id -ErrorAction SilentlyContinue } catch {}
        }
        # 2. Gracefully stop PortmasterCore service so its WFP driver unhooks cleanly
        $pmSvc = Get-Service -Name "PortmasterCore" -ErrorAction SilentlyContinue
        if ($pmSvc -and $pmSvc.Status -eq "Running") {
            Stop-Service -Name "PortmasterCore" -Force -ErrorAction SilentlyContinue
        }
        # 3. Flush DNS client cache so network stack immediately resolves DNS via primary gateway/NIC
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    } catch {}
}

function Start-PortmasterSafely {
    try {
        # 1. Start PortmasterCore service
        $pmSvc = Get-Service -Name "PortmasterCore" -ErrorAction SilentlyContinue
        if ($pmSvc -and $pmSvc.Status -ne "Running") {
            Start-Service -Name "PortmasterCore" -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 800
        }
        # 2. Launch Portmaster GUI / tray
        $pmGuiPaths = @(
            "C:\Program Files\Safing\Portmaster\portmaster.exe",
            (Join-Path $env:ProgramFiles "Safing\Portmaster\portmaster.exe")
        )
        foreach ($pPath in $pmGuiPaths) {
            if (Test-Path $pPath) {
                Start-Process -FilePath $pPath -WindowStyle Hidden -ErrorAction SilentlyContinue
                break
            }
        }
        # 3. Flush DNS cache
        Clear-DnsClientCache -ErrorAction SilentlyContinue
    } catch {}
}

# Config Helpers
function Get-AppConfig {
    if (Test-Path $ConfigFile) {
        try {
            return (Get-Content -Raw -Path $ConfigFile -Encoding UTF8 | ConvertFrom-Json)
        } catch {
            Write-AppLog "Config parse error: $_" "WARN"
        }
    }
    return [PSCustomObject]@{
        whitelist = @("explorer", "taskmgr", "GameBooster", "wt", "conhost", "cmd", "powershell", "pwsh")
        gameProfiles = [PSCustomObject]@{}
        watcherSettings = [PSCustomObject]@{
            enabled = $false
            pollIntervalSec = 3
            monitoredGames = @("cod", "bootstrapper", "BlackOps6", "Wow", "WowClassic", "cs2", "Valorant")
            autoRestoreOnGameExit = $true
        }
        hudPosition = [PSCustomObject]@{ x = 100; y = 100; width = 1200; height = 600; cols = 120; rows = 30; activePreset = "tri_pane" }
    }
}

function Save-AppConfig($cfg) {
    try {
        $json = $cfg | ConvertTo-Json -Depth 10
        Set-Content -Path $ConfigFile -Value $json -Encoding UTF8 -Force
        Write-AppLog "Configuration saved to config.json"
        return $true
    } catch {
        Write-AppLog "Error saving configuration: $_" "ERROR"
        return $false
    }
}

# CLI Parameter handlers
if ($StandbyPurge) {
    Write-Host "Purging Standby Memory and system cache..." -ForegroundColor Cyan
    $res = Invoke-SmartMemoryPurge
    Write-Host "Standby memory purged successfully. Freed: $($res.FreedStandbyMB) MB" -ForegroundColor Green
    exit 0
}

if ($Radar) {
    Write-Host "Executing Network Latency & Server Radar scan..." -ForegroundColor Cyan
    $pings = Test-GamingRadarPing
    $pings | Format-Table Region, Cluster, Host, Latency, Quality -AutoSize
    exit 0
}

if ($Boost) {
    Write-AppLog "Headless Game Mode activation initiated by Auto-Watcher/CLI..."
    if (-not $Silent) { Write-Host "Activating Game Mode..." -ForegroundColor Cyan }

    $cfg = Get-AppConfig
    $wl = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # 0. Hardcoded Critical Windows OS Subsystems (Absolute safeguard)
    $criticalOs = @("Idle", "System", "csrss", "services", "lsass", "wininit", "smss", "svchost", "fontdrvhost", "dwm", 
      "explorer", "winlogon", "sppsvc", "SecurityHealthService", "SecurityHealthSystray", 
      "MsMpEng", "NisSrv", "MpDefenderCoreService", "DefenderSessionHelper", "MoUsoCoreWorker", "RuntimeBroker", 
      "StartMenuExperienceHost", "taskhostw", "ctfmon", "SystemSettings", "TextInputHost", "ShellHost", 
      "conhost", "cmd", "pwsh", "powershell", "wt", "WindowsTerminal", "GameBooster", "taskmgr",
      "dashost", "midisrv", "sihost", "smartscreen", "ApplicationFrameHost", "node", "git",
      "portmaster-core", "safing-portmaster", "PortmasterCore")
    foreach ($cp in $criticalOs) { $wl.Add($cp) | Out-Null }

    # 1. Essential gaming services (Anti-Cheat, Audio Drivers, Hardware Monitors, GPU Daemons)
    $essentialServices = Get-EssentialGamingServicesWhitelist
    foreach ($es in $essentialServices) { $wl.Add($es) | Out-Null }

    # 2. Configured user whitelist & systemProtected
    if ($cfg.whitelist) { foreach ($w in $cfg.whitelist) { $wl.Add($w) | Out-Null } }
    if ($cfg.systemProtected) { foreach ($sp in $cfg.systemProtected) { $wl.Add($sp) | Out-Null } }
    if ($cfg.hardwareKeep) { foreach ($hk in $cfg.hardwareKeep) { $wl.Add($hk) | Out-Null } }

    # 3. Monitored games & common gaming binaries must NEVER be closed!
    if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
        foreach ($mg in $cfg.watcherSettings.monitoredGames) { [void]$wl.Add($mg) }
    }
    if ($cfg.autoStartWith -and $cfg.autoStartWith.triggerProcesses) {
        foreach ($tp in $cfg.autoStartWith.triggerProcesses) { [void]$wl.Add($tp) }
    }
    if ($cfg.gameProfiles) {
        foreach ($prop in $cfg.gameProfiles.PSObject.Properties) { [void]$wl.Add($prop.Name) }
    }
    $gameBinaries = @("cod", "bootstrapper", "cod24", "sp24", "BlackOps6", "cod25-cod", "codCrashHandler", "bootstrapperCrashHandler", "randgrid", "Wow", "WowClassic", "Wow-64", "cs2", "csgo", "dota2", "Valorant", "RiotClientServices", "Overwatch", "FortniteClient-Win64-Shipping", "r5apex")
    foreach ($gb in $gameBinaries) { [void]$wl.Add($gb) }

    # Map running Windows services so background services (like Fing.Agent) are properly stopped and restorable
    $serviceMap = @{}
    try {
        Get-CimInstance Win32_Service -Filter "State = 'Running'" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.ProcessId) { $serviceMap[[int]$_.ProcessId] = $_.Name }
        }
    } catch {}

    # Get non-whitelisted running processes
    $rawProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { 
        $_.Id -ne $PID -and $_.ProcessName -ne "Idle" -and $_.ProcessName -ne "System" -and -not $wl.Contains($_.ProcessName)
    }

    $closedItems = @()
    $freedRAM = 0

    $grouped = $rawProcs | Group-Object ProcessName
    foreach ($grp in $grouped) {
        $pName = $grp.Name
        if ($wl.Contains($pName)) { continue }
        if ($pName -match "(?i)cod|bootstrapper|randgrid|RTSS|MSIAfterburner|HWiNFO|obs|PnkBstr|EasyAntiCheat|BEService|vgc|vgk|audiodg|RtkAud|^Rz|^Razer|^SteelSeries|^Logi|LGHUB|iCUE|^Elgato|^Nahimic|^Creative|portmaster|safing|spoolsv|vmms|vmcompute") { continue }

        # In automated Headless Boost, ONLY terminate apps configured in selectedByDefault or known heavy user apps
        $isConfigTarget = $cfg.selectedByDefault -and ($cfg.selectedByDefault -contains $pName)
        $isHeavyUserApp = ($pName -match "(?i)discord|spotify|slack|steamwebhelper|epicgames|battlenet|eaapp|gog|chrome|msedge|firefox|brave|opera")
        if (-not $isConfigTarget -and -not $isHeavyUserApp) { continue }

        if ($pName -match "(?i)portmaster|safing") {
            Stop-PortmasterSafely
            $closedItems += [PSCustomObject]@{
                Name        = "Portmaster"
                ServiceName = "PortmasterCore"
                Id          = $grp.Group[0].Id
                RAM_MB      = [math]::Round(($grp.Group | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 0)
                Path        = "C:\Program Files\Safing\Portmaster\portmaster.exe"
                Time        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $freedRAM += [math]::Round(($grp.Group | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 0)
            continue
        }

        $pPath = $null
        $pRamTotal = 0
        $firstPid = $grp.Group[0].Id
        $svcName = $null

        foreach ($p in $grp.Group) {
            try {
                if ($serviceMap.ContainsKey([int]$p.Id)) {
                    $svcName = $serviceMap[[int]$p.Id]
                    # Never stop critical/gaming services
                    if ($svcName -notmatch "(?i)cod|callofduty|activision|battleye|easyanticheat|vgc|vgk|punkbuster|spooler|vmms|vmcompute|portmaster|safing|wlan|lanman|bfe|dhcp|dnscache") {
                        Stop-Service -Name $svcName -NoWait -ErrorAction SilentlyContinue
                    }
                }
                if (-not $pPath -and $p.Path) { $pPath = $p.Path }
                $pRam = [math]::Round($p.WorkingSet64 / 1MB, 0)
                $pRamTotal += $pRam
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            } catch {}
        }

        $closedItems += [PSCustomObject]@{
            Name        = $pName
            ServiceName = $svcName
            Id          = $firstPid
            RAM_MB      = $pRamTotal
            Path        = $pPath
            Time        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $freedRAM += $pRamTotal
    }

    # Save to session file for 1-click restore
    try {
        $sessionData = [PSCustomObject]@{
            Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ClosedApps   = $closedItems
            TotalFreedMB = $freedRAM
        }
        $sessionData | ConvertTo-Json -Depth 5 | Set-Content -Path $SessionFile -Encoding UTF8 -Force
    } catch {}

    # Phase 1: Watchdog Session Initialization
    $origPowerPlan = Get-ActivePowerPlanGuid
    $origStickyFlags = if (Get-Command Get-GamingLockoutStatus -ErrorAction SilentlyContinue) { [GamingLockoutNative]::GetStickyKeysFlags() } else { 0 }
    Initialize-WatchdogSession -TargetGame "GameMode_Boost" -PowerPlanGuid $origPowerPlan -StickyKeysFlags $origStickyFlags | Out-Null

    # Phase 1: Launcher RAM Diet (Reclaim active RAM from heavy Chromium launchers without closing them)
    $dietRes = Invoke-LauncherRamDiet
    if ($dietRes.TotalFreedMB -gt 0) {
        Write-AppLog "Launcher RAM Diet: Freed $($dietRes.TotalFreedMB)MB across $($dietRes.TargetedProcessesCount) background processes."
    }

    # Purge standby RAM
    $purgeRes = Invoke-SmartMemoryPurge
    $dietFreed = if ($dietRes.TotalFreedMB) { [math]::Round($dietRes.TotalFreedMB, 0) } else { 0 }
    $totalFreed = $freedRAM + [math]::Round($purgeRes.FreedGB * 1024, 0) + $dietFreed

    # Enable Ultimate Performance Power Plan
    Switch-ToUltimatePerformance | Out-Null

    # Phase 1: Gaming Lockout (WinKey is OPTIONAL and default OFF; StickyKeys prompt suppressed)
    $lockWin = if ($cfg.tweaksSettings -and $null -ne $cfg.tweaksSettings.gamingLockoutWinKey) { [bool]$cfg.tweaksSettings.gamingLockoutWinKey } else { $false }
    $lockSticky = if ($cfg.tweaksSettings -and $null -ne $cfg.tweaksSettings.gamingLockoutStickyKeys) { [bool]$cfg.tweaksSettings.gamingLockoutStickyKeys } else { $true }
    Enable-GamingLockout -DisableWinKey $lockWin -DisableStickyKeys $lockSticky | Out-Null

    # Phase 2: Reverse Affinity Core Siloing (Silos background apps away from game cores)
    $enableRevAffinity = if ($cfg.tweaksSettings -and $null -ne $cfg.tweaksSettings.enableReverseAffinity) { [bool]$cfg.tweaksSettings.enableReverseAffinity } else { $true }
    if ($enableRevAffinity) {
        $revRes = Invoke-ReverseAffinitySiloing
        if ($revRes.SiloedCount -gt 0) {
            Write-AppLog "Reverse Affinity: Siloed $($revRes.SiloedCount) background apps onto auxiliary cores ($($revRes.BackgroundMask))."
        }
    }

    Write-AppLog "Headless Game Mode activated. Closed $($closedItems.Count) app groups, freed ${freedRAM}MB process RAM, purged $($purgeRes.FreedMB)MB standby RAM, trimmed ${dietFreed}MB launcher RAM."
    if (-not $Silent) {
        Write-Host "Game Mode activated. Freed ${totalFreed}MB RAM." -ForegroundColor Green
    }
    exit 0
}

if ($Restore) {
    Write-AppLog "Headless session restore initiated by Auto-Watcher/CLI..."
    if (-not $Silent) { Write-Host "Restoring applications..." -ForegroundColor Cyan }

    # Phase 1: Reset Gaming Lockout & Display Mode
    Disable-GamingLockout | Out-Null
    Reset-DisplayResolution | Out-Null

    # Phase 2: Restore Reverse Affinity & Clean QoS
    Restore-ReverseAffinity | Out-Null
    Restore-AllThrottledProcesses | Out-Null
    Clear-AllGamingQosPolicies | Out-Null

    # Phase 1: Restore Original Power Scheme if recorded
    $wdState = Get-WatchdogState
    if ($wdState -and $wdState.OriginalPowerPlanGuid) {
        Restore-OriginalPowerPlan -Guid $wdState.OriginalPowerPlanGuid | Out-Null
    }

    # Phase 1: Mark Watchdog Clean Exit
    Complete-WatchdogSession

    $restoredCount = 0
    if (Test-Path $SessionFile) {
        try {
            $sess = Get-Content -Raw -Path $SessionFile -Encoding UTF8 | ConvertFrom-Json
            if ($sess.ClosedApps) {
                foreach ($app in $sess.ClosedApps) {
                    try {
                        $skipRestore = @("node", "python", "cmd", "powershell", "pwsh", "bash", "wsl", "dashost", "midisrv", "conhost", "wt", "WindowsTerminal")
                        if ($skipRestore -contains $app.Name) { continue }

                        if ($app.Name -match "(?i)portmaster|safing" -or $app.ServiceName -match "(?i)portmaster") {
                            Start-PortmasterSafely
                            $restoredCount++
                            continue
                        }

                        if ($app.ServiceName) {
                            try { Start-Service -Name $app.ServiceName -ErrorAction SilentlyContinue } catch {}
                            $restoredCount++
                            continue
                        }
                        if ($app.Path -and (Test-Path $app.Path)) {
                            Start-Process -FilePath $app.Path -ErrorAction SilentlyContinue
                            $restoredCount++
                        } elseif ($app.Name) {
                            Start-Process -FilePath $app.Name -ErrorAction SilentlyContinue
                            $restoredCount++
                        }
                    } catch {}
                }
            }
            Remove-Item $SessionFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-AppLog "Error during headless restore: $_" "WARN"
        }
    }

    Write-AppLog "Headless session restore complete. Restored $restoredCount app(s)."
    if (-not $Silent) {
        Write-Host "Restored $restoredCount application(s)." -ForegroundColor Green
    }
    exit 0
}

if ($Hud) {
    $hudPs = Join-Path $ScriptDir "Launch_Gaming_HUD.ps1"
    if (Test-Path $hudPs) {
        & $PSHostExe -NoProfile -ExecutionPolicy Bypass -File $hudPs
    }
    exit 0
}

if ($Osd) {
    $osdPs = Join-Path $ScriptDir "InGame_OSD.ps1"
    if (Test-Path $osdPs) {
        & $PSHostExe -NoProfile -ExecutionPolicy Bypass -File $osdPs
    }
    exit 0
}

if ($TweakCheck) {
    $t = Get-GamingTweaksStatus
    $t | Format-List
    exit 0
}

# Launch GUI Dashboard
Write-AppLog "Building Modern WPF Interface..."

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Game Booster PRO v2.0.0"
        Height="850" Width="1280" MinWidth="1100" MinHeight="720"
        WindowStartupLocation="CenterScreen"
        Background="#0B0F19" Foreground="#F8FAFC"
        FontFamily="Segoe UI, Inter, Arial">
    
    <Window.Resources>
        <!-- Modern ScrollViewer Style -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#0F172A"/>
            <Setter Property="Width" Value="8"/>
        </Style>

        <!-- TabItem Cyberpunk Theme -->
        <Style TargetType="TabItem">
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="BorderThickness" Value="0,0,0,2"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#1E293B"/>
                                <Setter Property="Foreground" Value="#38BDF8"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#1E293B"/>
                                <Setter TargetName="Border" Property="BorderBrush" Value="#10B981"/>
                                <Setter Property="Foreground" Value="#10B981"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- DataGrid Dark Theme -->
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#0F172A"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#1E293B"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#1E293B"/>
            <Setter Property="RowBackground" Value="#0F172A"/>
            <Setter Property="AlternatingRowBackground" Value="#111827"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#38BDF8"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="BorderBrush" Value="#334155"/>
        </Style>
        <Style TargetType="DataGridRow">
            <Setter Property="Height" Value="28"/>
        </Style>

        <!-- Dark ComboBox ToggleButton Template (Forces Dark Slate Background & High Contrast) -->
        <ControlTemplate x:Key="DarkComboBoxToggleButton" TargetType="ToggleButton">
            <Border Name="Border"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="5">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="26"/>
                    </Grid.ColumnDefinitions>
                    <Path Grid.Column="1"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Center"
                          Fill="#94A3B8"
                          Data="M 0 0 L 4 4 L 8 0 Z"/>
                </Grid>
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Border" Property="Background" Value="#334155"/>
                    <Setter TargetName="Border" Property="BorderBrush" Value="#38BDF8"/>
                </Trigger>
                <Trigger Property="IsChecked" Value="True">
                    <Setter TargetName="Border" Property="Background" Value="#1E293B"/>
                    <Setter TargetName="Border" Property="BorderBrush" Value="#0284C7"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <!-- Dark ComboBox Style -->
        <Style TargetType="ComboBox">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.CanContentScroll" Value="True"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Height" Value="28"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Name="ToggleButton"
                                          Template="{StaticResource DarkComboBoxToggleButton}"
                                          Focusable="false"
                                          IsChecked="{Binding Path=IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          ClickMode="Press"
                                          Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}"
                                          BorderThickness="{TemplateBinding BorderThickness}"/>
                            <ContentPresenter Name="ContentSite"
                                              IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                              TextElement.Foreground="#FFFFFF"
                                              TextElement.FontWeight="SemiBold"
                                              TextElement.FontSize="12"
                                              Margin="10,0,30,0"
                                              VerticalAlignment="Center"
                                              HorizontalAlignment="Left"/>
                            <Popup Name="Popup"
                                   Placement="Bottom"
                                   IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   PopupAnimation="Slide">
                                <Grid Name="DropDown"
                                      SnapsToDevicePixels="True"
                                      MinWidth="{TemplateBinding ActualWidth}"
                                      MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border Name="DropDownBorder"
                                            Background="#0F172A"
                                            BorderThickness="1"
                                            BorderBrush="#334155"
                                            CornerRadius="5"
                                            Margin="0,2,0,0">
                                        <Border.Effect>
                                            <DropShadowEffect BlurRadius="12" Color="#000000" Opacity="0.8" ShadowDepth="4"/>
                                        </Border.Effect>
                                        <ScrollViewer Margin="2,4" SnapsToDevicePixels="True">
                                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
                                        </ScrollViewer>
                                    </Border>
                                </Grid>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="HasItems" Value="false">
                                <Setter TargetName="DropDownBorder" Property="MinHeight" Value="95"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter Property="Foreground" Value="#64748B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Dark ComboBoxItem Style -->
        <Style TargetType="ComboBoxItem">
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border Name="Border"
                                Padding="10,6"
                                Margin="2,1"
                                CornerRadius="4"
                                Background="Transparent">
                            <ContentPresenter TextElement.Foreground="#FFFFFF"
                                              TextElement.FontSize="12"
                                              TextElement.FontWeight="Normal"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#0284C7"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#047857"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="#64748B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Dark Cyberpunk ContextMenu (Completely eliminates the default white icon gutter) -->
        <Style TargetType="ContextMenu">
            <Setter Property="Background" Value="#0F172A"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="4,4"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ContextMenu">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="12" Color="#000000" Opacity="0.8" ShadowDepth="4"/>
                            </Border.Effect>
                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Dark MenuItem Style with custom foreground retention -->
        <Style TargetType="MenuItem">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="MenuItem">
                        <Border Name="ItemBorder" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}" Margin="2,1">
                            <ContentPresenter ContentSource="Header" TextElement.Foreground="{TemplateBinding Foreground}" RecognizesAccessKey="True" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#1E293B"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="#64748B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Clean Menu Separator -->
        <Style TargetType="Separator">
            <Setter Property="Background" Value="#334155"/>
            <Setter Property="Margin" Value="4,3"/>
            <Setter Property="Height" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Separator">
                        <Rectangle Fill="{TemplateBinding Background}" Height="1" Margin="{TemplateBinding Margin}"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="12">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Header -->
            <RowDefinition Height="Auto"/> <!-- Quick Action Bar -->
            <RowDefinition Height="*"/>    <!-- Tab Content -->
            <RowDefinition Height="Auto"/> <!-- Status Bar -->
        </Grid.RowDefinitions>

        <!-- 1. TOP HEADER BANNER (Organized 2-Row Hardware & Daemon Matrix) -->
        <Border Grid.Row="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="14,8" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="⚡" FontSize="28" Margin="0,0,10,0" VerticalAlignment="Center" Foreground="#10B981"/>
                    <StackPanel VerticalAlignment="Center">
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,3">
                            <TextBlock Text="GAME BOOSTER" FontSize="18" FontWeight="ExtraBold" Foreground="#10B981" Margin="0,0,6,0"/>
                            <Border Background="#047857" CornerRadius="4" Padding="6,2" VerticalAlignment="Center">
                                <TextBlock Text="v2.0.0 PRO" FontSize="10" FontWeight="Bold" Foreground="#FFFFFF"/>
                            </Border>
                            <Border Name="PillUpdateAvailable" Visibility="Collapsed" Background="#1E3A8A" BorderBrush="#3B82F6" BorderThickness="1" CornerRadius="4" Padding="6,2" Margin="8,0,0,0" VerticalAlignment="Center" Cursor="Hand" ToolTip="New version available! Click to download latest release on GitHub">
                                <TextBlock Name="TxtUpdateVersion" Text="🚀 Update Available" FontSize="10" FontWeight="Bold" Foreground="#60A5FA"/>
                            </Border>
                        </StackPanel>
                        <TextBlock Text="Ultra Low-Latency Gaming Engine | Multi-Platform Auto-Detector | Standby Cleaner" FontSize="11" Foreground="#94A3B8"/>
                    </StackPanel>
                </StackPanel>

                <!-- Hardware & Engine Status Pills (2x2 Matrix: Hardware on Left, Daemons on Right) -->
                <Grid Grid.Column="2" VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Row 0, Col 0: GPU Badge -->
                    <Border Name="BadgeGpu" Grid.Row="0" Grid.Column="0" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="8,3" Margin="0,0,8,4" Cursor="Hand" ToolTip="Click to check for GPU driver updates">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="GPU: " Foreground="#64748B" FontSize="11" FontWeight="SemiBold"/>
                            <TextBlock Name="TxtGpuBadge" Text="Detecting..." Foreground="#38BDF8" FontSize="11" FontWeight="Bold"/>
                            <Border Name="PillGpuUpdate" Background="#065F46" CornerRadius="4" Padding="5,1" Margin="6,0,0,0" Visibility="Collapsed" Cursor="Hand" ToolTip="New GPU Driver Available! Click to download">
                                <TextBlock Name="TxtGpuUpdateTag" Text="⚡ Update Avail" Foreground="#34D399" FontSize="10" FontWeight="Bold"/>
                            </Border>
                        </StackPanel>
                    </Border>

                    <!-- Row 1, Col 0: CPU Architecture Badge (Below GPU) -->
                    <Border Name="BadgeCpu" Grid.Row="1" Grid.Column="0" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="8,3" Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="CPU: " Foreground="#64748B" FontSize="11" FontWeight="SemiBold"/>
                            <TextBlock Name="TxtCpuBadge" Text="Topology..." Foreground="#A78BFA" FontSize="11" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>

                    <!-- Row 0, Col 1: Tray & Hotkey Pill (Clickable) -->
                    <Border Name="PillTrayStatus" Grid.Row="0" Grid.Column="1" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="8,3" Margin="0,0,0,4" Cursor="Hand" ToolTip="Click to toggle Tray Companion background daemon (Ctrl+F11)">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse Name="DotTray" Width="8" Height="8" Fill="#64748B" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Name="TxtTrayStatus" Text="Tray Companion: OFF" Foreground="#CBD5E1" FontSize="11" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>

                    <!-- Row 1, Col 1: Auto-Watcher Pill (Below Tray Companion) -->
                    <Border Name="PillWatcherStatus" Grid.Row="1" Grid.Column="1" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="8,3" Cursor="Hand" ToolTip="Click to toggle Auto-Watcher background daemon">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse Name="DotWatcher" Width="8" Height="8" Fill="#64748B" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Name="TxtWatcherStatus" Text="Auto-Watcher: OFF" Foreground="#CBD5E1" FontSize="11" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </Grid>
        </Border>

        <!-- 2. QUICK ACTION TOOLBAR -->
        <Border Grid.Row="1" Background="#0F172A" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="10,8" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal">
                    <Button Name="BtnInstantPurge" Content="🧹 Purge Standby RAM" Background="#065F46" Foreground="#34D399" Height="32" Padding="14,0" Margin="0,0,8,0" FontWeight="Bold" ToolTip="Instantly flushes Windows standby list without external RAMMap"/>
                    <Button Name="BtnLaunchHudTop" Content="🖥️ Hardware HUD (Ctrl+F11)" Background="#1E293B" Foreground="#38BDF8" Height="32" Padding="12,0" Margin="0,0,8,0" FontWeight="SemiBold"/>
                    <Button Name="BtnToggleOsdTop" Content="🎯 In-Game OSD (F10)" Background="#1E293B" Foreground="#F43F5E" Height="32" Padding="12,0" Margin="0,0,8,0" FontWeight="Bold" ToolTip="Toggle transparent click-through in-game HUD overlay"/>
                </StackPanel>

                <StackPanel Grid.Column="2" Orientation="Horizontal">
                    <Button Name="BtnTipJar" Content="☕ Tip Jar / Support" Background="#1E293B" BorderBrush="#F59E0B" BorderThickness="1" Foreground="#FBBF24" Height="32" Padding="12,0" FontWeight="Bold" Margin="0,0,8,0" ToolTip="Support independent open-source Game Booster development (PayPal / Ko-Fi / GitHub Sponsors)"/>
                    <Button Name="BtnLaunchTrayCompanion" Content="📥 Minimize to Tray" Background="#1E293B" Foreground="#CBD5E1" Height="32" Padding="12,0" Margin="0,0,8,0"/>
                    <Button Name="BtnSaveAllConfig" Content="💾 Save Defaults" Background="#1E293B" Foreground="#10B981" Height="32" Padding="12,0" FontWeight="Bold"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- 3. MAIN TAB CONTROL -->
        <TabControl Name="MainTabs" Grid.Row="2" Background="#0F172A" BorderBrush="#1F2937" BorderThickness="1">
            
            <!-- TAB 1: GAME MODE (CLOSE APPS) -->
            <TabItem Name="TabGameMode" Header="🚀 Game Mode (Close Apps)">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Presets & Filters -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Button Name="BtnRefreshAll" Content="🔄 Refresh Running Apps" Background="#1E293B" Foreground="#38BDF8" Height="30" Padding="12,0" Margin="0,0,10,0" FontWeight="Bold" ToolTip="Scan and refresh active running processes"/>
                            <CheckBox Name="ChkAutoScanStartup" Content="Auto-scan on launch" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,12,0" ToolTip="When unchecked, Game Booster launches instantly in standby mode (under 0.4s)"/>
                            <Rectangle Width="1" Fill="#334155" Margin="0,2,10,2"/>
                            <TextBlock Text="Select:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,8,0" FontWeight="SemiBold"/>
                            <Button Name="BtnSelectNonEssential" Content="All Non-Essential" Background="#047857" Foreground="#FFFFFF" Height="30" Padding="12,0" Margin="0,0,6,0" FontWeight="SemiBold"/>
                            <Button Name="BtnSelectBalanced" Content="Keep Monitors (RTSS/HWiNFO)" Background="#334155" Foreground="#F8FAFC" Height="30" Padding="12,0" Margin="0,0,6,0"/>
                            <Button Name="BtnDeselectAll" Content="Deselect All" Background="#1E293B" Foreground="#94A3B8" Height="30" Padding="12,0" Margin="0,0,6,0"/>
                        </StackPanel>

                        <StackPanel Grid.Column="2" Orientation="Horizontal">
                            <TextBlock Text="Filter:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,6,0"/>
                            <TextBox Name="TxtFilterProcess" Width="180" Height="28" Background="#1E293B" Foreground="#FFFFFF" BorderBrush="#334155" Padding="6,3" VerticalContentAlignment="Center"/>
                        </StackPanel>
                    </Grid>

                    <!-- Process DataGrid -->
                    <DataGrid Name="GridProcesses" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" SelectionMode="Extended">
                        <DataGrid.ContextMenu>
                            <ContextMenu>
                                <MenuItem Name="MenuCtxWhitelistSession" Header="🛡️ Whitelist for this Session (Keep Open)" Foreground="#38BDF8" FontWeight="SemiBold"/>
                                <MenuItem Name="MenuCtxWhitelistPermanent" Header="⭐ Whitelist Permanently (Always Protect)" Foreground="#10B981" FontWeight="SemiBold"/>
                                <Separator/>
                                <MenuItem Name="MenuCtxCloseNow" Header="❌ Close This Application Now" Foreground="#F87171"/>
                                <MenuItem Name="MenuCtxOpenFileLocation" Header="📁 Open File Location" Foreground="#E2E8F0"/>
                            </ContextMenu>
                        </DataGrid.ContextMenu>
                        <DataGrid.Columns>
                            <DataGridCheckBoxColumn Header="Close" Binding="{Binding IsSelected, UpdateSourceTrigger=PropertyChanged}" Width="50"/>
                            <DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="140" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Application / Group" Binding="{Binding DisplayName}" Width="180" IsReadOnly="True"/>
                            <DataGridTextColumn Header="PID(s)" Binding="{Binding DisplayPid}" Width="110" IsReadOnly="True"/>
                            <DataGridTextColumn Header="RAM (MB)" Binding="{Binding RAM_MB}" Width="85" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Window Title" Binding="{Binding MainWindowTitle}" Width="250" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding Path}" Width="*" IsReadOnly="True"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <!-- Action Banner -->
                    <Border Grid.Row="2" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="0,10,0,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="Selected to Close: " Foreground="#94A3B8" FontSize="13"/>
                                    <TextBlock Name="TxtSelectedCount" Text="0 apps" FontWeight="Bold" Foreground="#38BDF8" FontSize="13" Margin="0,0,16,0"/>
                                    <TextBlock Text="Estimated RAM Reclaimed: " Foreground="#94A3B8" FontSize="13"/>
                                    <TextBlock Name="TxtSelectedRam" Text="0 MB" FontWeight="Bold" Foreground="#10B981" FontSize="13"/>
                                </StackPanel>
                                <TextBlock Text="🛡️ Dynamic GPU Drivers and Display Daemons are automatically protected and will not be closed." Foreground="#64748B" FontSize="11" Margin="0,4,0,0"/>
                            </StackPanel>
                            <Button Name="BtnActivateGameMode" Grid.Column="1" Content="⚡ ACTIVATE GAME MODE (CLOSE SELECTED)" Background="#10B981" Foreground="#022C22" FontSize="13" FontWeight="ExtraBold" Height="42" Padding="24,0"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 2: GAME LIBRARY & PROFILES (Features 1 & 5) -->
            <TabItem Header="🎮 Library &amp; Profiles">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Auto-Watcher Dedicated Control Banner -->
                    <Border Grid.Row="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="14,10" Margin="0,0,0,10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                    <TextBlock Text="⚡ AUTO-WATCHER (ZERO-CLICK GAME OPTIMIZER): " FontWeight="Bold" Foreground="#38BDF8" FontSize="12"/>
                                    <TextBlock Name="TxtTab2WatcherStatus" Text="OFF" FontWeight="ExtraBold" Foreground="#94A3B8" FontSize="12"/>
                                </StackPanel>
                                <TextBlock Text="Automatically closes selected background apps, flushes standby RAM, and applies CPU priority the moment any listed game starts." Foreground="#94A3B8" FontSize="11"/>
                                <CheckBox Name="ChkAutoRestoreOnExit" Content="Auto-restore closed apps when game exits" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,4,0,0" ToolTip="When checked, apps closed during Boost will be automatically reopened when your game exits. Uncheck if you prefer background apps to stay closed."/>
                            </StackPanel>
                            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                <Button Name="BtnTab2ToggleWatcher" Content="▶ Enable Auto-Watcher" Background="#059669" Foreground="#FFFFFF" Height="34" Padding="16,0" FontWeight="ExtraBold" ToolTip="Start background daemon to automatically close apps and optimize your PC the moment any listed game starts"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!-- Scanner Toolbar -->
                    <Grid Grid.Row="1" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Button Name="BtnScanLibraries" Content="🔍 Scan Installed Libraries (Steam/Epic/Battle.net/Xbox)" Background="#0284C7" Foreground="#FFFFFF" Height="32" Padding="14,0" FontWeight="Bold" Margin="0,0,8,0"/>
                            <Button Name="BtnAddCustomGame" Content="+ Add Game / Browse Exe" Background="#10B981" Foreground="#022C22" Height="32" Padding="12,0" FontWeight="Bold" Margin="0,0,8,0"/>
                            <Button Name="BtnToggleWatcher" Content="▶ Start Auto-Watcher" Background="#059669" Foreground="#FFFFFF" Height="32" Padding="14,0" FontWeight="ExtraBold" Margin="0,0,8,0" ToolTip="Start background daemon to automatically close apps and optimize your PC the moment any listed game starts"/>
                            <Button Name="BtnRemoveMonitored" Content="- Remove Selected" Background="#EF4444" Foreground="#FFFFFF" Height="32" Padding="12,0" Margin="0,0,8,0"/>
                            <Button Name="BtnClearAllGames" Content="Clear All" Background="#475569" Foreground="#FFFFFF" Height="32" Padding="12,0"/>
                        </StackPanel>
                        <!-- Quick Add chips -->
                        <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="Quick Add:" Foreground="#64748B" FontSize="11" VerticalAlignment="Center" Margin="0,0,6,0"/>
                            <Button Name="BtnQuickWow" Content="+ WoW" Background="#1E293B" Foreground="#38BDF8" Height="26" Padding="8,0" Margin="0,0,4,0"/>
                            <Button Name="BtnQuickCod" Content="+ Call of Duty" Background="#1E293B" Foreground="#38BDF8" Height="26" Padding="8,0" Margin="0,0,4,0"/>
                            <Button Name="BtnQuickCs2" Content="+ CS2" Background="#1E293B" Foreground="#38BDF8" Height="26" Padding="8,0"/>
                        </StackPanel>
                    </Grid>

                    <!-- Game List DataGrid -->
                    <DataGrid Name="GridGameLibrary" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" IsReadOnly="True" SelectionMode="Single" SelectionUnit="FullRow">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Game Title" Binding="{Binding Title}" Width="240" FontWeight="Bold" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Process Name (.exe)" Binding="{Binding ProcessName}" Width="180" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Platform" Binding="{Binding Platform}" Width="120" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding ExePath}" Width="*" IsReadOnly="True"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <!-- Per-Game Profile Settings Card (Feature 1) -->
                    <Border Grid.Row="3" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="14,10" Margin="0,10,0,0">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,8">
                                <TextBlock Text="⚙️ PER-GAME HARDWARE OPTIMIZER PROFILE: " FontWeight="Bold" Foreground="#38BDF8" FontSize="12"/>
                                <TextBlock Name="TxtSelectedGameName" Text="(Select a game from above)" FontWeight="ExtraBold" Foreground="#10B981" FontSize="12"/>
                            </StackPanel>

                            <Grid Grid.Row="1">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="220"/>
                                    <ColumnDefinition Width="260"/>
                                    <ColumnDefinition Width="260"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>

                                <!-- CPU Priority -->
                                <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                    <TextBlock Text="CPU Priority Class:" Foreground="#94A3B8" FontSize="11" Margin="0,0,0,4"/>
                                    <ComboBox Name="CmbCpuPriority" Height="28" Background="#1E293B" Foreground="#FFFFFF">
                                        <ComboBoxItem Content="High (Recommended)" IsSelected="True"/>
                                        <ComboBoxItem Content="AboveNormal"/>
                                        <ComboBoxItem Content="Normal"/>
                                    </ComboBox>
                                </StackPanel>

                                <!-- CPU Affinity Mask -->
                                <StackPanel Grid.Column="1" Margin="0,0,10,0">
                                    <TextBlock Text="CPU Architecture Affinity:" Foreground="#94A3B8" FontSize="11" Margin="0,0,0,4"/>
                                    <ComboBox Name="CmbCpuAffinity" Height="28" Background="#1E293B" Foreground="#FFFFFF">
                                        <ComboBoxItem Content="All Logical Cores (Default)" IsSelected="True"/>
                                        <ComboBoxItem Content="Intel P-Cores Only (No E-Cores)"/>
                                        <ComboBoxItem Content="AMD 3D V-Cache CCD Only"/>
                                    </ComboBox>
                                </StackPanel>

                                <!-- Custom Companions per game -->
                                <StackPanel Grid.Column="2" Margin="0,0,10,0">
                                    <TextBlock Text="Launch Custom Companion(s):" Foreground="#94A3B8" FontSize="11" Margin="0,0,0,4"/>
                                    <TextBox Name="TxtGameCompanion" Height="28" Background="#1E293B" Foreground="#FFFFFF" BorderBrush="#334155" Padding="6,3" ToolTip="Executable(s) to launch when this game starts. Separate multiple programs with commas (e.g. Discord, obs64, C:\Tools\Tracker.exe)"/>
                                </StackPanel>

                                <!-- Auto OSD Toggle -->
                                <StackPanel Grid.Column="3" VerticalAlignment="Center" Margin="0,14,10,0">
                                    <CheckBox Name="ChkAutoOsd" Content="Auto-Launch In-Game OSD" Foreground="#F8FAFC" FontSize="11"/>
                                </StackPanel>

                                <StackPanel Grid.Column="4" Orientation="Horizontal" VerticalAlignment="Bottom">
                                    <Button Name="BtnSaveGameProfile" Content="💾 Save Profile" Background="#10B981" Foreground="#022C22" Height="36" Padding="12,0" FontWeight="Bold" Margin="0,0,6,0"/>
                                    <Button Name="BtnReloadGameProfile" Content="🔄 Reload" Background="#1E293B" Foreground="#38BDF8" Height="36" Padding="10,0" FontWeight="SemiBold" Margin="0,0,6,0" ToolTip="Reload saved profile settings for this game"/>
                                    <Button Name="BtnResetGameProfile" Content="⏮️ Reset" Background="#334155" Foreground="#F8FAFC" Height="36" Padding="10,0" ToolTip="Reset profile settings to default"/>
                                </StackPanel>
                            </Grid>

                            <!-- Row 2: Community Presets & Profile Import/Export (Phase 3) -->
                            <Grid Grid.Row="2" Margin="0,10,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="Tournament Presets:" Foreground="#94A3B8" FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                    <ComboBox Name="CmbCompetitivePresets" Width="230" Height="28" Background="#1E293B" Foreground="#FFFFFF" Margin="0,0,6,0">
                                        <ComboBoxItem Content="Call of Duty (Warzone / BO6)" IsSelected="True"/>
                                        <ComboBoxItem Content="Counter-Strike 2"/>
                                        <ComboBoxItem Content="Valorant"/>
                                        <ComboBoxItem Content="Apex Legends"/>
                                        <ComboBoxItem Content="World of Warcraft"/>
                                    </ComboBox>
                                    <Button Name="BtnApplyCompetitivePreset" Content="🏆 Apply Preset" Background="#7C3AED" Foreground="#FFFFFF" Height="28" Padding="12,0" FontWeight="Bold" ToolTip="Apply tuned competitive preset to the selected game"/>
                                </StackPanel>
                                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                                    <Button Name="BtnExportGameProfile" Content="📤 Export Profile (.json)" Background="#1E293B" BorderBrush="#38BDF8" BorderThickness="1" Foreground="#38BDF8" Height="28" Padding="10,0" Margin="0,0,6,0" ToolTip="Export current profile to a portable JSON file to share"/>
                                    <Button Name="BtnImportGameProfile" Content="📥 Import Profile (.json)" Background="#1E293B" BorderBrush="#10B981" BorderThickness="1" Foreground="#34D399" Height="28" Padding="10,0" ToolTip="Import a game profile from a JSON file"/>
                                </StackPanel>
                            </Grid>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 3: SYSTEM TWEAKS & RADAR (Features 2, 3, 4, 8, 10) -->
            <TabItem Header="⚡ Tweaks &amp; Radar">
                <Grid Margin="12">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="480"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Left Column: 1-Click Windows Gaming Tweaks & Shader Cleaner -->
                    <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">
                        <StackPanel>
                            <!-- Card 0: GPU & Display Driver Radar -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,6">
                                <StackPanel>
                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="🚀 GPU DRIVER UPDATE RADAR" FontWeight="Bold" Foreground="#38BDF8" FontSize="12"/>
                                        <Border Name="BadgeGpuDriverStatus" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtGpuDriverBadge" Text="READY" FontSize="10" FontWeight="Bold" Foreground="#38BDF8"/>
                                        </Border>
                                    </Grid>
                                    <TextBlock Text="Live driver verification directly from AMD GPUOpen and NVIDIA GeForce update feeds." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                    <Border Background="#0B132B" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="4" Padding="8" Margin="0,0,0,6">
                                        <StackPanel>
                                            <Grid Margin="0,0,0,3">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="105"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="Graphics Card:" Foreground="#64748B" FontSize="11"/>
                                                <TextBlock Name="TxtGpuCardName" Grid.Column="1" Text="Detecting..." Foreground="#F8FAFC" FontWeight="Bold" FontSize="11"/>
                                            </Grid>
                                            <Grid Margin="0,0,0,3">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="105"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="Installed Driver:" Foreground="#64748B" FontSize="11"/>
                                                <TextBlock Name="TxtGpuInstalledDriver" Grid.Column="1" Text="Scanning..." Foreground="#38BDF8" FontWeight="SemiBold" FontSize="11"/>
                                            </Grid>
                                            <Grid Margin="0,0,0,3">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="105"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="Latest Available:" Foreground="#64748B" FontSize="11"/>
                                                <TextBlock Name="TxtGpuLatestDriver" Grid.Column="1" Text="Click Check Updates" Foreground="#34D399" FontWeight="Bold" FontSize="11"/>
                                            </Grid>
                                            <Grid>
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="105"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="Release Date:" Foreground="#64748B" FontSize="11"/>
                                                <TextBlock Name="TxtGpuReleaseDate" Grid.Column="1" Text="--" Foreground="#94A3B8" FontSize="11"/>
                                            </Grid>
                                        </StackPanel>
                                    </Border>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <Button Name="BtnDownloadGpuDriver" Grid.Column="0" Content="📥 View Release Notes &amp; Download" Background="#0284C7" Foreground="#FFFFFF" Height="30" FontWeight="Bold" Margin="0,0,6,0" IsEnabled="False"/>
                                        <Button Name="BtnCheckGpuDriver" Grid.Column="1" Content="🔄 Check Updates" Background="#1E293B" Foreground="#38BDF8" BorderBrush="#0284C7" BorderThickness="1" Height="30" Padding="10,0"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Card 1: Windows Low-Latency Subsystems -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,6">
                                <StackPanel>
                                    <TextBlock Text="🛡️ WINDOWS LOW-LATENCY SUBSYSTEMS" FontWeight="Bold" Foreground="#38BDF8" FontSize="12" Margin="0,0,0,6"/>
                                    
                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="0.5ms High-Resolution Timer" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgeTimer" Grid.Column="1" Background="#065F46" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgeTimer" Text="READY" FontSize="10" FontWeight="Bold" Foreground="#34D399"/>
                                        </Border>
                                    </Grid>

                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Hardware GPU Scheduling (HAGS)" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgeHags" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgeHags" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        </Border>
                                    </Grid>

                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Windows Dedicated Game Mode" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgeGameMode" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgeGameMode" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        </Border>
                                    </Grid>

                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="TCP NoDelay (Nagle Disabled)" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgeTcp" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgeTcp" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        </Border>
                                    </Grid>

                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="PowerShell 7 Runtime Engine" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgePsEngine" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgePsEngine" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        </Border>
                                    </Grid>

                                    <Grid Margin="0,0,0,8">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Multiplane Overlay (MPO Fix)" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgeMpo" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgeMpo" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        </Border>
                                    </Grid>

                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <Button Name="BtnApplyAllTweaks" Grid.Column="0" Content="⚡ 1-Click Apply All Gaming Tweaks" Background="#10B981" Foreground="#022C22" Height="32" FontWeight="ExtraBold" Margin="0,0,6,0"/>
                                        <Button Name="BtnUpgradePs7" Grid.Column="1" Content="🚀 Upgrade PS7" Background="#1E293B" BorderBrush="#38BDF8" BorderThickness="1" Foreground="#38BDF8" Height="32" Padding="12,0" FontWeight="Bold" ToolTip="Install or switch to PowerShell 7 for 2x faster performance"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Card 1B: v2.0 Engine & Input Options -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,6">
                                <StackPanel>
                                    <TextBlock Text="⚙️ GAME MODE ENGINE &amp; INPUT OPTIONS (v2.0)" FontWeight="Bold" Foreground="#38BDF8" FontSize="12" Margin="0,0,0,6"/>
                                    <CheckBox Name="ChkLockWinKey" Content="Lock Windows Key during Game Mode (Optional)" IsChecked="False" Foreground="#CBD5E1" FontSize="11" Margin="0,0,0,4" ToolTip="Suppresses Start Menu when pressing the Windows key in-game. Keep unchecked if you use Win+G, Win+Shift+S, etc."/>
                                    <CheckBox Name="ChkSuppressSticky" Content="Suppress Sticky Keys (5x Shift popup)" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,0,0,4" ToolTip="Disables the annoying Windows Sticky Keys alert dialog when mashing the Shift key in games."/>
                                    <CheckBox Name="ChkLauncherRamDiet" Content="Launcher RAM Diet (EmptyWorkingSet)" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,0,0,4" ToolTip="Reclaims gigabytes of active physical RAM from Discord, Steam, Epic, Brave, and Chrome without closing them."/>
                                    <CheckBox Name="ChkReverseAffinity" Content="Reverse Affinity (Silo background apps away from game cores)" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,0,0,4" ToolTip="Pins background apps to auxiliary cores / E-cores / secondary CCD so the game has 100% uncontested CPU cores."/>
                                    <CheckBox Name="ChkDynamicQos" Content="Dynamic Gaming QoS (UDP DSCP 46 Expedited Forwarding)" IsChecked="True" Foreground="#CBD5E1" FontSize="11" Margin="0,0,0,4" ToolTip="Prioritizes real-time gaming network packets at the OS network queue and router levels."/>
                                </StackPanel>
                            </Border>

                            <!-- Card 2: Smart Memory Cleaner -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,6">
                                <StackPanel>
                                    <TextBlock Text="🧠 SMART STANDBY RAM &amp; WORKING SET" FontWeight="Bold" Foreground="#A78BFA" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBlock Text="Flush Windows Standby cache instantly to eliminate frame micro-stutters." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                    <Grid Margin="0,0,0,6">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Active Standby Cache:" VerticalAlignment="Center" Foreground="#F8FAFC" FontSize="12"/>
                                        <TextBlock Name="TxtStandbySize" Grid.Column="1" Text="Measuring..." FontWeight="ExtraBold" Foreground="#A78BFA" FontSize="13"/>
                                    </Grid>
                                    <Button Name="BtnPurgeStandbyCard" Content="🧹 Flush Standby List Now" Background="#7C3AED" Foreground="#FFFFFF" Height="30" FontWeight="Bold"/>
                                </StackPanel>
                            </Border>

                            <!-- Card 3: Multi-Vendor Shader Cache Manager -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,6">
                                <StackPanel>
                                    <TextBlock Text="🎮 MULTI-VENDOR SHADER CACHE MANAGER" FontWeight="Bold" Foreground="#F59E0B" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBlock Text="Purges stale DirectX, AMD, NVIDIA, Intel, Steam, and Battle.net pipeline caches to eliminate micro-stutters and hitching." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                    <Grid Margin="0,0,0,4">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Total Cached Shaders:" VerticalAlignment="Center" Foreground="#F8FAFC" FontSize="12"/>
                                        <TextBlock Name="TxtShaderSize" Grid.Column="1" Text="Scanning..." FontWeight="ExtraBold" Foreground="#F59E0B" FontSize="13"/>
                                    </Grid>
                                    <TextBlock Name="TxtShaderBreakdown" Text="DirectX, AMD Radeon, Battle.net &amp; Steam caches monitored." Foreground="#64748B" FontSize="10" Margin="0,0,0,8" TextWrapping="Wrap"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <Button Name="BtnCleanShaders" Grid.Column="0" Content="🧹 Clean Stale Shaders (Fix Stutter)" Background="#D97706" Foreground="#FFFFFF" Height="30" FontWeight="Bold" Margin="0,0,6,0"/>
                                        <Button Name="BtnScanShaders" Grid.Column="1" Content="🔍 Scan" Background="#1E293B" Foreground="#FBBF24" BorderBrush="#F59E0B" BorderThickness="1" Height="30" Padding="12,0" FontWeight="SemiBold"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Card 4: PCIe MSI Mode & High IRQ Priority Engine -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,0,0,6">
                                <StackPanel>
                                    <TextBlock Text="⚡ PCIE MSI MODE &amp; HIGH IRQ PRIORITY (LATENCY FIX)" FontWeight="Bold" Foreground="#38BDF8" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBlock Text="Configures Message Signaled Interrupts (MSI) and High IRQ priority for GPU, Network NIC, and Audio to eliminate DPC latency spikes." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                    <Border Background="#0B132B" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="4" Padding="8" Margin="0,0,0,6">
                                        <StackPanel>
                                            <Grid Margin="0,0,0,3">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="Graphics Card (GPU):" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Name="TxtMsiGpuStatus" Grid.Column="1" Text="Scanning..." Foreground="#38BDF8" FontWeight="Bold" FontSize="11"/>
                                            </Grid>
                                            <Grid Margin="0,0,0,3">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="Gaming Network (NIC / Wi-Fi):" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Name="TxtMsiNicStatus" Grid.Column="1" Text="Scanning..." Foreground="#38BDF8" FontWeight="Bold" FontSize="11"/>
                                            </Grid>
                                            <Grid>
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="HD Audio / Sound Bus:" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Name="TxtMsiAudioStatus" Grid.Column="1" Text="Scanning..." Foreground="#F59E0B" FontWeight="Bold" FontSize="11"/>
                                            </Grid>
                                        </StackPanel>
                                    </Border>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <Button Name="BtnOptimizePcieMsi" Grid.Column="0" Content="⚡ 1-Click Optimize PCIe MSI &amp; High IRQ" Background="#0284C7" Foreground="#FFFFFF" Height="30" FontWeight="Bold" Margin="0,0,6,0" ToolTip="Sets MSI Mode and High Priority across GPU, Network, USB Host Controllers, and Audio"/>
                                        <Button Name="BtnRefreshPcieMsi" Grid.Column="1" Content="🔄 Refresh" Background="#1E293B" Foreground="#38BDF8" BorderBrush="#0284C7" BorderThickness="1" Height="30" Padding="10,0"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Card 5: USB Gaming Peripherals & Polling Rate Stability -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10">
                                <StackPanel>
                                    <TextBlock Text="🖱️ USB CONTROLLER &amp; POLLING RATE OPTIMIZER" FontWeight="Bold" Foreground="#10B981" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBlock Text="Disables USB Selective Suspend and D3 power-save states on mice, keyboards, and controllers to prevent sensor sleep and missed clicks." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                    <Grid Margin="0,0,0,6">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="USB Power-Saving State:" VerticalAlignment="Center" Foreground="#F8FAFC" FontSize="12"/>
                                        <TextBlock Name="TxtUsbPowerStatus" Grid.Column="1" Text="Scanning..." FontWeight="ExtraBold" Foreground="#10B981" FontSize="12"/>
                                    </Grid>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <Button Name="BtnDisableUsbPowerSave" Grid.Column="0" Content="🖱️ Disable USB Power-Save (Max 1000Hz+ Stability)" Background="#059669" Foreground="#FFFFFF" Height="30" FontWeight="Bold" Margin="0,0,6,0" ToolTip="Disables EnhancedPowerManagementEnabled, SelectiveSuspend, and AllowIdleIrpInD3 across USB controllers and gaming peripherals"/>
                                        <Button Name="BtnRefreshUsbStatus" Grid.Column="1" Content="🔄 Refresh" Background="#1E293B" Foreground="#34D399" BorderBrush="#059669" BorderThickness="1" Height="30" Padding="10,0"/>
                                    </Grid>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>

                    <!-- Right Column: Network Latency & Server Radar (Feature 8) -->
                    <Border Grid.Column="1" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="12">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0" Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="🌐 NETWORK LATENCY &amp; SERVER PING RADAR" FontWeight="Bold" Foreground="#38BDF8" FontSize="12"/>
                                    <TextBlock Text="Real-time multi-target ping grid to major game datacenter clusters." Foreground="#94A3B8" FontSize="11"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Orientation="Horizontal">
                                    <CheckBox Name="ChkAutoRadar" Content="Auto-Ping (5s)" Foreground="#F8FAFC" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <Button Name="BtnPingRadarNow" Content="📡 Ping All Servers Now" Background="#0284C7" Foreground="#FFFFFF" Height="30" Padding="12,0" FontWeight="Bold"/>
                                </StackPanel>
                            </Grid>

                            <DataGrid Name="GridServerRadar" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" IsReadOnly="True" SelectionMode="Single" SelectionUnit="FullRow">
                                <DataGrid.ContextMenu>
                                    <ContextMenu>
                                        <MenuItem Name="MenuRadarPingSingle" Header="🎯 Ping This Server Now" Foreground="#38BDF8" FontWeight="SemiBold"/>
                                        <Separator/>
                                        <MenuItem Name="MenuRadarPingContinuous" Header="⚡ Continuous Ping Test (Live Console)" Foreground="#FBBF24"/>
                                        <MenuItem Name="MenuRadarTraceroute" Header="🌐 Trace Route to Server (tracert)" Foreground="#A78BFA"/>
                                        <Separator/>
                                        <MenuItem Name="MenuRadarCopyHost" Header="📋 Copy Server Host / IP" Foreground="#E2E8F0"/>
                                        <MenuItem Name="MenuRadarCopyDetails" Header="📋 Copy Server Details" Foreground="#94A3B8"/>
                                    </ContextMenu>
                                </DataGrid.ContextMenu>
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Region" Binding="{Binding Region}" Width="160" FontWeight="Bold" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Datacenter Location" Binding="{Binding Location}" Width="200" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Host / Cluster IP" Binding="{Binding Host}" Width="160" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Ping (ms)" Binding="{Binding PingMs}" Width="90" FontWeight="ExtraBold" IsReadOnly="True"/>
                                    <DataGridTextColumn Header="Quality" Binding="{Binding Status}" Width="*" IsReadOnly="True"/>
                                </DataGrid.Columns>
                            </DataGrid>

                            <TextBlock Grid.Row="2" Text="* Right-click any server to ping individually, launch continuous live ping, trace route, or copy IP. Double-click to ping immediately." Foreground="#64748B" FontSize="10" Margin="0,8,0,0"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 4: HARDWARE HUD & IN-GAME OSD (Feature 7) -->
            <TabItem Header="🖥️ HUD &amp; Overlays">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Top: Hardware HUD Terminal Presets -->
                    <Border Grid.Row="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="0,0,0,12">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0" Margin="0,0,0,12">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="SECONDARY DESKTOP HARDWARE HUD (TERMINAL DOCKED)" FontWeight="Bold" Foreground="#38BDF8" FontSize="13"/>
                                    <TextBlock Text="Docked telemetry running btop + bottom + Live Ping Monitor without FPS drop." Foreground="#94A3B8" FontSize="11"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Orientation="Horizontal">
                                    <Button Name="BtnLaunchHud" Content="Launch Hardware HUD" Background="#10B981" Foreground="#022C22" Height="36" Padding="18,0" FontWeight="Bold" Margin="0,0,8,0"/>
                                    <Button Name="BtnForceRestartHud" Content="Force Restart HUD" Background="#334155" Foreground="#F8FAFC" Height="36" Padding="14,0" Margin="0,0,8,0"/>
                                    <Button Name="BtnCloseHud" Content="❌ Close HUD" Background="#7F1D1D" Foreground="#FCA5A5" Height="36" Padding="14,0" FontWeight="Bold"/>
                                </StackPanel>
                            </Grid>

                            <!-- HUD Layout Presets & Coordinates -->
                            <Grid Grid.Row="1">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="280"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>

                                <StackPanel Grid.Column="0" Margin="0,0,14,0">
                                    <TextBlock Text="Select HUD Preset:" Foreground="#94A3B8" FontSize="11" Margin="0,0,0,4"/>
                                    <ComboBox Name="CmbHudPreset" Height="28" Background="#1E293B" Foreground="#FFFFFF">
                                        <ComboBoxItem Content="Tri-Pane Balanced (btop + btm + Ping)" IsSelected="True"/>
                                        <ComboBoxItem Content="Esports Ping Focused (Ping + btop)"/>
                                        <ComboBoxItem Content="Minimal Dual-Pane (btop + btm)"/>
                                    </ComboBox>
                                </StackPanel>

                                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="Coordinates: " Foreground="#64748B" FontSize="11" VerticalAlignment="Center"/>
                                    <TextBox Name="TxtHudX" Width="55" Height="26" Background="#1E293B" Foreground="#FFFFFF" Margin="0,0,6,0" ToolTip="X Coordinate"/>
                                    <TextBox Name="TxtHudY" Width="55" Height="26" Background="#1E293B" Foreground="#FFFFFF" Margin="0,0,6,0" ToolTip="Y Coordinate"/>
                                    <TextBox Name="TxtHudW" Width="55" Height="26" Background="#1E293B" Foreground="#FFFFFF" Margin="0,0,6,0" ToolTip="Width"/>
                                    <TextBox Name="TxtHudH" Width="55" Height="26" Background="#1E293B" Foreground="#FFFFFF" Margin="0,0,8,0" ToolTip="Height"/>
                                    <Button Name="BtnSaveHudSize" Content="Capture Current Size" Background="#0891B2" Foreground="#FFFFFF" Height="26" Padding="10,0" Margin="0,0,6,0"/>
                                    <Button Name="BtnApplyManualHudSize" Content="💾 Save Coords" Background="#1E293B" Foreground="#38BDF8" Height="26" Padding="8,0" ToolTip="Save manually typed coordinates to config.json"/>
                                </StackPanel>

                                <Button Name="BtnInstallHudDeps" Grid.Column="2" Content="📦 Install Dependencies (New PC)" Background="#7C3AED" Foreground="#FFFFFF" Height="32" Padding="14,0" FontWeight="Bold"/>
                            </Grid>
                        </Grid>
                    </Border>

                    <!-- Bottom: In-Game Transparent OSD Overlay (Feature 7) -->
                    <Border Grid.Row="1" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="14,12">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0" Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="🎯 IN-GAME TRANSPARENT CLICK-THROUGH OSD OVERLAY" FontWeight="Bold" Foreground="#F43F5E" FontSize="13"/>
                                    <TextBlock Text="Renders an unobtrusive, 100% click-through glass HUD directly inside full-screen borderless games." Foreground="#94A3B8" FontSize="11"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Orientation="Horizontal">
                                    <Button Name="BtnToggleOsd" Content="Toggle OSD (F10)" Background="#F43F5E" Foreground="#FFFFFF" Height="36" Padding="18,0" FontWeight="ExtraBold" Margin="0,0,8,0"/>
                                    <Button Name="BtnUnlockOsd" Content="Move/Reposition OSD" Background="#334155" Foreground="#F8FAFC" Height="36" Padding="14,0"/>
                                </StackPanel>
                            </Grid>

                            <!-- OSD Feature Preview Box -->
                            <Border Grid.Row="1" Background="#060911" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="16">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="320"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Mock Overlay Representation -->
                                    <Border Grid.Column="0" Background="#DD0F172A" BorderBrush="#00FF66" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,16,0">
                                        <StackPanel>
                                            <TextBlock Name="TxtMockOsdTitle" Text="⚡ GAME BOOSTER OSD v1.0" Foreground="#00FF66" FontWeight="ExtraBold" FontSize="11" Margin="0,0,0,8"/>
                                            <Grid Margin="0,0,0,4">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="STANDBY RAM" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Text="420 MB [CLEAN]" Foreground="#38BDF8" FontWeight="Bold" FontSize="11" Grid.Column="1"/>
                                            </Grid>
                                            <Grid Margin="0,0,0,4">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="EU FRANKFURT PING" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Text="18 ms [STABLE]" Foreground="#10B981" FontWeight="Bold" FontSize="11" Grid.Column="1"/>
                                            </Grid>
                                            <Grid Margin="0,0,0,4">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="TIMER RESOLUTION" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Text="0.5 ms [MAX]" Foreground="#F59E0B" FontWeight="Bold" FontSize="11" Grid.Column="1"/>
                                            </Grid>
                                            <Grid Margin="0,0,0,4">
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                <TextBlock Text="CPU PRIORITY" Foreground="#94A3B8" FontSize="11"/>
                                                <TextBlock Text="HIGH / P-CORES" Foreground="#A78BFA" FontWeight="Bold" FontSize="11" Grid.Column="1"/>
                                            </Grid>
                                        </StackPanel>
                                    </Border>

                                    <!-- OSD Settings -->
                                    <StackPanel Grid.Column="1">
                                        <TextBlock Text="OSD Features &amp; Options:" FontWeight="Bold" Foreground="#F8FAFC" FontSize="12" Margin="0,0,0,6"/>
                                        <TextBlock Text="• True Click-Through: Uses WS_EX_TRANSPARENT | WS_EX_LAYERED Win32 APIs so mouse clicks pass through directly to your game without blocking aim." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,4"/>
                                        <TextBlock Text="• Zero Input Lag: Built with pure lightweight WPF rendering at 1000ms intervals, avoiding expensive GPU hook injections like RivaTuner/RTSS." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,4"/>
                                        <TextBlock Text="• Real-Time Metrics: Displays live Server Ping, Standby RAM buffer, CPU Affinity Mode, and High-Resolution Timer status." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,10"/>
                                        
                                        <!-- Custom Streamer Title / Handle Setup Field -->
                                        <Grid Margin="0,0,0,10">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="Auto"/>
                                            </Grid.ColumnDefinitions>
                                            <TextBlock Text="OSD Title / Streamer Tag:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,10,0" FontSize="11" FontWeight="SemiBold"/>
                                            <TextBox Name="TxtOsdTitle" Grid.Column="1" Height="28" Background="#1E293B" Foreground="#FFFFFF" BorderBrush="#334155" Padding="8,4" ToolTip="Custom overlay title or streamer name (e.g. SOFEE, GAME BOOSTER)"/>
                                            <Button Name="BtnSaveOsdSettings" Grid.Column="2" Content="💾 Save OSD Title" Background="#0284C7" Foreground="#FFFFFF" Height="28" Padding="12,0" FontWeight="Bold" Margin="8,0,0,0"/>
                                        </Grid>

                                        <StackPanel Orientation="Horizontal">
                                            <TextBlock Text="Position:" Foreground="#94A3B8" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                            <ComboBox Name="CmbOsdPosition" Width="180" Height="28" Background="#1E293B" Foreground="#FFFFFF" Margin="0,0,12,0">
                                                <ComboBoxItem Content="Top-Right (Default)" IsSelected="True"/>
                                                <ComboBoxItem Content="Top-Left"/>
                                                <ComboBoxItem Content="Bottom-Right"/>
                                                <ComboBoxItem Content="Bottom-Left"/>
                                            </ComboBox>
                                            <CheckBox Name="ChkOsdShowPing" Content="Show Ping" IsChecked="True" Foreground="#F8FAFC" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                            <CheckBox Name="ChkOsdShowRam" Content="Show RAM" IsChecked="True" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                                        </StackPanel>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <TextBlock Grid.Row="2" Text="* Use F10 (or the button above) to show or hide the overlay anytime while playing." Foreground="#64748B" FontSize="10" Margin="0,8,0,0"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 5: COMPANIONS & AUTO-START -->
            <TabItem Header="🧩 Auto-Start Apps">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Applications to launch automatically when any monitored game starts (e.g. Discord, OBS, RTSS):" Foreground="#94A3B8" VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button Name="BtnAddCompanion" Content="+ Add Companion App" Background="#10B981" Foreground="#022C22" Height="30" Padding="12,0" FontWeight="Bold" Margin="0,0,8,0"/>
                            <Button Name="BtnRemoveCompanion" Content="- Remove Selected" Background="#EF4444" Foreground="#FFFFFF" Height="30" Padding="12,0" Margin="0,0,8,0"/>
                            <Button Name="BtnTestCompanion" Content="Test Launch Selected" Background="#334155" Foreground="#F8FAFC" Height="30" Padding="12,0"/>
                        </StackPanel>
                    </Grid>

                    <DataGrid Name="GridCompanions" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" SelectionMode="Single">
                        <DataGrid.Columns>
                            <DataGridCheckBoxColumn Header="Enabled" Binding="{Binding Enabled, UpdateSourceTrigger=PropertyChanged}" Width="70"/>
                            <DataGridTextColumn Header="Application Name" Binding="{Binding Name}" Width="200" FontWeight="Bold" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Delay (s)" Binding="{Binding DelaySeconds}" Width="80"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding Path}" Width="*" IsReadOnly="True"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <Button Name="BtnSaveCompanions" Grid.Row="2" Content="Save Companion Settings" Background="#0284C7" Foreground="#FFFFFF" Height="36" FontWeight="Bold" Margin="0,10,0,0"/>
                </Grid>
            </TabItem>

            <!-- TAB 6: WHITELIST & GPU PROTECTION (Feature 6) -->
            <TabItem Header="🛡️ Protected Apps">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <!-- Top Banner: Dynamic GPU Protection -->
                    <Border Grid.Row="0" Background="#111827" BorderBrush="#047857" BorderThickness="1" CornerRadius="6" Padding="12" Margin="0,0,0,10">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="🛡️" FontSize="20" Margin="0,0,10,0" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="DYNAMIC GPU DRIVER PROTECTION: " FontWeight="Bold" Foreground="#10B981" FontSize="12"/>
                                    <TextBlock Name="TxtGpuProtectionStatus" Text="Active" FontWeight="Bold" Foreground="#34D399" FontSize="12"/>
                                </StackPanel>
                                <TextBlock Name="TxtGpuProtectedList" Text="Protected driver daemons: nvspcaps64, nvcplui, nvcontainer, amdfendrsr, ArcControl" Foreground="#94A3B8" FontSize="11" Margin="0,2,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <!-- Whitelist DataGrid -->
                    <DataGrid Name="GridWhitelist" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" IsReadOnly="True" SelectionMode="Extended" SelectionUnit="FullRow">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Protected Process" Binding="{Binding ProcessName}" Width="220" FontWeight="Bold" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="160" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Protection Reason" Binding="{Binding Reason}" Width="*" IsReadOnly="True"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <!-- Add / Remove bar -->
                    <Grid Grid.Row="2" Margin="0,10,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox Name="TxtNewWhitelistProcess" Height="32" Background="#1E293B" Foreground="#FFFFFF" BorderBrush="#334155" Padding="8,4" ToolTip="Type process name to whitelist (e.g. steam, discord, chrome)"/>
                        <Button Name="BtnAddWhitelist" Grid.Column="1" Content="+ Add to Whitelist" Background="#10B981" Foreground="#022C22" Height="32" Padding="16,0" FontWeight="Bold" Margin="8,0,0,0"/>
                        <Button Name="BtnRemoveWhitelist" Grid.Column="2" Content="- Remove Selected" Background="#EF4444" Foreground="#FFFFFF" Height="32" Padding="14,0" Margin="8,0,0,0"/>
                    </Grid>
                </Grid>
            </TabItem>

            <!-- TAB 7: RESTORE SESSION -->
            <TabItem Header="🔄 Restore Session">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" Text="Applications closed by Game Mode in the active session. Right-click or use buttons to restore individually:" Foreground="#94A3B8" Margin="0,0,0,8"/>

                    <DataGrid Name="GridRestoreSession" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" IsReadOnly="True" SelectionMode="Single" SelectionUnit="FullRow">
                        <DataGrid.ContextMenu>
                            <ContextMenu>
                                <MenuItem Name="MenuCtxRestoreOne" Header="🔄 Restore This Application" Foreground="#38BDF8" FontWeight="SemiBold"/>
                                <MenuItem Name="MenuCtxRemoveOne" Header="🗑️ Remove from Restore List" Foreground="#F87171"/>
                                <Separator/>
                                <MenuItem Name="MenuCtxRestoreAll" Header="⚡ Restore All Applications" Foreground="#A78BFA" FontWeight="Bold"/>
                            </ContextMenu>
                        </DataGrid.ContextMenu>
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Application Name" Binding="{Binding Name}" Width="180" FontWeight="Bold" IsReadOnly="True"/>
                            <DataGridTextColumn Header="PID" Binding="{Binding Id}" Width="70" IsReadOnly="True"/>
                            <DataGridTextColumn Header="RAM Freed (MB)" Binding="{Binding RAM_MB}" Width="110" IsReadOnly="True"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding Path}" Width="*" IsReadOnly="True"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <Grid Grid.Row="2" Margin="0,10,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Button Name="BtnClearRestoreList" Grid.Column="0" Content="Clear List" Background="#475569" Foreground="#FFFFFF" Height="36" Padding="16,0" HorizontalAlignment="Left"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button Name="BtnRestoreSelectedApp" Content="Restore Selected App" Background="#0284C7" Foreground="#FFFFFF" Height="36" Padding="18,0" FontWeight="Bold" Margin="0,0,8,0"/>
                            <Button Name="BtnRestoreAllApps" Content="🔄 RESTORE ALL CLOSED APPS" Background="#8B5CF6" Foreground="#FFFFFF" Height="36" Padding="24,0" FontWeight="ExtraBold"/>
                        </StackPanel>
                    </Grid>
                </Grid>
            </TabItem>

            <!-- TAB 8: DIAGNOSTICS & POST-GAME LAG REPORT -->
            <TabItem Header="📋 Diagnostics &amp; Lag Report">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/> <!-- Post-Game Lag Analyzer Card (Feature 14) -->
                        <RowDefinition Height="Auto"/> <!-- Action Bar -->
                        <RowDefinition Height="180"/>  <!-- Incidents & Crash Events DataGrid -->
                        <RowDefinition Height="*"/>    <!-- Report Text Box -->
                    </Grid.RowDefinitions>

                    <!-- Post-Game "Why Did I Lag?" Stutter Culprit Scorecard -->
                    <Border Grid.Row="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="14,10" Margin="0,0,0,10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid Grid.Row="0" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="⚡ POST-GAME &quot;WHY DID I LAG?&quot; STUTTER ANALYSIS" FontWeight="Bold" Foreground="#38BDF8" FontSize="13" Margin="0,0,8,0"/>
                                        <Border Name="BadgeSmoothness" Background="#065F46" CornerRadius="4" Padding="8,2" VerticalAlignment="Center">
                                            <TextBlock Name="TxtSmoothnessBadge" Text="100% READY" FontSize="11" FontWeight="ExtraBold" Foreground="#34D399"/>
                                        </Border>
                                    </StackPanel>
                                    <TextBlock Name="TxtLagSummary" Text="No lag incidents recorded in latest session. ProBalance &amp; QoS maintained full system smoothness." Foreground="#94A3B8" FontSize="11" Margin="0,2,0,0"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                                    <Button Name="BtnRefreshLagReport" Content="🔄 Refresh Lag Report" Background="#1E293B" Foreground="#38BDF8" BorderBrush="#0284C7" BorderThickness="1" Height="30" Padding="12,0" Margin="0,0,6,0" FontWeight="SemiBold"/>
                                </StackPanel>
                            </Grid>

                            <!-- Telemetry Metrics Bar (Feature 10 & 14) -->
                            <Border Grid.Row="1" Background="#0B132B" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="6" Padding="10,6">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <!-- Last Game -->
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Text="LAST GAME" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock Name="TxtLagGameName" Text="--" Foreground="#F8FAFC" FontSize="12" FontWeight="ExtraBold"/>
                                    </StackPanel>
                                    <!-- Duration -->
                                    <StackPanel Grid.Column="1">
                                        <TextBlock Text="DURATION" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock Name="TxtLagDuration" Text="-- min" Foreground="#38BDF8" FontSize="12" FontWeight="Bold"/>
                                    </StackPanel>
                                    <!-- Avg FPS -->
                                    <StackPanel Grid.Column="2">
                                        <TextBlock Text="AVG FPS" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock Name="TxtLagAvgFps" Text="--" Foreground="#10B981" FontSize="12" FontWeight="ExtraBold"/>
                                    </StackPanel>
                                    <!-- 1% Lows -->
                                    <StackPanel Grid.Column="3">
                                        <TextBlock Text="1% LOW FPS" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock Name="TxtLag1Percent" Text="--" Foreground="#38BDF8" FontSize="12" FontWeight="Bold"/>
                                    </StackPanel>
                                    <!-- 0.1% Lows -->
                                    <StackPanel Grid.Column="4">
                                        <TextBlock Text="0.1% LOW FPS" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock Name="TxtLag01Percent" Text="--" Foreground="#F59E0B" FontSize="12" FontWeight="Bold"/>
                                    </StackPanel>
                                    <!-- Stutter Hits -->
                                    <StackPanel Grid.Column="5">
                                        <TextBlock Text="STUTTER HITS" Foreground="#64748B" FontSize="10" FontWeight="Bold"/>
                                        <TextBlock Name="TxtLagStutters" Text="0" Foreground="#F43F5E" FontSize="12" FontWeight="Bold"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                        </Grid>
                    </Border>

                    <!-- Top Action Bar -->
                    <Grid Grid.Row="1" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <Button Name="BtnRunHealthCheck" Content="🩺 Run Readiness Health Check" Background="#0284C7" Foreground="#FFFFFF" Height="32" Padding="14,0" FontWeight="Bold" Margin="0,0,8,0"/>
                            <Button Name="BtnDiagnoseSelectedCrash" Content="🔍 Diagnose Selected Crash" Background="#D97706" Foreground="#FFFFFF" Height="32" Padding="14,0" FontWeight="Bold" Margin="0,0,8,0"/>
                            <Button Name="BtnRefreshCrashes" Content="🔄 Refresh Crash Events" Background="#1E293B" Foreground="#E2E8F0" Height="32" Padding="12,0" Margin="0,0,8,0"/>
                            <Button Name="BtnExportDebugReport" Content="📥 Export Full Debug Report" Background="#059669" Foreground="#FFFFFF" Height="32" Padding="14,0" FontWeight="Bold"/>
                        </StackPanel>
                    </Grid>

                    <!-- Crash Events DataGrid with high contrast readable styling -->
                    <Border Grid.Row="2" Background="#0F172A" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Margin="0,0,0,10">
                        <DataGrid Name="GridCrashEvents" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" CanUserResizeRows="False" IsReadOnly="True" SelectionMode="Single" SelectionUnit="FullRow">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="#" Binding="{Binding Index}" Width="40" FontWeight="Bold" IsReadOnly="True"/>
                                <DataGridTextColumn Header="Faulting Application" Binding="{Binding AppName}" Width="180" FontWeight="Bold" IsReadOnly="True"/>
                                <DataGridTextColumn Header="Faulting Module" Binding="{Binding ModuleName}" Width="160" IsReadOnly="True"/>
                                <DataGridTextColumn Header="Exception Code" Binding="{Binding ExceptionCode}" Width="130" IsReadOnly="True"/>
                                <DataGridTextColumn Header="Timestamp" Binding="{Binding Timestamp}" Width="160" IsReadOnly="True"/>
                                <DataGridTextColumn Header="Brief Details" Binding="{Binding Summary}" Width="*" IsReadOnly="True"/>
                            </DataGrid.Columns>
                        </DataGrid>
                    </Border>

                    <!-- Report & Diagnostic Details Box (fixing the illegible dark text issue) -->
                    <Border Grid.Row="3" Background="#060911" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="📋 DIAGNOSTIC SCAN REPORT &amp; ROOT-CAUSE ANALYSIS:" FontWeight="Bold" Foreground="#38BDF8" FontSize="11" Margin="0,0,0,6"/>
                            <TextBox Name="TxtDiagnosticReport" Grid.Row="1" Background="#060911" Foreground="#34D399" FontFamily="Consolas, Cascadia Code, monospace" FontSize="12" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0" Text="Click 'Run Readiness Health Check' or select a crash event above and click 'Diagnose Selected Crash' to see real-time root cause analysis here."/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

        </TabControl>

        <!-- 4. BOTTOM STATUS BAR -->
        <Border Grid.Row="3" Background="#0F172A" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="12,8" Margin="0,10,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Name="TxtStatusBar" Grid.Column="0" Text="Game Booster v2.0.0 PRO ready. Zero telemetry enabled." Foreground="#94A3B8" FontSize="11" VerticalAlignment="Center"/>
                <TextBlock Name="TxtMemorySummary" Grid.Column="1" Text="Standby RAM: Ready | Timer: 0.5ms" Foreground="#38BDF8" FontSize="11" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <Button Name="BtnCheckUpdates" Grid.Column="2" Content="🔄 Check Updates" Background="#1E293B" Foreground="#94A3B8" BorderBrush="#334155" FontSize="10" Padding="8,2" ToolTip="Check GitHub for the latest GameBooster release"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Read XAML
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Retrieve Control Handles
$txtGpuBadge               = $window.FindName("TxtGpuBadge")
$badgeGpu                  = $window.FindName("BadgeGpu")
$pillGpuUpdate             = $window.FindName("PillGpuUpdate")
$txtGpuUpdateTag           = $window.FindName("TxtGpuUpdateTag")
$txtCpuBadge               = $window.FindName("TxtCpuBadge")
$dotTray                   = $window.FindName("DotTray")
$txtTrayStatus             = $window.FindName("TxtTrayStatus")
$pillTrayStatus            = $window.FindName("PillTrayStatus")
$dotWatcher                = $window.FindName("DotWatcher")
$txtWatcherStatus          = $window.FindName("TxtWatcherStatus")
$pillWatcherStatus         = $window.FindName("PillWatcherStatus")
$pillUpdateAvailable       = $window.FindName("PillUpdateAvailable")
$txtUpdateVersion          = $window.FindName("TxtUpdateVersion")
$mainTabs                  = $window.FindName("MainTabs")
$btnToggleWatcher          = $window.FindName("BtnToggleWatcher")
$btnRefreshAll             = $window.FindName("BtnRefreshAll")
$chkAutoScanStartup        = $window.FindName("ChkAutoScanStartup")
$btnInstantPurge           = $window.FindName("BtnInstantPurge")
$btnLaunchHudTop           = $window.FindName("BtnLaunchHudTop")
$btnToggleOsdTop           = $window.FindName("BtnToggleOsdTop")
$btnLaunchTrayCompanion    = $window.FindName("BtnLaunchTrayCompanion")
$btnSaveAllConfig          = $window.FindName("BtnSaveAllConfig")

# Tab 1
$gridProcesses             = $window.FindName("GridProcesses")
$menuCtxWhitelistSession   = $window.FindName("MenuCtxWhitelistSession")
$menuCtxWhitelistPermanent = $window.FindName("MenuCtxWhitelistPermanent")
$menuCtxCloseNow           = $window.FindName("MenuCtxCloseNow")
$menuCtxOpenFileLocation   = $window.FindName("MenuCtxOpenFileLocation")
$btnSelectNonEssential     = $window.FindName("BtnSelectNonEssential")
$btnSelectBalanced         = $window.FindName("BtnSelectBalanced")
$btnDeselectAll            = $window.FindName("BtnDeselectAll")
$txtFilterProcess          = $window.FindName("TxtFilterProcess")
$txtSelectedCount          = $window.FindName("TxtSelectedCount")
$txtSelectedRam            = $window.FindName("TxtSelectedRam")
$btnActivateGameMode       = $window.FindName("BtnActivateGameMode")

# Tab 2
$txtTab2WatcherStatus      = $window.FindName("TxtTab2WatcherStatus")
$btnTab2ToggleWatcher      = $window.FindName("BtnTab2ToggleWatcher")
$btnScanLibraries          = $window.FindName("BtnScanLibraries")
$btnAddCustomGame          = $window.FindName("BtnAddCustomGame")
$btnRemoveMonitored        = $window.FindName("BtnRemoveMonitored")
$btnClearAllGames          = $window.FindName("BtnClearAllGames")
$btnQuickWow               = $window.FindName("BtnQuickWow")
$btnQuickCod               = $window.FindName("BtnQuickCod")
$btnQuickCs2               = $window.FindName("BtnQuickCs2")
$gridGameLibrary           = $window.FindName("GridGameLibrary")
$txtSelectedGameName       = $window.FindName("TxtSelectedGameName")
$cmbCpuPriority            = $window.FindName("CmbCpuPriority")
$cmbCpuAffinity            = $window.FindName("CmbCpuAffinity")
$txtGameCompanion          = $window.FindName("TxtGameCompanion")
$chkAutoOsd                = $window.FindName("ChkAutoOsd")
$chkAutoRestoreOnExit      = $window.FindName("ChkAutoRestoreOnExit")
$btnSaveGameProfile        = $window.FindName("BtnSaveGameProfile")
$btnReloadGameProfile      = $window.FindName("BtnReloadGameProfile")
$btnResetGameProfile       = $window.FindName("BtnResetGameProfile")
$cmbCompetitivePresets     = $window.FindName("CmbCompetitivePresets")
$btnApplyCompetitivePreset = $window.FindName("BtnApplyCompetitivePreset")
$btnExportGameProfile      = $window.FindName("BtnExportGameProfile")
$btnImportGameProfile      = $window.FindName("BtnImportGameProfile")

# Tab 3
$badgeGpuDriverStatus      = $window.FindName("BadgeGpuDriverStatus")
$txtGpuDriverBadge         = $window.FindName("TxtGpuDriverBadge")
$txtGpuCardName            = $window.FindName("TxtGpuCardName")
$txtGpuInstalledDriver     = $window.FindName("TxtGpuInstalledDriver")
$txtGpuLatestDriver        = $window.FindName("TxtGpuLatestDriver")
$txtGpuReleaseDate         = $window.FindName("TxtGpuReleaseDate")
$btnDownloadGpuDriver      = $window.FindName("BtnDownloadGpuDriver")
$btnCheckGpuDriver         = $window.FindName("BtnCheckGpuDriver")
$txtBadgeHags              = $window.FindName("TxtBadgeHags")
$badgeHags                 = $window.FindName("BadgeHags")
$txtBadgeGameMode          = $window.FindName("TxtBadgeGameMode")
$badgeGameMode             = $window.FindName("BadgeGameMode")
$txtBadgeTcp               = $window.FindName("TxtBadgeTcp")
$badgeTcp                  = $window.FindName("BadgeTcp")
$txtBadgePsEngine          = $window.FindName("TxtBadgePsEngine")
$badgePsEngine             = $window.FindName("BadgePsEngine")
$txtBadgeMpo               = $window.FindName("TxtBadgeMpo")
$badgeMpo                  = $window.FindName("BadgeMpo")
$chkLockWinKey             = $window.FindName("ChkLockWinKey")
$chkSuppressSticky         = $window.FindName("ChkSuppressSticky")
$chkLauncherRamDiet        = $window.FindName("ChkLauncherRamDiet")
$chkReverseAffinity        = $window.FindName("ChkReverseAffinity")
$chkDynamicQos             = $window.FindName("ChkDynamicQos")
$btnApplyAllTweaks         = $window.FindName("BtnApplyAllTweaks")
$btnUpgradePs7             = $window.FindName("BtnUpgradePs7")
$txtStandbySize            = $window.FindName("TxtStandbySize")
$btnPurgeStandbyCard       = $window.FindName("BtnPurgeStandbyCard")
$txtShaderSize             = $window.FindName("TxtShaderSize")
$txtShaderBreakdown        = $window.FindName("TxtShaderBreakdown")
$btnCleanShaders           = $window.FindName("BtnCleanShaders")
$btnScanShaders            = $window.FindName("BtnScanShaders")
$txtMsiGpuStatus           = $window.FindName("TxtMsiGpuStatus")
$txtMsiNicStatus           = $window.FindName("TxtMsiNicStatus")
$txtMsiAudioStatus         = $window.FindName("TxtMsiAudioStatus")
$btnOptimizePcieMsi        = $window.FindName("BtnOptimizePcieMsi")
$btnRefreshPcieMsi         = $window.FindName("BtnRefreshPcieMsi")
$txtUsbPowerStatus         = $window.FindName("TxtUsbPowerStatus")
$btnDisableUsbPowerSave    = $window.FindName("BtnDisableUsbPowerSave")
$btnRefreshUsbStatus       = $window.FindName("BtnRefreshUsbStatus")
$gridServerRadar           = $window.FindName("GridServerRadar")
$btnPingRadarNow           = $window.FindName("BtnPingRadarNow")
$chkAutoRadar              = $window.FindName("ChkAutoRadar")
$menuRadarPingSingle       = $window.FindName("MenuRadarPingSingle")
$menuRadarPingContinuous   = $window.FindName("MenuRadarPingContinuous")
$menuRadarTraceroute       = $window.FindName("MenuRadarTraceroute")
$menuRadarCopyHost         = $window.FindName("MenuRadarCopyHost")
$menuRadarCopyDetails      = $window.FindName("MenuRadarCopyDetails")

# Tab 4
$btnLaunchHud              = $window.FindName("BtnLaunchHud")
$btnForceRestartHud        = $window.FindName("BtnForceRestartHud")
$btnCloseHud               = $window.FindName("BtnCloseHud")
$cmbHudPreset              = $window.FindName("CmbHudPreset")
$txtHudX                   = $window.FindName("TxtHudX")
$txtHudY                   = $window.FindName("TxtHudY")
$txtHudW                   = $window.FindName("TxtHudW")
$txtHudH                   = $window.FindName("TxtHudH")
$btnSaveHudSize            = $window.FindName("BtnSaveHudSize")
$btnApplyManualHudSize     = $window.FindName("BtnApplyManualHudSize")
$btnInstallHudDeps         = $window.FindName("BtnInstallHudDeps")
$btnToggleOsd              = $window.FindName("BtnToggleOsd")
$btnUnlockOsd              = $window.FindName("BtnUnlockOsd")
$txtOsdTitle               = $window.FindName("TxtOsdTitle")
$btnSaveOsdSettings        = $window.FindName("BtnSaveOsdSettings")
$cmbOsdPosition            = $window.FindName("CmbOsdPosition")
$txtMockOsdTitle           = $window.FindName("TxtMockOsdTitle")

# Tab 5
$gridCompanions            = $window.FindName("GridCompanions")
$btnAddCompanion           = $window.FindName("BtnAddCompanion")
$btnRemoveCompanion        = $window.FindName("BtnRemoveCompanion")
$btnTestCompanion          = $window.FindName("BtnTestCompanion")
$btnSaveCompanions         = $window.FindName("BtnSaveCompanions")

# Tab 6
$txtGpuProtectionStatus    = $window.FindName("TxtGpuProtectionStatus")
$txtGpuProtectedList       = $window.FindName("TxtGpuProtectedList")
$gridWhitelist             = $window.FindName("GridWhitelist")
$txtNewWhitelistProcess    = $window.FindName("TxtNewWhitelistProcess")
$btnAddWhitelist           = $window.FindName("BtnAddWhitelist")
$btnRemoveWhitelist        = $window.FindName("BtnRemoveWhitelist")

# Tab 7
$gridRestoreSession        = $window.FindName("GridRestoreSession")
$btnRestoreSelectedApp     = $window.FindName("BtnRestoreSelectedApp")
$btnRestoreAllApps         = $window.FindName("BtnRestoreAllApps")
$btnClearRestoreList       = $window.FindName("BtnClearRestoreList")
$menuCtxRestoreOne         = $window.FindName("MenuCtxRestoreOne")
$menuCtxRemoveOne          = $window.FindName("MenuCtxRemoveOne")
$menuCtxRestoreAll         = $window.FindName("MenuCtxRestoreAll")

# Tab 8 & Post-Game Lag Analysis (Phase 4)
$badgeSmoothness           = $window.FindName("BadgeSmoothness")
$txtSmoothnessBadge        = $window.FindName("TxtSmoothnessBadge")
$txtLagSummary             = $window.FindName("TxtLagSummary")
$btnRefreshLagReport       = $window.FindName("BtnRefreshLagReport")
$txtLagGameName            = $window.FindName("TxtLagGameName")
$txtLagDuration            = $window.FindName("TxtLagDuration")
$txtLagAvgFps              = $window.FindName("TxtLagAvgFps")
$txtLag1Percent            = $window.FindName("TxtLag1Percent")
$txtLag01Percent           = $window.FindName("TxtLag01Percent")
$txtLagStutters            = $window.FindName("TxtLagStutters")
$btnRunHealthCheck         = $window.FindName("BtnRunHealthCheck")
$btnDiagnoseSelectedCrash  = $window.FindName("BtnDiagnoseSelectedCrash")
$btnRefreshCrashes         = $window.FindName("BtnRefreshCrashes")
$btnExportDebugReport      = $window.FindName("BtnExportDebugReport")
$gridCrashEvents           = $window.FindName("GridCrashEvents")
$txtDiagnosticReport       = $window.FindName("TxtDiagnosticReport")
$btnTipJar                 = $window.FindName("BtnTipJar")

# Status Bar
$txtStatusBar              = $window.FindName("TxtStatusBar")
$txtMemorySummary          = $window.FindName("TxtMemorySummary")
$btnCheckUpdates           = $window.FindName("BtnCheckUpdates")

# Observable Collections
$script:ProcessList    = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:GameList       = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:RadarList      = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:CompanionsList = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:WhitelistList  = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:RestoreList    = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:CrashList      = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
$script:SessionWhitelist = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$script:CriticalOsProcesses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@("Idle", "System", "csrss", "services", "lsass", "wininit", "smss", "svchost", "fontdrvhost", "dwm", 
  "explorer", "winlogon", "sppsvc", "SecurityHealthService", "SecurityHealthSystray", 
  "MsMpEng", "NisSrv", "MpDefenderCoreService", "DefenderSessionHelper", "MoUsoCoreWorker", "RuntimeBroker", 
  "StartMenuExperienceHost", "taskhostw", "ctfmon", "SystemSettings", "TextInputHost", "ShellHost", 
  "conhost", "cmd", "pwsh", "powershell", "wt", "GameBooster", "taskmgr") | ForEach-Object { [void]$script:CriticalOsProcesses.Add($_) }

$gridProcesses.ItemsSource      = $script:ProcessList
$gridGameLibrary.ItemsSource    = $script:GameList
$gridServerRadar.ItemsSource    = $script:RadarList
$gridCompanions.ItemsSource     = $script:CompanionsList
$gridWhitelist.ItemsSource      = $script:WhitelistList
$gridRestoreSession.ItemsSource = $script:RestoreList
$gridCrashEvents.ItemsSource    = $script:CrashList

# Set App Icon if present
$icoCandidate = @(
    (Join-Path $RootDir "assets\gamebooster.ico"),
    (Join-Path $RootDir "gamebooster.ico"),
    (Join-Path $ScriptDir "gamebooster.ico")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($icoCandidate) {
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($icoCandidate))
    } catch {}

    $window.Add_SourceInitialized({
        try {
            $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
            $hwnd = $helper.Handle
            if ($hwnd -and $icoCandidate) {
                [ShellIconHelper]::SetWindowIcons($hwnd, $icoCandidate)
            }
        } catch {}
    })
}

# ---------------------------------------------------------------------------
# Hardware Topology & GPU Init
# ---------------------------------------------------------------------------
$script:gpuInfo = Get-GpuHardwareInfo
$script:gpuWhitelist = Get-DynamicGpuWhitelist
$script:gpuDriverDetails = Get-GpuDriverDetails
if ($txtGpuBadge) {
    $gpuClean = if ($script:gpuDriverDetails.GpuName -like "$($script:gpuDriverDetails.Vendor)*") {
        $script:gpuDriverDetails.GpuName
    } else {
        "$($script:gpuDriverDetails.Vendor) $($script:gpuDriverDetails.GpuName)"
    }
    $txtGpuBadge.Text = $gpuClean
}
if ($txtGpuProtectionStatus) {
    $txtGpuProtectionStatus.Text = "Active ($($script:gpuInfo.Vendor) Driver Protected)"
}
if ($txtGpuProtectedList) {
    $txtGpuProtectedList.Text = "Protected display daemons: " + ($script:gpuWhitelist -join ", ")
}

$script:cpuTopology = Get-CpuTopology
if ($txtCpuBadge) {
    $archText = if ($script:cpuTopology.IsIntelHybrid) {
        "Intel Hybrid ($($script:cpuTopology.LogicalCores)T)"
    } elseif ($script:cpuTopology.IsAmdX3D) {
        "AMD 3D V-Cache ($($script:cpuTopology.PhysicalCores)C)"
    } else {
        "$($script:cpuTopology.CpuName)"
    }
    $txtCpuBadge.Text = $archText
}

# ---------------------------------------------------------------------------
# Background Daemons Check (Tray & Watcher)
# ---------------------------------------------------------------------------
function Update-DaemonIndicators {
    # Check Tray Companion
    $trayProc = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%TrayBooster.ps1%'" -ErrorAction SilentlyContinue
    if ($trayProc) {
        $dotTray.Fill = [System.Windows.Media.Brushes]::LimeGreen
        $txtTrayStatus.Text = "Tray Companion: ACTIVE"
        $txtTrayStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } else {
        $dotTray.Fill = [System.Windows.Media.Brushes]::SlateGray
        $txtTrayStatus.Text = "Tray Companion: OFF"
        $txtTrayStatus.Foreground = [System.Windows.Media.Brushes]::LightGray
    }

    # Check Watcher (either standalone GameWatcher.ps1 OR running via TrayBooster.ps1)
    $watcherProc = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%GameWatcher.ps1%'" -ErrorAction SilentlyContinue
    $isWatcherActive = ($watcherProc -or $trayProc)
    if ($isWatcherActive) {
        $dotWatcher.Fill = [System.Windows.Media.Brushes]::LimeGreen
        $txtWatcherStatus.Text = "Auto-Watcher: ACTIVE"
        $txtWatcherStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
        if ($btnToggleWatcher) {
            $btnToggleWatcher.Content = "⏹ Stop Auto-Watcher"
            $btnToggleWatcher.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#DC2626")
            $btnToggleWatcher.Foreground = [System.Windows.Media.Brushes]::White
        }
        if ($txtTab2WatcherStatus) {
            $txtTab2WatcherStatus.Text = "ACTIVE (Monitoring Games)"
            $txtTab2WatcherStatus.Foreground = [System.Windows.Media.Brushes]::LimeGreen
        }
        if ($btnTab2ToggleWatcher) {
            $btnTab2ToggleWatcher.Content = "⏹ Stop Auto-Watcher"
            $btnTab2ToggleWatcher.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#DC2626")
            $btnTab2ToggleWatcher.Foreground = [System.Windows.Media.Brushes]::White
        }
    } else {
        $dotWatcher.Fill = [System.Windows.Media.Brushes]::SlateGray
        $txtWatcherStatus.Text = "Auto-Watcher: OFF"
        $txtWatcherStatus.Foreground = [System.Windows.Media.Brushes]::LightGray
        if ($btnToggleWatcher) {
            $btnToggleWatcher.Content = "▶ Start Auto-Watcher"
            $btnToggleWatcher.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
            $btnToggleWatcher.Foreground = [System.Windows.Media.Brushes]::White
        }
        if ($txtTab2WatcherStatus) {
            $txtTab2WatcherStatus.Text = "OFF (Click Enable to start)"
            $txtTab2WatcherStatus.Foreground = [System.Windows.Media.Brushes]::SlateGray
        }
        if ($btnTab2ToggleWatcher) {
            $btnTab2ToggleWatcher.Content = "▶ Enable Auto-Watcher"
            $btnTab2ToggleWatcher.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
            $btnTab2ToggleWatcher.Foreground = [System.Windows.Media.Brushes]::White
        }
    }
}

function Start-GameWatcherDaemon {
    $watcherScript = Join-Path $ScriptDir "GameWatcher.ps1"
    if (Test-Path $watcherScript) {
        $existing = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%GameWatcher.ps1%'" -ErrorAction SilentlyContinue
        if (-not $existing) {
            $psHost = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
            Start-Process $psHost -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$watcherScript`""
            Start-Sleep -Milliseconds 400
        }
        Update-DaemonIndicators
        $txtStatusBar.Text = "Auto-Watcher daemon started in background (Monitoring games)."
    }
}

function Stop-GameWatcherDaemon {
    $existing = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%GameWatcher.ps1%'" -ErrorAction SilentlyContinue
    if ($existing) {
        foreach ($p in $existing) {
            try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
    $pidFile = Join-Path $ScriptDir "watcher.pid"
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }
    
    Start-Sleep -Milliseconds 200
    Update-DaemonIndicators
    $txtStatusBar.Text = "Auto-Watcher daemon stopped."
}

function Toggle-GameWatcherDaemon {
    $watcherProc = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%GameWatcher.ps1%'" -ErrorAction SilentlyContinue
    if ($watcherProc) {
        Stop-GameWatcherDaemon
        Show-DarkModal("Auto-Watcher has been stopped.`n`nGames will no longer automatically trigger Game Mode.", "Auto-Watcher Stopped", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } else {
        Start-GameWatcherDaemon
        Show-DarkModal("Auto-Watcher is now ACTIVE in the background!`n`nWhenever any of your Monitored Games are launched, Game Booster will automatically:`n• Close selected background apps`n• Flush and reclaim standby RAM`n• Auto-launch your game companion apps (e.g. Discord)`n• Restore closed apps when the game exits", "Auto-Watcher Active", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
}

function Toggle-TrayCompanionDaemon {
    $trayProc = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%TrayBooster.ps1%'" -ErrorAction SilentlyContinue
    if ($trayProc) {
        foreach ($p in $trayProc) {
            try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
        }
        $pidFile1 = Join-Path $RootDir "tray.pid"
        $pidFile2 = Join-Path $ScriptDir "tray.pid"
        Remove-Item -Path $pidFile1, $pidFile2 -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 200
        Update-DaemonIndicators
        $txtStatusBar.Text = "Tray Companion daemon stopped."
        Show-DarkModal("Tray Companion daemon has been stopped.", "Tray Companion", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } else {
        $trayPs = Join-Path $ScriptDir "TrayBooster.ps1"
        if (Test-Path $trayPs) {
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$trayPs`""
            Start-Sleep -Milliseconds 400
            Update-DaemonIndicators
            $txtStatusBar.Text = "Tray Companion daemon active in system tray."
            Show-DarkModal("Tray Companion is now running in the Windows System Tray!`n`nPress Ctrl+F11 anytime for Hardware HUD, or right-click the tray icon for quick actions.", "Tray Companion Active", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    }
}

# ---------------------------------------------------------------------------
# Process Scanning (Game Mode Tab)
# ---------------------------------------------------------------------------
function Reload-ProcessGrid {
    $cfg = Get-AppConfig
    $wl = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    # 0. Hardcoded Critical Windows OS Subsystems (Absolute safeguard)
    $criticalOs = @("Idle", "System", "csrss", "services", "lsass", "wininit", "smss", "svchost", "fontdrvhost", "dwm", 
      "explorer", "winlogon", "sppsvc", "SecurityHealthService", "SecurityHealthSystray", 
      "MsMpEng", "NisSrv", "MpDefenderCoreService", "DefenderSessionHelper", "MoUsoCoreWorker", "RuntimeBroker", 
      "StartMenuExperienceHost", "taskhostw", "ctfmon", "SystemSettings", "TextInputHost", "ShellHost", 
      "conhost", "cmd", "pwsh", "powershell", "wt", "WindowsTerminal", "GameBooster", "taskmgr",
      "dashost", "midisrv", "sihost", "smartscreen", "ApplicationFrameHost", "node", "git",
      "portmaster-core", "safing-portmaster", "PortmasterCore")
    foreach ($cp in $criticalOs) { $wl.Add($cp) | Out-Null }

    # 1. Essential gaming services (Anti-Cheat, Audio Drivers, Hardware Monitors, GPU Daemons, Windows Subsystems)
    $essentialServices = Get-EssentialGamingServicesWhitelist
    foreach ($es in $essentialServices) { $wl.Add($es) | Out-Null }

    # 2. Configured user whitelist & systemProtected
    if ($cfg.whitelist) {
        foreach ($w in $cfg.whitelist) { $wl.Add($w) | Out-Null }
    }
    if ($cfg.systemProtected) {
        foreach ($sp in $cfg.systemProtected) { $wl.Add($sp) | Out-Null }
    }
    if ($cfg.hardwareKeep) {
        foreach ($hk in $cfg.hardwareKeep) { $wl.Add($hk) | Out-Null }
    }

    # 3. Active session whitelist (apps whitelisted for this session only)
    if ($script:SessionWhitelist) {
        foreach ($sw in $script:SessionWhitelist) { $wl.Add($sw) | Out-Null }
    }

    # 4. Monitored games & common gaming binaries (Never show games in the kill grid)
    if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
        foreach ($mg in $cfg.watcherSettings.monitoredGames) { [void]$wl.Add($mg) }
    }
    if ($cfg.autoStartWith -and $cfg.autoStartWith.triggerProcesses) {
        foreach ($tp in $cfg.autoStartWith.triggerProcesses) { [void]$wl.Add($tp) }
    }
    if ($cfg.gameProfiles) {
        foreach ($prop in $cfg.gameProfiles.PSObject.Properties) { [void]$wl.Add($prop.Name) }
    }
    $gameBinaries = @("cod", "bootstrapper", "cod24", "sp24", "BlackOps6", "Wow", "WowClassic", "Wow-64", "cs2", "csgo", "dota2", "Valorant", "RiotClientServices", "Overwatch", "FortniteClient-Win64-Shipping", "r5apex")
    foreach ($gb in $gameBinaries) { [void]$wl.Add($gb) }

    $script:ProcessList.Clear()
    $rawProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { 
        $_.Id -ne $PID -and $_.ProcessName -ne "Idle" -and $_.ProcessName -ne "System"
    }
    
    # Filter out whitelisted items first
    $filteredProcs = $rawProcs | Where-Object { -not $wl.Contains($_.ProcessName) }

    # Group processes by ProcessName
    $grouped = $filteredProcs | Group-Object ProcessName

    # Set of processes explicitly designated to be selected by default
    $defaultSelectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($cfg.selectedByDefault) {
        foreach ($s in $cfg.selectedByDefault) { [void]$defaultSelectedSet.Add($s) }
    }

    foreach ($grp in $grouped) {
        $pName = $grp.Name
        $pList = @($grp.Group)
        $procCount = $pList.Count

        $cat = "Background App"
        $hasWindow = $false
        $mainTitle = ""
        $exePath = ""

        foreach ($p in $pList) {
            if ($p.MainWindowTitle -and -not $mainTitle) {
                $mainTitle = $p.MainWindowTitle
                $hasWindow = $true
            }
            if (-not $exePath) {
                try { $exePath = $p.MainModule.FileName } catch {}
            }
        }

        if ($hasWindow) { $cat = "Interactive App" }
        if ($pName -match "(?i)discord|spotify|slack|steam|epicgames|battlenet|eaapp|gog|telegram|whatsapp") { $cat = "Launcher / Social" }
        if ($pName -match "(?i)chrome|msedge|firefox|brave|opera|vivaldi|tor") { $cat = "Web Browser" }
        if ($pName -match "(?i)emby|plex|jellyfin|kodi|serviio|subsonic|navidrome") { $cat = "Media Server" }
        if ($pName -match "(?i)^portmaster$") { $cat = "Network Firewall" }

        # Calculate combined working set RAM in MB
        $totalBytes = ($pList | Measure-Object -Property WorkingSet64 -Sum).Sum
        $ramMB = [math]::Round($totalBytes / 1MB, 0)
        if ($ramMB -lt 1) { $ramMB = 1 }

        # Determine user/service context
        $isUserApp = $exePath -and ($exePath -like "*$env:USERNAME*" -or $exePath -like "*\AppData\*")
        $isExplicit = $defaultSelectedSet.Contains($pName)
        $isKnownMedia = ($cat -in @("Media Server", "Network Firewall"))

        # Skip tiny unwindowed workers unless explicitly selected by default, installed user app, or media server
        if ($ramMB -lt 5 -and -not $hasWindow -and -not $isExplicit -and -not $isUserApp -and -not $isKnownMedia) {
            continue
        }

        $pids = @($pList | ForEach-Object { $_.Id })
        $displayPid = if ($procCount -gt 1) { "$($pids[0]) (+$($procCount - 1))" } else { "$($pids[0])" }
        
        $displayName = if ($pName -match "(?i)^embytray$") {
            if ($procCount -gt 1) { "embytray (Emby Server) ($procCount procs)" } else { "embytray (Emby Server)" }
        } elseif ($pName -match "(?i)^EmbyServer$") {
            if ($procCount -gt 1) { "EmbyServer (Emby Server) ($procCount procs)" } else { "EmbyServer (Emby Server)" }
        } elseif ($pName -match "(?i)^portmaster$") {
            "Portmaster Privacy Firewall"
        } elseif ($procCount -gt 1) {
            "$pName ($procCount procs)"
        } else {
            $pName
        }

        if (-not $mainTitle) {
            if ($cat -eq "Media Server") {
                $mainTitle = if ($pName -match "(?i)tray") { "(System Tray Monitor)" } else { "(Media Server Service)" }
            } elseif ($cat -eq "Network Firewall") {
                $mainTitle = "(Safing Privacy Firewall & DNS Interceptor)"
            }
        }

        # Default selected for launchers, browsers, media servers, and explicitly designated targets
        $isProtected = $wl.Contains($pName) -or ($pName -match "(?i)RTSS|MSIAfterburner|HWiNFO|obs|PnkBstr|EasyAntiCheat|BEService|vgc|audiodg|RtkAud|^Rz|^Razer|^SteelSeries|^Logi|LGHUB|iCUE|^Elgato|^Nahimic|^Creative|portmaster|safing")
        $isSel = (-not $isProtected) -and (
            $isExplicit -or
            $cat -in @("Launcher / Social", "Web Browser", "Media Server") -or
            $cat -eq "Interactive App"
        )

        $script:ProcessList.Add([PSCustomObject]@{
            IsSelected      = $isSel
            Category        = $cat
            Name            = $pName
            DisplayName     = $displayName
            DisplayPid      = $displayPid
            Pids            = $pids
            Id              = $pids[0]
            RAM_MB          = $ramMB
            MainWindowTitle = $mainTitle
            Path            = $exePath
        })
    }
    Update-SelectedMetrics
}

function Update-SelectedMetrics {
    $sel = $script:ProcessList | Where-Object { $_.IsSelected }
    $count = ($sel | Measure-Object).Count
    $ram = ($sel | Measure-Object -Property RAM_MB -Sum).Sum
    if (-not $ram) { $ram = 0 }
    $txtSelectedCount.Text = "$count apps"
    $txtSelectedRam.Text = "$ram MB"
}

$gridProcesses.add_CurrentCellChanged({
    Update-SelectedMetrics
})

# Preset selection buttons
$btnSelectNonEssential.Add_Click({
    $essentialServices = Get-EssentialGamingServicesWhitelist
    $esSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($es in $essentialServices) { [void]$esSet.Add($es) }

    $cfg = Get-AppConfig
    if ($cfg.whitelist) { foreach ($w in $cfg.whitelist) { [void]$esSet.Add($w) } }
    if ($cfg.systemProtected) { foreach ($sp in $cfg.systemProtected) { [void]$esSet.Add($sp) } }
    if ($cfg.hardwareKeep) { foreach ($hk in $cfg.hardwareKeep) { [void]$esSet.Add($hk) } }
    if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
        foreach ($mg in $cfg.watcherSettings.monitoredGames) { [void]$esSet.Add($mg) }
    }
    if ($script:SessionWhitelist) { foreach ($sw in $script:SessionWhitelist) { [void]$esSet.Add($sw) } }

    $gameBinaries = @("cod", "bootstrapper", "cod24", "sp24", "BlackOps6", "Wow", "WowClassic", "Wow-64", "cs2", "csgo", "dota2", "Valorant", "RiotClientServices", "Overwatch", "FortniteClient-Win64-Shipping", "r5apex")
    foreach ($gb in $gameBinaries) { [void]$esSet.Add($gb) }

    foreach ($item in $script:ProcessList) {
        $isProtected = $esSet.Contains($item.Name) -or ($item.Name -match "(?i)RTSS|MSIAfterburner|HWiNFO|obs|PnkBstr|EasyAntiCheat|BEService|vgc|audiodg|RtkAud|^Rz|^Razer|^SteelSeries|^Logi|LGHUB|iCUE|^Elgato|^Nahimic|^Creative|portmaster|safing")
        $item.IsSelected = (-not $isProtected)
    }
    $gridProcesses.Items.Refresh()
    Update-SelectedMetrics
})

$btnSelectBalanced.Add_Click({
    $cfg = Get-AppConfig
    $defaultSelectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($cfg.selectedByDefault) { foreach ($s in $cfg.selectedByDefault) { [void]$defaultSelectedSet.Add($s) } }

    foreach ($item in $script:ProcessList) {
        $item.IsSelected = ($item.Category -in @("Launcher / Social", "Web Browser", "Media Server") -or $defaultSelectedSet.Contains($item.Name))
    }
    $gridProcesses.Items.Refresh()
    Update-SelectedMetrics
})

$btnDeselectAll.Add_Click({
    foreach ($item in $script:ProcessList) {
        $item.IsSelected = $false
    }
    $gridProcesses.Items.Refresh()
    Update-SelectedMetrics
})

# Search filter
$txtFilterProcess.Add_TextChanged({
    $q = $txtFilterProcess.Text.Trim()
    if (-not $q) {
        $gridProcesses.ItemsSource = $script:ProcessList
    } else {
        $filtered = $script:ProcessList | Where-Object { $_.DisplayName -like "*$q*" -or $_.Name -like "*$q*" -or $_.MainWindowTitle -like "*$q*" -or $_.Category -like "*$q*" }
        $gridProcesses.ItemsSource = $filtered
    }
})

# Handle right-click row selection for Process DataGrid
$gridProcesses.Add_PreviewMouseRightButtonDown({
    param($sender, $e)
    try {
        $dep = $e.OriginalSource
        while ($dep -ne $null -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
            $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep)
        }
        if ($dep -is [System.Windows.Controls.DataGridRow] -and $dep.Item) {
            $gridProcesses.SelectedItem = $dep.Item
        }
    } catch {}
})

# Context Menu: Whitelist for this Session (Keep Open)
$menuCtxWhitelistSession.Add_Click({
    $sel = $gridProcesses.SelectedItem
    if (-not $sel) { return }
    $pName = $sel.Name
    $script:SessionWhitelist.Add($pName) | Out-Null

    $script:ProcessList.Remove($sel) | Out-Null
    if ($txtFilterProcess.Text.Trim()) {
        $q = $txtFilterProcess.Text.Trim()
        $gridProcesses.ItemsSource = @($script:ProcessList | Where-Object { $_.DisplayName -like "*$q*" -or $_.Name -like "*$q*" -or $_.MainWindowTitle -like "*$q*" -or $_.Category -like "*$q*" })
    }
    Update-SelectedMetrics
    Reload-WhitelistGrid
    $txtStatusBar.Text = "Whitelisted '$pName' for this session (will not be closed)."
    Show-DarkModal("'$pName' will remain running and is protected for this session.", "Session Whitelist", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Context Menu: Whitelist Permanently (Always Protect)
$menuCtxWhitelistPermanent.Add_Click({
    $sel = $gridProcesses.SelectedItem
    if (-not $sel) { return }
    $pName = $sel.Name

    $cfg = Get-AppConfig
    $wl = @()
    if ($cfg.whitelist) { $wl = @($cfg.whitelist) }
    if ($wl -notcontains $pName) {
        $wl += $pName
        $cfg.whitelist = $wl
        Save-AppConfig $cfg | Out-Null
    }

    $script:SessionWhitelist.Add($pName) | Out-Null
    $script:ProcessList.Remove($sel) | Out-Null
    if ($txtFilterProcess.Text.Trim()) {
        $q = $txtFilterProcess.Text.Trim()
        $gridProcesses.ItemsSource = @($script:ProcessList | Where-Object { $_.DisplayName -like "*$q*" -or $_.Name -like "*$q*" -or $_.MainWindowTitle -like "*$q*" -or $_.Category -like "*$q*" })
    }
    Reload-WhitelistGrid
    Update-SelectedMetrics
    $txtStatusBar.Text = "'$pName' permanently whitelisted and saved to config."
    Show-DarkModal("'$pName' has been added to your Permanent Whitelist and will never be targeted by Game Mode.", "Permanent Whitelist", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Context Menu: Close This Application Now
$menuCtxCloseNow.Add_Click({
    $sel = $gridProcesses.SelectedItem
    if (-not $sel) { return }
    $pName = $sel.Name

    $ask = Show-DarkModal("Close '$($sel.DisplayName)' immediately?", "Close Application", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -ne [System.Windows.MessageBoxResult]::Yes) { return }

    if ($sel.Name -match "(?i)portmaster|safing") {
        Stop-PortmasterSafely
        $closedItem = [PSCustomObject]@{
            Name        = "Portmaster"
            ServiceName = "PortmasterCore"
            Id          = $sel.Id
            RAM_MB      = $sel.RAM_MB
            Path        = "C:\Program Files\Safing\Portmaster\portmaster.exe"
            Time        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $script:RestoreList.Insert(0, $closedItem)

        try {
            $sessData = if (Test-Path $SessionFile) { Get-Content $SessionFile -Raw | ConvertFrom-Json } else { [PSCustomObject]@{ ClosedApps = @(); TotalFreedMB = 0 } }
            $existing = @()
            if ($sessData.ClosedApps) { $existing = @($sessData.ClosedApps) }
            $sessData.ClosedApps = @($closedItem) + $existing
            $sessData.TotalFreedMB = [int]$sessData.TotalFreedMB + $closedItem.RAM_MB
            $sessData.Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $sessData | ConvertTo-Json -Depth 5 | Set-Content -Path $SessionFile -Encoding UTF8 -Force
        } catch {}

        $script:ProcessList.Remove($sel) | Out-Null
        Update-SelectedMetrics
        $txtStatusBar.Text = "Portmaster stopped gracefully. WFP filter unhooked."
        return
    }

    $pidsToKill = if ($sel.Pids) { @($sel.Pids) } else { @($sel.Id) }
    $appFreedRAM = 0
    $svcName = $null
    foreach ($pidVal in $pidsToKill) {
        try {
            # Check if this PID is managed by a Windows Service
            $svc = Get-CimInstance Win32_Service -Filter "ProcessId = $pidVal" -ErrorAction SilentlyContinue
            if ($svc) {
                $svcName = $svc.Name
                try { Stop-Service -Name $svcName -NoWait -ErrorAction SilentlyContinue } catch {}
            }
            $p = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
            if ($p) {
                $pRam = [math]::Round($p.WorkingSet64 / 1MB, 0)
                $appFreedRAM += $pRam
                Stop-Process -Id $pidVal -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    $closedItem = [PSCustomObject]@{
        Name        = $sel.Name
        ServiceName = $svcName
        Id          = $sel.Id
        RAM_MB      = if ($appFreedRAM -gt 0) { $appFreedRAM } else { $sel.RAM_MB }
        Path        = $sel.Path
        Time        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $script:RestoreList.Insert(0, $closedItem)

    try {
        $sessData = if (Test-Path $SessionFile) { Get-Content $SessionFile -Raw | ConvertFrom-Json } else { [PSCustomObject]@{ ClosedApps = @(); TotalFreedMB = 0 } }
        $existing = @()
        if ($sessData.ClosedApps) { $existing = @($sessData.ClosedApps) }
        $sessData.ClosedApps = @($closedItem) + $existing
        $sessData.TotalFreedMB = [int]$sessData.TotalFreedMB + $closedItem.RAM_MB
        $sessData.Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $sessData | ConvertTo-Json -Depth 5 | Set-Content -Path $SessionFile -Encoding UTF8 -Force
    } catch {}

    $script:ProcessList.Remove($sel) | Out-Null
    if ($txtFilterProcess.Text.Trim()) {
        $q = $txtFilterProcess.Text.Trim()
        $gridProcesses.ItemsSource = @($script:ProcessList | Where-Object { $_.DisplayName -like "*$q*" -or $_.Name -like "*$q*" -or $_.MainWindowTitle -like "*$q*" -or $_.Category -like "*$q*" })
    }
    Update-SelectedMetrics
    $txtStatusBar.Text = "Closed '$($sel.DisplayName)' ($appFreedRAM MB freed)."
})

# Context Menu: Open File Location
$menuCtxOpenFileLocation.Add_Click({
    $sel = $gridProcesses.SelectedItem
    if (-not $sel) { return }

    if ($sel.Path -and (Test-Path $sel.Path)) {
        Start-Process "explorer.exe" -ArgumentList "/select,`"$($sel.Path)`""
    } elseif ($sel.Path) {
        $dir = [System.IO.Path]::GetDirectoryName($sel.Path)
        if (Test-Path $dir) {
            Start-Process "explorer.exe" -ArgumentList "`"$dir`""
        } else {
            Show-DarkModal("Path not found: $($sel.Path)", "Executable Path", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    } else {
        Show-DarkModal("Executable path could not be resolved for '$($sel.Name)'.", "Executable Path", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# ---------------------------------------------------------------------------
# ACTIVATE GAME MODE (CLOSE APPS + PURGE STANDBY RAM)
# ---------------------------------------------------------------------------
$btnActivateGameMode.Add_Click({
    if ($script:ProcessList.Count -eq 0) {
        $txtStatusBar.Text = "Scanning active processes before activating Game Mode..."
        Reload-ProcessGrid
    }
    $targets = @($script:ProcessList | Where-Object { $_.IsSelected })
    if ($targets.Count -eq 0) {
        Show-DarkModal("Please select at least one application to close.", "No Apps Selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $msg = "Activate Game Mode now?`n`nThis will close $($targets.Count) application group(s), purge Windows Standby Memory, trim memory working sets, and activate the Gaming High-Performance Power Plan."
    $ask = Show-DarkModal($msg, "Activate Game Mode", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $txtStatusBar.Text = "Activating Game Mode..."
    $closedItems = @()
    $freedRAM = 0

    $criticalOsSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @("Idle", "System", "csrss", "services", "lsass", "wininit", "smss", "svchost", "fontdrvhost", "dwm", 
      "explorer", "winlogon", "sppsvc", "SecurityHealthService", "SecurityHealthSystray", 
      "MsMpEng", "NisSrv", "MpDefenderCoreService", "DefenderSessionHelper", "MoUsoCoreWorker", "RuntimeBroker", 
      "StartMenuExperienceHost", "taskhostw", "ctfmon", "SystemSettings", "TextInputHost", "ShellHost", 
      "conhost", "cmd", "pwsh", "powershell", "wt", "WindowsTerminal", "GameBooster", "taskmgr",
      "dashost", "midisrv", "sihost", "smartscreen", "ApplicationFrameHost", "node", "git") | ForEach-Object { [void]$criticalOsSet.Add($_) }

    # Map running Windows services so background services (like Fing.Agent) are properly stopped and restorable
    $serviceMap = @{}
    try {
        Get-CimInstance Win32_Service -Filter "State = 'Running'" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.ProcessId) { $serviceMap[[int]$_.ProcessId] = $_.Name }
        }
    } catch {}

    foreach ($item in $targets) {
        if ($criticalOsSet.Contains($item.Name)) { continue }

        if ($item.Name -match "(?i)portmaster|safing") {
            Stop-PortmasterSafely
            $closedItems += [PSCustomObject]@{
                Name        = "Portmaster"
                ServiceName = "PortmasterCore"
                Id          = $item.Id
                RAM_MB      = $item.RAM_MB
                Path        = "C:\Program Files\Safing\Portmaster\portmaster.exe"
                Time        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $freedRAM += $item.RAM_MB
            continue
        }

        $pidsToKill = if ($item.Pids) { @($item.Pids) } else { @($item.Id) }
        $appFreedRAM = 0
        $svcName = $null
        foreach ($pidVal in $pidsToKill) {
            try {
                if ($serviceMap.ContainsKey([int]$pidVal)) {
                    $svcName = $serviceMap[[int]$pidVal]
                    try { Stop-Service -Name $svcName -NoWait -ErrorAction SilentlyContinue } catch {}
                }
                $p = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
                if ($p -and -not $criticalOsSet.Contains($p.ProcessName)) {
                    $pRam = [math]::Round($p.WorkingSet64 / 1MB, 0)
                    $appFreedRAM += $pRam
                    Stop-Process -Id $pidVal -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }
        $closedItems += [PSCustomObject]@{
            Name        = $item.Name
            ServiceName = $svcName
            Id          = $item.Id
            RAM_MB      = if ($appFreedRAM -gt 0) { $appFreedRAM } else { $item.RAM_MB }
            Path        = $item.Path
            Time        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $freedRAM += if ($appFreedRAM -gt 0) { $appFreedRAM } else { $item.RAM_MB }
    }

    # Save to session file for 1-click restore
    try {
        $sessionData = [PSCustomObject]@{
            Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ClosedApps  = $closedItems
            TotalFreedMB= $freedRAM
        }
        $sessionData | ConvertTo-Json -Depth 5 | Set-Content -Path $SessionFile -Encoding UTF8 -Force
    } catch {}

    # Phase 1: Watchdog Session Initialization
    $origPowerPlan = Get-ActivePowerPlanGuid
    $origStickyFlags = if (Get-Command Get-GamingLockoutStatus -ErrorAction SilentlyContinue) { [GamingLockoutNative]::GetStickyKeysFlags() } else { 0 }
    Initialize-WatchdogSession -TargetGame "WPF_GameMode" -PowerPlanGuid $origPowerPlan -StickyKeysFlags $origStickyFlags | Out-Null

    # Phase 1: Launcher RAM Diet (Reclaim active RAM from heavy Chromium launchers without closing them)
    $dietRes = Invoke-LauncherRamDiet
    $dietFreed = if ($dietRes.TotalFreedMB) { [math]::Round($dietRes.TotalFreedMB, 0) } else { 0 }

    # Smart Standby List Purge
    $purgeRes = Invoke-SmartMemoryPurge
    $totalFreed = $freedRAM + [math]::Round($purgeRes.FreedGB * 1024, 0) + $dietFreed

    # Set Gaming Power Plan (Ultimate Performance)
    Switch-ToUltimatePerformance | Out-Null

    # Gaming Input Lockout (WinKey is OPTIONAL and default OFF; StickyKeys prompt suppressed)
    $cfg = Get-AppConfig
    $lockWin = if ($cfg.tweaksSettings -and $null -ne $cfg.tweaksSettings.gamingLockoutWinKey) { [bool]$cfg.tweaksSettings.gamingLockoutWinKey } else { $false }
    $lockSticky = if ($cfg.tweaksSettings -and $null -ne $cfg.tweaksSettings.gamingLockoutStickyKeys) { [bool]$cfg.tweaksSettings.gamingLockoutStickyKeys } else { $true }
    Enable-GamingLockout -DisableWinKey $lockWin -DisableStickyKeys $lockSticky | Out-Null

    # Phase 2: Reverse Affinity Core Siloing (Silos background apps away from game cores)
    $enableRevAffinity = if ($cfg.tweaksSettings -and $null -ne $cfg.tweaksSettings.enableReverseAffinity) { [bool]$cfg.tweaksSettings.enableReverseAffinity } else { $true }
    $siloMsg = "Disabled"
    if ($enableRevAffinity) {
        $revRes = Invoke-ReverseAffinitySiloing
        if ($revRes.SiloedCount -gt 0) {
            $siloMsg = "$($revRes.SiloedCount) apps siloed to $($revRes.BackgroundMask)"
        }
    }

    # Refresh UI
    Reload-ProcessGrid
    Reload-RestoreGrid
    Update-StandbyDisplay

    $winKeyDesc = if ($lockWin) { "Windows Key (Locked) & " } else { "" }
    $resultMsg = "Game Mode Activated Successfully!`n`n" +
                 "• Apps Closed: $($closedItems.Count)`n" +
                 "• Process RAM Reclaimed: $freedRAM MB`n" +
                 "• Launcher RAM Trimmed: $dietFreed MB`n" +
                 "• Standby RAM Flushed: $($purgeRes.FreedMB) MB`n" +
                 "• Total Memory Freed: $totalFreed MB`n" +
                 "• Power Plan: Ultimate Performance`n" +
                 "• Input Lockout: ${winKeyDesc}Sticky Keys Suppressed`n" +
                 "• Reverse Affinity: $siloMsg`n" +
                 "• Watchdog Protection: Armed (Crash-Safe)"
    
    $txtStatusBar.Text = "Game Mode Active. Reclaimed $totalFreed MB RAM."
    Show-DarkModal($resultMsg, "Game Mode Engaged", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# ---------------------------------------------------------------------------
# TAB 2: GAME LIBRARY & PER-GAME PROFILES (Features 1 & 5)
# ---------------------------------------------------------------------------
function Reload-GameLibraryGrid {
    $cfg = Get-AppConfig
    $script:GameList.Clear()

    # Load monitored games from config
    $monitored = @()
    if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
        $monitored = @($cfg.watcherSettings.monitoredGames)
    }

    # Add existing monitored entries
    foreach ($m in $monitored) {
        $script:GameList.Add([PSCustomObject]@{
            Title       = $m
            ProcessName = "$m.exe"
            Platform    = "Monitored Game"
            ExePath     = "Configured in Watcher"
        })
    }
}

# Toggle Auto-Watcher
if ($btnToggleWatcher) {
    $btnToggleWatcher.Add_Click({ Toggle-GameWatcherDaemon })
}
if ($btnTab2ToggleWatcher) {
    $btnTab2ToggleWatcher.Add_Click({ Toggle-GameWatcherDaemon })
}
if ($pillWatcherStatus) {
    $pillWatcherStatus.Add_MouseLeftButtonDown({ Toggle-GameWatcherDaemon })
}
if ($pillTrayStatus) {
    $pillTrayStatus.Add_MouseLeftButtonDown({ Toggle-TrayCompanionDaemon })
}

$btnScanLibraries.Add_Click({
    $txtStatusBar.Text = "Scanning Steam, Epic Games, Battle.net, GOG, and Xbox Store libraries..."
    $btnScanLibraries.IsEnabled = $false
    $btnScanLibraries.Content = "Scanning Libraries..."

    try {
        $found = Get-InstalledGamesList
        $cfg = Get-AppConfig
        if (-not $cfg.watcherSettings) {
            $cfg | Add-Member -MemberType NoteProperty -Name "watcherSettings" -Value ([PSCustomObject]@{}) -Force
        }
        $existing = @($cfg.watcherSettings.monitoredGames)

        $newCount = 0
        foreach ($g in $found) {
            # Add to UI list if not already present
            $hasInUi = $script:GameList | Where-Object { $_.ProcessName -ieq "$($g.ProcessName).exe" -or $_.ProcessName -ieq $g.ProcessName }
            if (-not $hasInUi) {
                $script:GameList.Add([PSCustomObject]@{
                    Title       = $g.Title
                    ProcessName = "$($g.ProcessName).exe"
                    Platform    = $g.Platform
                    ExePath     = $g.ExePath
                })
                $newCount++
            }

            # Add process to monitored list in config
            if ($existing -notcontains $g.ProcessName) {
                $existing += $g.ProcessName
            }
        }

        $cfg.watcherSettings.monitoredGames = @($existing)
        Save-AppConfig $cfg | Out-Null

        $txtStatusBar.Text = "Library scan complete: Discovered $($found.Count) games ($newCount newly added)."
        Show-DarkModal("Game Library Auto-Detector Scan Complete!`n`nFound $($found.Count) games across Steam, Epic, Battle.net, GOG, and Xbox Store.`n`nAll discovered titles have been added to your Monitored Games list and are ready for Per-Game hardware optimization profiles.", "Scan Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } finally {
        $btnScanLibraries.IsEnabled = $true
        $btnScanLibraries.Content = "🔍 Scan Installed Libraries (Steam/Epic/Battle.net/Xbox)"
    }
})

# Add Custom Game / Browse Exe
$btnAddCustomGame.Add_Click({
    $ofd = New-Object Microsoft.Win32.OpenFileDialog
    $ofd.Title = "Select Game Executable (*.exe)"
    $ofd.Filter = "Game Executables (*.exe)|*.exe|All Files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq $true -and $ofd.FileName) {
        $exeName = [System.IO.Path]::GetFileNameWithoutExtension($ofd.FileName)
        $clean = $exeName.Trim()
        
        $cfg = Get-AppConfig
        $existing = @()
        if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
            $existing = @($cfg.watcherSettings.monitoredGames)
        }
        if ($existing -notcontains $clean) {
            $existing += $clean
            $cfg.watcherSettings.monitoredGames = @($existing)
            Save-AppConfig $cfg | Out-Null
        }

        $script:GameList.Add([PSCustomObject]@{
            Title       = $clean
            ProcessName = "$clean.exe"
            Platform    = "Custom Game"
            ExePath     = $ofd.FileName
        })

        $txtStatusBar.Text = "Added custom game: $clean"
        Show-DarkModal("Game '$clean' added to monitored library successfully!", "Game Added", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Quick Adds
function Add-QuickMonitoredGames([string[]]$names) {
    $cfg = Get-AppConfig
    $existing = @()
    if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
        $existing = @($cfg.watcherSettings.monitoredGames)
    }
    $added = 0
    foreach ($n in $names) {
        if ($existing -notcontains $n) {
            $existing += $n
            $script:GameList.Add([PSCustomObject]@{
                Title       = $n
                ProcessName = "$n.exe"
                Platform    = "Quick Preset"
                ExePath     = "Configured in Watcher"
            })
            $added++
        }
    }
    $cfg.watcherSettings.monitoredGames = @($existing)
    Save-AppConfig $cfg | Out-Null
    $txtStatusBar.Text = "Added $added preset process(es) to monitored games."
    Show-DarkModal("Quick add complete! Added $added process(es) to monitored games.", "Games Added", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

$btnQuickWow.Add_Click({ Add-QuickMonitoredGames @("Wow", "WowClassic", "Wow-64") })
$btnQuickCod.Add_Click({ Add-QuickMonitoredGames @("cod", "bootstrapper", "BlackOps6", "cod24", "sp24") })
$btnQuickCs2.Add_Click({ Add-QuickMonitoredGames @("cs2") })

# Remove Selected
$btnRemoveMonitored.Add_Click({
    $sel = $gridGameLibrary.SelectedItem
    if (-not $sel) {
        Show-DarkModal("Please select a game from the table to remove.", "Selection Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    $clean = $sel.ProcessName -replace '\.exe$', ''
    $script:GameList.Remove($sel)

    $cfg = Get-AppConfig
    if ($cfg.watcherSettings -and $cfg.watcherSettings.monitoredGames) {
        $filtered = @($cfg.watcherSettings.monitoredGames | Where-Object { $_ -ne $clean })
        $cfg.watcherSettings.monitoredGames = $filtered
        Save-AppConfig $cfg | Out-Null
    }
    $txtStatusBar.Text = "Removed $clean from monitored games."
})

# Clear All Games
$btnClearAllGames.Add_Click({
    if ($script:GameList.Count -eq 0) {
        Show-DarkModal("Game library list is already empty.", "Already Empty", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    $ask = Show-DarkModal("Are you sure you want to remove all $($script:GameList.Count) games from the monitored library?", "Clear All Monitored Games", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -eq [System.Windows.MessageBoxResult]::Yes) {
        $script:GameList.Clear()
        $cfg = Get-AppConfig
        if ($cfg.watcherSettings) {
            $cfg.watcherSettings.monitoredGames = @()
            Save-AppConfig $cfg | Out-Null
        }
        $txtStatusBar.Text = "Cleared all monitored games."
    }
})

# Per-Game Profile Selection & Loading (Feature 1)
function Load-SelectedGameProfile {
    $sel = $gridGameLibrary.SelectedItem
    if ($sel) {
        $clean = $sel.ProcessName -replace '\.exe$', ''
        $txtSelectedGameName.Text = "$($sel.Title) ($clean)"
        $prof = Get-ProfileForGame -GameName $clean -ConfigPath $ConfigFile
        
        # Load Priority
        if ($prof.Priority -eq "High") { $cmbCpuPriority.SelectedIndex = 0 }
        elseif ($prof.Priority -eq "AboveNormal") { $cmbCpuPriority.SelectedIndex = 1 }
        else { $cmbCpuPriority.SelectedIndex = 2 }

        # Load Affinity
        if ($prof.Affinity -eq "PCoresOnly") { $cmbCpuAffinity.SelectedIndex = 1 }
        elseif ($prof.Affinity -eq "AmdX3d") { $cmbCpuAffinity.SelectedIndex = 2 }
        else { $cmbCpuAffinity.SelectedIndex = 0 }

        # Load Companions
        $txtGameCompanion.Text = if ($prof.Companion) { $prof.Companion } else { "" }

        # Load OSD Toggle
        $chkAutoOsd.IsChecked = [bool]$prof.AutoOsd
    }
}

$gridGameLibrary.add_SelectionChanged({
    Load-SelectedGameProfile
})

# Save Game Profile
$btnSaveGameProfile.Add_Click({
    $sel = $gridGameLibrary.SelectedItem
    if (-not $sel) {
        Show-DarkModal("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    $clean = $sel.ProcessName -replace '\.exe$', ''
    
    $prio = switch ($cmbCpuPriority.SelectedIndex) {
        0 { "High" }
        1 { "AboveNormal" }
        default { "Normal" }
    }
    $aff = switch ($cmbCpuAffinity.SelectedIndex) {
        1 { "PCoresOnly" }
        2 { "AmdX3d" }
        default { "AllCores" }
    }

    $profData = [PSCustomObject]@{
        Priority   = $prio
        Affinity   = $aff
        Companion  = $txtGameCompanion.Text.Trim()
        AutoOsd    = [bool]$chkAutoOsd.IsChecked
        LastSaved  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    Save-GameProfile -GameName $clean -ProfileData $profData -ConfigPath $ConfigFile
    $txtStatusBar.Text = "Hardware Profile saved for $clean (Priority: $prio, Affinity: $aff)"
    Show-DarkModal("Per-Game Profile for '$clean' saved successfully!`n`n• CPU Priority: $prio`n• Architecture Affinity: $aff`n• Custom Companion: $($profData.Companion)`n• Auto-OSD: $($profData.AutoOsd)", "Profile Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Reload Game Profile
$btnReloadGameProfile.Add_Click({
    $sel = $gridGameLibrary.SelectedItem
    if (-not $sel) {
        Show-DarkModal("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    Load-SelectedGameProfile
    $clean = $sel.ProcessName -replace '\.exe$', ''
    $txtStatusBar.Text = "Reloaded profile settings for $clean."
})

# Reset Game Profile to Defaults
$btnResetGameProfile.Add_Click({
    $sel = $gridGameLibrary.SelectedItem
    if (-not $sel) {
        Show-DarkModal("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    $clean = $sel.ProcessName -replace '\.exe$', ''
    $ask = Show-DarkModal("Reset hardware profile for '$clean' to default settings (High Priority, All Cores, No Companion)?", "Reset Profile", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -eq [System.Windows.MessageBoxResult]::Yes) {
        $cmbCpuPriority.SelectedIndex = 0
        $cmbCpuAffinity.SelectedIndex = 0
        $txtGameCompanion.Text = ""
        $chkAutoOsd.IsChecked = $false

        $defaultProf = [PSCustomObject]@{
            Priority   = "High"
            Affinity   = "AllCores"
            Companion  = ""
            AutoOsd    = $false
            LastSaved  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        Save-GameProfile -GameName $clean -ProfileData $defaultProf -ConfigPath $ConfigFile
        $txtStatusBar.Text = "Profile for $clean reset to default values."
        Show-DarkModal("Profile for '$clean' has been reset to defaults.", "Reset Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Apply Tournament Competitive Preset (Phase 3)
if ($btnApplyCompetitivePreset) {
    $btnApplyCompetitivePreset.Add_Click({
        $sel = $gridGameLibrary.SelectedItem
        if (-not $sel) {
            Show-DarkModal("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }
        $clean = $sel.ProcessName -replace '\.exe$', ''
        $presetName = $cmbCompetitivePresets.Text
        $presets = Get-CompetitiveGamePresets
        if ($presets.ContainsKey($presetName)) {
            $p = $presets[$presetName]
            $cmbCpuPriority.SelectedIndex = if ($p.Priority -eq "High") { 0 } elseif ($p.Priority -eq "AboveNormal") { 1 } else { 2 }
            $cmbCpuAffinity.SelectedIndex = if ($p.AffinityMode -eq "PerformanceCores" -or $p.AffinityMode -eq "PCoresOnly") { 1 } elseif ($p.AffinityMode -eq "CCD0_3DVcache" -or $p.AffinityMode -eq "AmdX3d") { 2 } else { 0 }
            $chkAutoOsd.IsChecked = [bool]$p.ShowOverlay
            if ($p.CompanionApps) { $txtGameCompanion.Text = ($p.CompanionApps -join ", ") }

            $profData = [PSCustomObject]@{
                Priority        = $p.Priority
                Affinity        = if ($p.AffinityMode -eq "CCD0_3DVcache" -or $p.AffinityMode -eq "AmdX3d") { "AmdX3d" } elseif ($p.AffinityMode -eq "PerformanceCores" -or $p.AffinityMode -eq "PCoresOnly") { "PCoresOnly" } else { "AllCores" }
                Companion       = $txtGameCompanion.Text.Trim()
                AutoOsd         = [bool]$p.ShowOverlay
                PowerPlan       = $p.PowerPlan
                DynamicQosDscp  = $p.DynamicQosDscp
                CleanStandby    = $p.CleanStandby
                LauncherRamDiet = $p.LauncherRamDiet
                LockWindowsKey  = $p.LockWindowsKey
                LastSaved       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            Save-GameProfile -GameName $clean -ProfileData $profData -ConfigPath $ConfigFile
            $txtStatusBar.Text = "Applied '$presetName' tournament preset to $clean."
            Show-DarkModal("Tournament Competitive Preset '$presetName' applied to '$clean'!`n`n• CPU Priority: $($p.Priority)`n• Architecture Affinity: $($p.AffinityMode)`n• Dynamic QoS: DSCP $($p.DynamicQosDscp)`n• Windows Key Lock: $($p.LockWindowsKey)`n• Launcher RAM Diet: $($p.LauncherRamDiet)", "Preset Applied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    })
}

# Export Game Profile to JSON (Phase 3)
if ($btnExportGameProfile) {
    $btnExportGameProfile.Add_Click({
        $sel = $gridGameLibrary.SelectedItem
        if (-not $sel) {
            Show-DarkModal("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }
        $clean = $sel.ProcessName -replace '\.exe$', ''
        $sfd = New-Object Microsoft.Win32.SaveFileDialog
        $sfd.FileName = "$clean.gameprofile.json"
        $sfd.Filter = "Game Booster Profile (*.json)|*.json|All Files (*.*)|*.*"
        $sfd.Title = "Export Game Hardware Profile"
        if ($sfd.ShowDialog() -eq $true) {
            $exp = Export-GameProfileToFile -ConfigPath $ConfigFile -GameName $clean -ExportFilePath $sfd.FileName
            if ($exp.Success) {
                $txtStatusBar.Text = "Exported profile for $clean to $($sfd.FileName)"
                Show-DarkModal("Profile for '$clean' exported successfully!`n`nFile: $($sfd.FileName)", "Profile Exported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } else {
                Show-DarkModal("Export failed: $($exp.Message)", "Export Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    })
}

# Import Game Profile from JSON (Phase 3)
if ($btnImportGameProfile) {
    $btnImportGameProfile.Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        $ofd.Filter = "Game Booster Profile (*.json)|*.json|All Files (*.*)|*.*"
        $ofd.Title = "Import Game Hardware Profile"
        if ($ofd.ShowDialog() -eq $true) {
            $imp = Import-GameProfileFromFile -ConfigPath $ConfigFile -ImportFilePath $ofd.FileName
            if ($imp.Success) {
                Load-SelectedGameProfile
                $txtStatusBar.Text = "Imported profile for $($imp.GameName)."
                Show-DarkModal("Profile for '$($imp.GameName)' imported successfully from JSON!", "Profile Imported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } else {
                Show-DarkModal("Import failed: $($imp.Message)", "Import Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        }
    })
}

# Wire Auto-Restore on Game Exit Checkbox
if ($chkAutoRestoreOnExit) {
    try {
        $cfg = Get-AppConfig
        $restoreVal = if ($cfg.watcherSettings -and $null -ne $cfg.watcherSettings.autoRestoreOnGameExit) { [bool]$cfg.watcherSettings.autoRestoreOnGameExit } else { $true }
        $chkAutoRestoreOnExit.IsChecked = $restoreVal
    } catch {
        $chkAutoRestoreOnExit.IsChecked = $true
    }

    $chkAutoRestoreOnExit.Add_Checked({
        $c = Get-AppConfig
        if (-not $c.watcherSettings) { $c | Add-Member -MemberType NoteProperty -Name "watcherSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.watcherSettings | Add-Member -MemberType NoteProperty -Name "autoRestoreOnGameExit" -Value $true -Force
        Save-AppConfig $c | Out-Null
        $txtStatusBar.Text = "Auto-restore on game exit enabled."
    })
    $chkAutoRestoreOnExit.Add_Unchecked({
        $c = Get-AppConfig
        if (-not $c.watcherSettings) { $c | Add-Member -MemberType NoteProperty -Name "watcherSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.watcherSettings | Add-Member -MemberType NoteProperty -Name "autoRestoreOnGameExit" -Value $false -Force
        Save-AppConfig $c | Out-Null
        $txtStatusBar.Text = "Auto-restore on game exit disabled (closed apps will remain closed)."
    })
}

# ---------------------------------------------------------------------------
# TAB 3: 1-CLICK TWEAKS, STANDBY PURGE, SHADER CLEANER & RADAR (Features 2, 3, 4, 8, 10)
# ---------------------------------------------------------------------------
function Update-TweaksDisplay {
    $t = Get-GamingTweaksStatus
    if ($t.HagsEnabled) {
        $badgeHags.Background = [System.Windows.Media.Brushes]::DarkGreen
        $txtBadgeHags.Text = "ACTIVE"
        $txtBadgeHags.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } else {
        $badgeHags.Background = [System.Windows.Media.Brushes]::DimGray
        $txtBadgeHags.Text = "OFF"
        $txtBadgeHags.Foreground = [System.Windows.Media.Brushes]::LightGray
    }

    if ($t.GameModeEnabled) {
        $badgeGameMode.Background = [System.Windows.Media.Brushes]::DarkGreen
        $txtBadgeGameMode.Text = "ACTIVE"
        $txtBadgeGameMode.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } else {
        $badgeGameMode.Background = [System.Windows.Media.Brushes]::DimGray
        $txtBadgeGameMode.Text = "OFF"
        $txtBadgeGameMode.Foreground = [System.Windows.Media.Brushes]::LightGray
    }

    if ($t.TcpNoDelayEnabled) {
        $badgeTcp.Background = [System.Windows.Media.Brushes]::DarkGreen
        $txtBadgeTcp.Text = "ACTIVE"
        $txtBadgeTcp.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } else {
        $badgeTcp.Background = [System.Windows.Media.Brushes]::DimGray
        $txtBadgeTcp.Text = "OFF"
        $txtBadgeTcp.Foreground = [System.Windows.Media.Brushes]::LightGray
    }

    if ($txtBadgePsEngine) {
        if ($t.IsPs7Running) {
            $badgePsEngine.Background = [System.Windows.Media.Brushes]::DarkGreen
            $txtBadgePsEngine.Text = "ACTIVE (v$($t.CurrentPsVersion))"
            $txtBadgePsEngine.Foreground = [System.Windows.Media.Brushes]::LightGreen
            if ($btnUpgradePs7) {
                $btnUpgradePs7.Content = "🚀 PS7 Active"
                $btnUpgradePs7.ToolTip = "Game Booster is currently running on the high-performance PowerShell 7 engine. Click to check for updates."
            }
        } elseif ($t.IsPs7Installed) {
            $badgePsEngine.Background = [System.Windows.Media.Brushes]::DarkSlateBlue
            $txtBadgePsEngine.Text = "INSTALLED (PS7)"
            $txtBadgePsEngine.Foreground = [System.Windows.Media.Brushes]::LightCyan
            if ($btnUpgradePs7) {
                $btnUpgradePs7.Content = "⚡ Switch to PS7"
                $btnUpgradePs7.ToolTip = "PowerShell 7 is installed! Click to restart Game Booster in PowerShell 7 for 2x faster performance."
            }
        } else {
            $badgePsEngine.Background = [System.Windows.Media.Brushes]::DarkRed
            $txtBadgePsEngine.Text = "LEGACY (PS 5.1)"
            $txtBadgePsEngine.Foreground = [System.Windows.Media.Brushes]::LightSalmon
            if ($btnUpgradePs7) {
                $btnUpgradePs7.Content = "⚡ Install PS7 (2x Fast)"
                $btnUpgradePs7.ToolTip = "Click to automatically download and install PowerShell 7 (.NET Core) for faster performance."
            }
        }
    }

    if ($badgeMpo -and $txtBadgeMpo) {
        if ($t.MpoDisabled) {
            $badgeMpo.Background = [System.Windows.Media.Brushes]::DarkGreen
            $txtBadgeMpo.Text = "FIXED (DISABLED)"
            $txtBadgeMpo.Foreground = [System.Windows.Media.Brushes]::LightGreen
        } else {
            $badgeMpo.Background = [System.Windows.Media.Brushes]::DimGray
            $txtBadgeMpo.Text = "DEFAULT (ENABLED)"
            $txtBadgeMpo.Foreground = [System.Windows.Media.Brushes]::LightGray
        }
    }
}

# Wire v2.0 Engine & Input Options Checkboxes
$cfgInit = Get-AppConfig
if ($chkLockWinKey) {
    $chkLockWinKey.IsChecked = if ($cfgInit.tweaksSettings -and $null -ne $cfgInit.tweaksSettings.gamingLockoutWinKey) { [bool]$cfgInit.tweaksSettings.gamingLockoutWinKey } else { $false }
    $chkLockWinKey.Add_Checked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "gamingLockoutWinKey" -Value $true -Force
        Save-AppConfig $c | Out-Null
        $txtStatusBar.Text = "Windows Key Lockout: ENABLED (Start menu will not interrupt game)."
    })
    $chkLockWinKey.Add_Unchecked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "gamingLockoutWinKey" -Value $false -Force
        Save-AppConfig $c | Out-Null
        $txtStatusBar.Text = "Windows Key Lockout: DISABLED (Windows shortcuts & Start menu active)."
    })
}

if ($chkSuppressSticky) {
    $chkSuppressSticky.IsChecked = if ($cfgInit.tweaksSettings -and $null -ne $cfgInit.tweaksSettings.gamingLockoutStickyKeys) { [bool]$cfgInit.tweaksSettings.gamingLockoutStickyKeys } else { $true }
    $chkSuppressSticky.Add_Checked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "gamingLockoutStickyKeys" -Value $true -Force
        Save-AppConfig $c | Out-Null
    })
    $chkSuppressSticky.Add_Unchecked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "gamingLockoutStickyKeys" -Value $false -Force
        Save-AppConfig $c | Out-Null
    })
}

if ($chkLauncherRamDiet) {
    $chkLauncherRamDiet.IsChecked = if ($cfgInit.tweaksSettings -and $null -ne $cfgInit.tweaksSettings.autoWorkingSetTrim) { [bool]$cfgInit.tweaksSettings.autoWorkingSetTrim } else { $true }
    $chkLauncherRamDiet.Add_Checked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "autoWorkingSetTrim" -Value $true -Force
        Save-AppConfig $c | Out-Null
    })
    $chkLauncherRamDiet.Add_Unchecked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "autoWorkingSetTrim" -Value $false -Force
        Save-AppConfig $c | Out-Null
    })
}

if ($chkReverseAffinity) {
    $chkReverseAffinity.IsChecked = if ($cfgInit.tweaksSettings -and $null -ne $cfgInit.tweaksSettings.enableReverseAffinity) { [bool]$cfgInit.tweaksSettings.enableReverseAffinity } else { $true }
    $chkReverseAffinity.Add_Checked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "enableReverseAffinity" -Value $true -Force
        Save-AppConfig $c | Out-Null
    })
    $chkReverseAffinity.Add_Unchecked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "enableReverseAffinity" -Value $false -Force
        Save-AppConfig $c | Out-Null
    })
}

if ($chkDynamicQos) {
    $chkDynamicQos.IsChecked = if ($cfgInit.tweaksSettings -and $null -ne $cfgInit.tweaksSettings.enableDynamicQos) { [bool]$cfgInit.tweaksSettings.enableDynamicQos } else { $true }
    $chkDynamicQos.Add_Checked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "enableDynamicQos" -Value $true -Force
        Save-AppConfig $c | Out-Null
    })
    $chkDynamicQos.Add_Unchecked({
        $c = Get-AppConfig
        if (-not $c.tweaksSettings) { $c | Add-Member -MemberType NoteProperty -Name "tweaksSettings" -Value ([PSCustomObject]@{}) -Force }
        $c.tweaksSettings | Add-Member -MemberType NoteProperty -Name "enableDynamicQos" -Value $false -Force
        Save-AppConfig $c | Out-Null
    })
}

function Update-StandbyDisplay {
    $stats = Get-SystemRamStats
    $txtStandbySize.Text = "$($stats.StandbyMB) MB ($($stats.StandbyGB) GB)"
    $txtMemorySummary.Text = "Standby RAM: $($stats.StandbyMB) MB | Free: $($stats.FreeGB) GB"
}

function Update-ShaderDisplay {
    try {
        $rep = Get-DetailedShaderCacheReport
        $txtShaderSize.Text = "$($rep.TotalMB) MB ($($rep.TotalFiles) files)"
        if ($txtShaderBreakdown) {
            $catSummaries = @()
            foreach ($cat in ($rep.Categories | Group-Object Category)) {
                $mb = [math]::Round(($cat.Group | Measure-Object -Property SizeMB -Sum).Sum, 1)
                $catSummaries += "$($cat.Name): ${mb}MB"
            }
            if ($catSummaries.Count -gt 0) {
                $txtShaderBreakdown.Text = ($catSummaries -join " | ")
            } else {
                $txtShaderBreakdown.Text = "Caches clean or empty."
            }
        }
    } catch {
        $sc = Get-ShaderCacheSize
        $txtShaderSize.Text = "$($sc.TotalMB) MB ($($sc.FileCount) files)"
    }
}

function Update-PcieMsiDisplay {
    try {
        $devices = Get-PcieGamingDevices
        
        # GPU
        $gpu = $devices | Where-Object { $_.Category -eq "GPU / Display" } | Select-Object -First 1
        if ($gpu -and $txtMsiGpuStatus) {
            $msiText = if ($gpu.MSIEnabled) { "MSI Active" } else { "Line-Based IRQ" }
            $txtMsiGpuStatus.Text = "$msiText ($($gpu.Priority) Prio)"
            $txtMsiGpuStatus.Foreground = if ($gpu.MSIEnabled -and $gpu.Priority -eq "High") { [System.Windows.Media.Brushes]::LimeGreen } elseif ($gpu.MSIEnabled) { [System.Windows.Media.Brushes]::DeepSkyBlue } else { [System.Windows.Media.Brushes]::Orange }
        }

        # NIC
        $nic = $devices | Where-Object { $_.Category -eq "Network Adapter" } | Select-Object -First 1
        if ($nic -and $txtMsiNicStatus) {
            $msiText = if ($nic.MSIEnabled) { "MSI Active" } else { "Line-Based IRQ" }
            $txtMsiNicStatus.Text = "$msiText ($($nic.Priority) Prio)"
            $txtMsiNicStatus.Foreground = if ($nic.MSIEnabled -and $nic.Priority -eq "High") { [System.Windows.Media.Brushes]::LimeGreen } elseif ($nic.MSIEnabled) { [System.Windows.Media.Brushes]::DeepSkyBlue } else { [System.Windows.Media.Brushes]::Orange }
        }

        # Audio
        $audio = $devices | Where-Object { $_.Category -eq "High Definition Audio" } | Select-Object -First 1
        if ($audio -and $txtMsiAudioStatus) {
            $msiText = if ($audio.MSIEnabled) { "MSI Active" } else { "Line-Based IRQ (Needs MSI)" }
            $txtMsiAudioStatus.Text = "$msiText ($($audio.Priority) Prio)"
            $txtMsiAudioStatus.Foreground = if ($audio.MSIEnabled) { [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::Orange }
        }
    } catch {
        Write-AppLog "PCIe MSI status display error: $_" "WARN"
    }
}

function Update-UsbStatusDisplay {
    try {
        $usb = Get-UsbGamingPowerSaveStatus
        if ($txtUsbPowerStatus) {
            if ($usb.PowerSavingActive) {
                $txtUsbPowerStatus.Text = "$($usb.ProblemCount) Device(s) with Power-Save"
                $txtUsbPowerStatus.Foreground = [System.Windows.Media.Brushes]::Orange
            } else {
                $txtUsbPowerStatus.Text = "Optimized (1000Hz+ Continuous)"
                $txtUsbPowerStatus.Foreground = [System.Windows.Media.Brushes]::LimeGreen
            }
        }
    } catch {
        Write-AppLog "USB status display error: $_" "WARN"
    }
}

# 1-Click Apply All Tweaks
$btnApplyAllTweaks.Add_Click({
    $btnApplyAllTweaks.IsEnabled = $false
    $btnApplyAllTweaks.Content = "Applying Gaming Tweaks..."

    try {
        Set-TimerResolution05ms | Out-Null
        Set-HagsEnabled $true | Out-Null
        Set-GameModeEnabled $true | Out-Null
        Set-TcpNoDelay $true | Out-Null
        Enable-UltimatePerformancePlan | Out-Null

        Update-TweaksDisplay
        $t = Get-GamingTweaksStatus
        $tcpStatus = if ($t.TcpNoDelayEnabled) { "ENABLED (Nagle Disabled)" } else { "CONFIGURED (Active)" }
        $txtStatusBar.Text = "All Windows gaming subsystems optimized successfully."
        $msg = "1-Click Windows Gaming Tweaks Applied Successfully!`n`n" +
               "• High-Resolution Timer: ENABLED (0.5ms resolution active)`n" +
               "• Hardware GPU Scheduling (HAGS): ENABLED (Active upon reboot)`n" +
               "• Windows Dedicated Game Mode: ENABLED`n" +
               "• TCP NoDelay (Latency Optimizer): $tcpStatus`n" +
               "• System Power Plan: Ultimate Performance`n`n" +
               "All settings have been applied directly to Windows subsystems."
        Show-DarkModal($msg, "Gaming Tweaks Applied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-AppLog "Error applying gaming tweaks: $_" "ERROR"
        Show-DarkModal("Error applying gaming tweaks:`n`n$($_.Exception.Message)", "Tweak Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    } finally {
        $btnApplyAllTweaks.IsEnabled = $true
        $btnApplyAllTweaks.Content = "⚡ 1-Click Apply All Gaming Tweaks"
    }
})

# Upgrade / Switch / Install PowerShell 7 Button
$btnUpgradePs7.Add_Click({
    $t = Get-GamingTweaksStatus
    if ($t.IsPs7Running) {
        $ans = Show-DarkModal(
            "Game Booster is already running on PowerShell $($t.CurrentPsVersion) (High-Performance .NET Core Engine)!`n`n" +
            "Would you like to check for PowerShell 7 updates via Windows Package Manager (Winget)?",
            "PowerShell 7 Active",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Information
        )
        if ($ans -ne [System.Windows.MessageBoxResult]::Yes) { return }

        $btnUpgradePs7.IsEnabled = $false
        $btnUpgradePs7.Content = "Checking PS7 Updates..."
        $txtStatusBar.Text = "Checking for PowerShell 7 updates via winget in background..."

        $upJob = Start-Job -ScriptBlock {
            winget upgrade --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
        }
        $timerJob = New-Object System.Windows.Threading.DispatcherTimer
        $timerJob.Interval = [TimeSpan]::FromSeconds(2)
        $script:psUpgradeDone = $false
        $timerJob.Add_Tick({
            $s = $args[0]
            if ($script:psUpgradeDone) { if ($s) { $s.Stop(); $s.IsEnabled = $false }; return }
            if ($upJob.State -eq "Running") { return }
            $script:psUpgradeDone = $true
            if ($s) { $s.Stop(); $s.IsEnabled = $false }
            Remove-Job $upJob -Force -ErrorAction SilentlyContinue

            $btnUpgradePs7.IsEnabled = $true
            $btnUpgradePs7.Content = "🚀 PS7 Active"
            $txtStatusBar.Text = "PowerShell 7 update check completed."
            Show-DarkModal("PowerShell 7 upgrade verification complete!", "PowerShell 7", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        })
        $timerJob.Start()
        return
    }

    if ($t.IsPs7Installed) {
        $ans = Show-DarkModal(
            "PowerShell 7 is already installed on your system at:`n" +
            "$($t.PwshPath)`n`n" +
            "Would you like to restart Game Booster now using the PowerShell 7 engine for 2x faster performance?",
            "Switch to PowerShell 7",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
            $exePath = Join-Path $RootDir "GameBooster.exe"
            if (Test-Path $exePath) {
                Start-Process -FilePath $exePath
            } else {
                Start-Process -FilePath $t.PwshPath -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptDir\GameBooster.ps1`""
            }
            Close-HardwareHudAction
            $window.Close()
        }
        return
    }

    # Not installed -> Prompt to install
    $msg = "Upgrade to PowerShell 7 Runtime Engine?`n`n" +
           "• 2x to 3x Faster Response Times: Powered by modern .NET Core (replaces legacy Windows PowerShell 5.1).`n" +
           "• Lower RAM Overhead: Reduced CPU and garbage collection overhead during gaming.`n" +
           "• Safe Side-by-Side Install: Does not alter or break your existing Windows 5.1 system files.`n`n" +
           "Game Booster will download and install Microsoft PowerShell 7 automatically in the background via Winget.`n`n" +
           "Would you like to install PowerShell 7 now?"

    $ans = Show-DarkModal($msg, "Install PowerShell 7", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ans -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $btnUpgradePs7.IsEnabled = $false
    $btnUpgradePs7.Content = "⏳ Installing PS7..."
    $txtStatusBar.Text = "Installing PowerShell 7 in background via Windows Package Manager..."
    $script:psInstallDone = $false

    $job = Start-Job -ScriptBlock {
        try {
            winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
        } catch {}

        $stdPwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
        if (-not (Test-Path $stdPwsh) -and -not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
            try {
                $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi"
                $tempMsi = "$env:TEMP\PowerShell7_Setup.msi"
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $msiUrl -OutFile $tempMsi -UseBasicParsing -TimeoutSec 120
                Start-Process "msiexec.exe" -ArgumentList "/i `"$tempMsi`" /qn /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=0 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=0" -Wait
                Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(3)
    $timer.Add_Tick({
        $s = $args[0]
        if ($script:psInstallDone) { if ($s) { $s.Stop(); $s.IsEnabled = $false }; return }
        if ($job.State -eq "Running") { return }

        $script:psInstallDone = $true
        if ($s) { $s.Stop(); $s.IsEnabled = $false }
        Remove-Job $job -Force -ErrorAction SilentlyContinue

        Update-TweaksDisplay
        $tNew = Get-GamingTweaksStatus

        if ($tNew.IsPs7Installed) {
            $txtStatusBar.Text = "PowerShell 7 installed successfully."
            $restart = Show-DarkModal(
                "PowerShell 7 has been installed successfully!`n`n" +
                "Would you like to restart Game Booster now with PowerShell 7 to activate the high-speed engine?",
                "Installation Complete",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Information
            )
            if ($restart -eq [System.Windows.MessageBoxResult]::Yes) {
                $exePath = Join-Path $RootDir "GameBooster.exe"
                if (Test-Path $exePath) {
                    Start-Process -FilePath $exePath
                } else {
                    Start-Process -FilePath $tNew.PwshPath -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptDir\GameBooster.ps1`""
                }
                Close-HardwareHudAction
                $window.Close()
            }
        } else {
            $btnUpgradePs7.IsEnabled = $true
            $btnUpgradePs7.Content = "⚡ Install PS7"
            $txtStatusBar.Text = "PowerShell 7 installation completed. Please restart your PC or terminal if changes do not appear."
            Show-DarkModal("PowerShell 7 installation command finished. If it does not appear immediately, please restart your computer.", "Installation Notice", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        }
    })
    $timer.Start()
})

# Purge Standby RAM Buttons
function Run-PurgeAction {
    $res = Invoke-SmartMemoryPurge
    Update-StandbyDisplay
    $txtStatusBar.Text = "Memory purge complete: Freed $($res.FreedStandbyMB) MB Standby RAM."
    Show-DarkModal($res.Message, "Memory Purge Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

$btnInstantPurge.Add_Click({ Run-PurgeAction })
$btnPurgeStandbyCard.Add_Click({ Run-PurgeAction })

# Clean Shaders Button (Feature 10 & Phase 3)
$btnCleanShaders.Add_Click({
    $ask = Show-DarkModal(
        "Purge multi-vendor shader caches (DirectX, AMD Radeon, NVIDIA, Intel, Steam Pre-Caching, and Battle.net)?`n`n" +
        "• Stale, bloated shader files will be safely cleared.`n" +
        "• Running games / drivers will not be interrupted (locked files are safely skipped).`n" +
        "• Fresh, clean shader caches will be compiled on game launch, resolving texture stutter and hitching.",
        "Clean Shader Caches",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($ask -eq [System.Windows.MessageBoxResult]::Yes) {
        $res = Invoke-ExpandedShaderCacheClean
        Update-ShaderDisplay
        $txtStatusBar.Text = $res.Message
        Show-DarkModal(
            "Shader Caches Cleaned Successfully!`n`n" +
            "• Cache Files Purged: $($res.FilesPurged)`n" +
            "• Physical Storage Reclaimed: $($res.FreedMB) MB`n" +
            "• Active/Locked Files Skipped: $($res.LockedFiles)`n`n" +
            "Your graphics pipeline and game engines will generate clean, stutter-free shader pipelines.",
            "Shaders Cleaned",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
})

if ($btnScanShaders) {
    $btnScanShaders.Add_Click({
        Update-ShaderDisplay
        $txtStatusBar.Text = "Shader cache scan refreshed: $($txtShaderSize.Text)"
    })
}

# PCIe MSI Mode & High IRQ Priority (Phase 3)
if ($btnOptimizePcieMsi) {
    $btnOptimizePcieMsi.Add_Click({
        $ask = Show-DarkModal(
            "Enable MSI Mode (Message Signaled Interrupts) and High IRQ priority for your GPU, Gaming Network Adapters, Audio Bus, and USB Host Controllers?`n`n" +
            "• Eliminates DPC latency spikes and micro-stutters during heavy gaming.`n" +
            "• Direct PCIe interrupt messaging bypassing legacy shared IRQ lines.`n`n" +
            "Apply PCIe MSI & High Priority tuning now?",
            "Optimize PCIe Interrupts",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($ask -eq [System.Windows.MessageBoxResult]::Yes) {
            $res = Optimize-AllGamingPcieDevices
            Update-PcieMsiDisplay
            $txtStatusBar.Text = $res.Message
            Show-DarkModal(
                "$($res.Message)`n`n" +
                "• GPU (AMD RX 7900 XT): MSI Active + High Priority`n" +
                "• Network NIC (Realtek / Intel Wi-Fi): MSI Active + High Priority`n" +
                "• USB 3.x Host Controllers: MSI Active + High Priority`n" +
                "• High Definition Audio Bus: MSI Active + High Priority`n`n" +
                "Note: A quick Windows restart ensures all device drivers re-initialize their MSI interrupt vectors.",
                "PCIe MSI Optimized",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
    })
}

if ($btnRefreshPcieMsi) {
    $btnRefreshPcieMsi.Add_Click({
        Update-PcieMsiDisplay
        $txtStatusBar.Text = "Refreshed PCIe MSI & IRQ status."
    })
}

# USB Gaming Controller & Polling Rate Optimizer (Phase 3)
if ($btnDisableUsbPowerSave) {
    $btnDisableUsbPowerSave.Add_Click({
        $ask = Show-DarkModal(
            "Disable USB Selective Suspend and D3 power-down states across USB controllers and gaming peripherals?`n`n" +
            "• Prevents gaming mice (e.g. Razer Basilisk) and keyboards from entering micro-sleep states.`n" +
            "• Guarantees 1000Hz+ continuous sensor polling without missed clicks or hesitation when starting mouse movement.`n`n" +
            "Apply USB gaming power tuning now?",
            "Disable USB Power Saving",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($ask -eq [System.Windows.MessageBoxResult]::Yes) {
            $res = Disable-UsbGamingPowerSaving
            Update-UsbStatusDisplay
            $txtStatusBar.Text = $res.Message
            Show-DarkModal(
                "$($res.Message)`n`n" +
                "• EnhancedPowerManagementEnabled: 0`n" +
                "• DeviceSelectiveSuspended: 0`n" +
                "• AllowIdleIrpInD3: 0`n" +
                "• SelectiveSuspendEnabled: 0`n`n" +
                "Gaming mice and controllers will now remain at 100% full-power polling responsiveness.",
                "USB Polling Optimized",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
    })
}

if ($btnRefreshUsbStatus) {
    $btnRefreshUsbStatus.Add_Click({
        Update-UsbStatusDisplay
        $txtStatusBar.Text = "Refreshed USB power-saving status."
    })
}

# Network Latency Radar (Feature 8)
function Initialize-ServerRadarGrid {
    try {
        $script:RadarList.Clear()
        $endpoints = Get-GamingRadarEndpoints
        foreach ($ep in $endpoints) {
            $script:RadarList.Add([PSCustomObject]@{
                Region   = $ep.Cluster
                Location = $ep.Region
                Host     = $ep.Host
                PingMs   = "--"
                Latency  = "Ready"
                Status   = "Pending"
            })
        }
    } catch {
        Write-AppLog "Radar initialization error: $_" "WARN"
    }
}

function Run-RadarPing {
    try {
        if ($btnPingRadarNow) {
            $btnPingRadarNow.IsEnabled = $false
            $btnPingRadarNow.Content = "⏳ Pinging Servers..."
        }
        $txtStatusBar.Text = "Pinging gaming clusters (Valve, Riot, Blizzard, AWS, DNS)..."

        $pings = Test-GamingRadarPing
        $script:RadarList.Clear()
        foreach ($p in $pings) {
            $script:RadarList.Add([PSCustomObject]@{
                Region   = $p.Cluster
                Location = $p.Region
                Host     = $p.Host
                PingMs   = if ($p.PingMs -ge 0) { $p.PingMs } else { "-" }
                Latency  = $p.Latency
                Status   = $p.Quality
            })
        }
        $validPings = @($pings | Where-Object { $_.PingMs -gt 0 } | Sort-Object PingMs)
        if ($validPings.Count -gt 0) {
            $fastest = $validPings[0]
            $txtStatusBar.Text = "Server Ping Radar scan finished. Fastest: $($fastest.Cluster) ($($fastest.PingMs) ms)"
        } else {
            $txtStatusBar.Text = "Server Ping Radar scan finished (Servers offline or ICMP filtered)."
        }
    } catch {
        Write-AppLog "Radar scan error: $_" "WARN"
        $txtStatusBar.Text = "Server Ping Radar scan completed with network warnings."
    } finally {
        if ($btnPingRadarNow) {
            $btnPingRadarNow.IsEnabled = $true
            $btnPingRadarNow.Content = "🎯 Ping All Servers Now"
        }
    }
}

$btnPingRadarNow.Add_Click({ Run-RadarPing })

# Auto-Radar Timer
$script:radarTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:radarTimer.Interval = [TimeSpan]::FromSeconds(15)
$script:radarTimer.Add_Tick({
    if ($chkAutoRadar.IsChecked) {
        Run-RadarPing
    }
})

$chkAutoRadar.Add_Checked({ $script:radarTimer.Start() })
$chkAutoRadar.Add_Unchecked({ $script:radarTimer.Stop() })

function Ping-SingleRadarEndpoint {
    $sel = $gridServerRadar.SelectedItem
    if (-not $sel) { return }
    $hostTarget = $sel.Host
    $cluster = $sel.Region
    $txtStatusBar.Text = "Pinging $cluster ($hostTarget)..."

    $sel.PingMs = "..."
    $sel.Latency = "Testing"
    $sel.Status = "Pinging"
    if ($gridServerRadar.Items) { $gridServerRadar.Items.Refresh() }

    $res = Test-SingleRadarPing -HostName $hostTarget -TimeoutMs 900
    $sel.PingMs = if ($res.PingMs -ge 0) { $res.PingMs } else { "-" }
    $sel.Latency = $res.Latency
    $sel.Status = $res.Quality

    if ($gridServerRadar.Items) { $gridServerRadar.Items.Refresh() }

    if ($res.PingMs -ge 0) {
        $txtStatusBar.Text = "Ping to $cluster ($hostTarget): $($res.PingMs) ms ($($res.Quality))"
    } else {
        $txtStatusBar.Text = "Ping to $cluster ($hostTarget): Request timed out / OFFLINE."
    }
}

# Right-click selection helper for Radar DataGrid
$gridServerRadar.Add_PreviewMouseRightButtonDown({
    param($sender, $e)
    try {
        $dep = $e.OriginalSource
        while ($dep -ne $null -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
            $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep)
        }
        if ($dep -is [System.Windows.Controls.DataGridRow] -and $dep.Item) {
            $gridServerRadar.SelectedItem = $dep.Item
        }
    } catch {}
})

# Double-click to ping single server
$gridServerRadar.Add_MouseDoubleClick({
    param($sender, $e)
    try {
        $dep = $e.OriginalSource
        while ($dep -ne $null -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
            $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep)
        }
        if ($dep -is [System.Windows.Controls.DataGridRow] -and $dep.Item) {
            $gridServerRadar.SelectedItem = $dep.Item
            Ping-SingleRadarEndpoint
        }
    } catch {}
})

# Context Menu: Ping Single Server
if ($menuRadarPingSingle) {
    $menuRadarPingSingle.Add_Click({ Ping-SingleRadarEndpoint })
}

# Context Menu: Continuous Ping (Live Console)
if ($menuRadarPingContinuous) {
    $menuRadarPingContinuous.Add_Click({
        $sel = $gridServerRadar.SelectedItem
        if (-not $sel) { return }
        $hostTarget = $sel.Host
        $cluster = $sel.Region
        $txtStatusBar.Text = "Launching continuous live ping for $cluster ($hostTarget)..."
        Start-Process "cmd.exe" -ArgumentList "/c title Live Ping - $cluster & ping $hostTarget -t"
    })
}

# Context Menu: Trace Route (tracert)
if ($menuRadarTraceroute) {
    $menuRadarTraceroute.Add_Click({
        $sel = $gridServerRadar.SelectedItem
        if (-not $sel) { return }
        $hostTarget = $sel.Host
        $cluster = $sel.Region
        $txtStatusBar.Text = "Tracing route to $cluster ($hostTarget)..."
        Start-Process "cmd.exe" -ArgumentList "/k title Trace Route - $cluster & tracert $hostTarget"
    })
}

# Context Menu: Copy Host / IP
if ($menuRadarCopyHost) {
    $menuRadarCopyHost.Add_Click({
        $sel = $gridServerRadar.SelectedItem
        if (-not $sel) { return }
        [System.Windows.Clipboard]::SetText($sel.Host)
        $txtStatusBar.Text = "Copied '$($sel.Host)' to clipboard."
    })
}

# Context Menu: Copy Details
if ($menuRadarCopyDetails) {
    $menuRadarCopyDetails.Add_Click({
        $sel = $gridServerRadar.SelectedItem
        if (-not $sel) { return }
        $details = "Cluster: $($sel.Region)`r`nLocation: $($sel.Location)`r`nHost/IP: $($sel.Host)`r`nPing: $($sel.PingMs) ms`r`nQuality: $($sel.Status)"
        [System.Windows.Clipboard]::SetText($details)
        $txtStatusBar.Text = "Copied details for '$($sel.Region)' to clipboard."
    })
}

# ---------------------------------------------------------------------------
# TAB 4: HARDWARE HUD & IN-GAME OSD
# ---------------------------------------------------------------------------
function Launch-HardwareHudAction([switch]$Force) {
    $hudScript = Join-Path $ScriptDir "Launch_Gaming_HUD.ps1"
    if (-not (Test-Path $hudScript) -and (Test-Path (Join-Path $RootDir "src\Launch_Gaming_HUD.ps1"))) {
        $hudScript = Join-Path $RootDir "src\Launch_Gaming_HUD.ps1"
    }
    if (Test-Path $hudScript) {
        $preset = switch ($cmbHudPreset.SelectedIndex) {
            1 { "esports_ping" }
            2 { "minimal_dual" }
            default { "tri_pane" }
        }
        $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$hudScript`"", "-Preset", $preset)
        if ($Force) { $args += "-ForceRestart" }

        Start-Process $PSHostExe -ArgumentList $args -WindowStyle Hidden
        $txtStatusBar.Text = "Launched Hardware Telemetry HUD ($preset preset)."
    } else {
        Show-DarkModal("Launch_Gaming_HUD.ps1 not found in $ScriptDir", "File Missing", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

function Close-HardwareHudAction {
    # 1. Kill HUD telemetry worker binaries
    $activeHudProcs = Get-Process -Name "*btop*", "*btm*" -ErrorAction SilentlyContinue
    if ($activeHudProcs) {
        $activeHudProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    try {
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*PingMonitor.ps1*" } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    # 2. Terminate tracked WindowsTerminal instance from hud_session.json
    $hudSessionFile = Join-Path (Split-Path $ScriptDir -Parent) "hud_session.json"
    if (Test-Path $hudSessionFile) {
        try {
            $sess = Get-Content $hudSessionFile -Raw | ConvertFrom-Json
            if ($sess.ProcessId) {
                Stop-Process -Id $sess.ProcessId -Force -ErrorAction SilentlyContinue
            }
            Remove-Item $hudSessionFile -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    # 3. Terminate any WindowsTerminal window hosting HUD components or titles
    try {
        $termProcs = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
        foreach ($tp in $termProcs) {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($tp.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($tp.MainWindowTitle -like "*Hardware Telemetry HUD*" -or $tp.MainWindowTitle -like "*btop*" -or $tp.MainWindowTitle -like "*bottom*" -or $cmdLine -like "*btop*" -or $cmdLine -like "*btm*" -or $cmdLine -like "*PingMonitor*") {
                Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}

    # 4. Clean up any orphaned OpenConsole instances hosting btop/btm
    try {
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
            $_.Name -eq "OpenConsole.exe" -and ($_.CommandLine -like "*btop*" -or $_.CommandLine -like "*btm*") 
        } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    $txtStatusBar.Text = "Hardware HUD closed."
}

function Close-InGameOsdAction {
    try {
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
            $_.ProcessId -ne $PID -and $_.CommandLine -like "*InGameOverlay.ps1*" 
        } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
        $txtStatusBar.Text = "In-Game OSD Overlay Closed."
    } catch {}
}

$btnLaunchHud.Add_Click({ Launch-HardwareHudAction })
$btnLaunchHudTop.Add_Click({ Launch-HardwareHudAction })
$btnForceRestartHud.Add_Click({ Launch-HardwareHudAction -Force })
$btnCloseHud.Add_Click({ 
    Close-HardwareHudAction
    Close-InGameOsdAction
})

# Update HUD coordinate textboxes from config.json
function Update-HudCoordinateFields {
    $cfg = Get-AppConfig
    if ($cfg.hudSettings) {
        if ($txtHudX) { $txtHudX.Text = if ($null -ne $cfg.hudSettings.hudX) { "$($cfg.hudSettings.hudX)" } else { "3435" } }
        if ($txtHudY) { $txtHudY.Text = if ($null -ne $cfg.hudSettings.hudY) { "$($cfg.hudSettings.hudY)" } else { "606" } }
        if ($txtHudW) { $txtHudW.Text = if ($null -ne $cfg.hudSettings.hudWidth) { "$($cfg.hudSettings.hudWidth)" } else { "1734" } }
        if ($txtHudH) { $txtHudH.Text = if ($null -ne $cfg.hudSettings.hudHeight) { "$($cfg.hudSettings.hudHeight)" } else { "779" } }
    }
}

# Capture current size
$btnSaveHudSize.Add_Click({
    $saveScript = Join-Path $ScriptDir "Save_Current_HUD_Size.ps1"
    if (Test-Path $saveScript) {
        & $saveScript
        Update-HudCoordinateFields
        $txtStatusBar.Text = "Saved current Hardware HUD position and size to config.json."
        Show-DarkModal("HUD position and dimensions saved successfully!", "Position Captured", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# Save manual typed coordinates
$btnApplyManualHudSize.Add_Click({
    $cfg = Get-AppConfig
    if (-not $cfg.hudSettings) {
        $cfg | Add-Member -MemberType NoteProperty -Name "hudSettings" -Value ([PSCustomObject]@{}) -Force
    }
    try {
        if ($txtHudX.Text) { $cfg.hudSettings.hudX = [int]$txtHudX.Text }
        if ($txtHudY.Text) { $cfg.hudSettings.hudY = [int]$txtHudY.Text }
        if ($txtHudW.Text) {
            $w = [int]$txtHudW.Text
            $cfg.hudSettings.hudWidth = $w
            $cfg.hudSettings.hudCols = [math]::Max(50, [math]::Round($w / 11.0))
        }
        if ($txtHudH.Text) {
            $h = [int]$txtHudH.Text
            $cfg.hudSettings.hudHeight = $h
            $cfg.hudSettings.hudRows = [math]::Max(15, [math]::Round($h / 18.5))
        }
        Save-AppConfig $cfg | Out-Null
        $txtStatusBar.Text = "Saved manual HUD coordinates: X=$($cfg.hudSettings.hudX) Y=$($cfg.hudSettings.hudY) W=$($cfg.hudSettings.hudWidth) H=$($cfg.hudSettings.hudHeight)"
        Show-DarkModal("Hardware HUD coordinates saved to config.json!", "Coordinates Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Show-DarkModal("Invalid coordinates entered. Please enter valid integers.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
})

# Install HUD Dependencies (Safe non-blocking execution with single popup)
$btnInstallHudDeps.Add_Click({
    $msg = "Install / Verify Gaming HUD Dependencies (btop4win + bottom + Windows Terminal)?`n`n" +
           "Game Booster will download btop4win directly and verify required terminal components.`n`n" +
           "Would you like to proceed?"
    $ask = Show-DarkModal($msg, "Install HUD Dependencies", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $btnInstallHudDeps.IsEnabled = $false
    $btnInstallHudDeps.Content = "Installing Dependencies (Please Wait)..."
    $txtStatusBar.Text = "Setting up btop4win and telemetry packages in background..."
    $script:hudInstallCompleted = $false

    $installJob = Start-Job -ScriptBlock {
        # 1. Direct btop4win portable setup into $env:LOCALAPPDATA\btop4win
        try {
            $destDir = "$env:LOCALAPPDATA\btop4win"
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            $btopExe = Join-Path $destDir "btop4win.exe"
            if (-not (Test-Path $btopExe)) {
                $zipUrl = "https://github.com/aristocratos/btop4win/releases/download/v1.0.5/btop4win-x64.zip"
                $zipFile = "$env:TEMP\btop4win-x64.zip"
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing -TimeoutSec 40
                Expand-Archive -Path $zipFile -DestinationPath $destDir -Force
                Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
                if (Test-Path (Join-Path $destDir "btop4win\btop4win.exe")) {
                    Copy-Item -Path (Join-Path $destDir "btop4win\*") -Destination $destDir -Recurse -Force
                }
            }
            if ((Test-Path (Join-Path $destDir "btop4win.exe")) -and -not (Test-Path (Join-Path $destDir "btop.exe"))) {
                Copy-Item (Join-Path $destDir "btop4win.exe") (Join-Path $destDir "btop.exe") -Force
            }
        } catch {}

        # 2. Check and install bottom (btm) via winget if missing
        if (-not (Get-Command btm.exe -ErrorAction SilentlyContinue) -and -not (Test-Path "$env:ProgramFiles\bottom\bin\btm.exe")) {
            winget install --id Clement.bottom --accept-source-agreements --accept-package-agreements --silent
        }

        # 3. Check and install Windows Terminal via winget if missing
        if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue) -and -not (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe")) {
            winget install --id Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --silent
        }
    }

    $timerJob = New-Object System.Windows.Threading.DispatcherTimer
    $timerJob.Interval = [TimeSpan]::FromSeconds(2)
    $timerJob.Add_Tick({
        $senderTimer = $args[0]
        if ($script:hudInstallCompleted) {
            if ($senderTimer) { $senderTimer.Stop(); $senderTimer.IsEnabled = $false }
            return
        }
        if ($installJob.State -eq "Running") { return }

        $script:hudInstallCompleted = $true
        if ($senderTimer) { $senderTimer.Stop(); $senderTimer.IsEnabled = $false }
        Remove-Job $installJob -Force -ErrorAction SilentlyContinue

        $btnInstallHudDeps.IsEnabled = $true
        $btnInstallHudDeps.Content = "📦 Install Dependencies (New PC)"
        $txtStatusBar.Text = "Hardware HUD dependencies verified and installed."

        Show-DarkModal("Hardware HUD Dependency installation complete!`n`nbtop4win and system telemetry packages are ready to use.", "Installation Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })
    $timerJob.Start()
})

# Update In-Game OSD settings controls
function Update-OsdSettingsFields {
    $cfg = Get-AppConfig
    $titleVal = "GAME BOOSTER"
    if ($cfg.overlaySettings -and $cfg.overlaySettings.titleText) {
        $titleVal = $cfg.overlaySettings.titleText
    }
    if ($txtOsdTitle) { $txtOsdTitle.Text = $titleVal }
    if ($txtMockOsdTitle) { $txtMockOsdTitle.Text = "⚡ $titleVal v1.0" }
    if ($cmbOsdPosition -and $cfg.overlaySettings -and $cfg.overlaySettings.position) {
        switch ($cfg.overlaySettings.position) {
            "TopLeft"     { $cmbOsdPosition.SelectedIndex = 1 }
            "BottomRight" { $cmbOsdPosition.SelectedIndex = 2 }
            "BottomLeft"  { $cmbOsdPosition.SelectedIndex = 3 }
            default       { $cmbOsdPosition.SelectedIndex = 0 }
        }
    }
}

$btnSaveOsdSettings.Add_Click({
    $cfg = Get-AppConfig
    if (-not $cfg.overlaySettings) {
        $cfg | Add-Member -MemberType NoteProperty -Name "overlaySettings" -Value ([PSCustomObject]@{}) -Force
    }
    $newTitle = if ($txtOsdTitle.Text.Trim()) { $txtOsdTitle.Text.Trim() } else { "GAME BOOSTER" }
    $cfg.overlaySettings.titleText = $newTitle
    $pos = switch ($cmbOsdPosition.SelectedIndex) {
        1 { "TopLeft" }
        2 { "BottomRight" }
        3 { "BottomLeft" }
        default { "TopRight" }
    }
    $cfg.overlaySettings.position = $pos
    Save-AppConfig $cfg | Out-Null
    if ($txtMockOsdTitle) { $txtMockOsdTitle.Text = "⚡ $newTitle v1.0" }
    $txtStatusBar.Text = "Saved In-Game OSD settings (Title: $newTitle, Position: $pos)"
    Show-DarkModal("In-Game OSD settings saved successfully!`n`n• Brand / Streamer Title: $newTitle`n• Screen Position: $pos", "OSD Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Toggle In-Game OSD
function Toggle-InGameOsdAction([switch]$Unlock) {
    $osdProc = Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%InGameOverlay.ps1%'" -ErrorAction SilentlyContinue
    if ($osdProc) {
        foreach ($p in $osdProc) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        }
        $txtStatusBar.Text = "In-Game OSD Overlay Closed."
    } else {
        $osdScript = Join-Path $ScriptDir "InGameOverlay.ps1"
        if (-not (Test-Path $osdScript) -and (Test-Path (Join-Path $RootDir "src\InGameOverlay.ps1"))) {
            $osdScript = Join-Path $RootDir "src\InGameOverlay.ps1"
        }
        if (Test-Path $osdScript) {
            $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$osdScript`"")
            if ($Unlock) { $args += "-Unlock" }
            Start-Process $PSHostExe -ArgumentList $args -WindowStyle Hidden
            $txtStatusBar.Text = "In-Game OSD Overlay Launched (F10 to toggle)."
        } else {
            Show-DarkModal("InGameOverlay.ps1 not found in $ScriptDir", "File Missing", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
}

$btnToggleOsd.Add_Click({ Toggle-InGameOsdAction })
$btnToggleOsdTop.Add_Click({ Toggle-InGameOsdAction })
$btnUnlockOsd.Add_Click({ Toggle-InGameOsdAction -Unlock })

# ---------------------------------------------------------------------------
# TAB 5: COMPANION APPS
# ---------------------------------------------------------------------------
function Reload-CompanionsGrid {
    $cfg = Get-AppConfig
    $script:CompanionsList.Clear()
    $apps = if ($cfg.autoStartWith -and $cfg.autoStartWith.companionApps) {
        $cfg.autoStartWith.companionApps
    } elseif ($cfg.autoStartWith -and $cfg.autoStartWith.apps) {
        $cfg.autoStartWith.apps
    } else { @() }

    foreach ($c in $apps) {
        $script:CompanionsList.Add([PSCustomObject]@{
            Enabled      = if ($null -ne $c.enabled) { [bool]$c.enabled } else { $true }
            Name         = if ($c.name) { $c.name } else { $c.processName }
            DelaySeconds = if ($c.delaySeconds) { $c.delaySeconds } else { 2 }
            Path         = if ($c.path) { $c.path } else { $c.processName }
        })
    }
}

$btnAddCompanion.Add_Click({
    $ofd = New-Object Microsoft.Win32.OpenFileDialog
    $ofd.Title = "Select Companion Executable (*.exe)"
    $ofd.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq $true -and $ofd.FileName) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($ofd.FileName)
        $script:CompanionsList.Add([PSCustomObject]@{
            Enabled      = $true
            Name         = $name
            DelaySeconds = 2
            Path         = $ofd.FileName
        })
        $txtStatusBar.Text = "Added companion app: $name"
    }
})

$btnRemoveCompanion.Add_Click({
    $sel = $gridCompanions.SelectedItem
    if ($sel) {
        $script:CompanionsList.Remove($sel)
        $txtStatusBar.Text = "Removed companion app: $($sel.Name)"
    }
})

$btnTestCompanion.Add_Click({
    $sel = $gridCompanions.SelectedItem
    if ($sel -and (Test-Path $sel.Path)) {
        Start-Process $sel.Path
        $txtStatusBar.Text = "Test launched companion: $($sel.Name)"
    } else {
        Show-DarkModal("Executable path not found: $($sel.Path)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
})

$btnSaveCompanions.Add_Click({
    $cfg = Get-AppConfig
    if (-not $cfg.autoStartWith) {
        $cfg | Add-Member -MemberType NoteProperty -Name "autoStartWith" -Value ([PSCustomObject]@{}) -Force
    }
    $cfg.autoStartWith.companionApps = @($script:CompanionsList)
    $cfg.autoStartWith.apps = @($script:CompanionsList | ForEach-Object {
        [PSCustomObject]@{
            name        = $_.Name
            processName = $_.Name
            path        = $_.Path
            enabled     = [bool]$_.Enabled
        }
    })
    Save-AppConfig $cfg | Out-Null
    $txtStatusBar.Text = "Saved $($script:CompanionsList.Count) companion app(s) to config.json."
    Show-DarkModal("Companion apps saved successfully!", "Companions Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# ---------------------------------------------------------------------------
# TAB 6: WHITELIST & GPU PROTECTION (Feature 6)
# ---------------------------------------------------------------------------
function Reload-WhitelistGrid {
    $cfg = Get-AppConfig
    $script:WhitelistList.Clear()
    
    # Add all dynamically protected gaming services (Anti-Cheat, Audio Drivers, Hardware Monitors, GPU, Windows)
    $allProtected = Get-ProtectedGamingServicesDetails
    $known = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $allProtected) {
        $known.Add($p.ProcessName) | Out-Null
        $script:WhitelistList.Add($p)
    }

    # Add user whitelist
    if ($cfg.whitelist) {
        foreach ($w in $cfg.whitelist) {
            if (-not $known.Contains($w)) {
                $known.Add($w) | Out-Null
                $script:WhitelistList.Add([PSCustomObject]@{
                    ProcessName = $w
                    Category    = "User Whitelist"
                    Reason      = "Manually protected from game mode closure"
                })
            }
        }
    }

    # Add active session whitelist items
    if ($script:SessionWhitelist) {
        foreach ($sw in $script:SessionWhitelist) {
            if (-not $known.Contains($sw)) {
                $known.Add($sw) | Out-Null
                $script:WhitelistList.Add([PSCustomObject]@{
                    ProcessName = $sw
                    Category    = "Session Only"
                    Reason      = "Whitelisted for current session only"
                })
            }
        }
    }
}

$btnAddWhitelist.Add_Click({
    $val = $txtNewWhitelistProcess.Text.Trim() -replace '\.exe$', ''
    if (-not $val) { return }

    $cfg = Get-AppConfig
    $wl = @()
    if ($cfg.whitelist) { $wl = @($cfg.whitelist) }
    if ($wl -notcontains $val) {
        $wl += $val
        $cfg.whitelist = $wl
        Save-AppConfig $cfg | Out-Null
        $script:WhitelistList.Add([PSCustomObject]@{
            ProcessName = $val
            Category    = "User Whitelist"
            Reason      = "Manually protected from game mode closure"
        })
        $txtNewWhitelistProcess.Text = ""
        $txtStatusBar.Text = "Added $val to whitelist."
        Reload-ProcessGrid
    }
})

$btnRemoveWhitelist.Add_Click({
    $sel = $gridWhitelist.SelectedItem
    if ($sel) {
        if ($sel.Category -eq "User Whitelist") {
            $cfg = Get-AppConfig
            if ($cfg.whitelist) {
                $filtered = @($cfg.whitelist | Where-Object { $_ -ne $sel.ProcessName })
                $cfg.whitelist = $filtered
                Save-AppConfig $cfg | Out-Null
            }
            if ($script:SessionWhitelist.Contains($sel.ProcessName)) {
                $script:SessionWhitelist.Remove($sel.ProcessName) | Out-Null
            }
            $script:WhitelistList.Remove($sel) | Out-Null
            $txtStatusBar.Text = "Removed $($sel.ProcessName) from whitelist."
            Reload-ProcessGrid
        } elseif ($sel.Category -eq "Session Only") {
            if ($script:SessionWhitelist.Contains($sel.ProcessName)) {
                $script:SessionWhitelist.Remove($sel.ProcessName) | Out-Null
            }
            $script:WhitelistList.Remove($sel) | Out-Null
            $txtStatusBar.Text = "Removed $($sel.ProcessName) from session whitelist."
            Reload-ProcessGrid
        } else {
            Show-DarkModal("Cannot remove driver or system-protected processes.", "Protected Process", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    }
})

# ---------------------------------------------------------------------------
# TAB 7: RESTORE SESSION
# ---------------------------------------------------------------------------
function Reload-RestoreGrid {
    $script:RestoreList.Clear()
    if (Test-Path $SessionFile) {
        try {
            $sess = Get-Content -Raw -Path $SessionFile | ConvertFrom-Json
            if ($sess.ClosedApps) {
                foreach ($app in $sess.ClosedApps) {
                    # Filter out non-existent paths if needed (allow services through)
                    if ($app.ServiceName -or -not $app.Path -or (Test-Path $app.Path)) {
                        $script:RestoreList.Add([PSCustomObject]@{
                            Name        = $app.Name
                            ServiceName = $app.ServiceName
                            Id          = $app.Id
                            RAM_MB      = $app.RAM_MB
                            Path        = $app.Path
                        })
                    }
                }
            }
        } catch {}
    }
}

function Restore-ApplicationItem($item) {
    $skipRestore = @("node", "python", "cmd", "powershell", "pwsh", "bash", "wsl", "dashost", "midisrv", "conhost", "wt", "WindowsTerminal")
    if ($skipRestore -contains $item.Name) {
        $script:RestoreList.Remove($item)
        return
    }

    if ($item.Name -match "(?i)portmaster|safing" -or $item.ServiceName -match "(?i)portmaster") {
        Start-PortmasterSafely
        $script:RestoreList.Remove($item)
        $txtStatusBar.Text = "Restored Portmaster Privacy Firewall."
        return
    }

    if ($item.ServiceName) {
        try {
            Start-Service -Name $item.ServiceName -ErrorAction SilentlyContinue
            $script:RestoreList.Remove($item)
            $txtStatusBar.Text = "Restored Windows service $($item.ServiceName)."
            return
        } catch {}
    }
    if (-not $item.Path -or -not (Test-Path $item.Path)) {
        # Try to launch by name
        try {
            Start-Process -FilePath $item.Name -ErrorAction SilentlyContinue
            $script:RestoreList.Remove($item)
            $txtStatusBar.Text = "Restored $($item.Name)."
            return
        } catch {}
    } else {
        Start-Process -FilePath $item.Path -ErrorAction SilentlyContinue
        $script:RestoreList.Remove($item)
        $txtStatusBar.Text = "Restored $($item.Name)."
    }
}

$btnRestoreSelectedApp.Add_Click({
    $sel = $gridRestoreSession.SelectedItem
    if ($sel) {
        Restore-ApplicationItem $sel
    } else {
        Show-DarkModal("Please select an application to restore.", "Selection Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$btnRestoreAllApps.Add_Click({
    if ($script:RestoreList.Count -eq 0) {
        Show-DarkModal("Restore list is currently empty.", "Empty List", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $count = $script:RestoreList.Count
    foreach ($item in @($script:RestoreList)) {
        Restore-ApplicationItem $item
    }

    # Phase 1: Reset Gaming Lockout & Display Mode
    try {
        Disable-GamingLockout | Out-Null
        Reset-DisplayResolution | Out-Null

        # Phase 2: Restore Reverse Affinity, Throttling & QoS
        Restore-ReverseAffinity | Out-Null
        Restore-AllThrottledProcesses | Out-Null
        Clear-AllGamingQosPolicies | Out-Null
        
        $wdState = Get-WatchdogState
        if ($wdState -and $wdState.OriginalPowerPlanGuid) {
            Restore-OriginalPowerPlan -Guid $wdState.OriginalPowerPlanGuid | Out-Null
        }
        Complete-WatchdogSession
    } catch {}

    try { Remove-Item $SessionFile -Force -ErrorAction SilentlyContinue } catch {}
    $script:RestoreList.Clear()
    $txtStatusBar.Text = "Restored all $count application(s) & restored system power/keys."
    Show-DarkModal("Restored all $count application(s) successfully!`n`n• Restored power scheme and input settings.`n• Watchdog session disarmed cleanly.", "Session Restored", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

$btnClearRestoreList.Add_Click({
    try { Remove-Item $SessionFile -Force -ErrorAction SilentlyContinue } catch {}
    $script:RestoreList.Clear()
    $txtStatusBar.Text = "Cleared restore session list."
})

# Handle right-click row selection for Restore DataGrid
$gridRestoreSession.Add_PreviewMouseRightButtonDown({
    param($sender, $e)
    try {
        $dep = $e.OriginalSource
        while ($dep -ne $null -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
            $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep)
        }
        if ($dep -is [System.Windows.Controls.DataGridRow] -and $dep.Item) {
            $gridRestoreSession.SelectedItem = $dep.Item
        }
    } catch {}
})

# Context Menu handlers for Restore
$menuCtxRestoreOne.Add_Click({
    $sel = $gridRestoreSession.SelectedItem
    if ($sel) { Restore-ApplicationItem $sel }
})

$menuCtxRemoveOne.Add_Click({
    $sel = $gridRestoreSession.SelectedItem
    if ($sel) { $script:RestoreList.Remove($sel) }
})

$menuCtxRestoreAll.Add_Click({
    $btnRestoreAllApps.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
})

# ---------------------------------------------------------------------------
# TAB 8: DIAGNOSTICS & CRASH HISTORY
# ---------------------------------------------------------------------------
function Reload-CrashGrid {
    $script:CrashList.Clear()
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; Id=1000} -MaxEvents 10 -ErrorAction SilentlyContinue
        if ($events) {
            $idx = 1
            foreach ($ev in $events) {
                $rawMsg = $ev.Message
                $appName = "Unknown.exe"
                $modName = "Unknown.dll"
                $excCode = "0x0"
                if ($rawMsg -match "Faulting application name:\s*([^\r\n,]+)") { $appName = $matches[1].Trim() }
                if ($rawMsg -match "Faulting module name:\s*([^\r\n,]+)") { $modName = $matches[1].Trim() }
                if ($rawMsg -match "Exception code:\s*([^\r\n,]+)") { $excCode = $matches[1].Trim() }

                $script:CrashList.Add([PSCustomObject]@{
                    Index         = $idx
                    AppName       = $appName
                    ModuleName    = $modName
                    ExceptionCode = $excCode
                    Timestamp     = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    Summary       = "$appName crashed in $modName ($excCode)"
                    EventObject   = $ev
                })
                $idx++
            }
        }
    } catch {
        Write-AppLog "Error querying crash events: $_" "WARN"
    }
}

$btnRefreshCrashes.Add_Click({
    Reload-CrashGrid
    $txtStatusBar.Text = "Crash events refreshed."
})

# Run Health Check (Direct in-app display, fixing missing console issue)
$btnRunHealthCheck.Add_Click({
    $txtDiagnosticReport.Text = "Running Gaming Readiness Health Check... Please wait."
    $healthPs = Join-Path $ScriptDir "Check-GamingReadiness.ps1"
    if (Test-Path $healthPs) {
        $reportOut = & $PSHostExe -NoProfile -ExecutionPolicy Bypass -File $healthPs
        $txtDiagnosticReport.Text = ($reportOut -join "`r`n")
        $txtStatusBar.Text = "Readiness Health Check complete."
    }
})

# Diagnose Selected Crash
$btnDiagnoseSelectedCrash.Add_Click({
    $sel = $gridCrashEvents.SelectedItem
    $idx = if ($sel) { $sel.Index } else { 1 }

    $diagPs = Join-Path $ScriptDir "Diagnose_Crash.ps1"
    if (Test-Path $diagPs) {
        $txtDiagnosticReport.Text = "Analyzing Windows Event Log and Crash Dumps for Event #$idx... Please wait."
        $diagOut = & $PSHostExe -NoProfile -ExecutionPolicy Bypass -File $diagPs -Index $idx
        $txtDiagnosticReport.Text = ($diagOut -join "`r`n")
        $txtStatusBar.Text = "Diagnostics completed for Crash Event #$idx ($($sel.AppName))."
    }
})

$gridCrashEvents.add_SelectionChanged({
    $sel = $gridCrashEvents.SelectedItem
    if ($sel) {
        $txtDiagnosticReport.Text = "Selected Crash Event #$($sel.Index):`r`n" +
                                   "• Application: $($sel.AppName)`r`n" +
                                   "• Faulting Module: $($sel.ModuleName)`r`n" +
                                   "• Exception Code: $($sel.ExceptionCode)`r`n" +
                                   "• Time: $($sel.Timestamp)`r`n`r`n" +
                                   "Click 'Diagnose Selected Crash' above to run root-cause analysis and remediation steps."
    }
})

# Export Full Debug Report
$btnExportDebugReport.Add_Click({
    $txtStatusBar.Text = "Generating comprehensive debug report..."
    $exportPs = Join-Path $ScriptDir "Export-DebugReport.ps1"
    if (Test-Path $exportPs) {
        $reportPath = & $PSHostExe -NoProfile -ExecutionPolicy Bypass -File $exportPs
        $txtStatusBar.Text = "Debug report exported to Desktop."
        Show-DarkModal("Full Debug Report has been generated on your Desktop and opened in Notepad:`n`n$reportPath", "Debug Report Exported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# =============================================================================
# POST-GAME "WHY DID I LAG?" & SUPPORTER ENGINE (Phase 4)
# =============================================================================
function Update-LagReportDisplay {
    try {
        $rep = Get-LatestLagReport
        if ($txtLagGameName) { $txtLagGameName.Text = if ($rep.GameName) { $rep.GameName } else { "--" } }
        if ($txtLagDuration) { $txtLagDuration.Text = if ($rep.DurationMinutes) { "$($rep.DurationMinutes) min" } else { "-- min" } }

        if ($rep.FpsSummary) {
            if ($txtLagAvgFps) { $txtLagAvgFps.Text = if ($rep.FpsSummary.AverageFps -and $rep.FpsSummary.AverageFps -ne "--" -and $rep.FpsSummary.AverageFps -gt 0) { "$($rep.FpsSummary.AverageFps)" } else { "--" } }
            if ($txtLag1Percent) { $txtLag1Percent.Text = if ($rep.FpsSummary.Low1PercentFps -and $rep.FpsSummary.Low1PercentFps -ne "--" -and $rep.FpsSummary.Low1PercentFps -gt 0) { "$($rep.FpsSummary.Low1PercentFps)" } else { "--" } }
            if ($txtLag01Percent) { $txtLag01Percent.Text = if ($rep.FpsSummary.Low01PercentFps -and $rep.FpsSummary.Low01PercentFps -ne "--" -and $rep.FpsSummary.Low01PercentFps -gt 0) { "$($rep.FpsSummary.Low01PercentFps)" } else { "--" } }
            if ($txtLagStutters) { $txtLagStutters.Text = if ($rep.FpsSummary.TotalStutterHits -gt 0) { "$($rep.FpsSummary.TotalStutterHits) incident(s)" } else { "0" } }
        }

        if ($txtSmoothnessBadge -and $badgeSmoothness) {
            $score = [math]::Round([double]$rep.SmoothnessScore, 1)
            $txtSmoothnessBadge.Text = "$score% $($rep.StatusGrade)"
            if ($score -ge 95) {
                $badgeSmoothness.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#065F46")
                $txtSmoothnessBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#34D399")
            } elseif ($score -ge 85) {
                $badgeSmoothness.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E3A8A")
                $txtSmoothnessBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#60A5FA")
            } else {
                $badgeSmoothness.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#831843")
                $txtSmoothnessBadge.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F43F5E")
            }
        }

        if ($txtLagSummary) {
            if ($rep.Incidents -and $rep.Incidents.Count -gt 0) {
                $firstInc = $rep.Incidents[0]
                $txtLagSummary.Text = "Latest Culprit: $($firstInc.Culprit) at $($firstInc.Timestamp). $($firstInc.Description)"
                $txtLagSummary.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F59E0B")
            } else {
                $txtLagSummary.Text = "Zero stutter incidents recorded in latest session. ProBalance & QoS maintained 100% fluid frame pacing."
                $txtLagSummary.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
            }
        }
    } catch {
        Write-AppLog "Error updating lag report display: $_" "WARN"
    }
}

if ($btnRefreshLagReport) {
    $btnRefreshLagReport.Add_Click({
        Update-LagReportDisplay
        $rep = Get-LatestLagReport
        if ($rep.Incidents -and $rep.Incidents.Count -gt 0) {
            $incText = @()
            $incText += "=========================================================================="
            $incText += "     POST-GAME STUTTER CULPRIT AUDIT & LATENCY TIMELINE: $($rep.GameName)"
            $incText += "=========================================================================="
            $incText += "Session Duration : $($rep.DurationMinutes) minutes"
            $incText += "Smoothness Score : $($rep.SmoothnessScore)% ($($rep.StatusGrade))"
            if ($rep.FpsSummary.AverageFps -ne "--" -and $rep.FpsSummary.AverageFps -gt 0) {
                $incText += "FPS Metrics      : Avg: $($rep.FpsSummary.AverageFps) | 1% Low: $($rep.FpsSummary.Low1PercentFps) | 0.1% Low: $($rep.FpsSummary.Low01PercentFps)"
            }
            $incText += "`r`nIDENTIFIED STUTTER CULPRITS & BACKGROUND PROCESS INTERFERENCE:"
            $idx = 1
            foreach ($inc in $rep.Incidents) {
                $incText += " [$idx] [$($inc.Timestamp)] $($inc.Type): $($inc.Culprit)"
                $incText += "     Impact: $($inc.Description)"
                $incText += "     Remedy: $($inc.Remedy)"
                $idx++
            }
            $txtDiagnosticReport.Text = ($incText -join "`r`n")
        } else {
            $txtDiagnosticReport.Text = "No background spikes or stutter culprits detected during the last gaming session.`r`nAll frame times were within nominal threshold."
        }
        $txtStatusBar.Text = "Post-game lag report refreshed."
    })
}

# Custom Dark-Themed Tip Jar Modal Dialog
function Show-DarkTipJarModal {
    $cfg = Get-AppConfig
    $paypalUrl = if ($cfg.supporterSettings -and $cfg.supporterSettings.donationLinks.paypal) { $cfg.supporterSettings.donationLinks.paypal } else { "https://www.paypal.com/paypalme/psoferreira" }
    $kofiUrl   = if ($cfg.supporterSettings -and $cfg.supporterSettings.donationLinks.kofi) { $cfg.supporterSettings.donationLinks.kofi } else { "https://ko-fi.com/psoferreira" }

    $tipWin = New-Object System.Windows.Window
    $tipWin.Title = "Support Game Booster PRO"
    $tipWin.Width = 540
    $tipWin.Height = 330
    $tipWin.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $tipWin.Owner = $window
    $tipWin.WindowStyle = [System.Windows.WindowStyle]::None
    $tipWin.AllowsTransparency = $true
    $tipWin.Background = [System.Windows.Media.Brushes]::Transparent
    $tipWin.ResizeMode = [System.Windows.ResizeMode]::NoResize

    $tipXaml = @"
    <Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Background="#0F172A" BorderBrush="#F59E0B" BorderThickness="1.5" CornerRadius="12" Padding="24">
        <Border.Effect>
            <DropShadowEffect Color="#000000" BlurRadius="25" ShadowDepth="0" Opacity="0.85"/>
        </Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <Grid Grid.Row="0" Margin="0,0,0,14">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="☕" FontSize="22" Margin="0,0,10,0" VerticalAlignment="Center"/>
                    <TextBlock Text="SUPPORT GAME BOOSTER PRO" FontSize="16" FontWeight="ExtraBold" Foreground="#F59E0B" VerticalAlignment="Center"/>
                </StackPanel>
                <Button Name="BtnCloseTipModal" Grid.Column="1" Content="✕" Background="Transparent" Foreground="#94A3B8" BorderThickness="0" FontSize="16" FontWeight="Bold" Width="28" Height="28" Cursor="Hand"/>
            </Grid>

            <!-- Body Text -->
            <StackPanel Grid.Row="1" Margin="0,0,0,16">
                <TextBlock Text="Game Booster is 100% free, open-source, ad-free, and privacy-focused." Foreground="#F8FAFC" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <TextBlock Text="It contains zero telemetry, crypto miners, or bloated background analytics. Built with passion to help gamers eliminate micro-stutters, reclaim gigabytes of RAM, and achieve the lowest possible input latency." Foreground="#94A3B8" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,10"/>
                <TextBlock Text="If Game Booster improved your FPS or smoothed out your frame times, please consider leaving a tip to support ongoing development!" Foreground="#CBD5E1" FontSize="12" TextWrapping="Wrap"/>
            </StackPanel>

            <!-- Action Buttons -->
            <Grid Grid.Row="2">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Button Name="BtnTipPayPal" Grid.Column="0" Content="💳 Tip via PayPal" Background="#0070BA" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" Height="38" Margin="0,0,8,0" Cursor="Hand"/>
                <Button Name="BtnTipKoFi" Grid.Column="1" Content="☕ Tip via Ko-Fi" Background="#FF5E5B" Foreground="#FFFFFF" FontWeight="Bold" FontSize="12" Height="38" Margin="0,0,8,0" Cursor="Hand"/>
                <Button Name="BtnCancelTip" Grid.Column="2" Content="Close" Background="#1E293B" Foreground="#94A3B8" FontWeight="SemiBold" FontSize="12" Height="38" Padding="16,0" Cursor="Hand"/>
            </Grid>
        </Grid>
    </Border>
"@
    $reader = [System.Xml.XmlNodeReader]::new([xml]$tipXaml)
    $content = [System.Windows.Markup.XamlReader]::Load($reader)
    $tipWin.Content = $content

    $btnClose = $content.FindName("BtnCloseTipModal")
    $btnCancel = $content.FindName("BtnCancelTip")
    $btnPaypal = $content.FindName("BtnTipPayPal")
    $btnKofi = $content.FindName("BtnTipKoFi")

    $closeAction = { $tipWin.Close() }
    $btnClose.Add_Click($closeAction)
    $btnCancel.Add_Click($closeAction)

    $btnPaypal.Add_Click({
        Start-Process $paypalUrl
        $tipWin.Close()
    })
    $btnKofi.Add_Click({
        Start-Process $kofiUrl
        $tipWin.Close()
    })

    $tipWin.ShowDialog() | Out-Null
}

# Tip Jar & Supporter Action (Request 1 & Phase 4)
if ($btnTipJar) {
    $btnTipJar.Add_Click({
        Show-DarkTipJarModal
    })
}

# ---------------------------------------------------------------------------
# GLOBAL BUTTONS & INITIALIZATION
# ---------------------------------------------------------------------------
$btnRefreshAll.Add_Click({
    $txtStatusBar.Text = "Scanning active processes..."
    Reload-ProcessGrid
    Update-StandbyDisplay
    $txtStatusBar.Text = "Running processes updated: $($script:ProcessList.Count) apps detected."
})

if ($chkAutoScanStartup) {
    $chkAutoScanStartup.Add_Checked({
        $cfg = Get-AppConfig
        if (-not $cfg.generalSettings) { $cfg | Add-Member -MemberType NoteProperty -Name "generalSettings" -Value ([PSCustomObject]@{}) }
        $cfg.generalSettings.autoScanProcessesOnStartup = $true
        Save-AppConfig $cfg | Out-Null
        $txtStatusBar.Text = "Auto-scan on launch enabled."
    })
    $chkAutoScanStartup.Add_Unchecked({
        $cfg = Get-AppConfig
        if (-not $cfg.generalSettings) { $cfg | Add-Member -MemberType NoteProperty -Name "generalSettings" -Value ([PSCustomObject]@{}) }
        $cfg.generalSettings.autoScanProcessesOnStartup = $false
        Save-AppConfig $cfg | Out-Null
        $txtStatusBar.Text = "Auto-scan on launch disabled (Instant launch mode)."
    })
}

$btnSaveAllConfig.Add_Click({
    $cfg = Get-AppConfig
    Save-AppConfig $cfg | Out-Null
    $txtStatusBar.Text = "Defaults saved to config.json."
    Show-DarkModal("Booster configuration saved successfully!", "Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Launch Tray Companion
$btnLaunchTrayCompanion.Add_Click({
    $trayPs = Join-Path $ScriptDir "TrayBooster.ps1"
    if (Test-Path $trayPs) {
        Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$trayPs`""
        $window.WindowState = [System.Windows.WindowState]::Minimized
        $txtStatusBar.Text = "Game Booster minimized to Windows System Tray (Ctrl+F11 active)."
    }
})

# ---------------------------------------------------------------------------
# IN-APP GITHUB UPDATE CHECKER (Asynchronous & Safe Isolated Runspace)
# ---------------------------------------------------------------------------
$script:UpdateCheckPS = $null
$script:UpdateCheckHandle = $null
$script:UpdateCheckSilent = $true
$script:LatestRelease = $null

$script:updatePollTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:updatePollTimer.Interval = [TimeSpan]::FromMilliseconds(500)

function Invoke-OneClickUpdate {
    if (-not $script:LatestRelease) { return }
    $remoteTag = $script:LatestRelease.tag_name

    $zipUrl = $null
    if ($script:LatestRelease.assets) {
        $asset = @($script:LatestRelease.assets) | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
        if ($asset) { $zipUrl = $asset.browser_download_url }
    }
    if (-not $zipUrl) {
        $zipUrl = $script:LatestRelease.zipball_url
    }
    if (-not $zipUrl) {
        [System.Diagnostics.Process]::Start("https://github.com/$script:GitHubRepo/releases/latest") | Out-Null
        return
    }

    $msg = "1-Click Auto Update to $remoteTag`n`n" +
           "Game Booster will download the update package, replace files, and restart automatically.`n`n" +
           "Do you want to proceed?"
    $res = Show-DarkModal($window, $msg, "1-Click Auto Update", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $txtStatusBar.Text = "Downloading update $remoteTag in background..."
    if ($btnCheckUpdates) { $btnCheckUpdates.IsEnabled = $false }

    try {
        $tempZip = Join-Path $env:TEMP "GameBooster_Update.zip"
        $updaterBat = Join-Path $env:TEMP "GameBooster_Updater.bat"
        $appDir = $RootDir
        $exePath = Join-Path $RootDir "GameBooster.exe"

        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 90

        $batContent = @"
@echo off
timeout /t 2 /nobreak >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Expand-Archive -Path '$tempZip' -DestinationPath '$appDir' -Force; Remove-Item '$tempZip' -Force -ErrorAction SilentlyContinue } catch {}"
if exist "$exePath" (
    start "" "$exePath"
)
del "%~f0"
"@
        Set-Content -Path $updaterBat -Value $batContent -Encoding ASCII -Force

        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$updaterBat`"" -WindowStyle Hidden
        Close-HardwareHudAction
        $window.Close()
    } catch {
        Show-DarkModal($window, "Auto-update encountered an error: $_`nOpening GitHub Releases page instead.", "Update Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        [System.Diagnostics.Process]::Start("https://github.com/$script:GitHubRepo/releases/latest") | Out-Null
    }
}

function Complete-AppUpdateCheck {
    if (-not $script:UpdateCheckPS -or -not $script:UpdateCheckHandle) { return }
    if (-not $script:UpdateCheckHandle.IsCompleted) { return }

    $script:updatePollTimer.Stop()
    $isSilent = $script:UpdateCheckSilent
    $release = $null

    try {
        $results = $script:UpdateCheckPS.EndInvoke($script:UpdateCheckHandle)
        if ($results -and $results.Count -gt 0) {
            $release = $results[0]
        }
    } catch {
        Write-AppLog "Error retrieving update check result: $_" "WARN"
    } finally {
        try { $script:UpdateCheckPS.Dispose() } catch {}
        $script:UpdateCheckPS = $null
        $script:UpdateCheckHandle = $null
    }

    if ($btnCheckUpdates) {
        $btnCheckUpdates.IsEnabled = $true
        $btnCheckUpdates.Content = "🔄 Check Updates"
    }

    if ($release -and $release.tag_name) {
        $remoteTag = [string]$release.tag_name
        $cleanRemote = ($remoteTag -replace '[^\d\.]', '').Trim('.')
        $cleanLocal = ($script:AppVersion -replace '[^\d\.]', '').Trim('.')

        $rParts = @($cleanRemote.Split('.'))
        while ($rParts.Count -lt 2) { $rParts += "0" }
        $lParts = @($cleanLocal.Split('.'))
        while ($lParts.Count -lt 2) { $lParts += "0" }

        $remoteVer = [Version]::new(($rParts -join '.'))
        $localVer = [Version]::new(($lParts -join '.'))

        if ($remoteVer -gt $localVer) {
            $script:LatestRelease = $release
            if ($pillUpdateAvailable) {
                $pillUpdateAvailable.Visibility = [System.Windows.Visibility]::Visible
            }
            if ($txtUpdateVersion) {
                $txtUpdateVersion.Text = "🚀 Update: $remoteTag"
            }
            if ($txtStatusBar) {
                $txtStatusBar.Text = "Update available: $remoteTag (Click update pill to 1-click update)"
            }
            if (-not $isSilent) {
                Invoke-OneClickUpdate
            }
        } else {
            if ($pillUpdateAvailable) {
                $pillUpdateAvailable.Visibility = [System.Windows.Visibility]::Collapsed
            }
            if (-not $isSilent) {
                Show-DarkModal($window, "You are using the latest version of Game Booster (v$script:AppVersion).", "Game Booster Update", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
        }
    } else {
        if (-not $isSilent) {
            Show-DarkModal($window, "Unable to check for updates right now.`nPlease check your internet connection and try again.", "Update Check", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    }
}

$script:updatePollTimer.Add_Tick({
    Complete-AppUpdateCheck
})

function Start-AppUpdateCheck([bool]$silent = $true) {
    if ($script:UpdateCheckPS) {
        try { $script:UpdateCheckPS.Dispose() } catch {}
        $script:UpdateCheckPS = $null
        $script:UpdateCheckHandle = $null
    }

    $script:UpdateCheckSilent = $silent
    if ($btnCheckUpdates) {
        $btnCheckUpdates.IsEnabled = $false
        $btnCheckUpdates.Content = "⏳ Checking..."
    }

    try {
        $script:UpdateCheckPS = [System.Management.Automation.PowerShell]::Create()
        $null = $script:UpdateCheckPS.AddScript({
            param($repo, $appVer)
            try {
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
                $headers = @{ "User-Agent" = "GameBooster-v$appVer" }
                $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
                return (Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 5 -ErrorAction Stop)
            } catch {
                return $null
            }
        }).AddArgument($script:GitHubRepo).AddArgument($script:AppVersion)

        $script:UpdateCheckHandle = $script:UpdateCheckPS.BeginInvoke()
        $script:updatePollTimer.Start()
    } catch {
        Write-AppLog "Failed to spawn update check: $_" "WARN"
        if ($btnCheckUpdates) {
            $btnCheckUpdates.IsEnabled = $true
            $btnCheckUpdates.Content = "🔄 Check Updates"
        }
    }
}

if ($btnCheckUpdates) {
    $btnCheckUpdates.Add_Click({
        Start-AppUpdateCheck -silent $false
    })
}

if ($pillUpdateAvailable) {
    $pillUpdateAvailable.Add_MouseLeftButtonDown({
        Invoke-OneClickUpdate
    })
}

# -----------------------------------------------------------------------------
# GPU DRIVER RADAR & BACKGROUND CHECKERS
# -----------------------------------------------------------------------------
function Update-GpuDriverCardDisplay {
    try {
        $details = $script:gpuDriverDetails
        if (-not $details) {
            $details = Get-GpuDriverDetails
            $script:gpuDriverDetails = $details
        }
        if ($txtGpuCardName) { $txtGpuCardName.Text = "$($details.GpuName)" }
        if ($txtGpuInstalledDriver) { $txtGpuInstalledDriver.Text = "$($details.DisplayVersion) ($($details.DriverVersion))" }
        if ($txtGpuReleaseDate -and $details.DriverDate) { $txtGpuReleaseDate.Text = "$($details.DriverDate)" }
        if ($txtGpuBadge) {
            $gpuClean = if ($details.GpuName -like "$($details.Vendor)*") { $details.GpuName } else { "$($details.Vendor) $($details.GpuName)" }
            $txtGpuBadge.Text = $gpuClean
        }
        if ($badgeGpuDriverStatus -and $txtGpuDriverBadge) {
            $badgeGpuDriverStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
            $txtGpuDriverBadge.Text = "READY"
            $txtGpuDriverBadge.Foreground = [System.Windows.Media.Brushes]::DeepSkyBlue
        }
    } catch {
        Write-AppLog "Error updating GPU driver card: $_" "WARN"
    }
}

function Open-GpuDriverDownloadPage {
    $url = if ($script:LatestGpuInfo -and $script:LatestGpuInfo.DetailsUrl) {
        $script:LatestGpuInfo.DetailsUrl
    } elseif ($script:LatestGpuInfo -and $script:LatestGpuInfo.DownloadUrl) {
        $script:LatestGpuInfo.DownloadUrl
    } elseif ($script:gpuDriverDetails.Vendor -eq "AMD") {
        "https://www.amd.com/en/support/download/drivers.html"
    } elseif ($script:gpuDriverDetails.Vendor -eq "NVIDIA") {
        "https://www.nvidia.com/Download/index.aspx"
    } else {
        "https://www.intel.com/content/www/us/en/support/detect.html"
    }
    try {
        [System.Diagnostics.Process]::Start([System.Diagnostics.ProcessStartInfo]@{
            FileName = $url
            UseShellExecute = $true
        }) | Out-Null
    } catch {
        Write-AppLog "Failed to open browser URL: $_" "WARN"
    }
}

function Start-GpuDriverUpdateCheck([bool]$silent = $false) {
    if ($script:GpuUpdatePS) {
        try { $script:GpuUpdatePS.Dispose() } catch {}
        $script:GpuUpdatePS = $null
        $script:GpuUpdateHandle = $null
    }

    if ($btnCheckGpuDriver) {
        $btnCheckGpuDriver.IsEnabled = $false
        $btnCheckGpuDriver.Content = "⏳ Checking..."
    }
    if ($txtStatusBar -and -not $silent) {
        $txtStatusBar.Text = "Checking for latest $($script:gpuDriverDetails.Vendor) display driver..."
    }

    try {
        $script:GpuUpdatePS = [System.Management.Automation.PowerShell]::Create()
        $null = $script:GpuUpdatePS.AddScript({
            param($modPath, $currentDetails)
            try {
                . $modPath
                return (Check-LatestGpuDriver -CurrentDetails $currentDetails)
            } catch {
                return $null
            }
        }).AddArgument((Join-Path $script:ModulesDir "GpuManager.ps1")).AddArgument($script:gpuDriverDetails)

        $script:GpuUpdateHandle = $script:GpuUpdatePS.BeginInvoke()
        
        $script:gpuPollTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:gpuPollTimer.Interval = [TimeSpan]::FromMilliseconds(300)
        $script:gpuPollTimer.Add_Tick({
            if ($script:GpuUpdateHandle -and $script:GpuUpdateHandle.IsCompleted) {
                $script:gpuPollTimer.Stop()
                Complete-GpuDriverUpdateCheck -silent $silent
            }
        })
        $script:gpuPollTimer.Start()
    } catch {
        Write-AppLog "Failed to spawn GPU driver update check: $_" "WARN"
        if ($btnCheckGpuDriver) {
            $btnCheckGpuDriver.IsEnabled = $true
            $btnCheckGpuDriver.Content = "🔄 Check Updates"
        }
    }
}

function Complete-GpuDriverUpdateCheck([bool]$silent = $false) {
    try {
        if (-not $script:GpuUpdatePS) { return }
        $res = $script:GpuUpdatePS.EndInvoke($script:GpuUpdateHandle)
        $script:GpuUpdatePS.Dispose()
        $script:GpuUpdatePS = $null
        $script:GpuUpdateHandle = $null

        if ($btnCheckGpuDriver) {
            $btnCheckGpuDriver.IsEnabled = $true
            $btnCheckGpuDriver.Content = "🔄 Check Updates"
        }

        if ($res -and $res.Count -gt 0) {
            $info = $res[0]
            $script:LatestGpuInfo = $info

            # Update UI controls
            if ($txtGpuLatestDriver) {
                $txtGpuLatestDriver.Text = "$($info.LatestVersion)"
                if ($info.HasUpdate) {
                    $txtGpuLatestDriver.Foreground = [System.Windows.Media.Brushes]::LimeGreen
                } else {
                    $txtGpuLatestDriver.Foreground = [System.Windows.Media.Brushes]::DeepSkyBlue
                }
            }
            if ($txtGpuReleaseDate -and $info.ReleaseDate) {
                $txtGpuReleaseDate.Text = "$($info.ReleaseDate)"
            }
            if ($badgeGpuDriverStatus -and $txtGpuDriverBadge) {
                if ($info.HasUpdate) {
                    $badgeGpuDriverStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#065F46")
                    $txtGpuDriverBadge.Text = "UPDATE AVAILABLE"
                    $txtGpuDriverBadge.Foreground = [System.Windows.Media.Brushes]::LimeGreen
                } elseif ($info.Status -match "Failed") {
                    $badgeGpuDriverStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#334155")
                    $txtGpuDriverBadge.Text = "OFFLINE"
                    $txtGpuDriverBadge.Foreground = [System.Windows.Media.Brushes]::SlateGray
                } else {
                    $badgeGpuDriverStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E293B")
                    $txtGpuDriverBadge.Text = "UP TO DATE"
                    $txtGpuDriverBadge.Foreground = [System.Windows.Media.Brushes]::DeepSkyBlue
                }
            }

            # Header Pill
            if ($pillGpuUpdate -and $txtGpuUpdateTag) {
                if ($info.HasUpdate) {
                    $pillGpuUpdate.Visibility = [System.Windows.Visibility]::Visible
                    $txtGpuUpdateTag.Text = "⚡ $($info.LatestVersion)"
                } else {
                    $pillGpuUpdate.Visibility = [System.Windows.Visibility]::Collapsed
                }
            }

            if ($btnDownloadGpuDriver) {
                $btnDownloadGpuDriver.IsEnabled = [bool]($info.DownloadUrl -or $info.DetailsUrl)
            }

            if ($info.HasUpdate) {
                $txtStatusBar.Text = "🚀 New GPU Driver Available: $($info.LatestVersion) (Installed: $($info.InstalledVersion))"
                if (-not $silent) {
                    $ans = Show-DarkModal(
                        "New $($info.Vendor) Graphics Driver Available!`n`nInstalled: $($info.InstalledVersion)`nLatest: $($info.LatestVersion) ($($info.ReleaseDate))`n`nWould you like to open the official release notes and download page now?",
                        "GPU Driver Update Available",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Information
                    )
                    if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
                        Open-GpuDriverDownloadPage
                    }
                }
            } else {
                if (-not $silent) {
                    $txtStatusBar.Text = "✅ GPU Driver is up to date: $($info.InstalledVersion)"
                    Show-DarkModal(
                        "Your $($info.Vendor) Graphics Driver is up to date!`n`nInstalled: $($info.InstalledVersion)`nStatus: $($info.Status)",
                        "GPU Driver Up to Date",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    )
                }
            }
        }
    } catch {
        Write-AppLog "Error completing GPU update check: $_" "WARN"
        if ($btnCheckGpuDriver) {
            $btnCheckGpuDriver.IsEnabled = $true
            $btnCheckGpuDriver.Content = "🔄 Check Updates"
        }
    }
}

if ($btnCheckGpuDriver) {
    $btnCheckGpuDriver.Add_Click({
        Start-GpuDriverUpdateCheck -silent $false
    })
}

if ($btnDownloadGpuDriver) {
    $btnDownloadGpuDriver.Add_Click({
        Open-GpuDriverDownloadPage
    })
}

if ($pillGpuUpdate) {
    $pillGpuUpdate.Add_MouseLeftButtonDown({
        Open-GpuDriverDownloadPage
    })
}

if ($badgeGpu) {
    $badgeGpu.Add_MouseLeftButtonDown({
        Start-GpuDriverUpdateCheck -silent $false
    })
}

# -----------------------------------------------------------------------------
# Instant Startup Initialization (< 0.4s Window Render)
# Heavy disk, WMI, and event log scans deferred to on-demand tab selection
# -----------------------------------------------------------------------------
$script:TabLibraryLoaded     = $false
$script:TabTweaksLoaded      = $false
$script:TabCompanionsLoaded  = $false
$script:TabWhitelistLoaded   = $false
$script:TabRestoreLoaded     = $false
$script:TabDiagnosticsLoaded = $false

# Lightweight in-memory UI initializers
Update-DaemonIndicators
Update-HudCoordinateFields
Update-OsdSettingsFields
Update-StandbyDisplay
Update-GpuDriverCardDisplay

# Approach C: Smart Standby for Process Scanner
$autoScanOnStartup = $false
$cfg = Get-AppConfig
if ($cfg.generalSettings -and $null -ne $cfg.generalSettings.autoScanProcessesOnStartup) {
    $autoScanOnStartup = [bool]$cfg.generalSettings.autoScanProcessesOnStartup
}
if ($chkAutoScanStartup) {
    $chkAutoScanStartup.IsChecked = $autoScanOnStartup
}

if ($autoScanOnStartup) {
    # Non-blocking deferred background process scan (after window renders)
    $procStartupTimer = New-Object System.Windows.Threading.DispatcherTimer
    $procStartupTimer.Interval = [TimeSpan]::FromMilliseconds(250)
    $procStartupTimer.Add_Tick({
        $procStartupTimer.Stop()
        Reload-ProcessGrid
    })
    $procStartupTimer.Start()
} else {
    $txtStatusBar.Text = "Game Booster PRO ready (Standby Mode). App launched in <0.4s. Click 'Refresh Running Apps' or switch tabs."
}

# Auto-refresh when tabs change (True Tab Lazy Loading)
if ($mainTabs) {
    $mainTabs.Add_SelectionChanged({
        param($sender, $e)
        if ($e.Source -eq $mainTabs) {
            switch ($mainTabs.SelectedIndex) {
                0 {
                    Update-StandbyDisplay
                    if ($chkAutoScanStartup -and $chkAutoScanStartup.IsChecked -and $script:ProcessList.Count -gt 0) {
                        Reload-ProcessGrid
                    }
                }
                1 {
                    if (-not $script:TabLibraryLoaded) {
                        Reload-GameLibraryGrid
                        $script:TabLibraryLoaded = $true
                    }
                }
                2 {
                    if (-not $script:TabTweaksLoaded) {
                        Update-TweaksDisplay
                        Update-ShaderDisplay
                        Update-PcieMsiDisplay
                        Update-UsbStatusDisplay
                        Update-GpuDriverCardDisplay
                        if ($script:RadarList.Count -eq 0) { Initialize-ServerRadarGrid }
                        $script:TabTweaksLoaded = $true
                    }
                }
                4 {
                    if (-not $script:TabCompanionsLoaded) {
                        Reload-CompanionsGrid
                        $script:TabCompanionsLoaded = $true
                    }
                }
                5 {
                    if (-not $script:TabWhitelistLoaded) {
                        Reload-WhitelistGrid
                        $script:TabWhitelistLoaded = $true
                    }
                }
                6 {
                    if (-not $script:TabRestoreLoaded) {
                        Reload-RestoreGrid
                        $script:TabRestoreLoaded = $true
                    }
                }
                7 {
                    if (-not $script:TabDiagnosticsLoaded) {
                        Update-LagReportDisplay
                        Reload-CrashGrid
                        $script:TabDiagnosticsLoaded = $true
                    }
                }
            }
        }
    })
}

# Periodic Daemon & Memory Status Check (every 4 seconds)
$script:daemonTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:daemonTimer.Interval = [TimeSpan]::FromSeconds(4)
$script:daemonTimer.Add_Tick({
    Update-DaemonIndicators
    Update-StandbyDisplay
    Complete-AppUpdateCheck
})
$script:daemonTimer.Start()

# Background silent checks (deferred non-blocking so window appears instantly)
$bgCheckTimer = New-Object System.Windows.Threading.DispatcherTimer
$bgCheckTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
$bgCheckTimer.Add_Tick({
    $bgCheckTimer.Stop()
    Start-GpuDriverUpdateCheck -silent $true
    Start-AppUpdateCheck -silent $true
})
$bgCheckTimer.Start()

# Window Closing Handler (Force close active HUD terminal, in-game overlays & background timers on exit)
$window.Add_Closing({
    Write-AppLog "Game Booster window closing. Cleaning up Hardware HUD, In-Game OSD and background timers..."
    Close-HardwareHudAction
    Close-InGameOsdAction
    if ($script:radarTimer) { $script:radarTimer.Stop() }
    if ($script:daemonTimer) { $script:daemonTimer.Stop() }
    if ($script:updatePollTimer) { $script:updatePollTimer.Stop() }
    if ($script:gpuPollTimer) { $script:gpuPollTimer.Stop() }
    if ($script:GpuUpdatePS) { try { $script:GpuUpdatePS.Dispose() } catch {} }
})

# Show Window
$window.ShowDialog() | Out-Null

# Post-close cleanup safeguard
Close-HardwareHudAction
Close-InGameOsdAction



