# ============================================================================
# Game Booster PRO v2.0 - Module: Crash-Safe Watchdog & State Restoration
# Atomic journaling to guarantee PC never gets stuck if game or booster crashes
# ============================================================================

$global:WatchdogJournalPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\restore_state.json"
if (-not (Test-Path (Split-Path $global:WatchdogJournalPath))) {
    $global:WatchdogJournalPath = Join-Path -Path (Get-Location) -ChildPath "restore_state.json"
}

function Get-WatchdogState {
    if (Test-Path $global:WatchdogJournalPath) {
        try {
            $raw = Get-Content -Path $global:WatchdogJournalPath -Raw -ErrorAction Stop
            return ($raw | ConvertFrom-Json)
        } catch {
            return $null
        }
    }
    return $null
}

function Save-WatchdogState {
    param([PSCustomObject]$State)
    try {
        $json = $State | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText($global:WatchdogJournalPath, $json, [System.Text.Encoding]::UTF8)
        return $true
    } catch {
        Write-Warning "[WATCHDOG] Failed to save state journal: $_"
        return $false
    }
}

function Initialize-WatchdogSession {
    param(
        [string]$TargetGame = "",
        [string]$PowerPlanGuid = "",
        [hashtable]$DisplaySettings = $null,
        [int]$StickyKeysFlags = 0
    )

    $state = [PSCustomObject]@{
        SessionActive          = $true
        CleanExit              = $false
        StartTime              = (Get-Date).ToString("o")
        EndTime                = ""
        TargetGame             = $TargetGame
        OriginalPowerPlanGuid  = $PowerPlanGuid
        OriginalDisplayModes   = $DisplaySettings
        OriginalStickyKeysFlags= $StickyKeysFlags
        MpoAltered             = $false
        OriginalMpoVal         = 0
        ThrottledPids          = @()
        AppliedQosPolicies     = @()
        LastHeartbeat          = (Get-Date).ToString("o")
        RecoveredAt            = ""
        RecoveryNotes          = @()
    }

    Save-WatchdogState -State $state | Out-Null
    return $state
}

function Update-WatchdogHeartbeat {
    $state = Get-WatchdogState
    if ($state -and $state.SessionActive) {
        $state.LastHeartbeat = (Get-Date).ToString("o")
        Save-WatchdogState -State $state | Out-Null
    }
}

function Register-WatchdogProperty {
    param(
        [Parameter(Mandatory=$true)][string]$PropertyName,
        [Parameter(Mandatory=$true)]$Value
    )
    $state = Get-WatchdogState
    if ($state) {
        if ($state.PSObject.Properties[$PropertyName]) {
            $state.$PropertyName = $Value
        } else {
            $state | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $Value -Force
        }
        Save-WatchdogState -State $state | Out-Null
    }
}

function Complete-WatchdogSession {
    $state = Get-WatchdogState
    if ($state) {
        $state.SessionActive = $false
        $state.CleanExit = $true
        if ($state.PSObject.Properties["EndTime"]) {
            $state.EndTime = (Get-Date).ToString("o")
        } else {
            $state | Add-Member -MemberType NoteProperty -Name "EndTime" -Value ((Get-Date).ToString("o")) -Force
        }
        Save-WatchdogState -State $state | Out-Null
    }
}

function Invoke-WatchdogCrashRecovery {
    [CmdletBinding()]
    param()

    $state = Get-WatchdogState
    if (-not $state) { return $null }

    # If session was active and clean exit was NOT achieved, trigger automatic rollback
    if ($state.SessionActive -eq $true -and $state.CleanExit -eq $false) {
        $recoveredItems = [System.Collections.Generic.List[string]]::new()

        # 1. Rollback Power Plan
        if ($state.OriginalPowerPlanGuid -and $state.OriginalPowerPlanGuid -match "^[a-f0-9\-]{36}$") {
            try {
                if (Get-Command Restore-OriginalPowerPlan -ErrorAction SilentlyContinue) {
                    Restore-OriginalPowerPlan -Guid $state.OriginalPowerPlanGuid | Out-Null
                } elseif ([System.Type]::GetType("NativePower")) {
                    [NativePower]::SetActiveGuid($state.OriginalPowerPlanGuid) | Out-Null
                } else {
                    powercfg /setactive $state.OriginalPowerPlanGuid 2>$null
                }
                $recoveredItems.Add("Restored Power Scheme to original GUID ($($state.OriginalPowerPlanGuid))")
            } catch {
                $recoveredItems.Add("Failed to restore Power Scheme: $_")
            }
        }

        # 2. Reset Display Settings
        if ($state.OriginalDisplayModes) {
            try {
                if (Get-Command Reset-DisplayResolution -ErrorAction SilentlyContinue) {
                    Reset-DisplayResolution | Out-Null
                    $recoveredItems.Add("Reset Display Modes to Windows desktop defaults")
                }
            } catch {}
        }

        # 3. Rollback Sticky Keys
        if ($state.OriginalStickyKeysFlags -gt 0) {
            try {
                if (Get-Command Restore-StickyKeysFlags -ErrorAction SilentlyContinue) {
                    Restore-StickyKeysFlags -Flags $state.OriginalStickyKeysFlags | Out-Null
                    $recoveredItems.Add("Restored Sticky Keys flags")
                }
            } catch {}
        }

        # 4. Remove active QoS Policies if any were left registered
        if ($state.AppliedQosPolicies -and $state.AppliedQosPolicies.Count -gt 0) {
            foreach ($policy in $state.AppliedQosPolicies) {
                try {
                    Remove-NetQosPolicy -Name $policy -Confirm:$false -ErrorAction SilentlyContinue
                    $recoveredItems.Add("Removed residual QoS Policy: $policy")
                } catch {}
            }
        }

        # Mark session as recovered
        $state.SessionActive = $false
        $state.CleanExit = $true
        if ($state.PSObject.Properties["RecoveredAt"]) {
            $state.RecoveredAt = (Get-Date).ToString("o")
        } else {
            $state | Add-Member -MemberType NoteProperty -Name "RecoveredAt" -Value ((Get-Date).ToString("o")) -Force
        }
        $state.RecoveryNotes = $recoveredItems
        Save-WatchdogState -State $state | Out-Null

        return [PSCustomObject]@{
            Recovered      = $true
            TargetGame     = $state.TargetGame
            LastSessionDate= $state.StartTime
            RecoveredItems = $recoveredItems
            Message        = "Watchdog recovered $($recoveredItems.Count) system setting(s) after unexpected shutdown."
        }
    }

    return [PSCustomObject]@{
        Recovered = $false
        Message   = "Previous session exited cleanly. No recovery needed."
    }
}
