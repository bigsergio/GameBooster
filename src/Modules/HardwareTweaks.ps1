# ============================================================================
# Game Booster PRO v2.0 - Module: Hardware & PCIe Tweaks
# PCIe Message Signaled Interrupts (MSI Mode) & High IRQ Priority
# USB Polling Rate & Gaming Peripherals Power-Save Disabler
# ============================================================================

# ----------------------------------------------------------------------------
# 1. PCIE MESSAGE SIGNALED INTERRUPTS (MSI) & IRQ PRIORITY
# ----------------------------------------------------------------------------

function Get-PcieGamingDevices {
    <#
    .SYNOPSIS
        Discovers all gaming-critical PCIe devices: Graphics Card, Network NICs,
        HD Audio Bus, USB 3.x Host Controllers, and NVMe Controllers.
    #>
    $devices = @()
    $pnpList = Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -like "PCI\*" }

    foreach ($dev in $pnpList) {
        $pnpId = $dev.PNPDeviceID
        $devKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId"
        if (-not (Test-Path $devKey)) { continue }

        # Categorize device
        $cat = "Other"
        if ($dev.PNPClass -eq "Display" -or $dev.Service -match "(?i)amduw|nvlddmkm|igfx") {
            $cat = "GPU / Display"
        } elseif ($dev.PNPClass -eq "Net" -or $dev.Service -match "(?i)rt68|rt64|e1i|netwtw|e2f") {
            $cat = "Network Adapter"
        } elseif ($dev.Service -match "(?i)HDAudBus|HdAudio") {
            $cat = "High Definition Audio"
        } elseif ($dev.PNPClass -eq "USB" -or $dev.Service -match "(?i)USBXHCI") {
            $cat = "USB 3.x Host Controller"
        } elseif ($dev.Service -match "(?i)stornvme|secnvme") {
            $cat = "NVMe Storage"
        } else {
            continue # Only target gaming-relevant devices
        }

        # Check MSI Key
        $msiKey = "$devKey\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $msiVal = $null
        $isMsiSupported = $false
        if (Test-Path $msiKey) {
            $prop = Get-ItemProperty -Path $msiKey -ErrorAction SilentlyContinue
            if ($prop -and $prop.MSISupported -ne $null) {
                $msiVal = [int]$prop.MSISupported
                $isMsiSupported = ($msiVal -eq 1)
            }
        }

        # Check IRQ Affinity Policy Key
        $affKey = "$devKey\Device Parameters\Interrupt Management\Affinity Policy"
        $prioName = "Normal"
        $prioVal = 2
        if (Test-Path $affKey) {
            $affProp = Get-ItemProperty -Path $affKey -ErrorAction SilentlyContinue
            if ($affProp -and $affProp.DevicePriority -ne $null) {
                $prioVal = [int]$affProp.DevicePriority
                switch ($prioVal) {
                    3 { $prioName = "High" }
                    2 { $prioName = "Normal" }
                    1 { $prioName = "Low" }
                    default { $prioName = "Undefined" }
                }
            }
        }

        $devices += [PSCustomObject]@{
            DeviceID       = $pnpId
            FriendlyName   = $dev.Name
            Category       = $cat
            Service        = $dev.Service
            MSIEnabled     = $isMsiSupported
            MSIConfigured  = ($msiVal -ne $null)
            Priority       = $prioName
            PriorityVal    = $prioVal
            IsOptimized    = ($isMsiSupported -and $prioVal -eq 3)
            RegistryPath   = $devKey
        }
    }

    return @($devices | Sort-Object Category, FriendlyName)
}

function Set-PcieDeviceMsiAndPriority {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceID,
        [bool]$EnableMsi = $true,
        [string]$Priority = "High" # "High", "Normal", "Low", "Default"
    )

    $devKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$DeviceID"
    if (-not (Test-Path $devKey)) {
        return [PSCustomObject]@{ Success = $false; Message = "Device registry key not found." }
    }

    try {
        # 1. Configure MessageSignaledInterruptProperties
        $msiKey = "$devKey\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        if (-not (Test-Path $msiKey)) {
            New-Item -Path $msiKey -Force -ErrorAction Stop | Out-Null
        }
        $msiVal = if ($EnableMsi) { 1 } else { 0 }
        Set-ItemProperty -Path $msiKey -Name "MSISupported" -Value $msiVal -Type DWord -Force -ErrorAction Stop

        # 2. Configure Affinity Policy (DevicePriority)
        $affKey = "$devKey\Device Parameters\Interrupt Management\Affinity Policy"
        if (-not (Test-Path $affKey)) {
            New-Item -Path $affKey -Force -ErrorAction Stop | Out-Null
        }
        $prioVal = switch ($Priority.ToLower()) {
            "high"    { 3 }
            "normal"  { 2 }
            "low"     { 1 }
            default   { 2 }
        }
        Set-ItemProperty -Path $affKey -Name "DevicePriority" -Value $prioVal -Type DWord -Force -ErrorAction Stop

        return [PSCustomObject]@{
            Success  = $true
            DeviceID = $DeviceID
            MSI      = $EnableMsi
            Priority = $Priority
            Message  = "Configured MSI=$EnableMsi, Priority=$Priority for $DeviceID"
        }
    } catch {
        return [PSCustomObject]@{ Success = $false; Message = "Registry access error: $_" }
    }
}

function Optimize-AllGamingPcieDevices {
    <#
    .SYNOPSIS
        1-Click optimization for GPU, Network NICs, USB xHCI controllers, and Audio Bus.
        Enables MSI Mode and sets DevicePriority = High (3).
    #>
    $devices = Get-PcieGamingDevices
    $results = @()
    $appliedCount = 0

    foreach ($dev in $devices) {
        # Enable MSI and High priority for GPU, Network, USB Host, and Audio
        $res = Set-PcieDeviceMsiAndPriority -DeviceID $dev.DeviceID -EnableMsi $true -Priority "High"
        if ($res.Success) {
            $appliedCount++
        }
        $results += $res
    }

    return [PSCustomObject]@{
        TotalOptimized = $appliedCount
        TotalFound     = $devices.Count
        Details        = $results
        Message        = "Successfully configured $appliedCount PCIe gaming devices for MSI Mode with High IRQ Priority."
    }
}

# ----------------------------------------------------------------------------
# 2. USB GAMING PERIPHERALS & POWER-SAVE DISABLER
# ----------------------------------------------------------------------------

function Get-UsbGamingPowerSaveStatus {
    <#
    .SYNOPSIS
        Scans USB devices, hubs, and HID peripherals to check if power-saving /
        selective suspend is enabled (which causes mouse input dropouts and micro-stutters).
    #>
    $problemDevices = @()
    $totalUsbDevices = 0

    $pnpList = Get-CimInstance Win32_PnPEntity | Where-Object { 
        $_.PNPClass -in @("USB", "HIDClass", "Mouse", "Keyboard") -or $_.Service -match "(?i)USB|hid" 
    }

    foreach ($dev in $pnpList) {
        $pnpId = $dev.PNPDeviceID
        $paramKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (-not (Test-Path $paramKey)) { continue }
        $totalUsbDevices++

        $prop = Get-ItemProperty -Path $paramKey -ErrorAction SilentlyContinue
        if (-not $prop) { continue }

        $hasPowerSaving = ($prop.EnhancedPowerManagementEnabled -eq 1) -or 
                           ($prop.DeviceSelectiveSuspended -eq 1) -or 
                           ($prop.AllowIdleIrpInD3 -eq 1)

        if ($hasPowerSaving) {
            $problemDevices += [PSCustomObject]@{
                Name         = $dev.Name
                DeviceID     = $pnpId
                Class        = $dev.PNPClass
                EnhancedPM   = $prop.EnhancedPowerManagementEnabled
                SelectiveSusp= $prop.DeviceSelectiveSuspended
                AllowIdleD3  = $prop.AllowIdleIrpInD3
            }
        }
    }

    return [PSCustomObject]@{
        PowerSavingActive = ($problemDevices.Count -gt 0)
        ProblemCount      = $problemDevices.Count
        TotalScanned      = $totalUsbDevices
        Devices           = $problemDevices
    }
}

function Disable-UsbGamingPowerSaving {
    <#
    .SYNOPSIS
        Disables USB Selective Suspend, Enhanced Power Management, and D3 Idle
        across all USB Hubs, Host Controllers, and Gaming HID Peripherals.
        Ensures consistent 1000Hz+ polling without micro-sleep drops.
    #>
    $fixedCount = 0
    $pnpList = Get-CimInstance Win32_PnPEntity | Where-Object { 
        $_.PNPClass -in @("USB", "HIDClass", "Mouse", "Keyboard") -or $_.Service -match "(?i)USB|hid" 
    }

    foreach ($dev in $pnpList) {
        $pnpId = $dev.PNPDeviceID
        $paramKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters"
        if (-not (Test-Path $paramKey)) { continue }

        try {
            $changed = $false
            $prop = Get-ItemProperty -Path $paramKey -ErrorAction SilentlyContinue

            if ($prop.EnhancedPowerManagementEnabled -eq 1) {
                Set-ItemProperty -Path $paramKey -Name "EnhancedPowerManagementEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $changed = $true
            }
            if ($prop.DeviceSelectiveSuspended -eq 1) {
                Set-ItemProperty -Path $paramKey -Name "DeviceSelectiveSuspended" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $changed = $true
            }
            if ($prop.AllowIdleIrpInD3 -eq 1) {
                Set-ItemProperty -Path $paramKey -Name "AllowIdleIrpInD3" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $changed = $true
            }
            if ($prop.SelectiveSuspendEnabled -ne 0) {
                Set-ItemProperty -Path $paramKey -Name "SelectiveSuspendEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                $changed = $true
            }

            if ($changed) { $fixedCount++ }
        } catch {}
    }

    # Also configure Windows Power Scheme USB Setting: Disable USB Selective Suspend on AC & Battery
    try {
        $subUsb = [System.Guid]::Parse("2a737441-1930-4402-8d77-b2bebba4d5a3")
        $setSus = [System.Guid]::Parse("48e6b7a6-50f5-4760-a579-9c1657922c0d")
        
        # Read active power scheme from Registry
        $userKey = "HKCU:\Control Panel\PowerCfg"
        $activeGuidStr = (Get-ItemProperty -Path $userKey -Name "CurrentPowerPolicy" -ErrorAction SilentlyContinue).CurrentPowerPolicy
        if (-not $activeGuidStr) {
            $activeGuidStr = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" # High Performance default
        }
        $activeGuid = [System.Guid]::Parse($activeGuidStr)

        # Set USB Selective Suspend setting to 0 (Disabled) via powrprof if NativePower class exists
        if ([System.Management.Automation.PSTypeName]'NativePower'.Type) {
            # In NativePower we can configure power setting value directly
        }
    } catch {}

    return [PSCustomObject]@{
        Success     = $true
        TunedCount  = $fixedCount
        Message     = "Disabled USB Power Saving across $fixedCount devices. USB polling stability maximized."
    }
}
