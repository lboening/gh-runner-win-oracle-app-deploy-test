# Azure Resource Group Cleanup Scripts

This directory contains PowerShell scripts for automatically deleting Azure resource groups to optimize costs. The scripts are designed to run daily at 23:00 (11 PM) to clean up the Windows 2025 server and associated resources.

## 🚨 **IMPORTANT SAFETY WARNING**

These scripts will **PERMANENTLY DELETE** your entire Azure resource group and all resources within it. This includes:

- Virtual machines
- Storage accounts
- Networking components
- Databases
- All other Azure resources in the specified resource group

**Use with extreme caution and ensure you have proper backups if needed!**

## 📁 Files Overview

### Core Scripts

- **`Remove-AzureResourceGroup.ps1`** - Main cleanup script that deletes the Azure resource group
- **`Setup-ScheduledCleanup.ps1`** - Sets up Windows scheduled task for daily execution
- **`Manage-CleanupTask.ps1`** - Management utility for the scheduled task

### Configuration

- **`../configs/cleanup-config.json`** - Configuration file for cleanup settings

### Generated Files (created during setup)

- **`cleanup-environment.ps1`** - Environment variables for Azure authentication
- **`Run-ScheduledCleanup.ps1`** - Wrapper script for scheduled task execution

## 🚀 Quick Start

### 1. Configure Azure Authentication

You have two options for Azure authentication:

#### Option A: Interactive Authentication (Recommended for testing)

The script will prompt for login when needed.

#### Option B: Service Principal Authentication (Recommended for production)

Set up a service principal and configure environment variables:

```powershell
# Create a service principal (run in Azure CLI)
az ad sp create-for-rbac --name "AzureCleanupSP" --role "Contributor" --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID"

# Set environment variables
$env:AZURE_TENANT_ID = "your-tenant-id"
$env:AZURE_CLIENT_ID = "your-service-principal-id"
$env:AZURE_CLIENT_SECRET = "your-service-principal-secret"
$env:AZURE_SUBSCRIPTION_ID = "your-subscription-id"
$env:AZURE_RESOURCE_GROUP_NAME = "your-resource-group-name"
```

### 2. Test the Cleanup Script (Dry Run)

```powershell
# Test without actually deleting anything
.\Remove-AzureResourceGroup.ps1 -ResourceGroupName "your-rg-name" -SubscriptionId "your-sub-id" -DryRun
```

### 3. Set Up the Scheduled Task

```powershell
# Run as Administrator
.\Setup-ScheduledCleanup.ps1 -ResourceGroupName "your-rg-name" -SubscriptionId "your-sub-id"
```

### 4. Verify the Setup

```powershell
# Check task status
.\Manage-CleanupTask.ps1 -Action Status
```

## 🛠️ Detailed Usage

### Remove-AzureResourceGroup.ps1

Main cleanup script with the following parameters:

```powershell
.\Remove-AzureResourceGroup.ps1 [parameters]

# Required Parameters (can be set via environment variables)
-ResourceGroupName    # Name of the Azure resource group to delete
-SubscriptionId       # Azure subscription ID

# Optional Parameters
-TenantId            # Azure tenant ID (for service principal auth)
-ServicePrincipalId  # Service principal client ID
-ServicePrincipalSecret # Service principal secret
-Force               # Skip confirmation prompts
-DryRun              # Simulate without actually deleting
-ConfigFile          # Path to configuration file
```

### Setup-ScheduledCleanup.ps1

Creates a Windows scheduled task:

```powershell
.\Setup-ScheduledCleanup.ps1 [parameters]

# Optional Parameters
-TaskName            # Name of the scheduled task (default: "AzureResourceGroupCleanup")
-TaskDescription     # Description of the task
-RunTime             # Time to run daily (default: "23:00")
-ResourceGroupName   # Azure resource group name
-SubscriptionId      # Azure subscription ID
-UserAccount         # User account to run the task (default: "SYSTEM")
-DryRun              # Test setup without creating the task
```

### Manage-CleanupTask.ps1

Management utility for the scheduled task:

```powershell
.\Manage-CleanupTask.ps1 -Action <action> [parameters]

# Actions
-Action Install      # Install the scheduled task
-Action Uninstall    # Remove the scheduled task
-Action Enable       # Enable the scheduled task
-Action Disable      # Disable the scheduled task
-Action Status       # Show task status and details
-Action Test         # Test the cleanup script (dry run)
-Action RunNow       # Execute the task immediately (with confirmation)

# Optional Parameters
-TaskName           # Name of the scheduled task
-ResourceGroupName  # Azure resource group name
-SubscriptionId     # Azure subscription ID
-DryRun            # Simulate actions without executing
```

## 📋 Common Usage Examples

### Test Everything Before Going Live

```powershell
# 1. Test the cleanup script
.\Remove-AzureResourceGroup.ps1 -ResourceGroupName "rg-test" -SubscriptionId "sub-123" -DryRun

# 2. Test the scheduled task setup
.\Setup-ScheduledCleanup.ps1 -ResourceGroupName "rg-test" -SubscriptionId "sub-123" -DryRun

# 3. Test the management utility
.\Manage-CleanupTask.ps1 -Action Test -DryRun
```

### Install and Configure

```powershell
# Install the scheduled task (run as Administrator)
.\Manage-CleanupTask.ps1 -Action Install -ResourceGroupName "rg-github-runner" -SubscriptionId "your-sub-id"

# Check status
.\Manage-CleanupTask.ps1 -Action Status

# Test manually
.\Manage-CleanupTask.ps1 -Action Test
```

### Manage the Task

```powershell
# Temporarily disable the task
.\Manage-CleanupTask.ps1 -Action Disable

# Re-enable the task
.\Manage-CleanupTask.ps1 -Action Enable

# Remove the task completely
.\Manage-CleanupTask.ps1 -Action Uninstall
```

## 🔧 Configuration

Edit `../configs/cleanup-config.json` to customize settings:

```json
{
    "resourceGroupName": "rg-github-runner-win2025",
    "subscriptionId": "your-azure-subscription-id",
    "cleanupSchedule": {
        "time": "23:00",
        "frequency": "daily",
        "enabled": true
    },
    "safety": {
        "requireForceParameter": true,
        "maxRetries": 3,
        "retryDelaySeconds": 60,
        "timeoutMinutes": 30
    }
}
```

## 📊 Monitoring and Logging

### Logs Location

- Default log directory: `C:\Logs\`
- Log file pattern: `GitHubRunner_YYYYMMDD.log`
- Windows Event Log: Application log, source "GitHubRunner"

### Check Task Execution

```powershell
# View recent log entries
Get-Content "C:\Logs\GitHubRunner_$(Get-Date -Format 'yyyyMMdd').log" -Tail 50

# Check scheduled task history
Get-ScheduledTaskInfo -TaskName "AzureResourceGroupCleanup"

# View Windows Event Log
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='GitHubRunner'} -MaxEvents 10
```

## 🛡️ Safety Features

1. **Force Parameter Required**: Production runs require `-Force` parameter
2. **Dry Run Mode**: Test without actual deletion using `-DryRun`
3. **Retry Logic**: Automatic retries with exponential backoff
4. **Timeout Protection**: Operations timeout after 30 minutes
5. **Comprehensive Logging**: All actions are logged with timestamps
6. **Resource Validation**: Verifies resource group exists before deletion

## 🔍 Troubleshooting

### Common Issues

1. **"Access Denied" when creating scheduled task**
   - Solution: Run PowerShell as Administrator

2. **Azure authentication failures**
   - Check environment variables are set correctly
   - Verify service principal has Contributor role
   - Try interactive authentication first

3. **Task not running at scheduled time**
   - Check task status: `.\Manage-CleanupTask.ps1 -Action Status`
   - Verify task is enabled
   - Check Windows Event Log for errors

4. **Script execution policy errors**
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Debug Mode

Enable verbose logging:

```powershell
.\Remove-AzureResourceGroup.ps1 -ResourceGroupName "your-rg" -SubscriptionId "your-sub" -Verbose
```

## 💰 Cost Optimization Benefits

Running this cleanup daily at 23:00 ensures:

- No overnight compute costs when development is not active
- Automatic cleanup prevents forgotten resources from accumulating costs
- Predictable daily cost pattern
- Easy to budget for daytime-only usage

## ⚠️ Important Notes

1. **This is destructive**: All data in the resource group will be lost
2. **No recovery**: Once deleted, resources cannot be restored
3. **Dependencies**: Ensure no critical dependencies exist outside the resource group
4. **Backup strategy**: Implement proper backup procedures if data persistence is needed
5. **Cost calculation**: Monitor actual cost savings to validate the approach

## 📞 Support

For issues or questions:

1. Check the troubleshooting section above
2. Review log files for error details
3. Test with `-DryRun` flag first
4. Verify Azure permissions and authentication
