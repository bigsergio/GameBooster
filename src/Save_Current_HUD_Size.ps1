# ============================================================================
# Save Current Hardware Gaming HUD Size & Position
# Captures your manual adjustments and saves them to config.json
# ============================================================================

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
Set-Location -Path $RootDir

$ConfigFile = Join-Path $RootDir "config.json"
$LogFile = Join-Path $RootDir "gamebooster.log"

function Write-Log($msg) {
    $line = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [CONFIG] $msg"
    try { Add-Content -Path $LogFile -Value $line -Force -ErrorAction SilentlyContinue } catch {}
    Write-Host $msg
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowSaver {
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr hDesktop);
    [DllImport("user32.dll")] public static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc lpfn, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpfn, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@ -ErrorAction SilentlyContinue

$termProcs = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue
if (-not $termProcs) {
    Write-Warning "No active Windows Terminal (Gaming HUD) found running!"
    Write-Host "Please launch the Hardware HUD first, drag/resize it to your liking, then run this tool."
    exit 1
}

$targetPid = ($termProcs | Sort-Object StartTime -Descending | Select-Object -First 1).Id
$script:foundRect = $null

# Search Default desktop
$hDesk = [WindowSaver]::OpenDesktop("Default", 0, $false, 0x01FF)
if ($hDesk -ne [IntPtr]::Zero) {
    [WindowSaver]::EnumDesktopWindows($hDesk, {
        param($hWnd, $lParam)
        $procOut = 0
        [WindowSaver]::GetWindowThreadProcessId($hWnd, [ref]$procOut) | Out-Null
        if ($procOut -eq $targetPid -and [WindowSaver]::IsWindowVisible($hWnd)) {
            $r = New-Object WindowSaver+RECT
            [WindowSaver]::GetWindowRect($hWnd, [ref]$r) | Out-Null
            if (($r.Right - $r.Left) -gt 200 -and ($r.Bottom - $r.Top) -gt 200) {
                $script:foundRect = $r
                return $false
            }
        }
        return $true
    }, [IntPtr]::Zero) | Out-Null
    [WindowSaver]::CloseDesktop($hDesk) | Out-Null
}

if (-not $script:foundRect) {
    [WindowSaver]::EnumWindows({
        param($hWnd, $lParam)
        $procOut = 0
        [WindowSaver]::GetWindowThreadProcessId($hWnd, [ref]$procOut) | Out-Null
        if ($procOut -eq $targetPid -and [WindowSaver]::IsWindowVisible($hWnd)) {
            $r = New-Object WindowSaver+RECT
            [WindowSaver]::GetWindowRect($hWnd, [ref]$r) | Out-Null
            if (($r.Right - $r.Left) -gt 200 -and ($r.Bottom - $r.Top) -gt 200) {
                $script:foundRect = $r
                return $false
            }
        }
        return $true
    }, [IntPtr]::Zero) | Out-Null
}

if ($script:foundRect) {
    $x = $script:foundRect.Left
    $y = $script:foundRect.Top
    $w = $script:foundRect.Right - $script:foundRect.Left
    $h = $script:foundRect.Bottom - $script:foundRect.Top

    # Calculate column and row count for Windows Terminal native launch
    $cols = [math]::Max(50, [math]::Round($w / 11.0))
    $rows = [math]::Max(15, [math]::Round($h / 18.5))

    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host " Captured Current Gaming HUD Window Geometry:" -ForegroundColor Green
    Write-Host "   Position: X = $x, Y = $y"
    Write-Host "   Size:     Width = $w px, Height = $h px"
    Write-Host "   Terminal: ~$cols columns x $rows rows"
    Write-Host "===================================================" -ForegroundColor Cyan

    if (Test-Path $ConfigFile) {
        $cfg = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
        if (-not $cfg.hudSettings) {
            $cfg | Add-Member -MemberType NoteProperty -Name "hudSettings" -Value ([PSCustomObject]@{})
        }
        $cfg.hudSettings.hudX = $x
        $cfg.hudSettings.hudY = $y
        $cfg.hudSettings.hudWidth = $w
        $cfg.hudSettings.hudHeight = $h
        $cfg.hudSettings.hudCols = $cols
        $cfg.hudSettings.hudRows = $rows

        $cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Force
        Write-Log "Saved HUD geometry: X=$x, Y=$y, W=$w, H=$h, Cols=$cols, Rows=$rows"
        Write-Host ""
        Write-Host "[V] Successfully saved to config.json!" -ForegroundColor Green
        Write-Host "Every future launch will automatically dock to this exact size and location."
    }
} else {
    Write-Warning "Could not detect the Gaming HUD window geometry."
}

