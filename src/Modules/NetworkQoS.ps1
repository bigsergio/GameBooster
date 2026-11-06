# ============================================================================
# Game Booster PRO v2.0 - Module: Dynamic Network QoS & Packet Prioritization
# Tags active gaming UDP/TCP packets with DSCP 46 (Expedited Forwarding)
# Prioritizes gaming packets in OS network stack, NIC buffers & router queues
# ============================================================================

function Get-GamingQosPolicies {
    try {
        $policies = Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "GameBooster_QoS*" }
        return @($policies)
    } catch {
        return @()
    }
}

function Add-GamingQosPolicy {
    param(
        [Parameter(Mandatory=$true)][string]$GameExeOrPath,
        [int]$DscpValue = 46,
        [int]$Priority8021 = 5
    )

    $exeName = [System.IO.Path]::GetFileName($GameExeOrPath)
    if ($exeName -notmatch "\.exe$") { $exeName = "$exeName.exe" }
    $cleanName = ($exeName -replace '\.exe$', '') -replace '[^a-zA-Z0-9_]', '_'
    $policyName = "GameBooster_QoS_$cleanName"

    try {
        # Check if already exists
        $existing = Get-NetQosPolicy -Name $policyName -ErrorAction SilentlyContinue
        if ($existing) {
            Remove-NetQosPolicy -Name $policyName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }

        # Create new QoS rule targeting executable
        $newPolicy = New-NetQosPolicy -Name $policyName `
                                      -AppPathNameMatchCondition $exeName `
                                      -DSCPAction $DscpValue `
                                      -PriorityValue8021Action $Priority8021 `
                                      -ErrorAction Stop

        # Register with Watchdog for crash rollback
        if (Get-Command Register-WatchdogProperty -ErrorAction SilentlyContinue) {
            $state = Get-WatchdogState
            $policies = if ($state -and $state.AppliedQosPolicies) { [System.Collections.Generic.List[string]]::new($state.AppliedQosPolicies) } else { [System.Collections.Generic.List[string]]::new() }
            if (-not $policies.Contains($policyName)) {
                $policies.Add($policyName)
                Register-WatchdogProperty -PropertyName "AppliedQosPolicies" -Value @($policies)
            }
        }

        return [PSCustomObject]@{
            Success      = $true
            PolicyName   = $policyName
            TargetExe    = $exeName
            DscpValue    = $DscpValue
            Priority8021 = $Priority8021
            Message      = "Created QoS Expedited Forwarding policy (DSCP $DscpValue) for $exeName."
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.Exception.Message
            Message = "Failed to create QoS policy: $($_.Exception.Message)"
        }
    }
}

function Remove-GamingQosPolicy {
    param(
        [Parameter(Mandatory=$true)][string]$GameExeOrPath
    )

    $exeName = [System.IO.Path]::GetFileName($GameExeOrPath)
    $cleanName = ($exeName -replace '\.exe$', '') -replace '[^a-zA-Z0-9_]', '_'
    $policyName = "GameBooster_QoS_$cleanName"

    try {
        Remove-NetQosPolicy -Name $policyName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        return [PSCustomObject]@{
            Success    = $true
            PolicyName = $policyName
            Message    = "Removed QoS policy $policyName."
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}

function Clear-AllGamingQosPolicies {
    $removedCount = 0
    $policies = Get-GamingQosPolicies
    foreach ($p in $policies) {
        try {
            Remove-NetQosPolicy -Name $p.Name -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            $removedCount++
        } catch {}
    }

    return [PSCustomObject]@{
        Success      = $true
        RemovedCount = $removedCount
        Message      = "Cleared $removedCount active Game Booster QoS policies."
    }
}
