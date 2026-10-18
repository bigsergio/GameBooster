# ============================================================================
# Game Booster v1.0 - Live Transparent In-Game OSD (On-Screen Display)
# 100% Anti-Cheat Safe (Zero DLL injection), Click-Through, Hardware Telemetry
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Toggle,
    [switch]$Lock,
    [switch]$Unlock
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
$ConfigFile = Join-Path $RootDir "config.json"

# Win32 Helpers for Click-Through & Always On Top
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class OsdWin32 {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_LAYERED = 0x00080000;
    public const int WS_EX_TOOLWINDOW = 0x00000080;

    public static void EnableClickThrough(IntPtr hWnd) {
        int initial = GetWindowLong(hWnd, GWL_EXSTYLE);
        SetWindowLong(hWnd, GWL_EXSTYLE, initial | WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW);
        SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }
}
"@ -ErrorAction SilentlyContinue

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Game Booster v1.0 In-Game OSD" Height="42" SizeToContent="Width" MinWidth="380"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" WindowStartupLocation="Manual">
    <Border Name="OsdBorder" Background="#D90B0F19" BorderBrush="#0284C7" BorderThickness="1.5" CornerRadius="8" Padding="12,6">
        <Border.Effect>
            <DropShadowEffect BlurRadius="12" Color="#000000" Opacity="0.8" ShadowDepth="2"/>
        </Border.Effect>
        <Grid VerticalAlignment="Center">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <!-- Customizable Brand / Streamer Badge -->
            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,12,0">
                <Border Background="#0284C7" CornerRadius="4" Padding="6,2" Margin="0,0,6,0">
                    <TextBlock Name="TxtBrand" Text="GAME BOOSTER" Foreground="#FFFFFF" FontSize="10" FontWeight="Bold"/>
                </Border>
            </StackPanel>

            <!-- Metrics Bar -->
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                <!-- CPU -->
                <TextBlock Text="CPU:" Foreground="#94A3B8" FontSize="11" FontWeight="SemiBold" Margin="0,0,3,0"/>
                <TextBlock Name="TxtCpu" Text="--%" Foreground="#38BDF8" FontSize="11" FontWeight="Bold" Margin="0,0,10,0"/>

                <!-- RAM -->
                <TextBlock Text="RAM:" Foreground="#94A3B8" FontSize="11" FontWeight="SemiBold" Margin="0,0,3,0"/>
                <TextBlock Name="TxtRam" Text="-- GB" Foreground="#10B981" FontSize="11" FontWeight="Bold" Margin="0,0,10,0"/>

                <!-- PING -->
                <TextBlock Text="PING:" Foreground="#94A3B8" FontSize="11" FontWeight="SemiBold" Margin="0,0,3,0"/>
                <TextBlock Name="TxtPing" Text="-- ms" Foreground="#F59E0B" FontSize="11" FontWeight="Bold"/>
            </StackPanel>

            <!-- Mode Tag -->
            <TextBlock Name="TxtModeTag" Grid.Column="2" Text="[BOOSTED]" Foreground="#10B981" FontSize="10" FontWeight="Bold" VerticalAlignment="Center" Margin="10,0,0,0"/>
        </Grid>
    </Border>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml.OuterXml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Controls
$txtBrand   = $window.FindName("TxtBrand")
$txtCpu     = $window.FindName("TxtCpu")
$txtRam     = $window.FindName("TxtRam")
$txtPing    = $window.FindName("TxtPing")
$txtModeTag = $window.FindName("TxtModeTag")
$osdBorder  = $window.FindName("OsdBorder")

# Load Configuration
$cfg = if (Test-Path $ConfigFile) {
    try { Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
} else { $null }

# Set Custom Title / Streamer Tag
if ($cfg.overlaySettings -and $cfg.overlaySettings.titleText) {
    $txtBrand.Text = $cfg.overlaySettings.titleText
} else {
    $txtBrand.Text = "GAME BOOSTER"
}

# Position Screen Calculation
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$posSetting = if ($cfg.overlaySettings -and $cfg.overlaySettings.position) { $cfg.overlaySettings.position } else { "TopRight" }

switch ($posSetting) {
    "TopLeft" {
        $window.Left = $screen.Left + 25
        $window.Top = $screen.Top + 25
    }
    "BottomLeft" {
        $window.Left = $screen.Left + 25
        $window.Top = $screen.Bottom - 65
    }
    "BottomRight" {
        $window.Left = $screen.Right - 450
        $window.Top = $screen.Bottom - 65
    }
    "TopCenter" {
        $window.Left = ($screen.Left + $screen.Right) / 2 - 200
        $window.Top = $screen.Top + 25
    }
    default {
        # TopRight
        $window.Left = $screen.Right - 450
        $window.Top = $screen.Top + 25
    }
}

# Performance Counter & Ping Helpers
$ping = New-Object System.Net.NetworkInformation.Ping
$targetDns = "1.1.1.1"

# Timer to update stats every 1 second
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    # Update RAM
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $usedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
            $txtRam.Text = "$usedGB GB"
        }
    } catch {}

    # Update Ping
    try {
        $reply = $ping.Send($targetDns, 300)
        if ($reply.Status -eq "Success") {
            $ms = $reply.RoundtripTime
            $txtPing.Text = "${ms}ms"
            $txtPing.Foreground = if ($ms -le 25) { "#10B981" } elseif ($ms -le 60) { "#F59E0B" } else { "#EF4444" }
        } else {
            $txtPing.Text = "ERR"
            $txtPing.Foreground = "#EF4444"
        }
    } catch {
        $txtPing.Text = "--"
    }

    # Update CPU (fast lightweight estimation)
    try {
        $cpuLoad = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average).Average
        if ($null -ne $cpuLoad) {
            $txtCpu.Text = "$([int]$cpuLoad)%"
            $txtCpu.Foreground = if ($cpuLoad -gt 80) { "#EF4444" } else { "#38BDF8" }
        }
    } catch {}
})

if ($Unlock) {
    # Unlock mode: allows dragging overlay to reposition
    $osdBorder.BorderBrush = [System.Windows.Media.Brushes]::OrangeRed
    $txtModeTag.Text = "[DRAG TO MOVE]"
    $txtModeTag.Foreground = [System.Windows.Media.Brushes]::OrangeRed
    $window.Add_MouseLeftButtonDown({
        $window.DragMove()
    })
    $window.Add_MouseRightButtonDown({
        # Save position on right click
        $cfg = if (Test-Path $ConfigFile) { Get-Content $ConfigFile -Raw | ConvertFrom-Json } else { $null }
        if ($cfg) {
            if (-not $cfg.overlaySettings) { $cfg | Add-Member -MemberType NoteProperty -Name "overlaySettings" -Value ([PSCustomObject]@{}) }
            $cfg.overlaySettings.customX = [int]$window.Left
            $cfg.overlaySettings.customY = [int]$window.Top
            $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Force
        }
        $window.Close()
    })
} else {
    $window.Add_Loaded({
        # Make click-through so game receives all mouse events
        $hwnd = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
        [OsdWin32]::EnableClickThrough($hwnd)
        $timer.Start()
    })
}

$window.ShowDialog() | Out-Null
