# ============================================================================
# Game Booster v1.0 - Module: 1-Click Windows Gaming Tweaks
# Timer Resolution, HAGS, Game Mode, TCP NoDelay, & Power Scheme Optimization
# ============================================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class HighPrecisionTimer {
    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern int NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);

    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern int NtQueryTimerResolution(out uint MaximumResolution, out uint MinimumResolution, out uint CurrentResolution);

    public static uint Set05msResolution() {
        uint cur = 0;
        // 5000 in 100ns units = 0.5ms
        NtSetTimerResolution(5000, true, out cur);
        return cur;
    }

    public static uint GetCurrentResolution() {
        uint max, min, cur;
        NtQueryTimerResolution(out max, out min, out cur);
        return cur;
    }
}
"@ -ErrorAction SilentlyContinue

function Get-GamingTweaksStatus {
    # 1. Timer Resolution
    $curRes = [HighPrecisionTimer]::GetCurrentResolution()
    $curMs = [math]::Round($curRes / 10000, 2)
    $timerOptimized = ($curMs -le 1.0)

    # 2. HAGS (Hardware-Accelerated GPU Scheduling)
    $hagsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $hagsVal = 0
    if (Test-Path $hagsKey) {
        $hagsVal = (Get-ItemProperty -Path $hagsKey -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
    }
    $hagsEnabled = ($hagsVal -eq 2)

    # 3. Game Mode
    $gmKey = "HKCU:\Software\Microsoft\GameBar"
    $gmVal = 1
    if (Test-Path $gmKey) {
        $prop = Get-ItemProperty -Path $gmKey -Name "AllowAutoGameMode" -ErrorAction SilentlyContinue
        if ($prop) { $gmVal = $prop.AllowAutoGameMode }
    }
    $gameModeEnabled = ($gmVal -eq 1)

    # 4. Power Plan
    $activePlan = (powercfg /getactivescheme)
    $isHighPerf = ($activePlan -like "*Ultimate*" -or $activePlan -like "*High*")

    # 5. Network TCP NoDelay (Nagle's Algorithm)
    $tcpOptimized = $false
    $adaptersKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (Test-Path $adaptersKey) {
        $subKeys = Get-ChildItem -Path $adaptersKey -ErrorAction SilentlyContinue
        foreach ($k in $subKeys) {
            $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
            if ($p.TcpAckFrequency -eq 1 -and $p.TCPNoDelay -eq 1) {
                $tcpOptimized = $true
                break
            }
        }
    }

    return [PSCustomObject]@{
        TimerResolutionMs = $curMs
        TimerOptimized    = $timerOptimized
        HagsEnabled       = $hagsEnabled
        GameModeEnabled   = $gameModeEnabled
        HighPerfPowerPlan = $isHighPerf
        ActivePowerPlan   = $activePlan
        TcpNoDelayEnabled = $tcpOptimized
    }
}

function Set-TimerResolution05ms {
    $cur = [HighPrecisionTimer]::Set05msResolution()
    $ms = [math]::Round($cur / 10000, 2)
    return "Timer resolution tuned to ${ms}ms (Maximum hardware precision)."
}

function Set-HagsEnabled([bool]$enable) {
    $val = if ($enable) { 2 } else { 1 }
    $key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Set-ItemProperty -Path $key -Name "HwSchMode" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
    $state = if ($enable) { "ENABLED" } else { "DISABLED" }
    return "Hardware-Accelerated GPU Scheduling set to $state (Requires PC restart to take effect)."
}

function Set-GameModeEnabled([bool]$enable) {
    $val = if ($enable) { 1 } else { 0 }
    $key = "HKCU:\Software\Microsoft\GameBar"
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name "AllowAutoGameMode" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "AutoGameModeEnabled" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
    $state = if ($enable) { "ENABLED" } else { "DISABLED" }
    return "Windows Game Mode set to $state."
}

function Set-TcpNoDelay([bool]$enable) {
    $adaptersKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    if (-not (Test-Path $adaptersKey)) { return "Failed to access TCP interfaces." }
    $subKeys = Get-ChildItem -Path $adaptersKey -ErrorAction SilentlyContinue

    $appliedCount = 0
    foreach ($k in $subKeys) {
        $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
        # Target active connected interfaces with DhcpIPAddress or IPAddress
        if ($p.DhcpIPAddress -or $p.IPAddress) {
            try {
                if ($enable) {
                    Set-ItemProperty -Path $k.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $k.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $k.PSPath -Name "TcpDelAckTicks" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    $appliedCount++
                } else {
                    Remove-ItemProperty -Path $k.PSPath -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $k.PSPath -Name "TCPNoDelay" -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $k.PSPath -Name "TcpDelAckTicks" -Force -ErrorAction SilentlyContinue
                    $appliedCount++
                }
            } catch {}
        }
    }
    $state = if ($enable) { "ENABLED on $appliedCount interface(s)" } else { "RESTORED (Default Windows Batching)" }
    return "TCP NoDelay set to $state."
}

function Enable-UltimatePerformancePlan {
    try {
        # Duplicate Ultimate Performance scheme if missing
        $dup = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
        # Extract GUID
        $guidMatch = [regex]::Match($dup, "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})")
        if ($guidMatch.Success) {
            powercfg /setactive $guidMatch.Value
            return "Applied Ultimate Performance Power Scheme ($($guidMatch.Value))."
        }
    } catch {}
    # Fallback to High Performance
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    return "Applied High Performance Power Scheme."
}

