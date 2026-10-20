# ============================================================================
# Launch Hardware Gaming HUD (btop + btm + Ping Telemetry)
# Docked on Secondary Desktop with Layout Presets & Single-Instance Guard
# ============================================================================

[CmdletBinding()]
param(
    [string]$Preset,        # "tri_pane" (default), "esports_ping", "minimal_dual"
    [switch]$ForceRestart,  # Force clean restart instead of refocusing active HUD
    [switch]$DebugMode
)

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
Set-Location -Path $RootDir

# Determine PowerShell Host Executable
$PSHostExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }

$ConfigFile = Join-Path $RootDir "config.json"
$LogFile = Join-Path $RootDir "gamebooster.log"

function Write-HUDLog($msg, $level = "INFO") {
    $line = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [HUD-$level] $msg"
    try { Add-Content -Path $LogFile -Value $line -Force -ErrorAction SilentlyContinue } catch {}
    if ($DebugMode) {
        $color = if ($level -eq "ERROR") { "Red" } elseif ($level -eq "WARN") { "Yellow" } else { "Cyan" }
        Write-Host " [HUD] $msg" -ForegroundColor $color
    }
}

Write-HUDLog "Initiating Gaming HUD launch sequence (Preset: $Preset, ForceRestart: $ForceRestart)..."

# Load target coordinates & layout preferences from config.json
$hudX = 3450
$hudY = 693
$hudWidth = 1524
$hudHeight = 635
$hudCols = 139
$hudRows = 34
$activePreset = "tri_pane"

if (Test-Path $ConfigFile) {
    try {
        $cfg = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
        if ($cfg.hudSettings) {
            if ($null -ne $cfg.hudSettings.hudX) { $hudX = [int]$cfg.hudSettings.hudX }
            if ($null -ne $cfg.hudSettings.hudY) { $hudY = [int]$cfg.hudSettings.hudY }
            if ($null -ne $cfg.hudSettings.hudWidth) { $hudWidth = [int]$cfg.hudSettings.hudWidth }
            if ($null -ne $cfg.hudSettings.hudHeight) { $hudHeight = [int]$cfg.hudSettings.hudHeight }
            if ($null -ne $cfg.hudSettings.hudCols) { $hudCols = [int]$cfg.hudSettings.hudCols }
            if ($null -ne $cfg.hudSettings.hudRows) { $hudRows = [int]$cfg.hudSettings.hudRows }
            if ($cfg.hudSettings.layoutPreset) { $activePreset = $cfg.hudSettings.layoutPreset }
        }
    } catch {
        Write-HUDLog "Error loading config: $_" "WARN"
    }
}

if ($Preset) {
    $activePreset = $Preset
}

# Compile Win32 Window Snapper & Refocus Helper
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowSnapper {
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr hDesktop);
    [DllImport("user32.dll")] public static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc lpfn, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpfn, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    public static IntPtr FindWindowForPid(uint targetPid) {
        IntPtr found = IntPtr.Zero;
        IntPtr hDesk = OpenDesktop("Default", 0, false, 0x01FF);
        if (hDesk != IntPtr.Zero) {
            EnumDesktopWindows(hDesk, delegate(IntPtr hWnd, IntPtr lParam) {
                uint pid = 0;
                GetWindowThreadProcessId(hWnd, out pid);
                if (pid == targetPid && IsWindowVisible(hWnd)) {
                    RECT r;
                    GetWindowRect(hWnd, out r);
                    if ((r.Right - r.Left) > 200 && (r.Bottom - r.Top) > 200) {
                        found = hWnd;
                        return false;
                    }
                }
                return true;
            }, IntPtr.Zero);
            CloseDesktop(hDesk);
        }
        if (found == IntPtr.Zero) {
            EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
                uint pid = 0;
                GetWindowThreadProcessId(hWnd, out pid);
                if (pid == targetPid && IsWindowVisible(hWnd)) {
                    RECT r;
                    GetWindowRect(hWnd, out r);
                    if ((r.Right - r.Left) > 200 && (r.Bottom - r.Top) > 200) {
                        found = hWnd;
                        return false;
                    }
                }
                return true;
            }, IntPtr.Zero);
        }
        return found;
    }
}
"@ -ErrorAction SilentlyContinue

# Helper to find visible HWND of a process
function Get-VisibleWindowHwnd([int]$pidTarget) {
    return [WindowSnapper]::FindWindowForPid([uint32]$pidTarget)
}

# ============================================================================
# SINGLE-INSTANCE GUARD & FORCE RESTART
# ============================================================================
$activeHudProcs = Get-Process -Name "*btop*", "*btm*" -ErrorAction SilentlyContinue
$termProcs = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue

if ($ForceRestart) {
    Write-HUDLog "ForceRestart requested. Terminating all active HUD processes and associated terminals..."
    if ($activeHudProcs) {
        $activeHudProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    # Clean up PingMonitor instances
    try {
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*PingMonitor.ps1*" } | ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}
    # Clean up WindowsTerminal instances associated with HUD
    foreach ($tp in $termProcs) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($tp.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmdLine -like "*btop*" -or $cmdLine -like "*btm*" -or $cmdLine -like "*PingMonitor*" -or $cmdLine -like "*$hudX,$hudY*" -or $cmdLine -like "*--help*") {
                Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    Start-Sleep -Milliseconds 400
} else {
    if ($activeHudProcs -and $termProcs) {
        # Check if a terminal window currently hosts the HUD
        foreach ($tp in ($termProcs | Sort-Object StartTime -Descending)) {
            $h = Get-VisibleWindowHwnd $tp.Id
            if ($h -ne [IntPtr]::Zero) {
                Write-HUDLog "HUD is already active (HWND: $h). Refocusing and snapping instead of launching duplicate."
                [WindowSnapper]::ShowWindow($h, 9) | Out-Null # 9 = SW_RESTORE
                [WindowSnapper]::SetForegroundWindow($h) | Out-Null
                [WindowSnapper]::SetWindowPos($h, [IntPtr]::Zero, $hudX, $hudY, $hudWidth, $hudHeight, 0x0044) | Out-Null
                return
            }
        }
    }
    if ($activeHudProcs) {
        Write-HUDLog "Cleaning up orphan btop/btm processes..."
        $activeHudProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
    }
}

# Locate wt.exe, btop, and btm
$wtPath = (Get-Command wt.exe -ErrorAction SilentlyContinue).Source
if (-not $wtPath) { $wtPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe" }
Write-HUDLog "Using Windows Terminal: $wtPath"

$btopCmd = (Get-Command btop4win.exe -ErrorAction SilentlyContinue).Source
if (-not $btopCmd) { $btopCmd = (Get-Command btop.exe -ErrorAction SilentlyContinue).Source }
if (-not $btopCmd) {
    $cands = @(
        "$env:LOCALAPPDATA\btop4win\btop4win.exe",
        "$env:LOCALAPPDATA\btop4win\btop.exe",
        "$env:LOCALAPPDATA\btop4win\btop4win\btop4win.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\btop.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\aristocratos.btop4win_Microsoft.Winget.Source_8wekyb3d8bbwe\btop4win\btop4win.exe",
        "$env:ProgramFiles\btop4win\btop4win.exe",
        "$env:ProgramFiles\btop4win\btop.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { $btopCmd = $c; break } }
}

if (-not $btopCmd -or -not (Test-Path $btopCmd)) {
    Write-HUDLog "btop4win telemetry executable not found in any candidate path." "ERROR"
    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    [System.Windows.MessageBox]::Show("btop4win executable was not found!`n`nPlease open Game Booster and click 'Install Dependencies' in the Hardware HUD tab to install it automatically.", "Missing Dependency", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    exit 1
}

$btopDir = $ScriptDir
if (Test-Path $btopCmd) {
    try {
        $linkItem = Get-Item $btopCmd -ErrorAction SilentlyContinue
        if ($linkItem.Target) {
            $targetPath = @($linkItem.Target)[0]
            if (Test-Path $targetPath) {
                $btopCmd = $targetPath
                $btopDir = Split-Path -Parent $targetPath
            }
        } else {
            $btopDir = Split-Path -Parent $btopCmd
        }
    } catch {}
}

$btmCmd = (Get-Command btm.exe -ErrorAction SilentlyContinue).Source
if (-not $btmCmd) {
    $cands = @(
        "$env:ProgramFiles\bottom\bin\btm.exe",
        "$env:USERPROFILE\.cargo\bin\btm.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\btm.exe",
        "$env:LOCALAPPDATA\bottom\btm.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { $btmCmd = $c; break } }
}
if (-not $btmCmd) { $btmCmd = "btm" }

# ============================================================================
# CONSTRUCT PRESET ARGUMENTS
# ============================================================================
Write-HUDLog "Configuring HUD layout for preset: $activePreset (btop: $btopCmd, btm: $btmCmd)"

$pingScript = Join-Path $ScriptDir "PingMonitor.ps1"

$wtArgs = @(
    "-w", "new",
    "--pos", "$hudX,$hudY",
    "--size", "$hudCols,$hudRows"
)

switch ($activePreset) {
    "esports_ping" {
        # Preset 2: Left 45% btop, Right 55% Large Ping & Jitter Telemetry
        $wtArgs += @(
            "-d", $btopDir,
            $btopCmd,
            ";",
            "split-pane", "-V", "-s", "0.55", "-d", $ScriptDir, "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $pingScript
        )
    }
    "minimal_dual" {
        # Preset 3: Clean dual-pane btop (left) + btm (right)
        $wtArgs += @(
            "-d", $btopDir,
            $btopCmd,
            ";",
            "split-pane", "-V", "-s", "0.5", "-d", $ScriptDir, $btmCmd
        )
    }
    default {
        # Preset 1 (tri_pane): Left btop, Top-Right btm, Bottom-Right PingMonitor
        $wtArgs += @(
            "-d", $btopDir,
            $btopCmd,
            ";",
            "split-pane", "-V", "-s", "0.5", "-d", $ScriptDir, $btmCmd, "--default_widget_type", "net",
            ";",
            "split-pane", "-H", "-s", "0.35", "-d", $ScriptDir, "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $pingScript
        )
    }
}

Write-HUDLog "Executing wt.exe with args: $($wtArgs -join ' ')"

try {
    Start-Process -FilePath $wtPath -ArgumentList $wtArgs
    Write-HUDLog "Windows Terminal spawned successfully."
} catch {
    Write-HUDLog "Failed to spawn via path, trying alias wt.exe: $_" "WARN"
    Start-Process "wt.exe" -ArgumentList $wtArgs
}

# Snap window to exact coordinates
$attempts = 0
$snapped = $false
while ($attempts -lt 20 -and -not $snapped) {
    Start-Sleep -Milliseconds 250
    $termProcs = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending
    foreach ($termProc in $termProcs) {
        $targetHwnd = Get-VisibleWindowHwnd $termProc.Id
        if ($targetHwnd -and $targetHwnd -ne [IntPtr]::Zero) {
            Write-HUDLog "Found terminal window HWND: $targetHwnd. Applying SetWindowPos($hudX, $hudY, $hudWidth, $hudHeight)..."
            [WindowSnapper]::ShowWindow($targetHwnd, 9) | Out-Null
            [WindowSnapper]::SetWindowPos($targetHwnd, [IntPtr]::Zero, $hudX, $hudY, $hudWidth, $hudHeight, 0x0040) | Out-Null
            $snapped = $true
            Write-HUDLog "Window position successfully snapped."
            break
        }
    }
    $attempts++
}

if (-not $snapped) {
    Write-HUDLog "Window spawned with native --pos and --size parameters."
}

