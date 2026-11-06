# ============================================================================
# Game Booster PRO v2.0 - Module: Dynamic Display Resolution & Refresh Rate
# Win32 resolution and refresh rate switching per-game with clean reset on exit
# ============================================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
public struct DISPLAY_DEVICE_NATIVE {
    public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string DeviceName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
    public string DeviceString;
    public int StateFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
    public string DeviceID;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
    public string DeviceKey;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
public struct DEVMODE_NATIVE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string dmDeviceName;
    public short dmSpecVersion;
    public short dmDriverVersion;
    public short dmSize;
    public short dmDriverExtra;
    public int dmFields;
    public int dmPositionX;
    public int dmPositionY;
    public int dmDisplayOrientation;
    public int dmDisplayFixedOutput;
    public short dmColor;
    public short dmDuplex;
    public short dmYResolution;
    public short dmTTOption;
    public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string dmFormName;
    public short dmLogPixels;
    public short dmBitsPerPel;
    public int dmPelsWidth;
    public int dmPelsHeight;
    public int dmDisplayFlags;
    public int dmDisplayFrequency;
    public int dmICMMethod;
    public int dmICMIntent;
    public int dmMediaType;
    public int dmDitherType;
    public int dmReserved1;
    public int dmReserved2;
    public int dmPanningWidth;
    public int dmPanningHeight;

    public static DEVMODE_NATIVE Create() {
        DEVMODE_NATIVE dm = new DEVMODE_NATIVE();
        dm.dmDeviceName = new string(new char[32]);
        dm.dmFormName = new string(new char[32]);
        dm.dmSize = (short)Marshal.SizeOf(dm);
        return dm;
    }
}

public class DisplayMonitorInfo {
    public string DeviceName;
    public string DeviceString;
    public bool IsPrimary;
    public int Width;
    public int Height;
    public int RefreshRate;
    public int BitsPerPel;
    public int MaxHz;
    public List<string> SupportedModes = new List<string>();
}

public class DisplayManagerNative {
    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int EnumDisplaySettings(string lpszDeviceName, int iModeNum, ref DEVMODE_NATIVE lpDevMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE_NATIVE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE_NATIVE lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int ChangeDisplaySettingsEx(string lpszDeviceName, IntPtr lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

    public const int ENUM_CURRENT_SETTINGS = -1;
    public const uint CDS_UPDATEREGISTRY = 0x00000001;
    public const uint CDS_TEST = 0x00000002;
    public const uint CDS_FULLSCREEN = 0x00000004;
    public const uint CDS_RESET = 0x40000000;

    public const int DISP_CHANGE_SUCCESSFUL = 0;
    public const int DISP_CHANGE_RESTART = 1;
    public const int DISP_CHANGE_FAILED = -1;
    public const int DISP_CHANGE_BADMODE = -2;

    public const int DM_PELSWIDTH = 0x00080000;
    public const int DM_PELSHEIGHT = 0x00100000;
    public const int DM_DISPLAYFREQUENCY = 0x00400000;

    public static List<DisplayMonitorInfo> EnumerateMonitors() {
        var list = new List<DisplayMonitorInfo>();
        DISPLAY_DEVICE_NATIVE dd = new DISPLAY_DEVICE_NATIVE();
        dd.cb = Marshal.SizeOf(dd);

        for (uint i = 0; EnumDisplayDevices(null, i, ref dd, 0); i++) {
            if ((dd.StateFlags & 1) != 0) { // Attached to desktop
                var info = new DisplayMonitorInfo();
                info.DeviceName = dd.DeviceName;
                info.DeviceString = dd.DeviceString;
                info.IsPrimary = (dd.StateFlags & 4) != 0;

                DEVMODE_NATIVE dm = DEVMODE_NATIVE.Create();
                if (EnumDisplaySettings(dd.DeviceName, ENUM_CURRENT_SETTINGS, ref dm) != 0) {
                    info.Width = dm.dmPelsWidth;
                    info.Height = dm.dmPelsHeight;
                    info.RefreshRate = dm.dmDisplayFrequency;
                    info.BitsPerPel = dm.dmBitsPerPel;
                }

                int maxHz = info.RefreshRate;
                int mIdx = 0;
                var modeSet = new HashSet<string>();
                while (EnumDisplaySettings(dd.DeviceName, mIdx, ref dm) != 0) {
                    modeSet.Add(dm.dmPelsWidth + "x" + dm.dmPelsHeight + " @ " + dm.dmDisplayFrequency + "Hz");
                    if (dm.dmDisplayFrequency > maxHz) {
                        maxHz = dm.dmDisplayFrequency;
                    }
                    mIdx++;
                }
                info.MaxHz = maxHz;
                info.SupportedModes.AddRange(modeSet);
                list.Add(info);
            }
        }
        return list;
    }

    public static int ApplyDisplayMode(string deviceName, int width, int height, int hz) {
        DEVMODE_NATIVE dm = DEVMODE_NATIVE.Create();
        if (EnumDisplaySettings(deviceName, ENUM_CURRENT_SETTINGS, ref dm) == 0) return -99;
        
        dm.dmPelsWidth = width;
        dm.dmPelsHeight = height;
        if (hz > 0) dm.dmDisplayFrequency = hz;
        
        dm.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;
        if (hz > 0) dm.dmFields |= DM_DISPLAYFREQUENCY;

        // Try CDS_FULLSCREEN first
        int res = ChangeDisplaySettingsEx(deviceName, ref dm, IntPtr.Zero, CDS_FULLSCREEN, IntPtr.Zero);
        if (res != DISP_CHANGE_SUCCESSFUL) {
            // Fallback to CDS_UPDATEREGISTRY
            res = ChangeDisplaySettingsEx(deviceName, ref dm, IntPtr.Zero, CDS_UPDATEREGISTRY, IntPtr.Zero);
        }
        return res;
    }

    public static int ResetAllDisplays() {
        return ChangeDisplaySettingsEx(null, IntPtr.Zero, IntPtr.Zero, 0, IntPtr.Zero);
    }
}
"@ -ErrorAction SilentlyContinue

function Get-DisplayMonitors {
    $rawList = [DisplayManagerNative]::EnumerateMonitors()
    $monitors = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($m in $rawList) {
        $monitors.Add([PSCustomObject]@{
            DeviceName        = $m.DeviceName
            DeviceString      = $m.DeviceString
            IsPrimary         = $m.IsPrimary
            CurrentResolution = "$($m.Width)x$($m.Height)"
            CurrentWidth      = $m.Width
            CurrentHeight     = $m.Height
            CurrentHz         = $m.RefreshRate
            MaxHz             = $m.MaxHz
            BitsPerPixel      = $m.BitsPerPel
            SupportedModes    = @($m.SupportedModes)
        })
    }
    return $monitors
}

function Set-DisplayResolution {
    param(
        [Parameter(Mandatory=$true)][int]$Width,
        [Parameter(Mandatory=$true)][int]$Height,
        [int]$RefreshRate = 0,
        [string]$DeviceName = ""
    )

    $targetDevice = $DeviceName
    if (-not $targetDevice) {
        $all = Get-DisplayMonitors
        $prim = $all | Where-Object { $_.IsPrimary } | Select-Object -First 1
        if ($prim) { $targetDevice = $prim.DeviceName }
    }

    $res = [DisplayManagerNative]::ApplyDisplayMode($targetDevice, $Width, $Height, $RefreshRate)
    $success = ($res -eq [DisplayManagerNative]::DISP_CHANGE_SUCCESSFUL)

    return [PSCustomObject]@{
        Success          = $success
        DeviceName       = $targetDevice
        AppliedWidth     = $Width
        AppliedHeight    = $Height
        AppliedHz        = $RefreshRate
        ResultCode       = $res
        Message          = if ($success) { "Display mode successfully updated to ${Width}x${Height}." } else { "Display driver returned code $res." }
    }
}

function Reset-DisplayResolution {
    try {
        $res = [DisplayManagerNative]::ResetAllDisplays()
        return [PSCustomObject]@{
            Success    = ($res -eq [DisplayManagerNative]::DISP_CHANGE_SUCCESSFUL)
            ResultCode = $res
            Message    = "Display modes reset to Windows desktop configuration."
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}
