# ============================================================================
# Game Booster v1.2.2 - Module: Gaming Server Latency Radar
# Asynchronous multi-target ping grid for Valve, Riot, Blizzard, AWS, and DNS
# ============================================================================

function Get-LocalGatewayIp {
    try {
        $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
        if ($gw -and $gw -ne "0.0.0.0") { return $gw }
    } catch {}
    return "192.168.1.1"
}

function Get-GamingRadarEndpoints {
    $gw = Get-LocalGatewayIp
    return @(
        [PSCustomObject]@{ Cluster = "Local Gateway (Router)"; Host = $gw; Region = "LAN"; Type = "Router" },
        [PSCustomObject]@{ Cluster = "Cloudflare Primary"; Host = "1.1.1.1"; Region = "Global"; Type = "DNS" },
        [PSCustomObject]@{ Cluster = "Google Primary"; Host = "8.8.8.8"; Region = "Global"; Type = "DNS" },
        [PSCustomObject]@{ Cluster = "Valve / CS2 EU Central"; Host = "162.254.197.1"; Region = "Frankfurt"; Type = "Valve" },
        [PSCustomObject]@{ Cluster = "Valve / CS2 EU West"; Host = "155.133.248.1"; Region = "London"; Type = "Valve" },
        [PSCustomObject]@{ Cluster = "Valve / CS2 EU North"; Host = "155.133.252.1"; Region = "Stockholm"; Type = "Valve" },
        [PSCustomObject]@{ Cluster = "Blizzard / Battle.net EU"; Host = "37.244.54.10"; Region = "Paris"; Type = "Blizzard" },
        [PSCustomObject]@{ Cluster = "AWS Europe Central"; Host = "dynamodb.eu-central-1.amazonaws.com"; Region = "Frankfurt"; Type = "AWS" },
        [PSCustomObject]@{ Cluster = "AWS Europe West"; Host = "dynamodb.eu-west-1.amazonaws.com"; Region = "Ireland"; Type = "AWS" },
        [PSCustomObject]@{ Cluster = "Riot Games EU Central"; Host = "104.160.143.212"; Region = "Frankfurt"; Type = "Riot" }
    )
}

function Test-GamingRadarPing {
    param([int]$TimeoutMs = 600)
    $endpoints = Get-GamingRadarEndpoints
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $tasks = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($ep in $endpoints) {
        try {
            $p = New-Object System.Net.NetworkInformation.Ping
            $task = $p.SendPingAsync($ep.Host, $TimeoutMs)
            $tasks.Add([PSCustomObject]@{
                Endpoint = $ep
                PingObj  = $p
                Task     = $task
            })
        } catch {
            $results.Add([PSCustomObject]@{
                Cluster  = $ep.Cluster
                Region   = $ep.Region
                Host     = $ep.Host
                PingMs   = -1
                Latency  = "FAILED"
                Quality  = "OFFLINE"
            })
        }
    }

    foreach ($t in $tasks) {
        try {
            if ($t.Task.Wait($TimeoutMs + 300)) {
                $reply = $t.Task.Result
                $ms = if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { [int]$reply.RoundtripTime } else { -1 }
            } else {
                $ms = -1
            }
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
            try { $t.PingObj.Dispose() } catch {}
        }
    }

    return @($results)
}


function Test-SingleRadarPing {
    param(
        [string]$HostName,
        [int]$TimeoutMs = 800
    )
    if ([string]::IsNullOrWhiteSpace($HostName)) {
        return [PSCustomObject]@{
            PingMs  = -1
            Latency = "INVALID"
            Quality = "OFFLINE"
        }
    }
    try {
        $p = New-Object System.Net.NetworkInformation.Ping
        $reply = $p.Send($HostName, $TimeoutMs)
        $ms = if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { [int]$reply.RoundtripTime } else { -1 }
        $statusStr = if ($ms -ge 0) { "${ms} ms" } else { "TIMEOUT" }
        $quality = if ($ms -lt 0) { "OFFLINE" } elseif ($ms -le 25) { "EXCELLENT" } elseif ($ms -le 55) { "GOOD" } else { "HIGH" }
        try { $p.Dispose() } catch {}
        return [PSCustomObject]@{
            PingMs  = $ms
            Latency = $statusStr
            Quality = $quality
        }
    } catch {
        return [PSCustomObject]@{
            PingMs  = -1
            Latency = "FAILED"
            Quality = "OFFLINE"
        }
    }
}
