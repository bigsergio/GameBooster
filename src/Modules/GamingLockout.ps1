# ============================================================================
# Game Booster PRO v2.0 - Module: Gaming Input & Dialog Lockout
# Blocks accidental Windows Key presses & Sticky Keys popups during gameplay
# Safe for all kernel anti-cheats (operates at OS message queue level)
# ============================================================================

Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct STICKYKEYS_NATIVE {
    public uint cbSize;
    public uint dwFlags;
}

public class GamingLockoutNative {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;
    private const int VK_LWIN = 0x5B;
    private const int VK_RWIN = 0x5C;

    public const uint SPI_GETSTICKYKEYS = 0x003A;
    public const uint SPI_SETSTICKYKEYS = 0x003B;
    public const uint SKF_HOTKEYACTIVE  = 0x00000004;
    public const uint SKF_CONFIRMHOTKEY = 0x00000008;

    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookId = IntPtr.Zero;
    public static bool IsWinKeyLocked = false;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref STICKYKEYS_NATIVE pvParam, uint fWinIni);

    public static bool StartWinKeyLock() {
        if (_hookId != IntPtr.Zero) return true;
        try {
            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule curModule = curProcess.MainModule) {
                _hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
                IsWinKeyLocked = (_hookId != IntPtr.Zero);
                return IsWinKeyLocked;
            }
        } catch {
            return false;
        }
    }

    public static void StopWinKeyLock() {
        if (_hookId != IntPtr.Zero) {
            UnhookWindowsHookEx(_hookId);
            _hookId = IntPtr.Zero;
            IsWinKeyLocked = false;
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && IsWinKeyLocked) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == VK_LWIN || vkCode == VK_RWIN) {
                return (IntPtr)1; // Intercept & swallow Windows key
            }
        }
        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    public static uint GetStickyKeysFlags() {
        STICKYKEYS_NATIVE sk = new STICKYKEYS_NATIVE();
        sk.cbSize = (uint)Marshal.SizeOf(typeof(STICKYKEYS_NATIVE));
        if (SystemParametersInfo(SPI_GETSTICKYKEYS, sk.cbSize, ref sk, 0)) {
            return sk.dwFlags;
        }
        return 0;
    }

    public static bool SetStickyKeysFlags(uint flags) {
        STICKYKEYS_NATIVE sk = new STICKYKEYS_NATIVE();
        sk.cbSize = (uint)Marshal.SizeOf(typeof(STICKYKEYS_NATIVE));
        sk.dwFlags = flags;
        return SystemParametersInfo(SPI_SETSTICKYKEYS, sk.cbSize, ref sk, 0);
    }
}
"@ -ErrorAction SilentlyContinue

$global:OriginalStickyKeysFlags = 0

function Get-GamingLockoutStatus {
    $curFlags = [GamingLockoutNative]::GetStickyKeysFlags()
    $isStickyHotkeyActive = ($curFlags -band [GamingLockoutNative]::SKF_HOTKEYACTIVE) -ne 0
    $isWinKeyLocked = [GamingLockoutNative]::IsWinKeyLocked

    return [PSCustomObject]@{
        WinKeyLockActive       = $isWinKeyLocked
        StickyKeysHotkeyActive = $isStickyHotkeyActive
        StickyKeysLockedOut    = (-not $isStickyHotkeyActive)
        RawStickyFlags         = "0x{0:X}" -f $curFlags
    }
}

function Enable-GamingLockout {
    param(
        [bool]$DisableWinKey = $true,
        [bool]$DisableStickyKeys = $true
    )

    $results = [System.Collections.Generic.List[string]]::new()

    # 1. Windows Key Lockout
    if ($DisableWinKey) {
        $winLocked = [GamingLockoutNative]::StartWinKeyLock()
        if ($winLocked) {
            $results.Add("Windows Key locked out (Start menu will not interrupt game).")
        } else {
            $results.Add("Failed to install Windows Key keyboard hook.")
        }
    }

    # 2. Sticky Keys 5x Shift Lockout
    if ($DisableStickyKeys) {
        $curFlags = [GamingLockoutNative]::GetStickyKeysFlags()
        if ($curFlags -gt 0) {
            $global:OriginalStickyKeysFlags = $curFlags
            # Clear SKF_HOTKEYACTIVE (0x04) and SKF_CONFIRMHOTKEY (0x08)
            $newFlags = $curFlags -band (-bnot [GamingLockoutNative]::SKF_HOTKEYACTIVE)
            $newFlags = $newFlags -band (-bnot [GamingLockoutNative]::SKF_CONFIRMHOTKEY)
            $ok = [GamingLockoutNative]::SetStickyKeysFlags($newFlags)
            if ($ok) {
                $results.Add("Sticky Keys 5x Shift prompt suppressed.")
            }
        }
    }

    return [PSCustomObject]@{
        Success           = $true
        OriginalFlags     = $global:OriginalStickyKeysFlags
        ActionsPerformed  = @($results)
    }
}

function Disable-GamingLockout {
    $results = [System.Collections.Generic.List[string]]::new()

    # 1. Release Windows Key
    [GamingLockoutNative]::StopWinKeyLock()
    $results.Add("Windows Key hook uninstalled (Normal Start Menu restored).")

    # 2. Restore Sticky Keys
    if ($global:OriginalStickyKeysFlags -gt 0) {
        Restore-StickyKeysFlags -Flags $global:OriginalStickyKeysFlags | Out-Null
        $results.Add("Sticky Keys hotkey settings restored to baseline.")
    }

    return [PSCustomObject]@{
        Success          = $true
        ActionsPerformed = @($results)
    }
}

function Restore-StickyKeysFlags {
    param([uint32]$Flags)
    if ($Flags -gt 0) {
        return [GamingLockoutNative]::SetStickyKeysFlags($Flags)
    }
    return $false
}
