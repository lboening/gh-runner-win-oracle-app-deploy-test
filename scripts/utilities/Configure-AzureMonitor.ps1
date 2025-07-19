# Configure-AzureMonitor.ps1
# Script to configure Azure Monitor integration for enhanced logging

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory = $true)]
    [string]$SharedKey,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "$PSScriptRoot\..\..\configs\azure-monitor-config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$Environment = "Development",
    
    [Parameter(Mandatory = $false)]
    [string]$Region = "East US",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "rg-github-runner-win2025",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableNewLogsIngestionAPI,
    
    [Parameter(Mandatory = $false)]
    [string]$DataCollectionEndpoint,
    
    [Parameter(Mandatory = $false)]
    [string]$DataCollectionRuleId
)

# Import logging utility
. "$PSScriptRoot\Write-Log.ps1"

Write-Log "Configuring Azure Monitor integration..." -Level "Info"

# Load existing config or create new one
$Config = @{
    azureMonitor = @{
        enabled = $true
        workspaceId = $WorkspaceId
        sharedKey = $SharedKey
        logType = "GitHubRunnerLogs"
        batchSize = 100
        batchTimeout = 30
        retryCount = 3
        retryDelay = 5
    }
    logging = @{
        enableStructuredLogging = $true
        enableBatching = $true
        enableMetrics = $true
        logRetentionDays = 90
        compressOldLogs = $true
        enablePerformanceTracking = $true
    }
    customFields = @{
        environment = $Environment
        region = $Region
        resourceGroup = $ResourceGroup
        subscriptionId = $SubscriptionId
        applicationVersion = "1.0.0"
    }
}

# Add new Logs Ingestion API configuration if specified
if ($EnableNewLogsIngestionAPI) {
    $Config.azureMonitor.useNewAPI = $true
    $Config.azureMonitor.dataCollectionEndpoint = $DataCollectionEndpoint
    $Config.azureMonitor.dataCollectionRuleId = $DataCollectionRuleId
    $Config.azureMonitor.streamName = "Custom-GitHubRunnerLogs"
}

try {
    # Ensure config directory exists
    $ConfigDir = Split-Path $ConfigFile -Parent
    if (!(Test-Path $ConfigDir)) {
        New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
    }
    
    # Save configuration
    $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-Log "Azure Monitor configuration saved to: $ConfigFile" -Level "Success"
    
    # Test the connection
    Write-Log "Testing Azure Monitor connection..." -Level "Info"
    Test-AzureMonitorConnection -Config $Config
    
    # Set environment variables for easy access
    $env:AZURE_LOG_ANALYTICS_WORKSPACE_ID = $WorkspaceId
    $env:AZURE_LOG_ANALYTICS_SHARED_KEY = $SharedKey
    
    Write-Log "Azure Monitor integration configured successfully!" -Level "Success"
    Write-Log "You can now use Write-LogEnhanced with -EnableAzureMonitor switch" -Level "Info"
    
}
catch {
    Write-Log "Failed to configure Azure Monitor: $($_.Exception.Message)" -Level "Error"
    throw
}

function Test-AzureMonitorConnection {
    param($Config)
    
    $TestLogEntry = @{
        TimeGenerated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
        Level = "Info"
        Message = "Azure Monitor connectivity test"
        Component = "ConfigurationTest"
        Computer = $env:COMPUTERNAME
        TestProperty = "ConnectionTest"
    }
    
    try {
        # Import the enhanced logging functions
        . "$PSScriptRoot\Write-Log-Enhanced.ps1"
        
        Send-ToAzureMonitorBatch -LogEntries @($TestLogEntry) -Config $Config
        Write-Log "✓ Successfully sent test log to Azure Monitor" -Level "Success"
    }
    catch {
        Write-Log "✗ Failed to send test log to Azure Monitor: $($_.Exception.Message)" -Level "Error"
        throw
    }
}
