# ============================================================================
# Game Booster v1.0 - Diagnostic & System Crash Reporter
# Automatically aggregates System Reboots (Event 41/1001), App Crashes,
# and Game Booster logs into a single shareable report.
# ============================================================================

[CmdletBinding()]
param()

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$RootDir = if (Test-Path (Join-Path $ScriptDir "config.json")) { $ScriptDir } else { Split-Path -Parent $ScriptDir }

$desktop = [Environment]::GetFolderPath('Desktop')
$reportPath = Join-Path $desktop "GameBooster_Debug_Report.txt"

$report = [System.Collections.Generic.List[string]]::new()
function Add-Line($str = "") { $report.Add($str) }

Add-Line "================================================================================"
Add-Line "               GAME BOOSTER v1.0 PRO - SYSTEM & DEBUG REPORT                   "
Add-Line "================================================================================"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "Host Name: $env:COMPUTERNAME"
Add-Line "User:      $env:USERNAME"
Add-Line ""

# 1. OS & HARDWARE INFO
Add-Line "--------------------------------------------------------------------------------"
Add-Line "[1] OPERATING SYSTEM & HARDWARE TOPOLOGY"
Add-Line "--------------------------------------------------------------------------------"
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)

    Add-Line "OS Name:       $($os.Caption) ($($os.Version) - Build $($os.BuildNumber))"
    Add-Line "OS Arch:       $($os.OSArchitecture)"
    Add-Line "System Model:  $($cs.Manufacturer) $($cs.Model)"
    Add-Line "CPU:           $($cpu.Name) ($($cpu.NumberOfCores)C / $($cpu.NumberOfLogicalProcessors)T)"
    Add-Line "Total RAM:     $([math]::Round($os.TotalVisibleMemorySize / 1MB, 2)) GB"
    foreach ($g in $gpus) {
        Add-Line "GPU:           $($g.Name) (Driver: $($g.DriverVersion))"
    }
} catch {
    Add-Line "Error querying OS/Hardware: $_"
}
Add-Line ""

# 2. SYSTEM REBOOT & BSOD EVENTS (Kernel-Power Event 41 / BugCheck Event 1001)
Add-Line "--------------------------------------------------------------------------------"
Add-Line "[2] RECENT UNEXPECTED REBOOTS & BSOD CRASHES (System Event 41, 1001, 6008)"
Add-Line "--------------------------------------------------------------------------------"
try {
    $rebootEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,1001,6008} -MaxEvents 8 -ErrorAction SilentlyContinue)
    if ($rebootEvents.Count -eq 0) {
        Add-Line "No unexpected reboots or BSOD events recorded recently."
    } else {
        foreach ($ev in $rebootEvents) {
            Add-Line "--------------------------------------------------"
            Add-Line "Timestamp:    $($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))"
            Add-Line "Event ID:     $($ev.Id)"
            Add-Line "Provider:     $($ev.ProviderName)"
            $cleanMsg = ($ev.Message -split "`r?`n" | ForEach-Object { "  " + $_.Trim() }) -join "`r`n"
            Add-Line "Details:`r`n$cleanMsg"
        }
    }
} catch {
    Add-Line "Error reading System Event Log: $_"
}
Add-Line ""

# 3. RECENT MINIDUMPS
Add-Line "--------------------------------------------------------------------------------"
Add-Line "[3] CRASH MINIDUMPS (C:\Windows\Minidump)"
Add-Line "--------------------------------------------------------------------------------"
try {
    $minidumps = @(Get-ChildItem -Path "C:\Windows\Minidump" -Filter "*.dmp" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5)
    if ($minidumps.Count -eq 0) {
        Add-Line "No minidump (.dmp) files found in C:\Windows\Minidump."
    } else {
        foreach ($d in $minidumps) {
            Add-Line ("  {0:yyyy-MM-dd HH:mm:ss}  {1,10} KB  {2}" -f $d.LastWriteTime, [math]::Round($d.Length / 1KB, 0), $d.FullName)
        }
    }
} catch {
    Add-Line "Could not access C:\Windows\Minidump: $_"
}
Add-Line ""

# 4. RECENT APPLICATION ERRORS (Event 1000)
Add-Line "--------------------------------------------------------------------------------"
Add-Line "[4] RECENT APPLICATION CRASH EVENTS (Application Event 1000)"
Add-Line "--------------------------------------------------------------------------------"
try {
    $appEvents = @(Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; Id=1000} -MaxEvents 6 -ErrorAction SilentlyContinue)
    if ($appEvents.Count -eq 0) {
        Add-Line "No application crash events recorded recently."
    } else {
        foreach ($ev in $appEvents) {
            $msg = $ev.Message
            $appName = if ($msg -match "Faulting application name:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
            $modName = if ($msg -match "Faulting module name:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
            $code    = if ($msg -match "Exception code:\s*([^\r\n,]+)") { $matches[1].Trim() } else { "Unknown" }
            Add-Line ("  [{0:yyyy-MM-dd HH:mm:ss}] App: {1,-25} | Module: {2,-20} | Code: {3}" -f $ev.TimeCreated, $appName, $modName, $code)
        }
    }
} catch {
    Add-Line "Error querying application events: $_"
}
Add-Line ""

# 5. GAME BOOSTER LAST SESSION (Apps closed right before Game Mode reboot)
Add-Line "--------------------------------------------------------------------------------"
Add-Line "[5] GAME BOOSTER LAST ACTIVE SESSION (Apps Closed in Game Mode)"
Add-Line "--------------------------------------------------------------------------------"
$sessionFile = Join-Path $RootDir "last_session.json"
if (Test-Path $sessionFile) {
    try {
        $sContent = Get-Content -Raw -Path $sessionFile
        Add-Line $sContent
    } catch {
        Add-Line "Error reading last_session.json: $_"
    }
} else {
    Add-Line "last_session.json not found (no Game Mode closure executed in current install directory)."
}
Add-Line ""

# 6. GAME BOOSTER LOG (Last 50 entries)
Add-Line "--------------------------------------------------------------------------------"
Add-Line "[6] GAME BOOSTER APPLICATION LOG (Last 50 lines)"
Add-Line "--------------------------------------------------------------------------------"
$logFile = Join-Path $RootDir "gamebooster.log"
if (Test-Path $logFile) {
    try {
        $logLines = @(Get-Content -Path $logFile -Tail 50 -ErrorAction SilentlyContinue)
        foreach ($l in $logLines) { Add-Line "  $l" }
    } catch {
        Add-Line "Error reading gamebooster.log: $_"
    }
} else {
    Add-Line "gamebooster.log not found."
}
Add-Line ""

Add-Line "================================================================================"
Add-Line "                              END OF REPORT                                     "
Add-Line "================================================================================"

# Write out with UTF-8 BOM
[System.IO.File]::WriteAllLines($reportPath, $report, [System.Text.Encoding]::UTF8)

# Open in Notepad
try {
    Start-Process "notepad.exe" -ArgumentList "`"$reportPath`""
} catch {}

Write-Host "Debug Report generated successfully at:`n$reportPath" -ForegroundColor Green
return $reportPath
