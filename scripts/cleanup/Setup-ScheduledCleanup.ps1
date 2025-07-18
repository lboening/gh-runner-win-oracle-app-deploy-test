# Setup-ScheduledCleanup.ps1
# Creates a Windows scheduled task to run the Azure resource group cleanup daily at 23:00

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "AzureResourceGroupCleanup",
    
    [Parameter(Mandatory = $false)]
    [string]$TaskDescription = "Daily cleanup of Azure resource group to optimize costs",
    
    [Parameter(Mandatory = $false)]
    [string]$RunTime = "23:00",
    
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath = "$PSScriptRoot\Remove-AzureResourceGroup.ps1",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$UserAccount = "SYSTEM",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Import logging utility
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Test-ScheduledTaskModule {
    try {
        if (!(Get-Module -ListAvailable -Name ScheduledTasks)) {
            Write-Log "ScheduledTasks module not available. This requires Windows 8/Server 2012 or later." -Level "Error"
            return $false
        }
        
        Import-Module ScheduledTasks -Force
        return $true
    }
    catch {
        Write-Log "Failed to import ScheduledTasks module: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Remove-ExistingTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )
    
    try {
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        
        if ($ExistingTask) {
            Write-Log "Removing existing scheduled task: $TaskName" -Level "Warning"
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "Existing task removed successfully" -Level "Success"
        }
        else {
            Write-Log "No existing task found with name: $TaskName" -Level "Info"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to remove existing task: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Create-ScheduledTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName,
        
        [Parameter(Mandatory = $true)]
        [string]$TaskDescription,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $true)]
        [string]$RunTime,
        
        [Parameter(Mandatory = $true)]
        [string]$UserAccount,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = ""
    )
    
    try {
        Write-Log "Creating scheduled task: $TaskName" -Level "Info"
        
        # Create the action
        $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments"
        
        # Create the trigger (daily at specified time)
        $Trigger = New-ScheduledTaskTrigger -Daily -At $RunTime
        
        # Create the principal (run as specified user)
        if ($UserAccount -eq "SYSTEM") {
            $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        }
        else {
            $Principal = New-ScheduledTaskPrincipal -UserId $UserAccount -LogonType Interactive -RunLevel Highest
        }
        
        # Create additional settings
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
        
        # Register the task
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description $TaskDescription
        
        Write-Log "Scheduled task created successfully" -Level "Success"
        return $true
    }
    catch {
        Write-Log "Failed to create scheduled task: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Create-EnvironmentFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId
    )
    
    $EnvFile = "$PSScriptRoot\cleanup-environment.ps1"
    
    $EnvContent = @"
# cleanup-environment.ps1
# Environment variables for Azure resource group cleanup
# This file is sourced by the scheduled task

# Azure Configuration
`$env:AZURE_RESOURCE_GROUP_NAME = "$ResourceGroupName"
`$env:AZURE_SUBSCRIPTION_ID = "$SubscriptionId"

# Optional: Uncomment and configure these for service principal authentication
# `$env:AZURE_TENANT_ID = "your-tenant-id"
# `$env:AZURE_CLIENT_ID = "your-service-principal-id"
# `$env:AZURE_CLIENT_SECRET = "your-service-principal-secret"

Write-Host "Environment variables loaded for Azure cleanup task"
"@

    try {
        $EnvContent | Out-File -FilePath $EnvFile -Encoding UTF8 -Force
        Write-Log "Created environment file: $EnvFile" -Level "Success"
        return $EnvFile
    }
    catch {
        Write-Log "Failed to create environment file: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function Create-TaskWrapper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [string]$EnvFile
    )
    
    $WrapperPath = "$PSScriptRoot\Run-ScheduledCleanup.ps1"
    
    $WrapperContent = @"
# Run-ScheduledCleanup.ps1
# Wrapper script for scheduled task execution

# Set execution policy for this session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Load environment variables if file exists
if (Test-Path "$EnvFile") {
    . "$EnvFile"
}

# Set working directory
Set-Location "$PSScriptRoot"

# Execute the main cleanup script with Force parameter
try {
    & "$ScriptPath" -Force -Verbose
}
catch {
    Write-Error "Cleanup script failed: `$(`$_.Exception.Message)"
    exit 1
}
"@

    try {
        $WrapperContent | Out-File -FilePath $WrapperPath -Encoding UTF8 -Force
        Write-Log "Created task wrapper: $WrapperPath" -Level "Success"
        return $WrapperPath
    }
    catch {
        Write-Log "Failed to create task wrapper: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function Test-TaskSetup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )
    
    try {
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        
        Write-Log "Task verification successful:" -Level "Success"
        Write-Log "  Name: $($Task.TaskName)" -Level "Info"
        Write-Log "  State: $($Task.State)" -Level "Info"
        Write-Log "  Last Run Time: $($TaskInfo.LastRunTime)" -Level "Info"
        Write-Log "  Next Run Time: $($TaskInfo.NextRunTime)" -Level "Info"
        
        return $true
    }
    catch {
        Write-Log "Task verification failed: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Main execution
try {
    Write-Log "=== Setting up Azure Resource Group Cleanup Scheduled Task ===" -Level "Info"
    
    # Check if running as administrator
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (!$IsAdmin) {
        Write-Log "This script requires administrator privileges to create scheduled tasks" -Level "Error"
        Write-Log "Please run PowerShell as Administrator and try again" -Level "Error"
        exit 1
    }
    
    # Validate required modules
    if (!(Test-ScheduledTaskModule)) {
        exit 1
    }
    
    # Validate script path
    if (!(Test-Path $ScriptPath)) {
        Write-Log "Cleanup script not found: $ScriptPath" -Level "Error"
        exit 1
    }
    
    # Create environment file
    $EnvFile = Create-EnvironmentFile -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId
    if (!$EnvFile) {
        exit 1
    }
    
    # Create wrapper script
    $WrapperPath = Create-TaskWrapper -ScriptPath $ScriptPath -EnvFile $EnvFile
    if (!$WrapperPath) {
        exit 1
    }
    
    # Remove existing task if it exists
    if (!(Remove-ExistingTask -TaskName $TaskName)) {
        exit 1
    }
    
    # Create the scheduled task
    if ($DryRun) {
        Write-Log "DRY RUN: Would create scheduled task '$TaskName' to run daily at $RunTime" -Level "Warning"
        Write-Log "Script path: $WrapperPath" -Level "Info"
        Write-Log "User account: $UserAccount" -Level "Info"
    }
    else {
        if (!(Create-ScheduledTask -TaskName $TaskName -TaskDescription $TaskDescription -ScriptPath $WrapperPath -RunTime $RunTime -UserAccount $UserAccount)) {
            exit 1
        }
        
        # Test the task setup
        if (!(Test-TaskSetup -TaskName $TaskName)) {
            exit 1
        }
    }
    
    Write-Log "=== Scheduled Task Setup Completed Successfully ===" -Level "Success"
    Write-Log "Task Name: $TaskName" -Level "Info"
    Write-Log "Schedule: Daily at $RunTime" -Level "Info"
    Write-Log "Script: $WrapperPath" -Level "Info"
    
    if (!$DryRun) {
        Write-Log "You can manage this task using:" -Level "Info"
        Write-Log "  - Task Scheduler GUI (taskschd.msc)" -Level "Info"
        Write-Log "  - PowerShell: Get-ScheduledTask -TaskName '$TaskName'" -Level "Info"
        Write-Log "  - To test manually: Start-ScheduledTask -TaskName '$TaskName'" -Level "Info"
    }
}
catch {
    Write-Log "Critical error during setup: $($_.Exception.Message)" -Level "Error"
    exit 1
}
