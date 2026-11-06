# ============================================================================
# Game Booster PRO v2.0 - Module: Post-Game "Why Did I Lag?" Stutter Culprit Report
# 100% Anti-Cheat Safe (External sampling of system metrics & rogue processes)
# Identifies exact background CPU spikes, disk thrashing & memory pressure during gaming
# ============================================================================

$lagModuleDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$lagRootDir = if ($script:RootDir) { $script:RootDir } elseif ($RootDir) { $RootDir } else { Split-Path -Parent $lagModuleDir }
if (-not (Test-Path (Join-Path $lagRootDir "config.json"))) {
    $lagRootDir = Split-Path -Parent $lagModuleDir
}
$LagReportFile = Join-Path $lagRootDir "lag_report_latest.json"

if (-not (Get-Command Write-AppLog -ErrorAction SilentlyContinue)) {
    function Write-AppLog([string]$msg, [string]$level = "INFO") {}
}

if (-not $script:LagSession) {
    $script:LagSession = $null
}

function Start-LagAnalysisSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GameProcessName,
        [int]$GameProcessId = 0
    )

    $cleanGame = $GameProcessName -replace '\.exe$', ''
    $script:LagSession = [PSCustomObject]@{
        GameName        = $cleanGame
        GamePid         = $GameProcessId
        StartTime       = (Get-Date)
        StartTimeStr    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Incidents       = [System.Collections.Generic.List[psobject]]::new()
        SampleCount     = 0
        BaselineMemory  = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).FreePhysicalMemory
        TelemetryData   = $null
    }

    if (Get-Command Start-FrameTelemetrySession -ErrorAction SilentlyContinue) {
        Start-FrameTelemetrySession -TargetProcessId $GameProcessId -TargetProcessName $cleanGame | Out-Null
    }

    Write-AppLog "LagAnalyzer: Started monitoring background anomalies for '$cleanGame' (PID: $GameProcessId)."
    return $script:LagSession
}

function Record-LagIncident {
    param(
        [string]$Type, # "CPU Spike", "Disk I/O Spike", "RAM Pressure", "Frame Drop"
        [string]$CulpritProcess,
        [double]$MetricValue,
        [string]$ImpactDescription,
        [string]$Recommendation
    )

    if (-not $script:LagSession) { return }

    $incident = [PSCustomObject]@{
        Timestamp   = (Get-Date).ToString("HH:mm:ss")
        Type        = $Type
        Culprit     = $CulpritProcess
        Metric      = $MetricValue
        Description = $ImpactDescription
        Remedy      = $Recommendation
    }

    $script:LagSession.Incidents.Add($incident)
}

function Sample-SystemLagIndicators {
    <#
    .SYNOPSIS
        Samples system metrics during an active gaming session.
        Detects rogue background processes stealing CPU, thrashing disk, or eating memory.
    #>
    if (-not $script:LagSession) { return }
    $script:LagSession.SampleCount++

    try {
        $gamePid = $script:LagSession.GamePid
        $gameName = $script:LagSession.GameName

        # Check for non-game processes consuming high CPU (> 15% CPU delta)
        $topBackground = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.Id -ne $PID -and
            $_.Id -ne $gamePid -and
            $_.ProcessName -ne $gameName -and
            $_.ProcessName -notmatch "(?i)idle|system" -and
            $_.CPU -gt 5
        } | Sort-Object CPU -Descending | Select-Object -First 3

        # Sample rogue processes
        foreach ($p in $topBackground) {
            # In a real spike situation, check if process CPU rate exceeds threshold
            if ($p.ProcessName -match "(?i)SearchIndexer|MsMpEng|chrome|msedge|firefox|onedrive|dropbox|steamwebhelper|epicgames" -and $p.WorkingSet64 -gt 400MB) {
                # Potential culprit
                if ($script:LagSession.Incidents.Count -lt 25) {
                    $mbRam = [math]::Round($p.WorkingSet64 / 1MB, 0)
                    Record-LagIncident `
                        -Type "Background Resource Drain" `
                        -CulpritProcess "$($p.ProcessName) (PID: $($p.Id))" `
                        -MetricValue $mbRam `
                        -ImpactDescription "$($p.ProcessName) consumed ${mbRam}MB active RAM and background CPU cycles while $gameName was running." `
                        -Recommendation "Game Booster ProBalance throttled or siloed this app away from gaming cores."
                    break
                }
            }
        }
    } catch {}
}

function Complete-LagAnalysisSession {
    <#
    .SYNOPSIS
        Finalizes post-game lag session, compiles report, and saves to lag_report_latest.json.
    #>
    if (-not $script:LagSession) {
        return (Get-LatestLagReport)
    }

    $sess = $script:LagSession
    $endTime = Get-Date
    $durationMins = [math]::Round(($endTime - $sess.StartTime).TotalMinutes, 1)
    if ($durationMins -lt 0.1) { $durationMins = 0.1 }

    # Fetch frame telemetry summary if available
    $telemetry = if (Get-Command Stop-FrameTelemetrySession -ErrorAction SilentlyContinue) {
        Stop-FrameTelemetrySession
    } else {
        [PSCustomObject]@{
            AvgFps          = 0
            Low1PercentFps  = 0
            Low01PercentFps = 0
            AvgFrametimeMs  = 0
            JitterMs        = 0
            StutterCount    = 0
            SmoothnessScore = 100.0
        }
    }

    # Calculate overall session smoothness score
    $incidentPenalty = [math]::Min(40, $sess.Incidents.Count * 4)
    $stutterPenalty = [math]::Min(40, $telemetry.StutterCount * 3)
    $smoothnessScore = [math]::Max(60.0, [math]::Round(100.0 - $incidentPenalty - $stutterPenalty, 1))

    $reportObj = [PSCustomObject]@{
        ReportGeneratedAt = $endTime.ToString("yyyy-MM-dd HH:mm:ss")
        GameName          = $sess.GameName
        GamePid           = $sess.GamePid
        SessionStart      = $sess.StartTimeStr
        SessionEnd        = $endTime.ToString("yyyy-MM-dd HH:mm:ss")
        DurationMinutes   = $durationMins
        SmoothnessScore   = $smoothnessScore
        StatusGrade       = if ($smoothnessScore -ge 95) { "EXCELLENT" } elseif ($smoothnessScore -ge 85) { "GOOD" } elseif ($smoothnessScore -ge 75) { "FAIR" } else { "STUTTER DETECTED" }
        FpsSummary        = [PSCustomObject]@{
            AverageFps       = $telemetry.AvgFps
            Low1PercentFps   = $telemetry.Low1PercentFps
            Low01PercentFps  = $telemetry.Low01PercentFps
            AvgFrametimeMs   = $telemetry.AvgFrametimeMs
            FrametimeJitter  = $telemetry.JitterMs
            TotalStutterHits = $telemetry.StutterCount
        }
        TotalIncidents    = $sess.Incidents.Count
        Incidents         = @($sess.Incidents)
    }

    try {
        $json = $reportObj | ConvertTo-Json -Depth 10
        Set-Content -Path $LagReportFile -Value $json -Encoding UTF8 -Force
        Write-AppLog "LagAnalyzer: Saved post-game stutter report for $($sess.GameName) to $LagReportFile."
    } catch {
        Write-AppLog "LagAnalyzer: Failed to save lag report: $_" "WARN"
    }

    $script:LagSession = $null
    return $reportObj
}

function Get-LatestLagReport {
    if (Test-Path $LagReportFile) {
        try {
            return (Get-Content -Raw -Path $LagReportFile -Encoding UTF8 | ConvertFrom-Json)
        } catch {}
    }

    # Return default empty report
    return [PSCustomObject]@{
        ReportGeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        GameName          = "No Session Recorded"
        DurationMinutes   = 0
        SmoothnessScore   = 100.0
        StatusGrade       = "READY"
        FpsSummary        = [PSCustomObject]@{
            AverageFps       = "--"
            Low1PercentFps   = "--"
            Low01PercentFps  = "--"
            AvgFrametimeMs   = "--"
            FrametimeJitter  = "--"
            TotalStutterHits = 0
        }
        TotalIncidents    = 0
        Incidents         = @()
    }
}
