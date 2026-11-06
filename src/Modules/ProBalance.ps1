# ============================================================================
# Game Booster PRO v2.0 - Module: ProBalance & Dynamic EcoQoS Throttler
# Monitors background CPU usage; forces rogue background apps into Windows 11
# Efficiency Mode (EcoQoS) + Idle Priority to prevent 1% low frame drops
# Safe for all games: NEVER throttles active games or essential OS services
# ============================================================================

Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct PROCESS_POWER_THROTTLING_STATE {
    public uint Version;
    public uint ControlMask;
    public uint StateMask;
}

public class ProBalanceNative {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessInformation(
        IntPtr hProcess,
        int ProcessInformationClass,
        ref PROCESS_POWER_THROTTLING_STATE ProcessInformation,
        uint ProcessInformationSize
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetPriorityClass(IntPtr hProcess, uint dwPriorityClass);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint GetPriorityClass(IntPtr hProcess);

    public const int ProcessPowerThrottling = 4;
    public const uint PROCESS_POWER_THROTTLING_CURRENT_VERSION = 1;
    public const uint PROCESS_POWER_THROTTLING_EXECUTION_SPEED = 0x1;

    public const uint IDLE_PRIORITY_CLASS = 0x00000040;
    public const uint BELOW_NORMAL_PRIORITY_CLASS = 0x00004000;
    public const uint NORMAL_PRIORITY_CLASS = 0x00000020;
    public const uint ABOVE_NORMAL_PRIORITY_CLASS = 0x00008000;
    public const uint HIGH_PRIORITY_CLASS = 0x00000080;

    public static bool SetEcoQoS(IntPtr handle, bool enable) {
        try {
            PROCESS_POWER_THROTTLING_STATE state = new PROCESS_POWER_THROTTLING_STATE();
            state.Version = PROCESS_POWER_THROTTLING_CURRENT_VERSION;
            state.ControlMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED;
            state.StateMask = enable ? PROCESS_POWER_THROTTLING_EXECUTION_SPEED : 0;

            uint size = (uint)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE));
            return SetProcessInformation(handle, ProcessPowerThrottling, ref state, size);
        } catch {
            return false;
        }
    }

    public static bool ThrottleProcess(IntPtr handle) {
        try {
            SetEcoQoS(handle, true);
            return SetPriorityClass(handle, IDLE_PRIORITY_CLASS);
        } catch {
            return false;
        }
    }

    public static bool RestoreProcess(IntPtr handle) {
        try {
            SetEcoQoS(handle, false);
            return SetPriorityClass(handle, NORMAL_PRIORITY_CLASS);
        } catch {
            return false;
        }
    }
}
"@ -ErrorAction SilentlyContinue

$global:ThrottledProcessesRegistry = [System.Collections.Generic.Dictionary[int, psobject]]::new()

function Get-ProBalanceStatus {
    return [PSCustomObject]@{
        ThrottledCount   = $global:ThrottledProcessesRegistry.Count
        ThrottledDetails = @($global:ThrottledProcessesRegistry.Values)
    }
}

function Invoke-ProBalanceSweep {
    param(
        [string]$ActiveGameProcessName = "",
        [double]$CpuThresholdPercent = 15.0,
        [string[]]$ExemptProcessNames = @()
    )

    $exemptSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    
    # 1. Critical OS & Anti-Cheat Safeguards (NEVER throttle)
    @("Idle", "System", "csrss", "services", "lsass", "wininit", "smss", "svchost", "fontdrvhost", "dwm", 
      "explorer", "winlogon", "sppsvc", "SecurityHealthService", "SecurityHealthSystray", "audiodg", 
      "MsMpEng", "NisSrv", "conhost", "cmd", "pwsh", "powershell", "GameBooster", "taskmgr",
      "PnkBstrA", "PnkBstrB", "EasyAntiCheat", "BEService", "vgc", "RTSS", "MSIAfterburner") | ForEach-Object { [void]$exemptSet.Add($_) }

    if ($ActiveGameProcessName) {
        [void]$exemptSet.Add(($ActiveGameProcessName -replace '\.exe$', ''))
    }
    foreach ($ex in $ExemptProcessNames) { [void]$exemptSet.Add($ex) }

    # Query active background user processes consuming CPU
    $throttledThisRun = [System.Collections.Generic.List[PSCustomObject]]::new()
    
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { 
            -not $exemptSet.Contains($_.ProcessName) -and $_.Id -ne $PID -and $_.CPU -gt 0
        }

        # Take 1-second sample for processes with high total CPU
        $snap1 = @{}
        foreach ($p in $procs) { $snap1[$p.Id] = $p.CPU }

        Start-Sleep -Milliseconds 600

        $totalCores = [Environment]::ProcessorCount
        foreach ($p in (Get-Process -ErrorAction SilentlyContinue | Where-Object { $snap1.ContainsKey($_.Id) })) {
            try {
                $cpuDelta = ($p.CPU - $snap1[$p.Id]) / 0.6 / $totalCores * 100
                if ($cpuDelta -ge $CpuThresholdPercent) {
                    if (-not $global:ThrottledProcessesRegistry.ContainsKey($p.Id)) {
                        # Throttle rogue process into Windows 11 EcoQoS + Idle Priority
                        if ($p.Handle) {
                            $origPri = [ProBalanceNative]::GetPriorityClass($p.Handle)
                            $applied = [ProBalanceNative]::ThrottleProcess($p.Handle)
                            if ($applied) {
                                $record = [PSCustomObject]@{
                                    PID              = $p.Id
                                    ProcessName      = $p.ProcessName
                                    CpuUsagePercent  = [math]::Round($cpuDelta, 1)
                                    OriginalPriority = $origPri
                                    ThrottledAt      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                                }
                                $global:ThrottledProcessesRegistry[$p.Id] = $record
                                $throttledThisRun.Add($record)

                                # Register in Watchdog
                                if (Get-Command Register-WatchdogProperty -ErrorAction SilentlyContinue) {
                                    Register-WatchdogProperty -PropertyName "ThrottledPids" -Value @($global:ThrottledProcessesRegistry.Keys)
                                }
                            }
                        }
                    }
                }
            } catch {}
        }
    } catch {}

    return [PSCustomObject]@{
        NewlyThrottledCount = $throttledThisRun.Count
        TotalThrottledCount = $global:ThrottledProcessesRegistry.Count
        NewlyThrottled      = @($throttledThisRun)
    }
}

function Restore-AllThrottledProcesses {
    $restoredCount = 0
    foreach ($pidKey in @($global:ThrottledProcessesRegistry.Keys)) {
        try {
            $p = Get-Process -Id $pidKey -ErrorAction SilentlyContinue
            if ($p -and $p.Handle) {
                [ProBalanceNative]::RestoreProcess($p.Handle) | Out-Null
                $restoredCount++
            }
        } catch {}
    }

    $global:ThrottledProcessesRegistry.Clear()
    
    if (Get-Command Register-WatchdogProperty -ErrorAction SilentlyContinue) {
        Register-WatchdogProperty -PropertyName "ThrottledPids" -Value @()
    }

    return [PSCustomObject]@{
        Success       = $true
        RestoredCount = $restoredCount
        Message       = "Restored $restoredCount throttled process(es) to normal priority."
    }
}
