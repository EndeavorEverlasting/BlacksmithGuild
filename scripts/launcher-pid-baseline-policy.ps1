# Testable policy helpers for S1->S2 PID baseline diff launcher selection.
# Mirrors the intent of UIAHelper.CaptureBaselineProcessIds / GetNewProcessIdsSinceBaseline.

function Get-TbgNewProcessIdsSinceBaseline {
    param(
        [int[]]$BaselineProcessIds,
        [object[]]$CurrentProcesses
    )

    $baseline = @{}
    foreach ($id in @($BaselineProcessIds)) { $baseline[[int]$id] = $true }

    $newIds = New-Object System.Collections.Generic.List[int]
    foreach ($proc in @($CurrentProcesses)) {
        if ($null -eq $proc) { continue }
        $processId = if ($proc.PSObject.Properties['Id']) { [int]$proc.Id } else { [int]$proc.pid }
        if (-not $baseline.ContainsKey($processId)) {
            $newIds.Add($processId) | Out-Null
        }
    }
    return @($newIds.ToArray())
}

function Test-TbgLauncherSelectionRespectsPidBaseline {
    param(
        [int[]]$BaselineProcessIds,
        [object[]]$CurrentProcesses,
        [ValidateSet('pid_delta', 'process_name', 'title_only', 'coordinate_fallback', 'coord_window_pick')]
        [string]$SelectionMethod
    )

    $newPids = Get-TbgNewProcessIdsSinceBaseline -BaselineProcessIds $BaselineProcessIds -CurrentProcesses $CurrentProcesses
    if (@($newPids).Count -eq 0) {
        return [pscustomobject][ordered]@{
            allowed = $true
            preferredMethod = $SelectionMethod
            newPids = @()
            reason = 'no_new_pid_fallback_permitted'
        }
    }

    if ($SelectionMethod -in @('title_only', 'coordinate_fallback', 'coord_window_pick')) {
        return [pscustomobject][ordered]@{
            allowed = $false
            preferredMethod = 'pid_delta'
            newPids = @($newPids)
            reason = 'new_pid_after_baseline_blocks_weak_fallback'
        }
    }

    return [pscustomobject][ordered]@{
        allowed = $true
        preferredMethod = 'pid_delta'
        newPids = @($newPids)
        reason = 'new_pid_after_baseline'
    }
}
