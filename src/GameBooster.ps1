# ============================================================================
# Game Mode Booster v1.2.1 PRO
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
$ConfigTemplate = Join-Path $RootDir "config.template.json"
$LogFile = Join-Path $RootDir "gamebooster.log"
$SessionFile = Join-Path $RootDir "last_session.json"
$TrayPidFile = Join-Path $RootDir "tray.pid"

$script:AppVersion = "1.2.1"
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
    . (Join-Path $ModulesDir "CpuOptimizer.ps1")
    . (Join-Path $ModulesDir "GpuManager.ps1")
    . (Join-Path $ModulesDir "MemoryPurge.ps1")
    . (Join-Path $ModulesDir "LibraryScanner.ps1")
    . (Join-Path $ModulesDir "PerGameProfiles.ps1")
    . (Join-Path $ModulesDir "ServerRadar.ps1")
    . (Join-Path $ModulesDir "ShaderCleaner.ps1")
    . (Join-Path $ModulesDir "SystemTweaks.ps1")
    Write-AppLog "All core feature modules imported successfully."
} catch {
    Write-AppLog "Failed to load modules: $_" "ERROR"
}

# Determine PowerShell Host
$PSHostExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }

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
      "explorer", "winlogon", "sppsvc", "SearchIndexer", "SecurityHealthService", "SecurityHealthSystray", 
      "MsMpEng", "NisSrv", "MpDefenderCoreService", "DefenderSessionHelper", "MoUsoCoreWorker", "RuntimeBroker", 
      "StartMenuExperienceHost", "taskhostw", "ctfmon", "SystemSettings", "TextInputHost", "ShellHost", 
      "conhost", "cmd", "pwsh", "powershell", "wt", "WindowsTerminal", "GameBooster", "taskmgr",
      "dashost", "midisrv", "sihost", "smartscreen", "ApplicationFrameHost", "node", "git")
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
    $gameBinaries = @("cod", "bootstrapper", "cod24", "sp24", "BlackOps6", "Wow", "WowClassic", "Wow-64", "cs2", "csgo", "dota2", "Valorant", "RiotClientServices", "Overwatch", "FortniteClient-Win64-Shipping", "r5apex")
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
        if ($pName -match "(?i)RTSS|MSIAfterburner|HWiNFO|obs|PnkBstr|EasyAntiCheat|BEService|vgc|audiodg|RtkAud|^Rz|^Razer|^SteelSeries|^Logi|LGHUB|iCUE|^Elgato|^Nahimic|^Creative") { continue }

        $pPath = $null
        $pRamTotal = 0
        $firstPid = $grp.Group[0].Id
        $svcName = $null

        foreach ($p in $grp.Group) {
            try {
                if ($serviceMap.ContainsKey([int]$p.Id)) {
                    $svcName = $serviceMap[[int]$p.Id]
                    & sc.exe stop $svcName | Out-Null
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

    # Purge standby RAM
    $purgeRes = Invoke-SmartMemoryPurge
    $totalFreed = $freedRAM + [math]::Round($purgeRes.FreedGB * 1024, 0)

    # Enable Ultimate Performance Power Plan
    Enable-UltimatePerformancePlan | Out-Null

    Write-AppLog "Headless Game Mode activated. Closed $($closedItems.Count) app groups, freed ${freedRAM}MB process RAM, purged $($purgeRes.FreedMB)MB standby RAM."
    if (-not $Silent) {
        Write-Host "Game Mode activated. Freed ${totalFreed}MB RAM." -ForegroundColor Green
    }
    exit 0
}

if ($Restore) {
    Write-AppLog "Headless session restore initiated by Auto-Watcher/CLI..."
    if (-not $Silent) { Write-Host "Restoring applications..." -ForegroundColor Cyan }

    $restoredCount = 0
    if (Test-Path $SessionFile) {
        try {
            $sess = Get-Content -Raw -Path $SessionFile -Encoding UTF8 | ConvertFrom-Json
            if ($sess.ClosedApps) {
                foreach ($app in $sess.ClosedApps) {
                    try {
                        $skipRestore = @("node", "python", "cmd", "powershell", "pwsh", "bash", "wsl", "dashost", "midisrv", "conhost", "wt", "WindowsTerminal")
                        if ($skipRestore -contains $app.Name) { continue }

                        if ($app.ServiceName) {
                            & sc.exe start $app.ServiceName | Out-Null
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
        Title="Game Mode Booster v1.2.1 PRO"
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

        <!-- 1. TOP HEADER BANNER -->
        <Border Grid.Row="0" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="8" Padding="14,10" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="⚡" FontSize="26" Margin="0,0,10,0" VerticalAlignment="Center"/>
                    <StackPanel>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="GAME BOOSTER" FontSize="18" FontWeight="ExtraBold" Foreground="#10B981" Margin="0,0,6,0"/>
                            <Border Background="#047857" CornerRadius="4" Padding="6,2" VerticalAlignment="Center">
                                <TextBlock Text="v1.2.1 PRO" FontSize="10" FontWeight="Bold" Foreground="#FFFFFF"/>
                            </Border>
                            <Border Name="PillUpdateAvailable" Visibility="Collapsed" Background="#1E3A8A" BorderBrush="#3B82F6" BorderThickness="1" CornerRadius="4" Padding="6,2" Margin="8,0,0,0" VerticalAlignment="Center" Cursor="Hand" ToolTip="New version available! Click to download latest release on GitHub">
                                <TextBlock Name="TxtUpdateVersion" Text="🚀 Update Available" FontSize="10" FontWeight="Bold" Foreground="#60A5FA"/>
                            </Border>
                        </StackPanel>
                        <TextBlock Text="Ultra Low-Latency Gaming Engine | Multi-Platform Auto-Detector | Standby Cleaner" FontSize="11" Foreground="#94A3B8"/>
                    </StackPanel>
                </StackPanel>

                <!-- Hardware & Engine Status Pills -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <!-- GPU Badge -->
                    <Border Name="BadgeGpu" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="10,4" Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="GPU: " Foreground="#64748B" FontSize="11" FontWeight="SemiBold"/>
                            <TextBlock Name="TxtGpuBadge" Text="Detecting..." Foreground="#38BDF8" FontSize="11" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>
                    <!-- CPU Architecture Badge -->
                    <Border Name="BadgeCpu" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="10,4" Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="CPU: " Foreground="#64748B" FontSize="11" FontWeight="SemiBold"/>
                            <TextBlock Name="TxtCpuBadge" Text="Topology..." Foreground="#A78BFA" FontSize="11" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>
                    <!-- Tray & Hotkey Pill (Clickable) -->
                    <Border Name="PillTrayStatus" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="10,4" Margin="0,0,8,0" Cursor="Hand" ToolTip="Click to toggle Tray Companion background daemon (Ctrl+F11)">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse Name="DotTray" Width="8" Height="8" Fill="#64748B" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Name="TxtTrayStatus" Text="Tray Companion: OFF" Foreground="#CBD5E1" FontSize="11" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>
                    <!-- Auto-Watcher Pill (Clickable) -->
                    <Border Name="PillWatcherStatus" Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="6" Padding="10,4" Cursor="Hand" ToolTip="Click to toggle Auto-Watcher background daemon">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse Name="DotWatcher" Width="8" Height="8" Fill="#64748B" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Name="TxtWatcherStatus" Text="Auto-Watcher: OFF" Foreground="#CBD5E1" FontSize="11" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
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
                    <DataGrid Name="GridProcesses" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Extended">
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
                    <DataGrid Name="GridGameLibrary" Grid.Row="2" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Single">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Game Title" Binding="{Binding Title}" Width="240" FontWeight="Bold"/>
                            <DataGridTextColumn Header="Process Name (.exe)" Binding="{Binding ProcessName}" Width="180"/>
                            <DataGridTextColumn Header="Platform" Binding="{Binding Platform}" Width="120"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding ExePath}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>

                    <!-- Per-Game Profile Settings Card (Feature 1) -->
                    <Border Grid.Row="3" Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="14,10" Margin="0,10,0,0">
                        <Grid>
                            <Grid.RowDefinitions>
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
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 3: SYSTEM TWEAKS & RADAR (Features 2, 3, 4, 8, 10) -->
            <TabItem Header="⚡ Tweaks &amp; Radar">
                <Grid Margin="12">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="440"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Left Column: 1-Click Windows Gaming Tweaks & Shader Cleaner -->
                    <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,10,0">
                        <StackPanel>
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

                                    <Grid Margin="0,0,0,6">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="TCP NoDelay (Nagle Disabled)" VerticalAlignment="Center" Foreground="#F8FAFC"/>
                                        <Border Name="BadgeTcp" Grid.Column="1" Background="#1E293B" CornerRadius="4" Padding="8,2">
                                            <TextBlock Name="TxtBadgeTcp" Text="CHECKING" FontSize="10" FontWeight="Bold" Foreground="#CBD5E1"/>
                                        </Border>
                                    </Grid>

                                    <Button Name="BtnApplyAllTweaks" Content="⚡ 1-Click Apply All Gaming Tweaks" Background="#10B981" Foreground="#022C22" Height="32" FontWeight="ExtraBold"/>
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

                            <!-- Card 3: Shader Cache & Junk Cleaner (Feature 10) -->
                            <Border Background="#111827" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10">
                                <StackPanel>
                                    <TextBlock Text="📦 SHADER CACHE &amp; JUNK CLEANER" FontWeight="Bold" Foreground="#F59E0B" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBlock Text="Purge bloated DirectX, NVIDIA and AMD pipeline caches to fix stutters." Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,6"/>
                                    <Grid Margin="0,0,0,6">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="Calculated Cache Size:" VerticalAlignment="Center" Foreground="#F8FAFC" FontSize="12"/>
                                        <TextBlock Name="TxtShaderSize" Grid.Column="1" Text="Calculating..." FontWeight="ExtraBold" Foreground="#F59E0B" FontSize="13"/>
                                    </Grid>
                                    <Button Name="BtnCleanShaders" Content="🗑️ Clean Shaders (Fix Stutter)" Background="#D97706" Foreground="#FFFFFF" Height="30" FontWeight="Bold"/>
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

                            <DataGrid Name="GridServerRadar" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Single">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Region" Binding="{Binding Region}" Width="160" FontWeight="Bold"/>
                                    <DataGridTextColumn Header="Datacenter Location" Binding="{Binding Location}" Width="200"/>
                                    <DataGridTextColumn Header="Host / Cluster IP" Binding="{Binding Host}" Width="160"/>
                                    <DataGridTextColumn Header="Ping (ms)" Binding="{Binding PingMs}" Width="90" FontWeight="ExtraBold"/>
                                    <DataGridTextColumn Header="Quality" Binding="{Binding Status}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>

                            <TextBlock Grid.Row="2" Text="* Ping times are measured via ICMP Echo packets with 0ms interval socket batching." Foreground="#64748B" FontSize="10" Margin="0,8,0,0"/>
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

                    <DataGrid Name="GridCompanions" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Single">
                        <DataGrid.Columns>
                            <DataGridCheckBoxColumn Header="Enabled" Binding="{Binding Enabled, UpdateSourceTrigger=PropertyChanged}" Width="70"/>
                            <DataGridTextColumn Header="Application Name" Binding="{Binding Name}" Width="200" FontWeight="Bold"/>
                            <DataGridTextColumn Header="Delay (s)" Binding="{Binding DelaySeconds}" Width="80"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding Path}" Width="*"/>
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
                    <DataGrid Name="GridWhitelist" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Extended">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Protected Process" Binding="{Binding ProcessName}" Width="220" FontWeight="Bold"/>
                            <DataGridTextColumn Header="Category" Binding="{Binding Category}" Width="160"/>
                            <DataGridTextColumn Header="Protection Reason" Binding="{Binding Reason}" Width="*"/>
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

                    <DataGrid Name="GridRestoreSession" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Single">
                        <DataGrid.ContextMenu>
                            <ContextMenu>
                                <MenuItem Name="MenuCtxRestoreOne" Header="🔄 Restore This Application" Foreground="#38BDF8" FontWeight="SemiBold"/>
                                <MenuItem Name="MenuCtxRemoveOne" Header="🗑️ Remove from Restore List" Foreground="#F87171"/>
                                <Separator/>
                                <MenuItem Name="MenuCtxRestoreAll" Header="⚡ Restore All Applications" Foreground="#A78BFA" FontWeight="Bold"/>
                            </ContextMenu>
                        </DataGrid.ContextMenu>
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Application Name" Binding="{Binding Name}" Width="180" FontWeight="Bold"/>
                            <DataGridTextColumn Header="PID" Binding="{Binding Id}" Width="70"/>
                            <DataGridTextColumn Header="RAM Freed (MB)" Binding="{Binding RAM_MB}" Width="110"/>
                            <DataGridTextColumn Header="Executable Path" Binding="{Binding Path}" Width="*"/>
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

            <!-- TAB 8: DIAGNOSTICS & CRASH HISTORY -->
            <TabItem Header="📋 Diagnostics">
                <Grid Margin="12">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="200"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Top Action Bar -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
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
                    <Border Grid.Row="1" Background="#0F172A" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Margin="0,0,0,10">
                        <DataGrid Name="GridCrashEvents" AutoGenerateColumns="False" CanUserAddRows="False" SelectionMode="Single">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="#" Binding="{Binding Index}" Width="40" FontWeight="Bold"/>
                                <DataGridTextColumn Header="Faulting Application" Binding="{Binding AppName}" Width="180" FontWeight="Bold"/>
                                <DataGridTextColumn Header="Faulting Module" Binding="{Binding ModuleName}" Width="160"/>
                                <DataGridTextColumn Header="Exception Code" Binding="{Binding ExceptionCode}" Width="130"/>
                                <DataGridTextColumn Header="Timestamp" Binding="{Binding Timestamp}" Width="160"/>
                                <DataGridTextColumn Header="Brief Details" Binding="{Binding Summary}" Width="*"/>
                            </DataGrid.Columns>
                        </DataGrid>
                    </Border>

                    <!-- Report & Diagnostic Details Box (fixing the illegible dark text issue) -->
                    <Border Grid.Row="2" Background="#060911" BorderBrush="#1F2937" BorderThickness="1" CornerRadius="6" Padding="10">
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
                <TextBlock Name="TxtStatusBar" Grid.Column="0" Text="Game Booster v1.2.1 PRO ready. Zero telemetry enabled." Foreground="#94A3B8" FontSize="11" VerticalAlignment="Center"/>
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

# Tab 3
$txtBadgeHags              = $window.FindName("TxtBadgeHags")
$badgeHags                 = $window.FindName("BadgeHags")
$txtBadgeGameMode          = $window.FindName("TxtBadgeGameMode")
$badgeGameMode             = $window.FindName("BadgeGameMode")
$txtBadgeTcp               = $window.FindName("TxtBadgeTcp")
$badgeTcp                  = $window.FindName("BadgeTcp")
$btnApplyAllTweaks         = $window.FindName("BtnApplyAllTweaks")
$txtStandbySize            = $window.FindName("TxtStandbySize")
$btnPurgeStandbyCard       = $window.FindName("BtnPurgeStandbyCard")
$txtShaderSize             = $window.FindName("TxtShaderSize")
$btnCleanShaders           = $window.FindName("BtnCleanShaders")
$gridServerRadar           = $window.FindName("GridServerRadar")
$btnPingRadarNow           = $window.FindName("BtnPingRadarNow")
$chkAutoRadar              = $window.FindName("ChkAutoRadar")

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

# Tab 8
$btnRunHealthCheck         = $window.FindName("BtnRunHealthCheck")
$btnDiagnoseSelectedCrash  = $window.FindName("BtnDiagnoseSelectedCrash")
$btnRefreshCrashes         = $window.FindName("BtnRefreshCrashes")
$btnExportDebugReport      = $window.FindName("BtnExportDebugReport")
$gridCrashEvents           = $window.FindName("GridCrashEvents")
$txtDiagnosticReport       = $window.FindName("TxtDiagnosticReport")

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
  "explorer", "winlogon", "sppsvc", "SearchIndexer", "SecurityHealthService", "SecurityHealthSystray", 
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
if ($txtGpuBadge) {
    $txtGpuBadge.Text = "$($script:gpuInfo.Vendor) $($script:gpuInfo.Name)"
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
        [System.Windows.MessageBox]::Show("Auto-Watcher has been stopped.`n`nGames will no longer automatically trigger Game Mode.", "Auto-Watcher Stopped", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } else {
        Start-GameWatcherDaemon
        [System.Windows.MessageBox]::Show("Auto-Watcher is now ACTIVE in the background!`n`nWhenever any of your Monitored Games are launched, Game Booster will automatically:`n• Close selected background apps`n• Flush and reclaim standby RAM`n• Auto-launch your game companion apps (e.g. Discord)`n• Restore closed apps when the game exits", "Auto-Watcher Active", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Tray Companion daemon has been stopped.", "Tray Companion", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } else {
        $trayPs = Join-Path $ScriptDir "TrayBooster.ps1"
        if (Test-Path $trayPs) {
            Start-Process $PSHostExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$trayPs`""
            Start-Sleep -Milliseconds 400
            Update-DaemonIndicators
            $txtStatusBar.Text = "Tray Companion daemon active in system tray."
            [System.Windows.MessageBox]::Show("Tray Companion is now running in the Windows System Tray!`n`nPress Ctrl+F11 anytime for Hardware HUD, or right-click the tray icon for quick actions.", "Tray Companion Active", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
      "explorer", "winlogon", "sppsvc", "SearchIndexer", "SecurityHealthService", "SecurityHealthSystray", 
      "MsMpEng", "NisSrv", "MpDefenderCoreService", "DefenderSessionHelper", "MoUsoCoreWorker", "RuntimeBroker", 
      "StartMenuExperienceHost", "taskhostw", "ctfmon", "SystemSettings", "TextInputHost", "ShellHost", 
      "conhost", "cmd", "pwsh", "powershell", "wt", "WindowsTerminal", "GameBooster", "taskmgr",
      "dashost", "midisrv", "sihost", "smartscreen", "ApplicationFrameHost", "node", "git")
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
        if ($pName -match "discord|spotify|slack|steam|epicgames|battlenet|eaapp|gog") { $cat = "Launcher / Social" }
        if ($pName -match "chrome|msedge|firefox|brave|opera") { $cat = "Web Browser" }

        # Calculate combined working set RAM in MB
        $totalBytes = ($pList | Measure-Object -Property WorkingSet64 -Sum).Sum
        $ramMB = [math]::Round($totalBytes / 1MB, 0)
        if ($ramMB -lt 5 -and -not $hasWindow) { continue } # Skip tiny unwindowed workers

        $pids = @($pList | ForEach-Object { $_.Id })
        $displayPid = if ($procCount -gt 1) { "$($pids[0]) (+$($procCount - 1))" } else { "$($pids[0])" }
        $displayName = if ($procCount -gt 1) { "$pName ($procCount procs)" } else { $pName }

        # Default selected for launchers, browsers, and background tools (Never select anti-cheats, sound drivers, or overlays)
        $isProtected = $wl.Contains($pName) -or ($pName -match "(?i)RTSS|MSIAfterburner|HWiNFO|obs|PnkBstr|EasyAntiCheat|BEService|vgc|audiodg|RtkAud|^Rz|^Razer|^SteelSeries|^Logi|LGHUB|iCUE|^Elgato|^Nahimic|^Creative")
        $isSel = (-not $isProtected -and ($cat -in @("Launcher / Social", "Web Browser") -or $cat -eq "Interactive App"))

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
        $isProtected = $esSet.Contains($item.Name) -or ($item.Name -match "(?i)RTSS|MSIAfterburner|HWiNFO|obs|PnkBstr|EasyAntiCheat|BEService|vgc|audiodg|RtkAud|^Rz|^Razer|^SteelSeries|^Logi|LGHUB|iCUE|^Elgato|^Nahimic|^Creative")
        $item.IsSelected = (-not $isProtected)
    }
    $gridProcesses.Items.Refresh()
    Update-SelectedMetrics
})

$btnSelectBalanced.Add_Click({
    foreach ($item in $script:ProcessList) {
        $item.IsSelected = ($item.Category -in @("Launcher / Social", "Web Browser"))
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
    [System.Windows.MessageBox]::Show("'$pName' will remain running and is protected for this session.", "Session Whitelist", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
    [System.Windows.MessageBox]::Show("'$pName' has been added to your Permanent Whitelist and will never be targeted by Game Mode.", "Permanent Whitelist", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Context Menu: Close This Application Now
$menuCtxCloseNow.Add_Click({
    $sel = $gridProcesses.SelectedItem
    if (-not $sel) { return }
    $pName = $sel.Name

    $ask = [System.Windows.MessageBox]::Show("Close '$($sel.DisplayName)' immediately?", "Close Application", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $pidsToKill = if ($sel.Pids) { @($sel.Pids) } else { @($sel.Id) }
    $appFreedRAM = 0
    $svcName = $null
    foreach ($pidVal in $pidsToKill) {
        try {
            # Check if this PID is managed by a Windows Service
            $svc = Get-CimInstance Win32_Service -Filter "ProcessId = $pidVal" -ErrorAction SilentlyContinue
            if ($svc) {
                $svcName = $svc.Name
                & sc.exe stop $svcName | Out-Null
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
            [System.Windows.MessageBox]::Show("Path not found: $($sel.Path)", "Executable Path", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    } else {
        [System.Windows.MessageBox]::Show("Executable path could not be resolved for '$($sel.Name)'.", "Executable Path", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# ---------------------------------------------------------------------------
# ACTIVATE GAME MODE (CLOSE APPS + PURGE STANDBY RAM)
# ---------------------------------------------------------------------------
$btnActivateGameMode.Add_Click({
    $targets = @($script:ProcessList | Where-Object { $_.IsSelected })
    if ($targets.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one application to close.", "No Apps Selected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $msg = "Activate Game Mode now?`n`nThis will close $($targets.Count) application group(s), purge Windows Standby Memory, trim memory working sets, and activate the Gaming High-Performance Power Plan."
    $ask = [System.Windows.MessageBox]::Show($msg, "Activate Game Mode", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $txtStatusBar.Text = "Activating Game Mode..."
    $closedItems = @()
    $freedRAM = 0

    $criticalOsSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @("Idle", "System", "csrss", "services", "lsass", "wininit", "smss", "svchost", "fontdrvhost", "dwm", 
      "explorer", "winlogon", "sppsvc", "SearchIndexer", "SecurityHealthService", "SecurityHealthSystray", 
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

        $pidsToKill = if ($item.Pids) { @($item.Pids) } else { @($item.Id) }
        $appFreedRAM = 0
        $svcName = $null
        foreach ($pidVal in $pidsToKill) {
            try {
                if ($serviceMap.ContainsKey([int]$pidVal)) {
                    $svcName = $serviceMap[[int]$pidVal]
                    & sc.exe stop $svcName | Out-Null
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

    # Smart Standby List Purge
    $purgeRes = Invoke-SmartMemoryPurge
    $totalFreed = $freedRAM + [math]::Round($purgeRes.FreedGB * 1024, 0)

    # Set Gaming Power Plan
    Enable-UltimatePerformancePlan | Out-Null

    # Refresh UI
    Reload-ProcessGrid
    Reload-RestoreGrid
    Update-StandbyDisplay

    $resultMsg = "Game Mode Activated Successfully!`n`n" +
                 "• Apps Closed: $($closedItems.Count)`n" +
                 "• Process RAM Reclaimed: $freedRAM MB`n" +
                 "• Standby RAM Flushed: $($purgeRes.FreedMB) MB`n" +
                 "• Total Memory Freed: $totalFreed MB`n" +
                 "• Power Plan: Ultimate Performance`n" +
                 "• Dynamic GPU Drivers: Protected"
    
    $txtStatusBar.Text = "Game Mode Active. Reclaimed $totalFreed MB RAM."
    [System.Windows.MessageBox]::Show($resultMsg, "Game Mode Engaged", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Game Library Auto-Detector Scan Complete!`n`nFound $($found.Count) games across Steam, Epic, Battle.net, GOG, and Xbox Store.`n`nAll discovered titles have been added to your Monitored Games list and are ready for Per-Game hardware optimization profiles.", "Scan Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Game '$clean' added to monitored library successfully!", "Game Added", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
    [System.Windows.MessageBox]::Show("Quick add complete! Added $added process(es) to monitored games.", "Games Added", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

$btnQuickWow.Add_Click({ Add-QuickMonitoredGames @("Wow", "WowClassic", "Wow-64") })
$btnQuickCod.Add_Click({ Add-QuickMonitoredGames @("cod", "bootstrapper", "BlackOps6", "cod24", "sp24") })
$btnQuickCs2.Add_Click({ Add-QuickMonitoredGames @("cs2") })

# Remove Selected
$btnRemoveMonitored.Add_Click({
    $sel = $gridGameLibrary.SelectedItem
    if (-not $sel) {
        [System.Windows.MessageBox]::Show("Please select a game from the table to remove.", "Selection Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Game library list is already empty.", "Already Empty", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    $ask = [System.Windows.MessageBox]::Show("Are you sure you want to remove all $($script:GameList.Count) games from the monitored library?", "Clear All Monitored Games", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
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
        [System.Windows.MessageBox]::Show("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
    [System.Windows.MessageBox]::Show("Per-Game Profile for '$clean' saved successfully!`n`n• CPU Priority: $prio`n• Architecture Affinity: $aff`n• Custom Companion: $($profData.Companion)`n• Auto-OSD: $($profData.AutoOsd)", "Profile Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})

# Reload Game Profile
$btnReloadGameProfile.Add_Click({
    $sel = $gridGameLibrary.SelectedItem
    if (-not $sel) {
        [System.Windows.MessageBox]::Show("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Please select a game from the table first.", "Select Game", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }
    $clean = $sel.ProcessName -replace '\.exe$', ''
    $ask = [System.Windows.MessageBox]::Show("Reset hardware profile for '$clean' to default settings (High Priority, All Cores, No Companion)?", "Reset Profile", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
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
        [System.Windows.MessageBox]::Show("Profile for '$clean' has been reset to defaults.", "Reset Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

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
}

function Update-StandbyDisplay {
    $stats = Get-SystemRamStats
    $txtStandbySize.Text = "$($stats.StandbyMB) MB ($($stats.StandbyGB) GB)"
    $txtMemorySummary.Text = "Standby RAM: $($stats.StandbyMB) MB | Free: $($stats.FreeGB) GB"
}

function Update-ShaderDisplay {
    $sc = Get-ShaderCacheSize
    $txtShaderSize.Text = "$($sc.TotalMB) MB ($($sc.FileCount) files)"
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
        [System.Windows.MessageBox]::Show($msg, "Gaming Tweaks Applied", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        Write-AppLog "Error applying gaming tweaks: $_" "ERROR"
        [System.Windows.MessageBox]::Show("Error applying gaming tweaks:`n`n$($_.Exception.Message)", "Tweak Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    } finally {
        $btnApplyAllTweaks.IsEnabled = $true
        $btnApplyAllTweaks.Content = "⚡ 1-Click Apply All Gaming Tweaks"
    }
})

# Purge Standby RAM Buttons
function Run-PurgeAction {
    $res = Invoke-SmartMemoryPurge
    Update-StandbyDisplay
    $txtStatusBar.Text = "Memory purge complete: Freed $($res.FreedStandbyMB) MB Standby RAM."
    [System.Windows.MessageBox]::Show($res.Message, "Memory Purge Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

$btnInstantPurge.Add_Click({ Run-PurgeAction })
$btnPurgeStandbyCard.Add_Click({ Run-PurgeAction })

# Clean Shaders Button (Feature 10)
$btnCleanShaders.Add_Click({
    $ask = [System.Windows.MessageBox]::Show("Are you sure you want to clean DirectX, NVIDIA, AMD, and Intel shader caches?`n`nGames will recompile clean shader caches on next launch, resolving texture stutter and micro-freezes.", "Clean Shader Caches", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($ask -eq [System.Windows.MessageBoxResult]::Yes) {
        $res = Invoke-ShaderCacheClean
        Update-ShaderDisplay
        $txtStatusBar.Text = "Cleaned shader caches: Freed $($res.FreedMB) MB ($($res.DeletedFiles) files)."
        [System.Windows.MessageBox]::Show("Shader Cache Cleaned Successfully!`n`n• Freed Space: $($res.FreedMB) MB`n• Cache files purged: $($res.DeletedFiles)`n`nYour graphics pipeline will generate clean stutter-free shaders on next game launch.", "Shaders Cleaned", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

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

# ---------------------------------------------------------------------------
# TAB 4: HARDWARE HUD & IN-GAME OSD
# ---------------------------------------------------------------------------
function Launch-HardwareHudAction([switch]$Force) {
    $hudScript = Join-Path $ScriptDir "Launch_Gaming_HUD.ps1"
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
        [System.Windows.MessageBox]::Show("Launch_Gaming_HUD.ps1 not found in $ScriptDir", "File Missing", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

function Close-HardwareHudAction {
    $activeHudProcs = Get-Process -Name "*btop*", "*btm*" -ErrorAction SilentlyContinue
    if ($activeHudProcs) {
        $activeHudProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    try {
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*PingMonitor.ps1*" } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}
    $termProcs = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
    foreach ($tp in $termProcs) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($tp.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmdLine -like "*btop*" -or $cmdLine -like "*btm*" -or $cmdLine -like "*PingMonitor*" -or $cmdLine -like "*--pos*") {
                Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    $txtStatusBar.Text = "Hardware HUD closed."
}

$btnLaunchHud.Add_Click({ Launch-HardwareHudAction })
$btnLaunchHudTop.Add_Click({ Launch-HardwareHudAction })
$btnForceRestartHud.Add_Click({ Launch-HardwareHudAction -Force })
$btnCloseHud.Add_Click({ Close-HardwareHudAction })

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
        [System.Windows.MessageBox]::Show("HUD position and dimensions saved successfully!", "Position Captured", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Hardware HUD coordinates saved to config.json!", "Coordinates Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Invalid coordinates entered. Please enter valid integers.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    }
})

# Install HUD Dependencies (Safe non-blocking execution with single popup)
$btnInstallHudDeps.Add_Click({
    $msg = "Install / Verify Gaming HUD Dependencies (btop4win + bottom + Windows Terminal)?`n`n" +
           "Game Booster will download btop4win directly and verify required terminal components.`n`n" +
           "Would you like to proceed?"
    $ask = [System.Windows.MessageBox]::Show($msg, "Install HUD Dependencies", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
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

        [System.Windows.MessageBox]::Show("Hardware HUD Dependency installation complete!`n`nbtop4win and system telemetry packages are ready to use.", "Installation Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
    [System.Windows.MessageBox]::Show("In-Game OSD settings saved successfully!`n`n• Brand / Streamer Title: $newTitle`n• Screen Position: $pos", "OSD Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        if (Test-Path $osdScript) {
            $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$osdScript`"")
            if ($Unlock) { $args += "-Unlock" }
            Start-Process $PSHostExe -ArgumentList $args -WindowStyle Hidden
            $txtStatusBar.Text = "In-Game OSD Overlay Launched (F10 to toggle)."
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
        [System.Windows.MessageBox]::Show("Executable path not found: $($sel.Path)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
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
    [System.Windows.MessageBox]::Show("Companion apps saved successfully!", "Companions Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
            [System.Windows.MessageBox]::Show("Cannot remove driver or system-protected processes.", "Protected Process", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
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

    if ($item.ServiceName) {
        try {
            & sc.exe start $item.ServiceName | Out-Null
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
        [System.Windows.MessageBox]::Show("Please select an application to restore.", "Selection Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$btnRestoreAllApps.Add_Click({
    if ($script:RestoreList.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Restore list is currently empty.", "Empty List", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $count = $script:RestoreList.Count
    foreach ($item in @($script:RestoreList)) {
        Restore-ApplicationItem $item
    }

    try { Remove-Item $SessionFile -Force -ErrorAction SilentlyContinue } catch {}
    $script:RestoreList.Clear()
    $txtStatusBar.Text = "Restored all $count application(s)."
    [System.Windows.MessageBox]::Show("Restored all $count application(s) successfully!", "Session Restored", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
        [System.Windows.MessageBox]::Show("Full Debug Report has been generated on your Desktop and opened in Notepad:`n`n$reportPath", "Debug Report Exported", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# ---------------------------------------------------------------------------
# GLOBAL BUTTONS & INITIALIZATION
# ---------------------------------------------------------------------------
$btnRefreshAll.Add_Click({
    Reload-ProcessGrid
    Reload-GameLibraryGrid
    Update-TweaksDisplay
    Update-StandbyDisplay
    Update-ShaderDisplay
    Reload-CompanionsGrid
    Reload-WhitelistGrid
    Reload-RestoreGrid
    Reload-CrashGrid
    Update-DaemonIndicators
    Update-HudCoordinateFields
    Update-OsdSettingsFields
    $txtStatusBar.Text = "All systems refreshed."
})

$btnSaveAllConfig.Add_Click({
    $cfg = Get-AppConfig
    Save-AppConfig $cfg | Out-Null
    $txtStatusBar.Text = "Defaults saved to config.json."
    [System.Windows.MessageBox]::Show("Booster configuration saved successfully!", "Saved", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
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
    $res = [System.Windows.MessageBox]::Show($window, $msg, "1-Click Auto Update", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
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
        [System.Windows.MessageBox]::Show($window, "Auto-update encountered an error: $_`nOpening GitHub Releases page instead.", "Update Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
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
                [System.Windows.MessageBox]::Show($window, "You are using the latest version of Game Booster (v$script:AppVersion).", "Game Booster Update", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            }
        }
    } else {
        if (-not $isSilent) {
            [System.Windows.MessageBox]::Show($window, "Unable to check for updates right now.`nPlease check your internet connection and try again.", "Update Check", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
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

# Populate all views on startup
Reload-ProcessGrid
Reload-GameLibraryGrid
Update-TweaksDisplay
Update-StandbyDisplay
Update-ShaderDisplay
Initialize-ServerRadarGrid
Reload-CompanionsGrid
Reload-WhitelistGrid
Reload-RestoreGrid
Reload-CrashGrid
Update-DaemonIndicators
Update-HudCoordinateFields
Update-OsdSettingsFields

# Auto-refresh when tabs change
if ($mainTabs) {
    $mainTabs.Add_SelectionChanged({
        param($sender, $e)
        if ($e.Source -eq $mainTabs) {
            switch ($mainTabs.SelectedIndex) {
                0 { Reload-ProcessGrid; Update-StandbyDisplay }
                1 { Reload-GameLibraryGrid }
                2 { Update-TweaksDisplay; if ($script:RadarList.Count -eq 0) { Initialize-ServerRadarGrid } }
                5 { Reload-WhitelistGrid }
                6 { Reload-RestoreGrid }
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

# Background silent update check
Start-AppUpdateCheck -silent $true

# Window Closing Handler (Force close active HUD terminal & monitors on exit)
$window.Add_Closing({
    Write-AppLog "Game Booster window closing. Cleaning up Hardware HUD and background timers..."
    Close-HardwareHudAction
    if ($script:radarTimer) { $script:radarTimer.Stop() }
    if ($script:daemonTimer) { $script:daemonTimer.Stop() }
    if ($script:updatePollTimer) { $script:updatePollTimer.Stop() }
})

# Show Window
$window.ShowDialog() | Out-Null

# Post-close cleanup safeguard
Close-HardwareHudAction



