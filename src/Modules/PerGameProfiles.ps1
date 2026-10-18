# ============================================================================
# Game Booster v1.0 - Module: Per-Game Profiles
# Custom CPU, GPU, Memory, Network, and Companion configurations per game
# ============================================================================

function Get-GameProfiles {
    param([string]$ConfigPath)
    if (-not $ConfigPath -or -not (Test-Path $ConfigPath)) {
        return @{}
    }
    try {
        $cfg = Get-Content -Raw -Path $ConfigPath -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.gameProfiles) {
            return $cfg.gameProfiles
        }
    } catch {}
    return @{}
}

function Get-DefaultGameProfile {
    param([string]$GameName)
    return [PSCustomObject]@{
        GameName        = $GameName
        PowerPlan       = "Ultimate"
        Priority        = "High"
        AffinityMode    = "PerformanceCores" # "All", "PerformanceCores", "CCD0_3DVcache"
        CleanStandby    = $true
        TimerResolution = $true
        ShowOverlay     = $true
        CompanionApps   = @("Discord")
    }
}

function Get-ProfileForGame {
    param(
        [string]$ConfigPath,
        [string]$GameName
    )
    if (-not $GameName) { return (Get-DefaultGameProfile "Default") }
    $clean = $GameName.Trim() -replace '\.exe$', ''
    $profiles = Get-GameProfiles -ConfigPath $ConfigPath
    
    if ($profiles -and $profiles.$clean) {
        return $profiles.$clean
    }
    return (Get-DefaultGameProfile $clean)
}

function Save-GameProfile {
    param(
        [string]$ConfigPath,
        [string]$GameName,
        [psobject]$ProfileData
    )
    if (-not $ConfigPath -or -not (Test-Path $ConfigPath)) { return }
    $clean = $GameName.Trim() -replace '\.exe$', ''
    if (-not $clean) { return }

    try {
        $cfg = Get-Content -Raw -Path $ConfigPath -Encoding UTF8 | ConvertFrom-Json
        if (-not $cfg.gameProfiles) {
            $cfg | Add-Member -MemberType NoteProperty -Name "gameProfiles" -Value ([PSCustomObject]@{}) -Force
        }
        $cfg.gameProfiles | Add-Member -MemberType NoteProperty -Name $clean -Value $ProfileData -Force
        $json = $cfg | ConvertTo-Json -Depth 10
        Set-Content -Path $ConfigPath -Value $json -Encoding UTF8 -Force
    } catch {
        Write-Error "Failed to save profile for $($clean): $_"
    }
}

