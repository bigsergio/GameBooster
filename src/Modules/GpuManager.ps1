# ============================================================================
# Game Booster v1.0 - Module: Dynamic GPU Vendor Detection & Management
# Identifies NVIDIA / AMD / Intel hardware and protects driver companion suites
# ============================================================================

function Get-GpuHardwareInfo {
    $gpuControllers = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -notmatch "Basic|Virtual|RDP|Remote|VNC" })

    $primaryGpu = if ($gpuControllers.Count -gt 0) { $gpuControllers[0] } else { $null }
    $gpuName = if ($primaryGpu) { $primaryGpu.Name } else { "Generic Display Adapter" }
    $driverVer = if ($primaryGpu) { $primaryGpu.DriverVersion } else { "Unknown" }
    $vramMB = if ($primaryGpu -and $primaryGpu.AdapterRAM) { [math]::Round($primaryGpu.AdapterRAM / 1MB) } else { 0 }

    # Detect Vendor
    $vendor = "Unknown"
    $protectedDriverProcesses = @()

    if ($gpuName -match "NVIDIA|GeForce|RTX|GTX|Quadro") {
        $vendor = "NVIDIA"
        $protectedDriverProcesses = @(
            "nvcontainer",
            "nvcplui",
            "NVIDIA Share",
            "NVIDIA Web Helper",
            "nvsphelper64",
            "NvDisplay.Container",
            "nvtelemetrycontainer"
        )
    } elseif ($gpuName -match "AMD|Radeon|RX|Vega") {
        $vendor = "AMD"
        $protectedDriverProcesses = @(
            "RadeonSoftware",
            "AMDRSServ",
            "AMDRSSrcExt",
            "amdow",
            "cncmd",
            "cpumetricsserver",
            "atieclxx",
            "atiesrxx"
        )
    } elseif ($gpuName -match "Intel|Arc|Iris|Xe") {
        $vendor = "Intel"
        $protectedDriverProcesses = @(
            "ArcControl",
            "IntelArcSysTray",
            "ArcNotificationServer",
            "igfxEM",
            "igfxCUIService"
        )
    }

    return [PSCustomObject]@{
        Name                     = $gpuName
        Vendor                   = $vendor
        DriverVersion            = $driverVer
        VramMB                   = $vramMB
        ProtectedDriverProcesses = $protectedDriverProcesses
    }
}

function Get-DynamicGpuWhitelist {
    $info = Get-GpuHardwareInfo
    return @($info.ProtectedDriverProcesses)
}

