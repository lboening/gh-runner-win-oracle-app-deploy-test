# Manage-CleanupTask.ps1
# Management utility for the Azure resource group cleanup scheduled task

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Install", "Uninstall", "Enable", "Disable", "Status", "Test", "RunNow")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "AzureResourceGroupCleanup",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Import logging utility
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Show-TaskStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )
    
    try {
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        
        Write-Log "=== Task Status ===" -Level "Info"
        Write-Log "Name: $($Task.TaskName)" -Level "Info"
        Write-Log "State: $($Task.State)" -Level "Info"
        Write-Log "Description: $($Task.Description)" -Level "Info"
        Write-Log "Last Run Time: $($TaskInfo.LastRunTime)" -Level "Info"
        Write-Log "Next Run Time: $($TaskInfo.NextRunTime)" -Level "Info"
        Write-Log "Last Task Result: $($TaskInfo.LastTaskResult)" -Level "Info"
        Write-Log "Number of Missed Runs: $($TaskInfo.NumberOfMissedRuns)" -Level "Info"
        
        # Show trigger details
        $Triggers = $Task.Triggers
        Write-Log "=== Triggers ===" -Level "Info"
        foreach ($Trigger in $Triggers) {
            Write-Log "Type: $($Trigger.CimClass.CimClassName)" -Level "Info"
            if ($Trigger.StartBoundary) {
                Write-Log "Start Time: $($Trigger.StartBoundary)" -Level "Info"
            }
        }
        
        # Show action details
        $Actions = $Task.Actions
        Write-Log "=== Actions ===" -Level "Info"
        foreach ($Action in $Actions) {
            Write-Log "Execute: $($Action.Execute)" -Level "Info"
            Write-Log "Arguments: $($Action.Arguments)" -Level "Info"
        }
        
        return $true
    }
    catch {
        Write-Log "Task '$TaskName' not found or error occurred: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Install-CleanupTask {
    try {
        Write-Log "Installing cleanup scheduled task..." -Level "Info"
        
        $SetupScript = "$PSScriptRoot\Setup-ScheduledCleanup.ps1"
        if (!(Test-Path $SetupScript)) {
            throw "Setup script not found: $SetupScript"
        }
        
        $Arguments = @()
        if ($ResourceGroupName) { $Arguments += "-ResourceGroupName `"$ResourceGroupName`"" }
        if ($SubscriptionId) { $Arguments += "-SubscriptionId `"$SubscriptionId`"" }
        if ($DryRun) { $Arguments += "-DryRun" }
        
        $ArgumentString = $Arguments -join " "
        
        & $SetupScript @Arguments
        
        Write-Log "Installation completed" -Level "Success"
        return $true
    }
    catch {
        Write-Log "Installation failed: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Uninstall-CleanupTask {
    try {
        Write-Log "Uninstalling cleanup scheduled task..." -Level "Info"
        
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($Task) {
            if ($DryRun) {
                Write-Log "DRY RUN: Would remove scheduled task '$TaskName'" -Level "Warning"
            }
            else {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-Log "Task '$TaskName' removed successfully" -Level "Success"
            }
        }
        else {
            Write-Log "Task '$TaskName' not found" -Level "Warning"
        }
        
        return $true
    }
    catch {
        Write-Log "Uninstallation failed: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Enable-CleanupTask {
    try {
        if ($DryRun) {
            Write-Log "DRY RUN: Would enable scheduled task '$TaskName'" -Level "Warning"
        }
        else {
            Enable-ScheduledTask -TaskName $TaskName
            Write-Log "Task '$TaskName' enabled successfully" -Level "Success"
        }
        return $true
    }
    catch {
        Write-Log "Failed to enable task: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Disable-CleanupTask {
    try {
        if ($DryRun) {
            Write-Log "DRY RUN: Would disable scheduled task '$TaskName'" -Level "Warning"
        }
        else {
            Disable-ScheduledTask -TaskName $TaskName
            Write-Log "Task '$TaskName' disabled successfully" -Level "Success"
        }
        return $true
    }
    catch {
        Write-Log "Failed to disable task: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-CleanupTask {
    try {
        Write-Log "Testing cleanup task (dry run)..." -Level "Info"
        
        $CleanupScript = "$PSScriptRoot\Remove-AzureResourceGroup.ps1"
        if (!(Test-Path $CleanupScript)) {
            throw "Cleanup script not found: $CleanupScript"
        }
        
        # Run the cleanup script in dry run mode
        & $CleanupScript -DryRun -Verbose
        
        Write-Log "Test completed" -Level "Success"
        return $true
    }
    catch {
        Write-Log "Test failed: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Start-CleanupTask {
    try {
        if ($DryRun) {
            Write-Log "DRY RUN: Would start scheduled task '$TaskName' immediately" -Level "Warning"
        }
        else {
            Write-Log "Starting task '$TaskName' immediately..." -Level "Warning"
            Write-Log "WARNING: This will actually delete your Azure resource group!" -Level "Error"
            
            $Confirmation = Read-Host "Are you sure you want to proceed? Type 'YES' to confirm"
            if ($Confirmation -eq "YES") {
                Start-ScheduledTask -TaskName $TaskName
                Write-Log "Task started. Check Task Scheduler for progress." -Level "Success"
            }
            else {
                Write-Log "Operation cancelled by user" -Level "Info"
            }
        }
        return $true
    }
    catch {
        Write-Log "Failed to start task: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Main execution
try {
    Write-Log "=== Azure Cleanup Task Manager ===" -Level "Info"
    Write-Log "Action: $Action" -Level "Info"
    Write-Log "Task Name: $TaskName" -Level "Info"
    Write-Log "Dry Run: $DryRun" -Level "Info"
    
    switch ($Action) {
        "Install" {
            $Success = Install-CleanupTask
        }
        "Uninstall" {
            $Success = Uninstall-CleanupTask
        }
        "Enable" {
            $Success = Enable-CleanupTask
        }
        "Disable" {
            $Success = Disable-CleanupTask
        }
        "Status" {
            $Success = Show-TaskStatus -TaskName $TaskName
        }
        "Test" {
            $Success = Test-CleanupTask
        }
        "RunNow" {
            $Success = Start-CleanupTask
        }
    }
    
    if ($Success) {
        Write-Log "Operation completed successfully" -Level "Success"
        exit 0
    }
    else {
        Write-Log "Operation failed" -Level "Error"
        exit 1
    }
}
catch {
    Write-Log "Critical error: $($_.Exception.Message)" -Level "Error"
    exit 1
}
