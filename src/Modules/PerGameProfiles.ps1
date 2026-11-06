# ============================================================================
# Game Booster PRO v2.0 - Module: Per-Game Profiles & Community Presets
# Custom CPU, GPU, Memory, Network QoS, and Display configurations per game
# Features: Import/Export JSON Profiles & Tournament Competitive Presets
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
        LauncherRamDiet = $true
        DynamicQosDscp  = 46
        LockWindowsKey  = $false
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

# ----------------------------------------------------------------------------
# COMMUNITY IMPORT / EXPORT ENGINE
# ----------------------------------------------------------------------------

function Export-GameProfileToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [Parameter(Mandatory = $true)]
        [string]$GameName,
        [Parameter(Mandatory = $true)]
        [string]$ExportFilePath
    )
    $clean = $GameName.Trim() -replace '\.exe$', ''
    $prof = Get-ProfileForGame -ConfigPath $ConfigPath -GameName $clean
    if (-not $prof) {
        return [PSCustomObject]@{ Success = $false; Message = "Profile not found for $clean." }
    }

    $exportObj = [PSCustomObject]@{
        SchemaVersion = "2.0"
        ExportedAt    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        GameName      = $clean
        Profile       = $prof
    }

    try {
        $json = $exportObj | ConvertTo-Json -Depth 10
        Set-Content -Path $ExportFilePath -Value $json -Encoding UTF8 -Force
        return [PSCustomObject]@{
            Success  = $true
            FilePath = $ExportFilePath
            Message  = "Profile for '$clean' exported successfully."
        }
    } catch {
        return [PSCustomObject]@{ Success = $false; Message = "Export failed: $_" }
    }
}

function Import-GameProfileFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [Parameter(Mandatory = $true)]
        [string]$ImportFilePath
    )
    if (-not (Test-Path $ImportFilePath)) {
        return [PSCustomObject]@{ Success = $false; Message = "File does not exist: $ImportFilePath" }
    }

    try {
        $raw = Get-Content -Raw -Path $ImportFilePath -Encoding UTF8 | ConvertFrom-Json
        $gameName = if ($raw.GameName) { $raw.GameName } else { (Split-Path $ImportFilePath -Leaf) -replace '\..*$', '' }
        $profData = if ($raw.Profile) { $raw.Profile } else { $raw }

        Save-GameProfile -ConfigPath $ConfigPath -GameName $gameName -ProfileData $profData
        return [PSCustomObject]@{
            Success  = $true
            GameName = $gameName
            Message  = "Profile for '$gameName' imported successfully into configuration."
        }
    } catch {
        return [PSCustomObject]@{ Success = $false; Message = "Import failed: $_" }
    }
}

# ----------------------------------------------------------------------------
# TOURNAMENT COMPETITIVE PRESETS
# ----------------------------------------------------------------------------

function Get-CompetitiveGamePresets {
    return @{
        "Call of Duty (Warzone / BO6)" = [PSCustomObject]@{
            GameName        = "cod"
            PowerPlan       = "Ultimate"
            Priority        = "High"
            AffinityMode    = "CCD0_3DVcache"
            CleanStandby    = $true
            LauncherRamDiet = $true
            DynamicQosDscp  = 46
            LockWindowsKey  = $true
            TimerResolution = $true
            ShowOverlay     = $true
            CompanionApps   = @("Discord")
        }
        "Counter-Strike 2" = [PSCustomObject]@{
            GameName        = "cs2"
            PowerPlan       = "Ultimate"
            Priority        = "High"
            AffinityMode    = "PerformanceCores"
            CleanStandby    = $true
            LauncherRamDiet = $true
            DynamicQosDscp  = 46
            LockWindowsKey  = $true
            TimerResolution = $true
            ShowOverlay     = $true
            CompanionApps   = @("Discord")
        }
        "Valorant" = [PSCustomObject]@{
            GameName        = "VALORANT-Win64-Shipping"
            PowerPlan       = "Ultimate"
            Priority        = "High"
            AffinityMode    = "PerformanceCores"
            CleanStandby    = $true
            LauncherRamDiet = $true
            DynamicQosDscp  = 46
            LockWindowsKey  = $true
            TimerResolution = $true
            ShowOverlay     = $false
            CompanionApps   = @("Discord")
        }
        "Apex Legends" = [PSCustomObject]@{
            GameName        = "r5apex"
            PowerPlan       = "Ultimate"
            Priority        = "High"
            AffinityMode    = "PerformanceCores"
            CleanStandby    = $true
            LauncherRamDiet = $true
            DynamicQosDscp  = 46
            LockWindowsKey  = $false
            TimerResolution = $true
            ShowOverlay     = $true
            CompanionApps   = @("Discord")
        }
        "World of Warcraft" = [PSCustomObject]@{
            GameName        = "Wow"
            PowerPlan       = "Ultimate"
            Priority        = "High"
            AffinityMode    = "CCD0_3DVcache"
            CleanStandby    = $true
            LauncherRamDiet = $true
            DynamicQosDscp  = 46
            LockWindowsKey  = $false
            TimerResolution = $true
            ShowOverlay     = $true
            CompanionApps   = @("Discord")
        }
    }
}
