# ============================================================================
# Game Booster PRO v2.0 - Module: 1% & 0.1% Lows Frame Telemetry
# 100% Anti-Cheat Safe (Zero DLL injection, pure out-of-process timing)
# Computes Average FPS, 1% Low FPS, 0.1% Low FPS, Frametime Pacing & Jitter
# ============================================================================

Add-Type @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class FrameStatsCollector {
    private List<double> frameTimes = new List<double>(5000);
    private Stopwatch sw = new Stopwatch();
    private long lastTicks = 0;
    private object lockObj = new object();
    private int stutterCount = 0;

    public void Start() {
        lock (lockObj) {
            frameTimes.Clear();
            stutterCount = 0;
            sw.Reset();
            sw.Start();
            lastTicks = sw.ElapsedTicks;
        }
    }

    public void RecordFrame(double frameTimeMs) {
        lock (lockObj) {
            if (frameTimeMs > 0 && frameTimeMs < 1000.0) {
                frameTimes.Add(frameTimeMs);
                if (frameTimes.Count > 10000) {
                    frameTimes.RemoveRange(0, 2000);
                }
                if (frameTimeMs > 25.0) { // Slower than 40 FPS / frame spike
                    stutterCount++;
                }
            }
        }
    }

    public void SampleTick() {
        lock (lockObj) {
            long currentTicks = sw.ElapsedTicks;
            long deltaTicks = currentTicks - lastTicks;
            lastTicks = currentTicks;

            double dtMs = (deltaTicks * 1000.0) / (double)Stopwatch.Frequency;
            if (dtMs > 0.5 && dtMs < 500.0) {
                frameTimes.Add(dtMs);
                if (frameTimes.Count > 10000) {
                    frameTimes.RemoveRange(0, 2000);
                }
                if (dtMs > 28.0) {
                    stutterCount++;
                }
            }
        }
    }

    public double[] GetMetrics() {
        lock (lockObj) {
            if (frameTimes.Count < 5) {
                return new double[] { 0, 0, 0, 0, 0, stutterCount, 100.0 };
            }

            List<double> sorted = new List<double>(frameTimes);
            sorted.Sort();

            // Average frame time
            double sum = 0;
            for (int i = 0; i < sorted.Count; i++) sum += sorted[i];
            double avgFrameTime = sum / sorted.Count;
            double avgFps = avgFrameTime > 0 ? (1000.0 / avgFrameTime) : 0;

            // 1% Low: 99th percentile slowest frame time
            int p99Index = (int)Math.Min(sorted.Count - 1, Math.Floor(sorted.Count * 0.99));
            double p99FrameTime = sorted[p99Index];
            double low1PercentFps = p99FrameTime > 0 ? (1000.0 / p99FrameTime) : 0;

            // 0.1% Low: 99.9th percentile slowest frame time
            int p999Index = (int)Math.Min(sorted.Count - 1, Math.Floor(sorted.Count * 0.999));
            double p999FrameTime = sorted[p999Index];
            double low01PercentFps = p999FrameTime > 0 ? (1000.0 / p999FrameTime) : 0;

            // Jitter / Standard Deviation
            double varianceSum = 0;
            for (int i = 0; i < sorted.Count; i++) {
                double diff = sorted[i] - avgFrameTime;
                varianceSum += diff * diff;
            }
            double jitterMs = Math.Sqrt(varianceSum / sorted.Count);

            // Smoothness percentage
            int smoothCount = 0;
            for (int i = 0; i < sorted.Count; i++) {
                if (Math.Abs(sorted[i] - avgFrameTime) < (avgFrameTime * 0.5)) {
                    smoothCount++;
                }
            }
            double smoothness = (double)smoothCount / sorted.Count * 100.0;

            return new double[] {
                Math.Round(avgFps, 1),
                Math.Round(low1PercentFps, 1),
                Math.Round(low01PercentFps, 1),
                Math.Round(avgFrameTime, 2),
                Math.Round(jitterMs, 2),
                stutterCount,
                Math.Round(smoothness, 1)
            };
        }
    }
}
"@ -ErrorAction SilentlyContinue

if (-not $script:GlobalFrameStats) {
    $script:GlobalFrameStats = [FrameStatsCollector]::new()
}

function Start-FrameTelemetrySession {
    param(
        [int]$TargetProcessId = 0,
        [string]$TargetProcessName = ""
    )
    $script:GlobalFrameStats.Start()
    $script:ActiveTelemetryGamePid = $TargetProcessId
    $script:ActiveTelemetryGameName = $TargetProcessName
    $script:TelemetryStartTime = Get-Date

    return [PSCustomObject]@{
        Status    = "Active"
        StartedAt = $script:TelemetryStartTime.ToString("yyyy-MM-dd HH:mm:ss")
        TargetPid = $TargetProcessId
        GameName  = $TargetProcessName
    }
}

function Record-FrameSample {
    param([double]$FrameTimeMs)
    if ($script:GlobalFrameStats) {
        $script:GlobalFrameStats.RecordFrame($FrameTimeMs)
    }
}

function Get-LiveFrameTelemetry {
    <#
    .SYNOPSIS
        Returns real-time 1% Lows, 0.1% Lows, Average FPS, and Stutter metrics.
    #>
    if (-not $script:GlobalFrameStats) {
        return [PSCustomObject]@{
            AvgFps           = 0
            Low1PercentFps   = 0
            Low01PercentFps  = 0
            AvgFrametimeMs   = 0
            JitterMs         = 0
            StutterCount     = 0
            SmoothnessScore  = 100.0
        }
    }

    $metrics = $script:GlobalFrameStats.GetMetrics()
    return [PSCustomObject]@{
        AvgFps           = $metrics[0]
        Low1PercentFps   = $metrics[1]
        Low01PercentFps  = $metrics[2]
        AvgFrametimeMs   = $metrics[3]
        JitterMs         = $metrics[4]
        StutterCount     = [int]$metrics[5]
        SmoothnessScore  = $metrics[6]
    }
}

function Stop-FrameTelemetrySession {
    $final = Get-LiveFrameTelemetry
    $duration = if ($script:TelemetryStartTime) { ((Get-Date) - $script:TelemetryStartTime).TotalMinutes } else { 0 }
    
    return [PSCustomObject]@{
        GameName        = $script:ActiveTelemetryGameName
        DurationMinutes = [math]::Round($duration, 1)
        AvgFps          = $final.AvgFps
        Low1PercentFps  = $final.Low1PercentFps
        Low01PercentFps = $final.Low01PercentFps
        AvgFrametimeMs  = $final.AvgFrametimeMs
        JitterMs        = $final.JitterMs
        StutterCount    = $final.StutterCount
        SmoothnessScore = $final.SmoothnessScore
    }
}
