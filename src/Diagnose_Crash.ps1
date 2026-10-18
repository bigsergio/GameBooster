# ============================================================================
# Game & Application Crash Root-Cause Diagnostics
# Multi-Crash History Analyzer (Select from the last 10 crash events)
# ============================================================================

[CmdletBinding()]
param(
    [int]$Index = 0  # 1-10 to directly diagnose a specific crash, or 0 for interactive selector
)

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }
$LogFile = Join-Path $RootDir "gamebooster.log"

function Write-DiagLog($msg) {
    $line = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [CRASH-DIAG] $msg"
    try { Add-Content -Path $LogFile -Value $line -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                 GAME & APPLICATION CRASH ROOT-CAUSE DIAGNOSTICS                " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Scanning Windows Event Logs and Game Dumps for the last 10 crash events...`n" -ForegroundColor Gray

# Common Gaming Exception Dictionary
$knownExceptions = @{
    "0xc0000005" = "STATUS_ACCESS_VIOLATION: Memory Access Violation. The game attempted to read/write unallocated RAM. Common causes: unstable XMP/EXPO RAM timings, VRAM exhaustion, or corrupt game cache."
    "0x887a0006" = "DXGI_ERROR_DEVICE_HUNG: GPU Driver Timeout. The graphics card stopped responding to DirectX commands. Common causes: GPU clock/undervolt instability or shader corruption."
    "0x887a0005" = "DXGI_ERROR_DEVICE_REMOVED: The GPU was physically reset or disconnected by the driver (TDR event)."
    "0xc00000fd" = "STATUS_STACK_OVERFLOW: Thread stack space exhausted. Often caused by infinite game script loops or corrupt shader compilation."
    "0x80000003" = "STATUS_BREAKPOINT: Hardcoded breakpoint encountered. Often triggered by anti-cheat (Ricochet) detecting injected DLL hooks."
    "0xc0000409" = "STATUS_STACK_BUFFER_OVERRUN: Security stack corruption detected. Process aborted to protect memory integrity."
    "0xc000001d" = "STATUS_ILLEGAL_INSTRUCTION: Game executed an instruction unsupported or corrupted in memory."
    "0xc0000006" = "STATUS_IN_PAGE_ERROR: The system could not read game data from disk into RAM (possible SSD/drive read failure)."
    "0xe0434352" = "CLR_EXCEPTION: .NET Runtime Fatal Exception. Often caused by missing .NET framework dependencies or unhandled managed code errors."
}

# 1. Fetch the last 10 Application Error events
$rawEvents = @(Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; Id=1000} -MaxEvents 10 -ErrorAction SilentlyContinue)

if (-not $rawEvents -or $rawEvents.Count -eq 0) {
    Write-Host "[V] No application crash events recorded in Windows Event Logs recently." -ForegroundColor Green
    exit 0
}

# Parse crashes into structured list
$parsedCrashes = @()
$idx = 1
foreach ($evt in $rawEvents) {
    $msg = $evt.Message
    $appName = if ($msg -match "Faulting application name:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
    $appVer  = if ($msg -match "version:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
    $modName = if ($msg -match "Faulting module name:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
    $modVer  = if ($msg -match "faulting module version:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
    $code    = if ($msg -match "Exception code:\s*(0x[0-9a-fA-F]+)") { $matches[1].ToLower().Trim() } else { "Unknown" }
    $offset  = if ($msg -match "Fault offset:\s*(0x[0-9a-fA-F]+)") { $matches[1].Trim() } else { "Unknown" }
    $path    = if ($msg -match "Faulting application path:\s*([^\r\n]+)") { $matches[1].Trim() } else { "Unknown" }

    $parsedCrashes += [PSCustomObject]@{
        Index         = $idx
        TimeCreated   = $evt.TimeCreated
        TimeFormatted = $evt.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        AppName       = $appName
        AppVer        = $appVer
        ModName       = $modName
        ModVer        = $modVer
        Code          = $code
        Offset        = $offset
        Path          = $path
        RawEvent      = $evt
    }
    $idx++
}

# Determine which crash to inspect
$targetIndex = $Index
if ($targetIndex -lt 1 -or $targetIndex -gt $parsedCrashes.Count) {
    Write-Host "Recent Application Crash History (Last $($parsedCrashes.Count) Events):" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    foreach ($c in $parsedCrashes) {
        $color = if ($c.AppName -match "cod|bootstrapper|Wow|game|league") { "Green" } else { "White" }
        Write-Host (" [{0,2}] {1}  |  {2,-26} | Code: {3,-10} | Module: {4}" -f $c.Index, $c.TimeFormatted, $c.AppName, $c.Code, $c.ModName) -ForegroundColor $color
    }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    
    $prompt = Read-Host "`nEnter crash number to diagnose (1-$($parsedCrashes.Count)) [Default: 1]"
    if ($prompt -match '^\d+$' -and [int]$prompt -ge 1 -and [int]$prompt -le $parsedCrashes.Count) {
        $targetIndex = [int]$prompt
    } else {
        $targetIndex = 1
    }
}

$selectedCrash = $parsedCrashes | Where-Object { $_.Index -eq $targetIndex } | Select-Object -First 1
if (-not $selectedCrash) { $selectedCrash = $parsedCrashes[0] }

# Deep Root-Cause Analysis for Selected Crash
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "DIAGNOSING CRASH EVENT #$($selectedCrash.Index): $($selectedCrash.AppName)" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Timestamp:          $($selectedCrash.TimeFormatted)"
Write-Host "Crashing App:       $($selectedCrash.AppName) (Version: $($selectedCrash.AppVer))" -ForegroundColor White
Write-Host "Faulting Module:    $($selectedCrash.ModName) (Version: $($selectedCrash.ModVer))" -ForegroundColor Red
Write-Host "Exception Code:     $($selectedCrash.Code)" -ForegroundColor Cyan
Write-Host "Fault Offset:       $($selectedCrash.Offset)"
Write-Host "Executable Path:    $($selectedCrash.Path)"
Write-Host ""

Write-DiagLog "Crash Event Selected: App=$($selectedCrash.AppName), Module=$($selectedCrash.ModName), Code=$($selectedCrash.Code), Time=$($selectedCrash.TimeFormatted)"

# Exception Breakdown
Write-Host "[ROOT CAUSE ANALYSIS]:" -ForegroundColor Green
if ($knownExceptions.ContainsKey($selectedCrash.Code)) {
    Write-Host "  -> $($knownExceptions[$selectedCrash.Code])" -ForegroundColor White
} else {
    Write-Host "  -> Exception $($selectedCrash.Code): Unhandled application exception." -ForegroundColor Gray
}

# Module Specific Culprit Analysis
$mod = $selectedCrash.ModName
if ($mod -match "amdxx|atidx|amdkmdag") {
    Write-Host "  -> CULPRIT: AMD Radeon Graphics Driver ($mod)" -ForegroundColor Red
    Write-Host "     Recommendation: Lower in-game VRAM target scale (set to 70%), or reset AMD Adrenalin GPU overclock/tuning." -ForegroundColor Yellow
}
elseif ($mod -match "RTSSHooks|RTSS") {
    Write-Host "  -> CULPRIT: RivaTuner Statistics Server Overlay Hook ($mod)" -ForegroundColor Red
    Write-Host "     Recommendation: Set RTSS Application Detection Level to 'Low' or add game executable to RTSS exclusion list." -ForegroundColor Yellow
}
elseif ($mod -match "DiscordHook") {
    Write-Host "  -> CULPRIT: Discord In-Game Overlay Injection ($mod)" -ForegroundColor Red
    Write-Host "     Recommendation: Disable Discord In-Game Overlay in Discord Settings > Game Overlay." -ForegroundColor Yellow
}
elseif ($mod -match "cod\.exe|bootstrapper") {
    Write-Host "  -> CULPRIT: Call of Duty Engine Internal ($mod)" -ForegroundColor Yellow
    Write-Host "     Recommendation: Run 'Scan and Repair' in Battle.net, or clear the Call of Duty 'shadercache' directory." -ForegroundColor White
}
elseif ($mod -match "Wow\.exe|WowClassic|WowB") {
    Write-Host "  -> CULPRIT: World of Warcraft Engine ($mod)" -ForegroundColor Yellow
    Write-Host "     Recommendation: Disable outdated UI AddOns or reset the WTF / Cache folders." -ForegroundColor White
}
elseif ($mod -match "ntdll\.dll|kernel32\.dll|kernelbase\.dll") {
    Write-Host "  -> CULPRIT: Windows Memory / Core Subsystem ($mod)" -ForegroundColor Yellow
    Write-Host "     Recommendation: Often caused by memory instability (XMP/EXPO) or corrupt system files. Run 'sfc /scannow' or verify RAM stability." -ForegroundColor White
}
else {
    Write-Host "  -> CULPRIT: Application internal module or third-party dependency ($mod)." -ForegroundColor Yellow
}

# 2. Check for GPU Driver Timeouts near crash time
$gpuCrash = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Display'; Id=4101} -MaxEvents 3 -ErrorAction SilentlyContinue
if ($gpuCrash) {
    $lastGpu = $gpuCrash[0]
    $timeDiff = [math]::Abs(($selectedCrash.TimeCreated - $lastGpu.TimeCreated).TotalMinutes)
    if ($timeDiff -le 5) {
        Write-Host "`n[!] CORRELATED GPU DRIVER TIMEOUT (TDR):" -ForegroundColor Red
        Write-Host "    A GPU display timeout occurred within $([math]::Round($timeDiff, 1)) minutes of this crash!" -ForegroundColor Red
        Write-Host "    Message: $($lastGpu.Message)"
        Write-Host "    Insight: The graphics card became unresponsive, triggering Windows TDR recovery." -ForegroundColor Yellow
    }
}

# 3. Locate Game Raw Dump Files
$codDumpPath = "$env:LOCALAPPDATA\Activision\Call of Duty\crash_dump"
if (Test-Path $codDumpPath) {
    $latestDumps = Get-ChildItem -Path $codDumpPath -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    if ($latestDumps) {
        Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "GAME RAW CRASH DUMP FILES ON DISK:" -ForegroundColor Cyan
        Write-Host "Location: $codDumpPath" -ForegroundColor Gray
        foreach ($d in $latestDumps) {
            Write-Host ("  [{0}] {1} ({2:N1} KB)" -f $d.LastWriteTime.ToString("yyyy-MM-dd HH:mm"), $d.Name, ($d.Length / 1KB)) -ForegroundColor White
        }
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan

