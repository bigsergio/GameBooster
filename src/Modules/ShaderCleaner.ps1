# ============================================================================
# Game Booster v1.0 - Module: GPU Shader Cache & Junk Cleaner
# 1-Click safe cleanup for DirectX, NVIDIA, AMD, and Intel shader caches
# ============================================================================

function Get-ShaderCacheDirectories {
    $dirs = @(
        "$env:LOCALAPPDATA\D3DSCache",
        "$env:LOCALAPPDATA\NVIDIA\DXCache",
        "$env:LOCALAPPDATA\NVIDIA\GLCache",
        "$env:LOCALAPPDATA\AMD\DxCache",
        "$env:LOCALAPPDATA\AMD\GLCache",
        "$env:LOCALAPPDATA\Intel\ShaderCache",
        "$env:LOCALAPPDATA\Temp"
    )
    return @($dirs | Where-Object { Test-Path $_ })
}

function Get-ShaderCacheSize {
    $dirs = Get-ShaderCacheDirectories
    $totalBytes = 0
    $fileCount = 0

    foreach ($d in $dirs) {
        $files = Get-ChildItem -Path $d -Recurse -File -ErrorAction SilentlyContinue
        if ($files) {
            $totalBytes += ($files | Measure-Object -Property Length -Sum).Sum
            $fileCount += $files.Count
        }
    }

    return [PSCustomObject]@{
        TotalMB   = [math]::Round($totalBytes / 1MB, 2)
        FileCount = $fileCount
    }
}

function Invoke-ShaderCacheClean {
    $dirs = Get-ShaderCacheDirectories
    $deletedFiles = 0
    $deletedBytes = 0

    foreach ($d in $dirs) {
        $files = Get-ChildItem -Path $d -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $len = $f.Length
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                $deletedFiles++
                $deletedBytes += $len
            } catch {
                # In-use shader cache files are skipped safely
            }
        }
    }

    $freedMB = [math]::Round($deletedBytes / 1MB, 2)
    return [PSCustomObject]@{
        FilesPurged = $deletedFiles
        FreedMB     = $freedMB
        Message     = "Shader Cache Cleaned: Removed $deletedFiles cache files, freed $freedMB MB. Micro-stutters and stale shaders cleared."
    }
}

