# ============================================================================
# Game Booster v1.0 - Module: Standby Memory & Working Set Purge
# Native Windows RAM optimization: Flushes cached Standby RAM & Trims Working Sets
# ============================================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class MemoryCleaner {
    [DllImport("psapi.dll")]
    public static extern int EmptyWorkingSet(IntPtr hwProc);

    [DllImport("ntdll.dll")]
    public static extern int RtlAdjustPrivilege(int Privilege, bool Enable, bool CurrentThread, out bool Enabled);

    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int SystemInformationClass, IntPtr SystemInformation, int SystemInformationLength);

    public static bool PurgeStandbyList() {
        try {
            bool en;
            // Enable SeProfileSingleProcessPrivilege (19), SeIncreaseQuotaPrivilege (5), SeLockMemoryPrivilege (4)
            RtlAdjustPrivilege(19, true, false, out en);
            RtlAdjustPrivilege(5, true, false, out en);
            RtlAdjustPrivilege(4, true, false, out en);

            // Command 4 = MemoryPurgeStandbyList
            IntPtr p4 = Marshal.AllocHGlobal(sizeof(int));
            Marshal.WriteInt32(p4, 4);
            uint r4 = NtSetSystemInformation(80, p4, sizeof(int));
            Marshal.FreeHGlobal(p4);

            // Command 3 = MemoryFlushModifiedList
            IntPtr p3 = Marshal.AllocHGlobal(sizeof(int));
            Marshal.WriteInt32(p3, 3);
            uint r3 = NtSetSystemInformation(80, p3, sizeof(int));
            Marshal.FreeHGlobal(p3);

            return (r4 == 0 || r3 == 0);
        } catch {
            return false;
        }
    }
}
"@ -ErrorAction SilentlyContinue

function Get-SystemRamStats {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $totalKB = if ($os) { [double]$os.TotalVisibleMemorySize } else { 0 }
    $freeKB  = if ($os) { [double]$os.FreePhysicalMemory } else { 0 }
    $usedKB  = $totalKB - $freeKB

    # Query true Windows Standby Cache size via performance counters
    $standbyMB = 0
    try {
        $samples = (Get-Counter "\Memory\Standby Cache Normal Priority Bytes", "\Memory\Standby Cache Reserve Bytes", "\Memory\Standby Cache Core Bytes" -ErrorAction SilentlyContinue).CounterSamples
        if ($samples) {
            $totalBytes = ($samples | Measure-Object CookedValue -Sum).Sum
            $standbyMB = [math]::Round($totalBytes / 1MB, 0)
        }
    } catch {}

    # Fallback estimation if counter unavailable
    if ($standbyMB -le 0 -and $totalKB -gt 0) {
        $standbyMB = [math]::Max(0, [math]::Round(($freeKB * 0.4) / 1024, 0))
    }

    return [PSCustomObject]@{
        TotalGB   = [math]::Round($totalKB / 1MB, 2)
        FreeGB    = [math]::Round($freeKB / 1MB, 2)
        UsedGB    = [math]::Round($usedKB / 1MB, 2)
        StandbyMB = $standbyMB
        StandbyGB = [math]::Round($standbyMB / 1024, 2)
    }
}

function Invoke-SmartMemoryPurge {
    param([string[]]$ExemptProcesses = @("GameBooster", "explorer", "dwm"))
    $before = Get-SystemRamStats
    $trimmedCount = 0

    # 1. Purge Standby List (requires SeProfileSingleProcessPrivilege / Admin)
    $standbyPurged = [MemoryCleaner]::PurgeStandbyList()

    # 2. Trim Working Sets of background user processes
    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $ExemptProcesses -notcontains $_.ProcessName }
    foreach ($p in $procs) {
        try {
            if ($p.Handle) {
                [MemoryCleaner]::EmptyWorkingSet($p.Handle) | Out-Null
                $trimmedCount++
            }
        } catch {}
    }

    # 3. Purge standby list once more to flush any pages moved during working set trim
    [MemoryCleaner]::PurgeStandbyList() | Out-Null

    # Allow memory subsystem to update
    Start-Sleep -Milliseconds 300
    $after = Get-SystemRamStats
    $freedStandbyMB = [math]::Max(0, ($before.StandbyMB - $after.StandbyMB))
    $freedGB = [math]::Max(0, [math]::Round($after.FreeGB - $before.FreeGB, 2))

    $freedDisplay = if ($freedStandbyMB -gt 1024) {
        "$([math]::Round($freedStandbyMB / 1024, 2)) GB"
    } else {
        "$freedStandbyMB MB"
    }

    return [PSCustomObject]@{
        TrimmedProcesses = $trimmedCount
        StandbyPurged    = $standbyPurged
        FreedStandbyMB   = $freedStandbyMB
        FreedGB          = $freedGB
        TotalRamGB       = $after.TotalGB
        CurrentFreeGB    = $after.FreeGB
        CurrentStandbyMB = $after.StandbyMB
        CurrentStandbyGB = $after.StandbyGB
        Message          = "Smart Memory Purge Complete: Trimmed $trimmedCount processes and flushed Standby Cache. Freed ~$freedDisplay."
    }
}

