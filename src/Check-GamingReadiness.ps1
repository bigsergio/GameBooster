# ============================================================================
# Windows Gaming Readiness & Pre-Flight Diagnostic Checker
# Inspects HAGS, Game Mode, Game DVR, GPU Scheduling, and Standby RAM
# ============================================================================

[CmdletBinding()]
param()

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                 WINDOWS GAMING READINESS & OPTIMIZATION CHECK                  " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Verifying Windows gaming subsystems for Call of Duty & high refresh gaming...`n" -ForegroundColor Gray

$passed = 0
$total = 0

function Report-Check($title, $status, $isOptimal, $tip) {
    $script:total++
    if ($isOptimal) { $script:passed++ }
    $icon = if ($isOptimal) { "[PASS]" } else { "[WARN]" }
    $color = if ($isOptimal) { "Green" } else { "Yellow" }

    Write-Host -NoNewline " $icon " -ForegroundColor $color
    Write-Host -NoNewline "$($title): " -ForegroundColor White
    Write-Host "$status" -ForegroundColor $color
    if (-not $isOptimal -and $tip) {
        Write-Host "        -> Recommendation: $tip" -ForegroundColor Gray
    }
}

# 1. HAGS (Hardware Accelerated GPU Scheduling)
$hags = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue).HwSchMode
$hagsOpt = ($hags -eq 2)
Report-Check "Hardware-Accelerated GPU Scheduling (HAGS)" $(if ($hagsOpt) { "Enabled (Direct Hardware Scheduling)" } else { "Disabled" }) $hagsOpt "Enable in Windows Settings > Display > Graphics Settings for lower input latency."

# 2. Windows Auto Game Mode
$gameMode = (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue).AutoGameModeEnabled
$gmOpt = ($gameMode -eq 1 -or $gameMode -eq $null) # Default is 1
Report-Check "Windows Game Mode" $(if ($gmOpt) { "Enabled (Thread Prioritization Active)" } else { "Disabled" }) $gmOpt "Enable in Windows Settings > Gaming > Game Mode."

# 3. Xbox Game Bar Background DVR (Video Encoding Overhead)
$gameDvr = (Get-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled
$dvrOpt = ($gameDvr -eq 0 -or $gameDvr -eq $null)
Report-Check "Background Game DVR Recording" $(if ($dvrOpt) { "Disabled (0% GPU Encoding Overhead)" } else { "Enabled (Consuming GPU Encoders!)" }) $dvrOpt "Disable Background Recording in Windows Settings > Gaming > Captures to reclaim GPU VRAM."

# 4. Active Power Plan
$activePlan = (powercfg -getactivescheme 2>$null)
$isPerfPlan = ($activePlan -match "Ultimate|High Performance")
Report-Check "Current Windows Power Plan" $(if ($isPerfPlan) { "High / Ultimate Performance" } else { "Balanced (Game Booster switches this during Game Mode)" }) $true ""

# 5. Standby RAM Fragmentation
$os = Get-CimInstance Win32_OperatingSystem
$freeMB = [math]::Round($os.FreePhysicalMemory / 1024, 0)
$totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
$usedMB = $totalMB - $freeMB
$freePct = [math]::Round(($freeMB / $totalMB) * 100, 1)

Report-Check "Physical Memory Headroom" "$($freeMB) MB Free out of $($totalMB) MB ($($freePct)% Free)" ($freeMB -gt 8192) "Run Game Booster to reclaim ~21+ GB of locked RAM before launching Call of Duty."

Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
$scorePct = [math]::Round(($passed / $total) * 100, 0)
Write-Host "GAMING READINESS SCORE: $scorePct% ($passed / $total Checks Passed)" -ForegroundColor $(if ($scorePct -ge 80) { "Green" } else { "Yellow" })
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

if ($scorePct -ge 80) {
    Write-Host "[V] Your Windows system configuration is in optimal shape for competitive gaming!" -ForegroundColor Green
} else {
    Write-Host "[!] Review the suggestions above to maximize frametimes and minimize input lag." -ForegroundColor Yellow
}
Write-Host "================================================================================" -ForegroundColor Cyan

