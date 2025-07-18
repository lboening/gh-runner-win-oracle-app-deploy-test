# Remove-AzureResourceGroup.ps1
# Automated Azure Resource Group cleanup script for cost optimization
# Runs daily at 23:00 to delete the entire resource group containing the Windows 2025 server

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId = $env:AZURE_TENANT_ID,
    
    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalId = $env:AZURE_CLIENT_ID,
    
    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalSecret = $env:AZURE_CLIENT_SECRET,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "$PSScriptRoot\..\configs\cleanup-config.json"
)

# Import logging utility
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Initialize-AzureConnection {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Initializing Azure connection..." -Level "Info"
        
        # Check if Azure PowerShell module is installed
        if (!(Get-Module -ListAvailable -Name Az)) {
            Write-Log "Azure PowerShell module not found. Installing..." -Level "Warning"
            Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
        }
        
        # Import Azure modules
        Import-Module Az.Accounts -Force
        Import-Module Az.Resources -Force
        
        # Authenticate using Service Principal
        if ($ServicePrincipalId -and $ServicePrincipalSecret) {
            Write-Log "Authenticating with Service Principal..." -Level "Info"
            $SecurePassword = ConvertTo-SecureString $ServicePrincipalSecret -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($ServicePrincipalId, $SecurePassword)
            
            Connect-AzAccount -ServicePrincipal -Credential $Credential -TenantId $TenantId -SubscriptionId $SubscriptionId
        }
        else {
            Write-Log "Attempting interactive authentication..." -Level "Info"
            Connect-AzAccount -SubscriptionId $SubscriptionId
        }
        
        # Set the subscription context
        Set-AzContext -SubscriptionId $SubscriptionId
        
        Write-Log "Successfully connected to Azure subscription: $SubscriptionId" -Level "Success"
        return $true
    }
    catch {
        Write-Log "Failed to connect to Azure: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Get-ResourceGroupInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    try {
        $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        
        if ($ResourceGroup) {
            Write-Log "Found resource group: $ResourceGroupName in location: $($ResourceGroup.Location)" -Level "Info"
            
            # Get all resources in the resource group
            $Resources = Get-AzResource -ResourceGroupName $ResourceGroupName
            Write-Log "Resource group contains $($Resources.Count) resources:" -Level "Info"
            
            foreach ($Resource in $Resources) {
                Write-Log "  - $($Resource.Name) ($($Resource.ResourceType))" -Level "Info"
            }
            
            return $ResourceGroup
        }
        else {
            Write-Log "Resource group '$ResourceGroupName' not found" -Level "Warning"
            return $null
        }
    }
    catch {
        Write-Log "Error getting resource group information: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function Remove-ResourceGroupWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 60
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Log "Deletion attempt $i of $MaxRetries for resource group: $ResourceGroupName" -Level "Info"
            
            if ($DryRun) {
                Write-Log "DRY RUN: Would delete resource group '$ResourceGroupName'" -Level "Warning"
                return $true
            }
            
            # Force delete without confirmation
            Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob
            
            # Wait for the job to complete
            Write-Log "Resource group deletion initiated. Monitoring progress..." -Level "Info"
            
            # Check if resource group still exists (deletion can take time)
            $timeout = 0
            $maxTimeout = 1800 # 30 minutes
            
            do {
                Start-Sleep -Seconds 30
                $timeout += 30
                $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
                
                if ($ResourceGroup) {
                    Write-Log "Deletion in progress... ($timeout seconds elapsed)" -Level "Info"
                }
                
            } while ($ResourceGroup -and $timeout -lt $maxTimeout)
            
            if (!$ResourceGroup) {
                Write-Log "Resource group '$ResourceGroupName' successfully deleted" -Level "Success"
                return $true
            }
            else {
                Write-Log "Resource group deletion timed out after $maxTimeout seconds" -Level "Warning"
            }
        }
        catch {
            Write-Log "Deletion attempt $i failed: $($_.Exception.Message)" -Level "Error"
            
            if ($i -lt $MaxRetries) {
                Write-Log "Waiting $RetryDelaySeconds seconds before retry..." -Level "Info"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    Write-Log "Failed to delete resource group after $MaxRetries attempts" -Level "Error"
    return $false
}

function Send-NotificationEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [string]$Details
    )
    
    # This function can be extended to send email notifications
    # For now, it just logs the notification
    if ($Success) {
        Write-Log "NOTIFICATION: Resource group '$ResourceGroupName' cleanup completed successfully" -Level "Success"
    }
    else {
        Write-Log "NOTIFICATION: Resource group '$ResourceGroupName' cleanup failed - $Details" -Level "Error"
    }
}

# Main execution
try {
    Write-Log "=== Azure Resource Group Cleanup Started ===" -Level "Info"
    Write-Log "Timestamp: $(Get-Date)" -Level "Info"
    Write-Log "Resource Group: $ResourceGroupName" -Level "Info"
    Write-Log "Dry Run Mode: $DryRun" -Level "Info"
    
    # Validate required parameters
    if ([string]::IsNullOrEmpty($ResourceGroupName)) {
        throw "Resource group name is required. Set AZURE_RESOURCE_GROUP_NAME environment variable or pass -ResourceGroupName parameter."
    }
    
    if ([string]::IsNullOrEmpty($SubscriptionId)) {
        throw "Subscription ID is required. Set AZURE_SUBSCRIPTION_ID environment variable or pass -SubscriptionId parameter."
    }
    
    # Load configuration file if it exists
    if (Test-Path $ConfigFile) {
        Write-Log "Loading configuration from: $ConfigFile" -Level "Info"
        $Config = Get-Content $ConfigFile | ConvertFrom-Json
        
        # Override parameters with config file values if not provided
        if ([string]::IsNullOrEmpty($ResourceGroupName) -and $Config.resourceGroupName) {
            $ResourceGroupName = $Config.resourceGroupName
        }
    }
    
    # Initialize Azure connection
    if (!(Initialize-AzureConnection)) {
        throw "Failed to establish Azure connection"
    }
    
    # Get resource group information
    $ResourceGroup = Get-ResourceGroupInfo -ResourceGroupName $ResourceGroupName
    
    if (!$ResourceGroup) {
        Write-Log "Resource group '$ResourceGroupName' not found. Nothing to delete." -Level "Warning"
        exit 0
    }
    
    # Safety check - require Force parameter for non-dry-run executions
    if (!$DryRun -and !$Force) {
        throw "This script will permanently delete the resource group '$ResourceGroupName' and all its resources. Use -Force parameter to confirm deletion or -DryRun to simulate."
    }
    
    # Calculate estimated cost savings (placeholder - would need actual cost calculation)
    Write-Log "Estimated daily cost savings: This depends on your resource configuration" -Level "Info"
    
    # Perform the deletion
    $DeletionSuccess = Remove-ResourceGroupWithRetry -ResourceGroupName $ResourceGroupName
    
    # Send notification
    if ($DeletionSuccess) {
        Send-NotificationEmail -Success $true -ResourceGroupName $ResourceGroupName
        Write-Log "=== Azure Resource Group Cleanup Completed Successfully ===" -Level "Success"
        exit 0
    }
    else {
        Send-NotificationEmail -Success $false -ResourceGroupName $ResourceGroupName -Details "Deletion failed after multiple attempts"
        Write-Log "=== Azure Resource Group Cleanup Failed ===" -Level "Error"
        exit 1
    }
}
catch {
    Write-Log "Critical error during cleanup: $($_.Exception.Message)" -Level "Error"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" -Level "Debug"
    Send-NotificationEmail -Success $false -ResourceGroupName $ResourceGroupName -Details $_.Exception.Message
    exit 1
}
finally {
    # Cleanup Azure context
    try {
        Disconnect-AzAccount -ErrorAction SilentlyContinue
        Write-Log "Disconnected from Azure" -Level "Info"
    }
    catch {
        # Ignore disconnect errors
    }
}
