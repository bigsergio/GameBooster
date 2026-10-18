# ============================================================================
# Live Gaming Latency, Jitter & Packet Loss Monitor
# Continuous RTT, Jitter, and Packet Loss Tracking for Call of Duty
# ============================================================================

$Host.UI.RawUI.WindowTitle = "Live Gaming Ping & Jitter Telemetry"

# Determine Gateway
$gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
if (-not $gw) { $gw = "192.168.86.1" }

$targetServer = "1.1.1.1"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "       LIVE GAMING LATENCY, JITTER & PACKET LOSS TELEMETRY        " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Router Gateway: $gw | Primary DNS: $targetServer`n" -ForegroundColor Gray

$pingGw = New-Object System.Net.NetworkInformation.Ping
$pingTgt = New-Object System.Net.NetworkInformation.Ping

$history = @()
$sent = 0
$lost = 0

while ($true) {
    $sent++
    $gwMs = -1
    $tgtMs = -1

    try {
        $replyGw = $pingGw.Send($gw, 400)
        if ($replyGw.Status -eq 'Success') { $gwMs = $replyGw.RoundtripTime }
    } catch {}

    try {
        $replyTgt = $pingTgt.Send($targetServer, 800)
        if ($replyTgt.Status -eq 'Success') {
            $tgtMs = $replyTgt.RoundtripTime
            $history += $tgtMs
            if ($history.Count -gt 25) { $history = $history[1..25] }
        } else {
            $lost++
        }
    } catch { $lost++ }

    $avg = if ($history.Count -gt 0) { [math]::Round(($history | Measure-Object -Average).Average, 1) } else { 0 }
    $min = if ($history.Count -gt 0) { ($history | Measure-Object -Minimum).Minimum } else { 0 }
    $max = if ($history.Count -gt 0) { ($history | Measure-Object -Maximum).Maximum } else { 0 }
    $jitter = $max - $min
    $lossPct = [math]::Round(($lost / $sent) * 100, 1)

    $timeStr = (Get-Date).ToString("HH:mm:ss")
    $statusColor = if ($tgtMs -ge 0 -and $tgtMs -lt 30) { "Green" } elseif ($tgtMs -lt 65) { "Yellow" } else { "Red" }
    $lossColor   = if ($lossPct -eq 0) { "Green" } else { "Red" }
    $gwColor     = if ($gwMs -ge 0 -and $gwMs -le 2) { "Green" } else { "Yellow" }

    Write-Host -NoNewline "[$timeStr] " -ForegroundColor DarkGray
    Write-Host -NoNewline "Router: " -ForegroundColor Gray
    Write-Host -NoNewline "$($gwMs)ms " -ForegroundColor $gwColor
    Write-Host -NoNewline "| Ping: " -ForegroundColor Gray
    Write-Host -NoNewline "$($tgtMs)ms " -ForegroundColor $statusColor
    Write-Host -NoNewline "| Jitter: " -ForegroundColor Gray
    Write-Host -NoNewline "+/-$($jitter)ms " -ForegroundColor $(if ($jitter -lt 15) { "Green" } else { "Yellow" })
    Write-Host -NoNewline "| Loss: " -ForegroundColor Gray
    Write-Host "$($lossPct)%" -ForegroundColor $lossColor

    Start-Sleep -Milliseconds 1000
}

