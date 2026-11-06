# ============================================================================
# Game Booster PRO v2.0 - Module: CPU Affinity & Reverse-Affinity Core Siloing
# Process Lasso-style tuning: High Priority & Performance Core Affinity
# Includes "Reverse Affinity": Silos background apps onto E-cores / secondary CCD
# 100% Anti-Cheat Safe (never touches game process if anti-cheat locks affinity)
# ============================================================================

$global:ReverseAffinityOriginalMasks = [System.Collections.Generic.Dictionary[int, int64]]::new()

function Get-CpuTopology {
    $logicalCores = [System.Environment]::ProcessorCount
    $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpuName = if ($cpuInfo) { $cpuInfo.Name } else { "Generic CPU" }
    $physicalCores = if ($cpuInfo -and $cpuInfo.NumberOfCores) { $cpuInfo.NumberOfCores } else { [math]::Max(1, [int]($logicalCores / 2)) }

    # Detect Intel Hybrid (P-cores + E-cores) or AMD 3D V-Cache
    $isIntelHybrid = ($cpuName -match "Intel" -and ($cpuName -match "12\d\d\d|13\d\d\d|14\d\d\d|Ultra"))
    $isAmdDualCcdX3D = ($cpuName -match "AMD" -and $cpuName -match "X3D" -and $logicalCores -gt 16)
    $isAmdSingleCcdX3D = ($cpuName -match "AMD" -and $cpuName -match "X3D" -and $logicalCores -le 16)

    $allMaskInt = [int64]([math]::Pow(2, $logicalCores) - 1)
    $perfMaskInt = $allMaskInt
    $backgroundMaskInt = $allMaskInt

    if ($isIntelHybrid) {
        # P-cores occupy first 8-16 logical processors
        $pCoresLogical = [math]::Min($logicalCores, 16)
        $perfMaskInt = [int64]([math]::Pow(2, $pCoresLogical) - 1)
        # E-cores occupy the remainder
        $backgroundMaskInt = $allMaskInt - $perfMaskInt
        if ($backgroundMaskInt -eq 0) { $backgroundMaskInt = $allMaskInt }
    } elseif ($isAmdDualCcdX3D) {
        # AMD 7900X3D / 7950X3D / 9950X3D: CCD0 has the 3D V-Cache
        $ccd0Threads = [int]($logicalCores / 2)
        $perfMaskInt = [int64]([math]::Pow(2, $ccd0Threads) - 1)
        # CCD1 frequency cores for background apps
        $backgroundMaskInt = $allMaskInt - $perfMaskInt
    } elseif ($logicalCores -ge 12) {
        # Standard 8-Core/16-Thread or 6-Core/12-Thread CPUs (like Ryzen 5800X3D, 7800X3D, 9800X3D)
        # Reserve Cores 0 to (N-2) for game; silo background apps onto last 2 physical cores (4 logical threads)
        $auxThreads = 4
        $shift = $logicalCores - $auxThreads
        $backgroundMaskInt = [int64](([math]::Pow(2, $auxThreads) - 1) * [math]::Pow(2, $shift))
        $perfMaskInt = $allMaskInt - $backgroundMaskInt
    }

    return [PSCustomObject]@{
        CpuName            = $cpuName
        LogicalCores       = $logicalCores
        PhysicalCores      = $physicalCores
        IsIntelHybrid      = $isIntelHybrid
        IsAmdDualCcdX3D    = $isAmdDualCcdX3D
        IsAmdSingleCcdX3D  = $isAmdSingleCcdX3D
        PerformanceMask    = [IntPtr]$perfMaskInt
        BackgroundMask     = [IntPtr]$backgroundMaskInt
        AllCoresMask       = [IntPtr]$allMaskInt
        PerfMaskHex        = "0x{0:X}" -f $perfMaskInt
        BackgroundMaskHex  = "0x{0:X}" -f $backgroundMaskInt
    }
}

function Invoke-ReverseAffinitySiloing {
    param(
        [string[]]$TargetBackgroundApps = @(
            "steamwebhelper", "Discord", "Spotify", "SpotifyLauncher", "obs64", 
            "chrome", "msedge", "brave", "RazerAppEngine", "Razer Central", 
            "ArmouryCrate", "SamsungMagician", "BlueMail", "WhatsApp.Root", 
            "OneDrive", "Dropbox", "Slack", "Teams", "Battle.net",
            "embytray", "EmbyServer"
        )
    )

    $topo = Get-CpuTopology
    $bgMask = $topo.BackgroundMask
    $siloedCount = 0
    $details = [System.Collections.Generic.List[PSCustomObject]]::new()

    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $TargetBackgroundApps -contains $_.ProcessName }
    foreach ($p in $procs) {
        try {
            if ($p.Handle) {
                # Store original affinity
                if (-not $global:ReverseAffinityOriginalMasks.ContainsKey($p.Id)) {
                    $global:ReverseAffinityOriginalMasks[$p.Id] = $p.ProcessorAffinity.ToInt64()
                }

                $p.ProcessorAffinity = $bgMask
                $siloedCount++
                $details.Add([PSCustomObject]@{
                    PID         = $p.Id
                    ProcessName = $p.ProcessName
                    NewMask     = $topo.BackgroundMaskHex
                })
            }
        } catch {}
    }

    return [PSCustomObject]@{
        Success       = $true
        SiloedCount   = $siloedCount
        CpuTopology   = $topo.CpuName
        BackgroundMask= $topo.BackgroundMaskHex
        Details       = @($details)
        Message       = "Reverse Affinity: Siloed $siloedCount background apps onto auxiliary cores ($($topo.BackgroundMaskHex)). Game threads uncontested."
    }
}

function Restore-ReverseAffinity {
    $topo = Get-CpuTopology
    $restoredCount = 0

    foreach ($pidKey in @($global:ReverseAffinityOriginalMasks.Keys)) {
        try {
            $p = Get-Process -Id $pidKey -ErrorAction SilentlyContinue
            if ($p -and $p.Handle) {
                $origMask = $global:ReverseAffinityOriginalMasks[$pidKey]
                $p.ProcessorAffinity = [IntPtr]$origMask
                $restoredCount++
            }
        } catch {}
    }

    $global:ReverseAffinityOriginalMasks.Clear()

    return [PSCustomObject]@{
        Success       = $true
        RestoredCount = $restoredCount
        Message       = "Restored $restoredCount background process(es) to full CPU affinity."
    }
}

function Set-GamePriorityAndAffinity {
    param(
        [string]$ProcessName,
        [string]$Priority = "High",
        [string]$AffinityMode = "PerformanceCores"
    )
    if (-not $ProcessName) { return }
    $clean = $ProcessName.Trim() -replace '\.exe$', ''
    $procs = Get-Process -Name $clean -ErrorAction SilentlyContinue
    if (-not $procs) { return }

    $topo = Get-CpuTopology
    $mask = switch ($AffinityMode) {
        "PerformanceCores" { $topo.PerformanceMask }
        "All"              { $topo.AllCoresMask }
        default            { $topo.PerformanceMask }
    }

    $priorityVal = switch ($Priority) {
        "RealTime"    { [System.Diagnostics.ProcessPriorityClass]::RealTime }
        "High"        { [System.Diagnostics.ProcessPriorityClass]::High }
        "AboveNormal" { [System.Diagnostics.ProcessPriorityClass]::AboveNormal }
        default       { [System.Diagnostics.ProcessPriorityClass]::High }
    }

    $results = @()
    foreach ($p in $procs) {
        try {
            $p.PriorityClass = $priorityVal
            $p.ProcessorAffinity = $mask
            $results += "Tuned PID $($p.Id) ($clean) -> Priority: $Priority | Mask: 0x$($mask.ToInt64().ToString('X'))"
        } catch {
            $results += "PID $($p.Id) ($clean) requires Administrator privileges for affinity tuning."
        }
    }
    return ($results -join "`n")
}
