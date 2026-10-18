# ============================================================================
# Game Booster v1.0 - Module: Gaming Server Latency Radar
# Asynchronous multi-target ping grid for Valve, Riot, Blizzard, AWS, and DNS
# ============================================================================

function Get-LocalGatewayIp {
    try {
        $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
        if ($gw) { return $gw }
    } catch {}
    return "192.168.1.1"
}

function Get-GamingRadarEndpoints {
    $gw = Get-LocalGatewayIp
    return @(
        [PSCustomObject]@{ Cluster = "Local Gateway (Router)"; Host = $gw; Region = "LAN"; Type = "Router" },
        [PSCustomObject]@{ Cluster = "Cloudflare Primary"; Host = "1.1.1.1"; Region = "Global"; Type = "DNS" },
        [PSCustomObject]@{ Cluster = "Google Primary"; Host = "8.8.8.8"; Region = "Global"; Type = "DNS" },
        [PSCustomObject]@{ Cluster = "Valve / CS2 EU Central"; Host = "155.133.243.1"; Region = "Frankfurt"; Type = "Valve" },
        [PSCustomObject]@{ Cluster = "Valve / CS2 EU East"; Host = "155.133.238.1"; Region = "Vienna"; Type = "Valve" },
        [PSCustomObject]@{ Cluster = "Valve / CS2 EU West"; Host = "155.133.248.1"; Region = "London"; Type = "Valve" },
        [PSCustomObject]@{ Cluster = "Riot Games EU Central"; Host = "104.160.143.212"; Region = "Frankfurt"; Type = "Riot" },
        [PSCustomObject]@{ Cluster = "Riot Games EU West"; Host = "104.160.141.3"; Region = "Paris"; Type = "Riot" },
        [PSCustomObject]@{ Cluster = "AWS Europe Central"; Host = "52.95.2.0"; Region = "Frankfurt"; Type = "AWS" }
    )
}

function Test-GamingRadarPing {
    param([int]$TimeoutMs = 600)
    $endpoints = Get-GamingRadarEndpoints
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $tasks = @()

    foreach ($ep in $endpoints) {
        $p = New-Object System.Net.NetworkInformation.Ping
        $task = $p.SendPingAsync($ep.Host, $TimeoutMs)
        $tasks += [PSCustomObject]@{
            Endpoint = $ep
            PingObj  = $p
            Task     = $task
        }
    }

    foreach ($t in $tasks) {
        try {
            $reply = $t.Task.GetAwaiter().GetResult()
            $ms = if ($reply.Status -eq "Success") { $reply.RoundtripTime } else { -1 }
            $statusStr = if ($ms -ge 0) { "${ms} ms" } else { "TIMEOUT" }
            $quality = if ($ms -lt 0) { "OFFLINE" } elseif ($ms -le 25) { "EXCELLENT" } elseif ($ms -le 55) { "GOOD" } else { "HIGH" }

            $results.Add([PSCustomObject]@{
                Cluster  = $t.Endpoint.Cluster
                Region   = $t.Endpoint.Region
                Host     = $t.Endpoint.Host
                PingMs   = $ms
                Latency  = $statusStr
                Quality  = $quality
            })
        } catch {
            $results.Add([PSCustomObject]@{
                Cluster  = $t.Endpoint.Cluster
                Region   = $t.Endpoint.Region
                Host     = $t.Endpoint.Host
                PingMs   = -1
                Latency  = "FAILED"
                Quality  = "OFFLINE"
            })
        } finally {
            $t.PingObj.Dispose()
        }
    }

    return @($results)
}

