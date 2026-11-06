# ============================================================================
# Game Booster PRO v2.0 - Module: Multi-Vendor GPU Shader Cache Manager
# Comprehensive 1-Click safe cleanup for DirectX, AMD, NVIDIA, Intel, Steam,
# and Battle.net/Call of Duty shader caches to eliminate compile stutters.
# ============================================================================

function Get-SteamLibraryShaderPaths {
    $paths = @()
    # Default C:\ location
    $defaultSteam = "C:\Program Files (x86)\Steam\steamapps\shadercache"
    if (Test-Path $defaultSteam) { $paths += $defaultSteam }

    # Scan all drive letters for SteamLibrary\steamapps\shadercache
    Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
        $candidate = "$($_.DriveLetter):\SteamLibrary\steamapps\shadercache"
        if (Test-Path $candidate) { $paths += $candidate }
        $candidate2 = "$($_.DriveLetter):\Games\SteamLibrary\steamapps\shadercache"
        if (Test-Path $candidate2) { $paths += $candidate2 }
    }

    return @($paths | Select-Object -Unique)
}

function Get-ExpandedShaderCacheLocations {
    <#
    .SYNOPSIS
        Returns all known shader cache directories grouped by category.
    #>
    $locations = @(
        # DirectX
        [PSCustomObject]@{ Category = "DirectX"; Path = "$env:LOCALAPPDATA\D3DSCache" },
        [PSCustomObject]@{ Category = "DirectX"; Path = "$env:LOCALAPPDATA\Microsoft\DirectX Shader Cache" },
        [PSCustomObject]@{ Category = "DirectX"; Path = "$env:LOCALAPPDATA\Microsoft\Direct3D" },

        # AMD Radeon
        [PSCustomObject]@{ Category = "AMD Radeon"; Path = "$env:LOCALAPPDATA\AMD\DxCache" },
        [PSCustomObject]@{ Category = "AMD Radeon"; Path = "$env:LOCALAPPDATA\AMD\GLCache" },
        [PSCustomObject]@{ Category = "AMD Radeon"; Path = "$env:LOCALAPPDATA\AMD\OglCache" },

        # NVIDIA GeForce
        [PSCustomObject]@{ Category = "NVIDIA"; Path = "$env:LOCALAPPDATA\NVIDIA\DXCache" },
        [PSCustomObject]@{ Category = "NVIDIA"; Path = "$env:LOCALAPPDATA\NVIDIA\GLCache" },
        [PSCustomObject]@{ Category = "NVIDIA"; Path = "$env:APPDATA\NVIDIA\ComputeCache" },
        [PSCustomObject]@{ Category = "NVIDIA"; Path = "$env:ProgramData\NVIDIA Corporation\NV_Cache" },

        # Intel Graphics
        [PSCustomObject]@{ Category = "Intel"; Path = "$env:LOCALAPPDATA\Intel\ShaderCache" },

        # Battle.net / Blizzard
        [PSCustomObject]@{ Category = "Battle.net"; Path = "$env:LOCALAPPDATA\Battle.net\Cache" },
        [PSCustomObject]@{ Category = "Battle.net"; Path = "$env:LOCALAPPDATA\Blizzard Entertainment\Battle.net\Cache" }
    )

    # Add Steam Pre-caching locations
    foreach ($sp in (Get-SteamLibraryShaderPaths)) {
        $locations += [PSCustomObject]@{ Category = "Steam Pre-Caching"; Path = $sp }
    }

    return @($locations | Where-Object { Test-Path $_.Path })
}

function Get-DetailedShaderCacheReport {
    <#
    .SYNOPSIS
        Scans all existing shader cache directories and computes file count and size.
    #>
    $locs = Get-ExpandedShaderCacheLocations
    $report = @()
    $totalBytes = 0
    $totalFiles = 0

    foreach ($loc in $locs) {
        $files = Get-ChildItem -Path $loc.Path -Recurse -File -ErrorAction SilentlyContinue
        $cnt = if ($files) { $files.Count } else { 0 }
        $bytes = if ($files) { ($files | Measure-Object -Property Length -Sum).Sum } else { 0 }
        $sizeMB = [math]::Round($bytes / 1MB, 2)

        $totalBytes += $bytes
        $totalFiles += $cnt

        $report += [PSCustomObject]@{
            Category  = $loc.Category
            Path      = $loc.Path
            FileCount = $cnt
            SizeMB    = $sizeMB
        }
    }

    return [PSCustomObject]@{
        TotalMB    = [math]::Round($totalBytes / 1MB, 2)
        TotalGB    = [math]::Round($totalBytes / 1GB, 3)
        TotalFiles = $totalFiles
        Categories = $report
    }
}

function Invoke-ExpandedShaderCacheClean {
    param(
        [string]$TargetCategory = "All" # "All", "DirectX", "AMD Radeon", "NVIDIA", "Steam Pre-Caching", "Battle.net"
    )

    $locs = Get-ExpandedShaderCacheLocations
    if ($TargetCategory -ne "All") {
        $locs = @($locs | Where-Object { $_.Category -like "*$TargetCategory*" })
    }

    $deletedFiles = 0
    $deletedBytes = 0
    $lockedFiles = 0

    foreach ($loc in $locs) {
        $files = Get-ChildItem -Path $loc.Path -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $len = $f.Length
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                $deletedFiles++
                $deletedBytes += $len
            } catch {
                # File is currently mapped into memory or locked by active GPU driver/game
                $lockedFiles++
            }
        }
    }

    $freedMB = [math]::Round($deletedBytes / 1MB, 2)
    return [PSCustomObject]@{
        Success      = $true
        FilesPurged  = $deletedFiles
        LockedFiles  = $lockedFiles
        FreedMB      = $freedMB
        Message      = "Purged $deletedFiles shader cache files ($freedMB MB reclaimed). Stale shader compiler blobs eliminated."
    }
}
