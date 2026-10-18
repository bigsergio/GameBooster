# ============================================================================
# Game Booster v1.0 - Module: Dynamic Hardware & Essential Services Protection
# Identifies GPU vendors, Audio drivers, Anti-Cheat daemons, and Hardware Monitors
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

function Get-ProtectedGamingServicesDetails {
    $services = [System.Collections.Generic.List[PSCustomObject]]::new()

    # 1. Anti-Cheat Daemons (Critical for online multiplayer - NEVER kill)
    $antiCheats = @(
        @{ Name = "PnkBstrA"; Reason = "PunkBuster Service component (Battlefield, CoD, older titles)" },
        @{ Name = "PnkBstrB"; Reason = "PunkBuster Service monitor (Required to prevent kick/ban)" },
        @{ Name = "EasyAntiCheat"; Reason = "Easy Anti-Cheat core service (Fortnite, Apex, Rust)" },
        @{ Name = "EasyAntiCheat_EOS"; Reason = "Easy Anti-Cheat Epic Online Services" },
        @{ Name = "EasyAntiCheat_Sys"; Reason = "Easy Anti-Cheat kernel driver helper" },
        @{ Name = "start_protected_game"; Reason = "Easy Anti-Cheat game launcher wrapper" },
        @{ Name = "BEService"; Reason = "BattlEye anti-cheat daemon (Rainbow Six, Destiny 2, Tarkov)" },
        @{ Name = "BEDaisy"; Reason = "BattlEye system hook companion" },
        @{ Name = "vgc"; Reason = "Riot Vanguard kernel service (Valorant, League of Legends)" },
        @{ Name = "vgtray"; Reason = "Riot Vanguard system tray monitor" },
        @{ Name = "steamservice"; Reason = "Steam Client Service & VAC helper" },
        @{ Name = "steamwebhelper"; Reason = "Steam overlay and authentication daemon" },
        @{ Name = "faceitclient"; Reason = "FACEIT competitive anti-cheat client" },
        @{ Name = "faceitservice"; Reason = "FACEIT kernel service daemon" },
        @{ Name = "eseaclient"; Reason = "ESEA League anti-cheat client" },
        @{ Name = "eseaservice"; Reason = "ESEA League kernel driver service" },
        @{ Name = "AntiCheatExpert"; Reason = "ACE Tencent Anti-Cheat system" },
        @{ Name = "SGuard"; Reason = "SGuard Anti-Cheat engine" },
        @{ Name = "SGuard64"; Reason = "SGuard Anti-Cheat 64-bit engine" },
        @{ Name = "GameMon"; Reason = "nProtect GameGuard security engine" },
        @{ Name = "GameMon64"; Reason = "nProtect GameGuard 64-bit engine" },
        @{ Name = "xigncode"; Reason = "Xigncode3 anti-cheat engine" },
        @{ Name = "mhyprot2"; Reason = "HoYoverse anti-cheat security daemon" },
        @{ Name = "Agent"; Reason = "Blizzard Battle.net authentication & update agent" }
    )
    foreach ($ac in $antiCheats) {
        $services.Add([PSCustomObject]@{
            ProcessName = $ac.Name
            Category    = "Anti-Cheat Protection"
            Reason      = $ac.Reason
        })
    }

    # 2. Sound Drivers & Audio Processing Subsystems (Critical for in-game audio)
    $audioDrivers = @(
        @{ Name = "audiodg"; Reason = "Windows Audio Device Graph Isolation (Core system sound engine)" },
        @{ Name = "AudioSrv"; Reason = "Windows Audio Service host" },
        @{ Name = "RtkAudUService"; Reason = "Realtek Universal Audio Service daemon" },
        @{ Name = "RAVBg64"; Reason = "Realtek HD Audio background processing daemon" },
        @{ Name = "HDPSHost"; Reason = "Realtek HD Audio driver host" },
        @{ Name = "WavesSvc"; Reason = "Waves MaxxAudio sound enhancement service" },
        @{ Name = "RtkAudioService64"; Reason = "Realtek 64-bit Audio driver service" },
        @{ Name = "RAVCpl64"; Reason = "Realtek Audio Control Panel daemon" },
        @{ Name = "CtHdaSvc"; Reason = "Creative Sound Blaster HD Audio service" },
        @{ Name = "SBCommand"; Reason = "Creative Sound Blaster Command control suite" },
        @{ Name = "NahimicService"; Reason = "Nahimic 3D Audio processing engine (MSI, ASUS, Dell)" },
        @{ Name = "SteelSeriesSonar"; Reason = "SteelSeries Sonar virtual spatial audio engine" },
        @{ Name = "SteelSeriesEngine"; Reason = "SteelSeries peripheral and headset audio control" },
        @{ Name = "DolbyDAX2API"; Reason = "Dolby Atmos & Digital Plus spatial audio driver" },
        @{ Name = "DolbyAtmos"; Reason = "Dolby Atmos headphone audio renderer" },
        @{ Name = "DAX3API"; Reason = "Dolby Atmos API spatial engine" },
        @{ Name = "DTSAudioService"; Reason = "DTS:X Ultra spatial sound daemon" },
        @{ Name = "SonicStudio3"; Reason = "ASUS ROG Sonic Studio spatial sound engine" },
        @{ Name = "RzAudioSrv"; Reason = "Razer Synapse THX Spatial Audio service" },
        @{ Name = "iCUE"; Reason = "Corsair iCUE virtual headset surround engine" },
        @{ Name = "lghub_agent"; Reason = "Logitech G HUB DTS audio driver companion" }
    )
    foreach ($ad in $audioDrivers) {
        $services.Add([PSCustomObject]@{
            ProcessName = $ad.Name
            Category    = "Audio & Sound Driver"
            Reason      = $ad.Reason
        })
    }

    # 3. Hardware Monitoring, FPS Overlays & Stream Tools
    $hardwareMonitors = @(
        @{ Name = "RTSS"; Reason = "RivaTuner Statistics Server (Frame rate limiter & OSD engine)" },
        @{ Name = "RTSSHooksLoader64"; Reason = "RivaTuner 64-bit Direct3D/Vulkan overlay loader" },
        @{ Name = "MSIAfterburner"; Reason = "MSI Afterburner GPU overclock & fan profile controller" },
        @{ Name = "HWiNFO64"; Reason = "HWiNFO hardware telemetry & sensor monitor" },
        @{ Name = "HWiNFO32"; Reason = "HWiNFO 32-bit hardware sensor monitor" },
        @{ Name = "obs64"; Reason = "OBS Studio streaming and game recording engine" },
        @{ Name = "FanControl"; Reason = "Custom GPU/CPU fan curve management utility" },
        @{ Name = "StreamDeck"; Reason = "Elgato Stream Deck hotkey controller" },
        @{ Name = "WaveLink"; Reason = "Elgato Wave Link digital audio mixer" }
    )
    foreach ($hm in $hardwareMonitors) {
        $services.Add([PSCustomObject]@{
            ProcessName = $hm.Name
            Category    = "Hardware & Overlay"
            Reason      = $hm.Reason
        })
    }

    # 4. GPU & Display Drivers
    $gpuInfo = Get-GpuHardwareInfo
    foreach ($g in $gpuInfo.ProtectedDriverProcesses) {
        $services.Add([PSCustomObject]@{
            ProcessName = $g
            Category    = "$($gpuInfo.Vendor) Display Driver"
            Reason      = "Display driver daemon & hardware acceleration service"
        })
    }

    # 5. Core Windows Subsystems
    $windowsCore = @(
        "explorer", "taskmgr", "dwm", "csrss", "winlogon", "services", "lsass", 
        "fontdrvhost", "svchost", "System", "ctfmon", "SystemSettings", "taskhostw", 
        "RuntimeBroker", "SearchHost", "StartMenuExperienceHost", "TextInputHost", 
        "ShellHost", "SecurityHealthSystray", "SecurityHealthService", "Sysmon64", 
        "conhost", "cmd", "pwsh", "powershell", "wt", "GameBooster"
    )
    foreach ($wc in $windowsCore) {
        $services.Add([PSCustomObject]@{
            ProcessName = $wc
            Category    = "Windows Subsystem"
            Reason      = "Core Windows shell and booster environment"
        })
    }

    return $services
}

function Get-EssentialGamingServicesWhitelist {
    $details = Get-ProtectedGamingServicesDetails
    $names = @($details | ForEach-Object { $_.ProcessName })
    return @($names | Select-Object -Unique)
}
