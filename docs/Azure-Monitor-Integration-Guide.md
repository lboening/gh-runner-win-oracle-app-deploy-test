# Azure Monitor Integration for Write-Log.ps1

## Overview

The enhanced logging utility provides comprehensive integration with Azure Monitor, enabling advanced log analytics, monitoring, and alerting capabilities for your GitHub Runner environment.

## Key Improvements

### 1. **Structured JSON Logging**
- **Before**: Simple text-based logs
- **After**: Rich JSON structure with metadata
- **Benefits**: Better querying, filtering, and analysis in Azure Monitor

### 2. **Azure Monitor Integration**
- Direct integration with Log Analytics workspace
- Support for both legacy Data Collector API and new Logs Ingestion API
- Automatic retry logic and error handling
- Batching for improved performance

### 3. **Enhanced Metadata**
- Operation and correlation IDs for tracing
- Performance metrics (memory usage, CPU time, duration)
- Azure resource context information
- Custom properties and metrics support

### 4. **Performance Optimization**
- Log batching to reduce API calls
- Asynchronous sending to avoid blocking
- Log file rotation and compression
- Configurable retry policies

### 5. **Advanced Features**
- Performance tracking wrapper (`Measure-LoggedOperation`)
- Multiple log levels including Trace and Critical
- Enhanced Windows Event Log integration
- Structured configuration management

## Configuration

### Basic Setup

1. **Configure Azure Monitor workspace**:
```powershell
.\scripts\utilities\Configure-AzureMonitor.ps1 `
    -WorkspaceId "your-workspace-id" `
    -SharedKey "your-shared-key" `
    -Environment "Production" `
    -Region "East US" `
    -ResourceGroup "rg-github-runner-win2025" `
    -SubscriptionId "your-subscription-id"
```

2. **Update existing scripts** to use enhanced logging:
```powershell
# Replace this:
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

# With this:
. "$PSScriptRoot\..\utilities\Write-Log-Enhanced.ps1"

# Then use:
Write-LogEnhanced -Message "Operation completed" -Level "Success" -EnableAzureMonitor
```

### Configuration File

The `azure-monitor-config.json` file contains:

```json
{
    "azureMonitor": {
        "enabled": true,
        "workspaceId": "your-workspace-id",
        "sharedKey": "your-shared-key",
        "logType": "GitHubRunnerLogs",
        "batchSize": 100,
        "batchTimeout": 30,
        "retryCount": 3,
        "retryDelay": 5
    },
    "logging": {
        "enableStructuredLogging": true,
        "enableBatching": true,
        "enableMetrics": true,
        "logRetentionDays": 90,
        "compressOldLogs": true,
        "enablePerformanceTracking": true
    },
    "customFields": {
        "environment": "Development",
        "region": "East US",
        "resourceGroup": "rg-github-runner-win2025",
        "subscriptionId": "your-subscription-id",
        "applicationVersion": "1.0.0"
    }
}
```

## Usage Examples

### Basic Enhanced Logging
```powershell
Write-LogEnhanced -Message "Application starting" -Level "Info" -EnableAzureMonitor
```

### Logging with Custom Properties
```powershell
Write-LogEnhanced -Message "User login successful" `
    -Level "Success" `
    -Component "Authentication" `
    -CustomProperties @{
        UserName = "john.doe"
        LoginMethod = "OAuth"
        IpAddress = "192.168.1.100"
    } `
    -EnableAzureMonitor
```

### Performance Tracking
```powershell
$Result = Measure-LoggedOperation -OperationName "Database Query" -ScriptBlock {
    # Your operation here
    Invoke-SqlCommand -Query "SELECT * FROM Users"
} -Component "Database" -Properties @{ QueryType = "Select" }
```

### Error Logging with Metrics
```powershell
Write-LogEnhanced -Message "API call failed" `
    -Level "Error" `
    -Component "WebAPI" `
    -CustomProperties @{
        Endpoint = "/api/users"
        StatusCode = 500
        ResponseTime = 1500
    } `
    -Metrics @{
        APICallFailed = 1
        ResponseTimeMs = 1500
    } `
    -EnableAzureMonitor
```

## Azure Monitor Queries

Use the provided KQL queries in `docs/AzureMonitor-KQL-Queries.kql` to:

### Monitor Application Health
```kql
GitHubRunnerLogs_CL
| where TimeGenerated >= ago(1h)
| summarize 
    TotalLogs = count(),
    ErrorRate = round(100.0 * countif(Level_s == "Error") / count(), 2),
    AvgMemoryMB = avg(MemoryUsageMB_d)
    by bin(TimeGenerated, 5m)
```

### Track Operation Performance
```kql
GitHubRunnerLogs_CL
| where EventName_s == "OperationComplete"
| summarize 
    Count = count(),
    AvgDuration = avg(Duration_d),
    P95Duration = percentile(Duration_d, 95)
    by Component_s
```

### Find Correlated Issues
```kql
GitHubRunnerLogs_CL
| where OperationId_g == "specific-operation-id"
| order by TimeGenerated
```

## Benefits for Azure Monitor

### 1. **Rich Querying Capabilities**
- Filter by any custom property
- Aggregate performance metrics
- Trace operations across components
- Correlate events using operation IDs

### 2. **Advanced Analytics**
- Trend analysis over time
- Performance regression detection
- Error pattern identification
- Resource utilization monitoring

### 3. **Alerting and Monitoring**
- Real-time error rate alerts
- Performance threshold monitoring
- Custom metric-based alerts
- Integration with Azure Monitor alerts

### 4. **Dashboards and Visualization**
- Azure Monitor Workbooks integration
- Custom dashboard creation
- Performance trend visualization
- Operational health monitoring

### 5. **Integration with Azure Services**
- Azure Logic Apps for automated responses
- Azure Functions for custom processing
- Power BI for business intelligence
- Azure Sentinel for security monitoring

## Migration Guide

### Step 1: Update Scripts
Replace `Write-Log` calls with `Write-LogEnhanced`:

```powershell
# Old:
Write-Log "Operation completed" -Level "Success"

# New:
Write-LogEnhanced "Operation completed" -Level "Success" -EnableAzureMonitor
```

### Step 2: Add Performance Tracking
Wrap operations with performance measurement:

```powershell
# Old:
Write-Log "Starting deployment" -Level "Info"
Deploy-Application
Write-Log "Deployment completed" -Level "Success"

# New:
Measure-LoggedOperation -OperationName "Application Deployment" -ScriptBlock {
    Deploy-Application
} -Component "Deployment"
```

### Step 3: Configure Azure Monitor
Run the configuration script once per environment:

```powershell
.\Configure-AzureMonitor.ps1 -WorkspaceId "xxx" -SharedKey "xxx"
```

## Best Practices

### 1. **Consistent Component Names**
Use standardized component names across your scripts:
- `GitHubRunner` - Main runner operations
- `Deployment` - Application deployments
- `Validation` - Testing and validation
- `Cleanup` - Resource cleanup operations
- `Setup` - Environment setup

### 2. **Meaningful Operation Names**
Use descriptive operation names for tracking:
- `"Oracle Database Connection"`
- `"IIS Website Deployment"`
- `"Azure Resource Cleanup"`

### 3. **Custom Properties Standards**
Define consistent property names:
- `UserName` for user identification
- `ResourceName` for Azure resource names
- `Duration` for operation timing
- `StatusCode` for HTTP responses

### 4. **Error Handling**
Always include error context:
```powershell
try {
    # Operation
}
catch {
    Write-LogEnhanced -Message "Operation failed: $($_.Exception.Message)" `
        -Level "Error" `
        -CustomProperties @{
            ErrorType = $_.Exception.GetType().Name
            StackTrace = $_.Exception.StackTrace
            ScriptLine = $_.InvocationInfo.ScriptLineNumber
        }
}
```

## Troubleshooting

### Common Issues

1. **Azure Monitor connection fails**
   - Verify workspace ID and shared key
   - Check network connectivity
   - Review authentication configuration

2. **Logs not appearing in Azure Monitor**
   - Allow up to 5 minutes for ingestion
   - Check log type name (should end with `_CL`)
   - Verify JSON format is correct

3. **Performance impact**
   - Enable batching to reduce API calls
   - Use asynchronous sending
   - Monitor memory usage

### Debugging

Enable verbose logging to troubleshoot issues:
```powershell
$VerbosePreference = "Continue"
Write-LogEnhanced -Message "Test" -EnableAzureMonitor -Verbose
```

## Security Considerations

1. **Protect Shared Keys**
   - Store in Azure Key Vault
   - Use environment variables
   - Rotate keys regularly

2. **Data Privacy**
   - Avoid logging sensitive information
   - Implement data masking for PII
   - Follow compliance requirements

3. **Network Security**
   - Use private endpoints if available
   - Monitor for unauthorized access
   - Implement proper firewall rules

## Cost Optimization

1. **Log Volume Management**
   - Use appropriate log levels
   - Implement log sampling for high-volume scenarios
   - Configure retention policies

2. **Batching Configuration**
   - Optimize batch size for your workload
   - Balance between latency and cost
   - Monitor Azure Monitor pricing

3. **Query Optimization**
   - Use time range filters
   - Limit result sets
   - Cache frequently used queries
