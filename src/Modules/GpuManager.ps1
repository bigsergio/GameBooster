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
        @{ Name = "WaveLink"; Reason = "Elgato Wave Link digital audio mixer" },
        @{ Name = "RzKLService"; Reason = "Razer Chroma Keyboard Lighting daemon" },
        @{ Name = "RzSDKService"; Reason = "Razer Chroma SDK service" },
        @{ Name = "RazerSynapseService"; Reason = "Razer Synapse peripheral configuration daemon" },
        @{ Name = "RazerAppEngine"; Reason = "Razer Synapse central control interface" },
        @{ Name = "RzActionSvc"; Reason = "Razer peripheral keybind & macro manager" },
        @{ Name = "Creative.App"; Reason = "Creative Sound Blaster suite" },
        @{ Name = "Creative.VADMonitorService"; Reason = "Creative virtual audio device monitor" },
        @{ Name = "lghub"; Reason = "Logitech G HUB peripheral suite" },
        @{ Name = "lghub_updater"; Reason = "Logitech G HUB updater" },
        @{ Name = "logi_lamparray_service"; Reason = "Logitech Dynamic Lighting driver" }
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

    # 5. Core Windows Subsystems & System Security Daemons
    $windowsCore = @(
        "explorer", "taskmgr", "dwm", "csrss", "winlogon", "services", "lsass", 
        "fontdrvhost", "svchost", "System", "ctfmon", "SystemSettings", "taskhostw", 
        "RuntimeBroker", "SearchHost", "StartMenuExperienceHost", "TextInputHost", 
        "ShellHost", "SecurityHealthSystray", "SecurityHealthService", "Sysmon64", 
        "conhost", "cmd", "pwsh", "powershell", "wt", "GameBooster", "smss", "wininit",
        "sppsvc", "MsMpEng", "NisSrv", "MpDefenderCoreService", 
        "DefenderSessionHelper", "MoUsoCoreWorker"
    )
    foreach ($wc in $windowsCore) {
        $services.Add([PSCustomObject]@{
            ProcessName = $wc
            Category    = "Windows Subsystem"
            Reason      = "Core Windows subsystem & security daemon (Protected)"
        })
    }

    return $services
}

function Get-EssentialGamingServicesWhitelist {
    $details = Get-ProtectedGamingServicesDetails
    $names = @($details | ForEach-Object { $_.ProcessName })
    return @($names | Select-Object -Unique)
}

function Get-GpuDriverDetails {
    $gpuControllers = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -notmatch "Basic|Virtual|RDP|Remote|VNC" })

    $primaryGpu = if ($gpuControllers.Count -gt 0) { $gpuControllers[0] } else { $null }
    $gpuName = if ($primaryGpu) { $primaryGpu.Name } else { "Generic Display Adapter" }
    $driverVer = if ($primaryGpu) { $primaryGpu.DriverVersion } else { "Unknown" }
    $driverDate = if ($primaryGpu -and $primaryGpu.DriverDate) {
        try {
            if ($primaryGpu.DriverDate -is [datetime]) {
                $primaryGpu.DriverDate.ToString("yyyy-MM-dd")
            } else {
                [System.Management.ManagementDateTimeConverter]::ToDateTime($primaryGpu.DriverDate.ToString()).ToString("yyyy-MM-dd")
            }
        } catch {
            "$($primaryGpu.DriverDate)".Split(" ")[0]
        }
    } else { "Unknown" }
    $pnpId = if ($primaryGpu) { $primaryGpu.PNPDeviceID } else { "" }

    # Detect Vendor & Display/Release Version
    $vendor = "Unknown"
    $displayVer = $driverVer

    if ($gpuName -match "NVIDIA|GeForce|RTX|GTX|Quadro") {
        $vendor = "NVIDIA"
        if ($driverVer -match '(\d+)\.(\d{2})(\d{2})$') {
            $displayVer = "Game Ready $($matches[1])$($matches[2]).$($matches[3])"
        }
    } elseif ($gpuName -match "AMD|Radeon|RX|Vega") {
        $vendor = "AMD"
        # Check AMD Registry for clean Adrenalin ReleaseVersion
        $classKeys = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000",
            "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001"
        )
        foreach ($ck in $classKeys) {
            $rel = (Get-ItemProperty -Path $ck -Name "ReleaseVersion" -ErrorAction SilentlyContinue).ReleaseVersion
            if ($rel) {
                if ($rel -match "^(\d+\.\d+(\.\d+)?)") {
                    $displayVer = "Adrenalin $($matches[1])"
                } else {
                    $displayVer = "Adrenalin $rel"
                }
                break
            }
        }
        if ($displayVer -eq $driverVer) {
            $cnVer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\AMD\CN" -Name "CNVersion" -ErrorAction SilentlyContinue).CNVersion
            if ($cnVer) { $displayVer = "Adrenalin $cnVer" }
        }
    } elseif ($gpuName -match "Intel|Arc|Iris|Xe") {
        $vendor = "Intel"
        $displayVer = "Intel Graphics $driverVer"
    }

    return [PSCustomObject]@{
        GpuName        = $gpuName
        Vendor         = $vendor
        DriverVersion  = $driverVer
        DisplayVersion = $displayVer
        DriverDate     = $driverDate
        PnpDeviceId    = $pnpId
    }
}

function Check-LatestGpuDriver {
    param(
        [Parameter(Mandatory = $false)]
        $CurrentDetails = $null
    )

    if (-not $CurrentDetails) {
        $CurrentDetails = Get-GpuDriverDetails
    }

    $vendor = $CurrentDetails.Vendor
    $installedVer = $CurrentDetails.DriverVersion
    $installedDisplay = $CurrentDetails.DisplayVersion

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    if ($vendor -eq "AMD") {
        try {
            $feed = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/GPUOpen-Drivers/amd-vulkan-versions/master/amdversions.xml" -TimeoutSec 5 -ErrorAction Stop
            $winDrivers = @($feed.amd_drivers.driver | Where-Object { $_.'operating-system' -eq "Windows" -and $_.version -notmatch "RDNA1" })
            if ($winDrivers.Count -gt 0) {
                $top = $winDrivers[0]
                $latestVer = "$($top.version)"
                $latestWinVer = "$($top.'windows-version')".TrimEnd('.')
                $relDate = "$($top.'release-date')"
                $dlUrl = "$($top.'download-url')"

                # Look up public marketing version for installed driver if available in feed
                $matchedCurrent = $winDrivers | Where-Object { "$($_.'windows-version')".TrimEnd('.') -eq $installedVer } | Select-Object -First 1
                if ($matchedCurrent -and $matchedCurrent.version) {
                    $installedDisplay = "Adrenalin $($matchedCurrent.version)"
                }

                $hasUpdate = $false
                try {
                    $hasUpdate = ([version]$latestWinVer -gt [version]$installedVer)
                } catch {
                    $hasUpdate = ($latestVer -ne $installedDisplay.Replace("Adrenalin ", "").Trim())
                }

                return [PSCustomObject]@{
                    Vendor            = "AMD"
                    GpuName           = $CurrentDetails.GpuName
                    InstalledVersion  = $installedDisplay
                    InstalledDriver   = $installedVer
                    LatestVersion     = "Adrenalin $latestVer"
                    LatestDriver      = $latestWinVer
                    ReleaseDate       = $relDate
                    HasUpdate         = $hasUpdate
                    DownloadUrl       = $dlUrl
                    DetailsUrl        = $dlUrl
                    Status            = if ($hasUpdate) { "Update Available" } else { "Up to Date" }
                    IsWHQL            = $true
                }
            }
        } catch {
            return [PSCustomObject]@{
                Vendor           = "AMD"
                GpuName          = $CurrentDetails.GpuName
                InstalledVersion = $installedDisplay
                InstalledDriver  = $installedVer
                LatestVersion    = "Unknown"
                HasUpdate        = $false
                DownloadUrl      = "https://www.amd.com/en/support/download/drivers.html"
                DetailsUrl       = "https://www.amd.com/en/support/download/drivers.html"
                Status           = "Check Failed (Offline/Timeout)"
                IsWHQL           = $false
            }
        }
    } elseif ($vendor -eq "NVIDIA") {
        try {
            $nvPnpId = "2684_10DE_889C_1043_1"
            if ($CurrentDetails.PnpDeviceId -match "PCI\\VEN_10DE&DEV_([0-9A-Fa-f]{4})(&SUBSYS_([0-9A-Fa-f]{8}))?") {
                $dev = $matches[1]
                $subsys = if ($matches[3]) {
                    "$($matches[3].Substring(0,4))_$($matches[3].Substring(4,4))_1"
                } else { "889C_1043_1" }
                $nvPnpId = "${dev}_10DE_${subsys}"
            }

            $payload = @{
                dIDa  = @($nvPnpId)
                osC   = "10.0"
                osB   = "22631"
                is6   = "1"
                lg    = "1033"
                iLp   = "0"
                prvMd = "0"
                upCRD = "0"
            } | ConvertTo-Json -Compress

            $encoded = [System.Uri]::EscapeDataString($payload)
            $url = "https://gfwsl.geforce.com/nvidia_web_services/controller.gfeclientcontent.NG.php/com.nvidia.services.GFEClientContent_NG.getDispDrvrByDevid/$encoded"
            $res = Invoke-RestMethod -Uri $url -TimeoutSec 6 -ErrorAction Stop

            $drvr = $res.DriverAttributes | Select-Object -First 1
            if ($drvr) {
                $latestVer = "$($drvr.Version)"
                $dlUrl = if ($drvr.DownloadURLAdmin) { $drvr.DownloadURLAdmin } else { $drvr.DownloadURL }
                $relNotes = if ($drvr.DetailsURL) { $drvr.DetailsURL } else { "https://www.nvidia.com/drivers" }
                $relDate = if ($drvr.ReleaseDateTime) { "$($drvr.ReleaseDateTime)".Split(" ")[0] } else { "" }

                $installedNum = $installedDisplay -replace "[^\d\.]", ""
                $hasUpdate = $false
                try {
                    $hasUpdate = ([version]$latestVer -gt [version]$installedNum)
                } catch {
                    $hasUpdate = ($latestVer -ne $installedNum)
                }

                return [PSCustomObject]@{
                    Vendor            = "NVIDIA"
                    GpuName           = $CurrentDetails.GpuName
                    InstalledVersion  = $installedDisplay
                    InstalledDriver   = $installedVer
                    LatestVersion     = "Game Ready $latestVer"
                    LatestDriver      = $latestVer
                    ReleaseDate       = $relDate
                    HasUpdate         = $hasUpdate
                    DownloadUrl       = $dlUrl
                    DetailsUrl        = $relNotes
                    Status            = if ($hasUpdate) { "Update Available" } else { "Up to Date" }
                    IsWHQL            = [bool]$drvr.IsWHQL
                }
            }
        } catch {
            return [PSCustomObject]@{
                Vendor           = "NVIDIA"
                GpuName          = $CurrentDetails.GpuName
                InstalledVersion = $installedDisplay
                InstalledDriver  = $installedVer
                LatestVersion    = "Unknown"
                HasUpdate        = $false
                DownloadUrl      = "https://www.nvidia.com/Download/index.aspx"
                DetailsUrl       = "https://www.nvidia.com/Download/index.aspx"
                Status           = "Check Failed (Offline/Timeout)"
                IsWHQL           = $false
            }
        }
    } elseif ($vendor -eq "Intel") {
        return [PSCustomObject]@{
            Vendor           = "Intel"
            GpuName          = $CurrentDetails.GpuName
            InstalledVersion = $installedDisplay
            InstalledDriver  = $installedVer
            LatestVersion    = "Intel Driver & Support Assistant"
            HasUpdate        = $false
            DownloadUrl      = "https://www.intel.com/content/www/us/en/support/detect.html"
            DetailsUrl       = "https://www.intel.com/content/www/us/en/support/detect.html"
            Status           = "Scan via Intel DSA"
            IsWHQL           = $true
        }
    }

    return [PSCustomObject]@{
        Vendor           = "Generic"
        GpuName          = $CurrentDetails.GpuName
        InstalledVersion = $installedDisplay
        InstalledDriver  = $installedVer
        LatestVersion    = "N/A"
        HasUpdate        = $false
        DownloadUrl      = ""
        DetailsUrl       = ""
        Status           = "Unsupported GPU Vendor"
        IsWHQL           = $false
    }
}
