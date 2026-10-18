# ============================================================================
# Game Booster v1.0 - Module: CPU Affinity & Core Parking Optimizer
# Process Lasso-style tuning: High Priority & Performance Core Affinity
# ============================================================================

function Get-CpuTopology {
    $logicalCores = [System.Environment]::ProcessorCount
    $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $cpuName = if ($cpuInfo) { $cpuInfo.Name } else { "Generic CPU" }
    $physicalCores = if ($cpuInfo -and $cpuInfo.NumberOfCores) { $cpuInfo.NumberOfCores } else { [math]::Max(1, [int]($logicalCores / 2)) }

    # Detect Intel Hybrid (P-cores + E-cores) or AMD 3D V-Cache
    $isIntelHybrid = ($cpuName -match "Intel" -and ($cpuName -match "12\d\d\d|13\d\d\d|14\d\d\d|Ultra"))
    $isAmdX3D = ($cpuName -match "AMD" -and $cpuName -match "X3D")

    # Generate Performance Mask
    # For Intel Hybrid: First half or physical P-cores
    # For standard: all cores or first CCD
    $perfMask = [IntPtr][int64]([math]::Pow(2, $logicalCores) - 1) # Default: All cores
    if ($isIntelHybrid) {
        # P-cores with HyperThreading occupy the first 8-16 logical processors
        $pCoresLogical = [math]::Min($logicalCores, 16)
        $perfMask = [IntPtr][int64]([math]::Pow(2, $pCoresLogical) - 1)
    } elseif ($isAmdX3D -and $logicalCores -gt 16) {
        # AMD 7900X3D / 7950X3D: CCD0 has the 3D V-Cache (first 12 or 16 threads)
        $ccd0Threads = [int]($logicalCores / 2)
        $perfMask = [IntPtr][int64]([math]::Pow(2, $ccd0Threads) - 1)
    }

    return [PSCustomObject]@{
        CpuName           = $cpuName
        LogicalCores      = $logicalCores
        PhysicalCores     = $physicalCores
        IsIntelHybrid     = $isIntelHybrid
        IsAmdX3D          = $isAmdX3D
        PerformanceMask   = $perfMask
        AllCoresMask      = [IntPtr][int64]([math]::Pow(2, $logicalCores) - 1)
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

