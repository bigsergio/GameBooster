# ============================================================================
# Game Booster PRO v2.0 - Module: 1-Click Windows Gaming Tweaks
# Timer Resolution, HAGS, MPO, Game Mode, TCP NoDelay, & Dynamic Power Scheme
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

public class NativePower {
    [DllImport("powrprof.dll")]
    public static extern uint PowerGetActiveScheme(IntPtr UserRootPowerKey, out IntPtr pSchemeGuid);

    [DllImport("powrprof.dll")]
    public static extern uint PowerSetActiveScheme(IntPtr UserRootPowerKey, ref Guid SchemeGuid);

    [DllImport("kernel32.dll")]
    public static extern IntPtr LocalFree(IntPtr hMem);

    public static string GetActiveGuid() {
        IntPtr pGuid;
        if (PowerGetActiveScheme(IntPtr.Zero, out pGuid) == 0 && pGuid != IntPtr.Zero) {
            Guid g = (Guid)Marshal.PtrToStructure(pGuid, typeof(Guid));
            LocalFree(pGuid);
            return g.ToString();
        }
        return string.Empty;
    }

    public static bool SetActiveGuid(string guidStr) {
        Guid g;
        if (Guid.TryParse(guidStr, out g)) {
            return PowerSetActiveScheme(IntPtr.Zero, ref g) == 0;
        }
        return false;
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

    # 3. MPO (Multiplane Overlay)
    $mpoStatus = Get-MpoStatus

    # 4. Game Mode
    $gmKey = "HKCU:\Software\Microsoft\GameBar"
    $gmVal = 1
    if (Test-Path $gmKey) {
        $prop = Get-ItemProperty -Path $gmKey -Name "AllowAutoGameMode" -ErrorAction SilentlyContinue
        if ($prop) { $gmVal = $prop.AllowAutoGameMode }
    }
    $gameModeEnabled = ($gmVal -eq 1)

    # 5. Power Plan (Native Win32 powrprof.dll & Registry - zero child processes)
    $activeGuid = Get-ActivePowerPlanGuid
    $isHighPerf = $false
    try {
        $schemeProp = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$activeGuid" -ErrorAction SilentlyContinue
        if ($schemeProp.FriendlyName -like "*Ultimate*" -or $schemeProp.FriendlyName -like "*High*") {
            $isHighPerf = $true
        }
    } catch {}

    # 6. Network TCP NoDelay (Nagle's Algorithm)
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

    # 7. PowerShell Runtime Engine Status
    $isPs7Running = ($PSVersionTable.PSVersion.Major -ge 7)
    $pwshCmd = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if (-not $pwshCmd) {
        $cands = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe"
        )
        foreach ($c in $cands) { if (Test-Path $c) { $pwshCmd = $c; break } }
    }
    $ps7Installed = ($null -ne $pwshCmd)
    $currentPsVer = $PSVersionTable.PSVersion.ToString()

    return [PSCustomObject]@{
        TimerResolutionMs = $curMs
        TimerOptimized    = $timerOptimized
        HagsEnabled       = $hagsEnabled
        MpoDisabled       = $mpoStatus.MpoDisabled
        MpoStatusText     = $mpoStatus.StatusText
        GameModeEnabled   = $gameModeEnabled
        HighPerfPowerPlan = $isHighPerf
        ActivePowerPlan   = $activePlan
        ActivePowerGuid   = $activeGuid
        TcpNoDelayEnabled = $tcpOptimized
        IsPs7Running      = $isPs7Running
        IsPs7Installed    = $ps7Installed
        CurrentPsVersion  = $currentPsVer
        PwshPath          = $pwshCmd
    }
}

function Set-TimerResolution05ms {
    $cur = [HighPrecisionTimer]::Set05msResolution()
    $ms = [math]::Round($cur / 10000, 2)
    return "Timer resolution tuned to ${ms}ms (Maximum hardware precision)."
}

function Set-TimerResolutionMaximum {
    param([bool]$enable = $true)
    return Set-TimerResolution05ms
}

function Set-HagsEnabled([bool]$enable) {
    $val = if ($enable) { 2 } else { 1 }
    $key = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Set-ItemProperty -Path $key -Name "HwSchMode" -Value $val -Type DWord -Force -ErrorAction SilentlyContinue
    $state = if ($enable) { "ENABLED" } else { "DISABLED" }
    return "Hardware-Accelerated GPU Scheduling set to $state (Requires PC restart to take effect)."
}

function Get-MpoStatus {
    $dwmKey = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    $val = $null
    if (Test-Path $dwmKey) {
        $val = (Get-ItemProperty -Path $dwmKey -Name "OverlayTestMode" -ErrorAction SilentlyContinue).OverlayTestMode
    }
    # OverlayTestMode = 5 means MPO is disabled (smooth borderless window fix)
    $isMpoDisabled = ($val -eq 5)
    return [PSCustomObject]@{
        MpoDisabled = $isMpoDisabled
        RawValue    = $val
        StatusText  = if ($isMpoDisabled) { "DISABLED (OverlayTestMode=5 - Fixes borderless window stutters)" } else { "ENABLED (Windows Default)" }
    }
}

function Set-MpoDisabled([bool]$disable) {
    $dwmKey = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
    if (-not (Test-Path $dwmKey)) { New-Item -Path $dwmKey -Force | Out-Null }
    if ($disable) {
        Set-ItemProperty -Path $dwmKey -Name "OverlayTestMode" -Value 5 -Type DWord -Force -ErrorAction SilentlyContinue
        return "Multiplane Overlay (MPO) DISABLED (OverlayTestMode=5). Eliminates borderless stutter and black flickering."
    } else {
        Remove-ItemProperty -Path $dwmKey -Name "OverlayTestMode" -Force -ErrorAction SilentlyContinue
        return "Multiplane Overlay (MPO) RESTORED to Windows default."
    }
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
        if ($k.PSChildName -match "^\{[a-f0-9\-]{36}\}$") {
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

function Get-ActivePowerPlanGuid {
    $guid = [NativePower]::GetActiveGuid()
    if ($guid) { return $guid }
    try {
        $reg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes" -ErrorAction SilentlyContinue
        if ($reg.ActivePowerScheme) { return $reg.ActivePowerScheme }
    } catch {}
    return "381b4222-f694-41f0-9685-ff5bb260df2e"
}

function Set-PowerPlanByGuid {
    param([Parameter(Mandatory=$true)][string]$Guid)
    if ($Guid -match "^[a-f0-9\-]{36}$") {
        return [NativePower]::SetActiveGuid($Guid)
    }
    return $false
}

function Switch-ToUltimatePerformance {
    $originalGuid = Get-ActivePowerPlanGuid

    # Locate Ultimate Performance Scheme in Registry (zero external process execution)
    $targetGuid = ""
    try {
        $schemes = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\*" -ErrorAction SilentlyContinue
        foreach ($s in $schemes) {
            if ($s.FriendlyName -like "*Ultimate*") {
                $targetGuid = $s.PSChildName
                break
            }
        }
        if (-not $targetGuid) {
            foreach ($s in $schemes) {
                if ($s.FriendlyName -like "*High Performance*" -or $s.PSChildName -eq "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c") {
                    $targetGuid = $s.PSChildName
                    break
                }
            }
        }
    } catch {}

    if (-not $targetGuid) {
        $targetGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" # High Performance standard GUID
    }

    $applied = [NativePower]::SetActiveGuid($targetGuid)
    return [PSCustomObject]@{
        Success      = $applied
        OriginalGuid = $originalGuid
        AppliedGuid  = $targetGuid
        PlanName     = "Ultimate Performance"
        Message      = "Activated Performance Power Scheme ($targetGuid)."
    }
}

function Restore-OriginalPowerPlan {
    param([Parameter(Mandatory=$true)][string]$Guid)
    if ($Guid -match "^[a-f0-9\-]{36}$") {
        [NativePower]::SetActiveGuid($Guid) | Out-Null
        return "Restored original power scheme ($Guid)."
    }
    # Fallback to Balanced
    [NativePower]::SetActiveGuid("381b4222-f694-41f0-9685-ff5bb260df2e") | Out-Null
    return "Restored default Balanced power scheme."
}

function Enable-UltimatePerformancePlan {
    $res = Switch-ToUltimatePerformance
    return $res.Message
}
