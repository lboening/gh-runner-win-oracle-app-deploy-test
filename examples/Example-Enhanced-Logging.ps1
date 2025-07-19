# Example-Enhanced-Logging.ps1
# Demonstrates the enhanced Azure Monitor logging capabilities

# Import the enhanced logging utility
. "$PSScriptRoot\Write-Log-Enhanced.ps1"

Write-Host "=== Azure Monitor Enhanced Logging Demo ===" -ForegroundColor Cyan

# 1. Basic enhanced logging
Write-LogEnhanced -Message "Application starting up" -Level "Info" -Component "Demo" -EnableAzureMonitor

# 2. Logging with custom properties
Write-LogEnhanced -Message "User authentication attempt" `
    -Level "Info" `
    -Component "Authentication" `
    -CustomProperties @{
        UserName = "demo.user"
        AuthMethod = "Certificate"
        ClientIP = "192.168.1.100"
        UserAgent = "PowerShell/7.0"
    } `
    -EnableAzureMonitor

# 3. Performance tracking example
Write-Host "Demonstrating performance tracking..." -ForegroundColor Yellow

$Result = Measure-LoggedOperation -OperationName "Simulated Database Query" -ScriptBlock {
    # Simulate some work
    Start-Sleep -Milliseconds 250
    Write-Host "  Executing query..." -ForegroundColor Gray
    Start-Sleep -Milliseconds 150
    return @{ Records = 42; ExecutionTime = 400 }
} -Component "Database" -Properties @{
    QueryType = "SELECT"
    Database = "UserDatabase"
    TableCount = 3
}

Write-Host "  Query returned $($Result.Records) records" -ForegroundColor Green

# 4. Error logging with context
try {
    Write-LogEnhanced -Message "Attempting risky operation" -Level "Info" -Component "Demo"
    
    # Simulate an error
    throw "Simulated database connection timeout"
}
catch {
    Write-LogEnhanced -Message "Operation failed: $($_.Exception.Message)" `
        -Level "Error" `
        -Component "Demo" `
        -CustomProperties @{
            ErrorType = $_.Exception.GetType().Name
            StackTrace = $_.Exception.StackTrace -split "`n" | Select-Object -First 3
            OperationContext = "Database Connection"
            RetryAttempt = 1
        } `
        -Metrics @{
            ErrorCount = 1
            FailureType = "Timeout"
        } `
        -EnableAzureMonitor
}

# 5. Success with metrics
Write-LogEnhanced -Message "File processing completed successfully" `
    -Level "Success" `
    -Component "FileProcessor" `
    -CustomProperties @{
        FileName = "data_export_20250718.csv"
        FileSize = "15.7 MB"
        RecordsProcessed = 25000
        ProcessingMode = "Batch"
    } `
    -Metrics @{
        FileSizeMB = 15.7
        RecordsProcessed = 25000
        ProcessingTimeSeconds = 45.2
        SuccessRate = 99.8
    } `
    -Duration 45200 `
    -EventName "FileProcessingComplete" `
    -EnableAzureMonitor

# 6. Warning with correlation ID
$CorrelationId = [System.Guid]::NewGuid().ToString()

Write-LogEnhanced -Message "Memory usage approaching threshold" `
    -Level "Warning" `
    -Component "HealthMonitor" `
    -CorrelationId $CorrelationId `
    -CustomProperties @{
        CurrentMemoryMB = 850
        ThresholdMB = 1024
        UtilizationPercent = 83
        RecommendedAction = "Consider restarting application"
    } `
    -Metrics @{
        MemoryUtilization = 83
        MemoryAvailableMB = 174
    } `
    -EnableAzureMonitor

# 7. Correlated follow-up log
Write-LogEnhanced -Message "Memory cleanup initiated" `
    -Level "Info" `
    -Component "HealthMonitor" `
    -CorrelationId $CorrelationId `
    -CustomProperties @{
        CleanupType = "Automatic"
        TriggerReason = "Memory threshold exceeded"
    } `
    -EnableAzureMonitor

# 8. Debug logging with detailed context
Write-LogEnhanced -Message "API response received" `
    -Level "Debug" `
    -Component "WebAPI" `
    -CustomProperties @{
        Endpoint = "https://api.example.com/v1/users"
        Method = "GET"
        StatusCode = 200
        ResponseTime = 125
        ResponseSize = "2.3 KB"
        CacheHit = $true
        RequestId = "req-789012"
    } `
    -Metrics @{
        ResponseTimeMs = 125
        ResponseSizeBytes = 2300
        CacheHitRate = 1
    } `
    -Duration 125 `
    -EnableAzureMonitor

# 9. Critical alert
Write-LogEnhanced -Message "Disk space critically low" `
    -Level "Critical" `
    -Component "SystemMonitor" `
    -CustomProperties @{
        DriveLetter = "C:"
        FreeSpaceGB = 0.5
        TotalSpaceGB = 100
        UtilizationPercent = 99.5
        AlertThreshold = 95
        RequiredAction = "Immediate cleanup required"
    } `
    -Metrics @{
        DiskUtilization = 99.5
        FreeSpaceGB = 0.5
        CriticalAlertTriggered = 1
    } `
    -EnableAzureMonitor

# 10. Demonstrate multiple operations in sequence
$OperationId = [System.Guid]::NewGuid().ToString()

Write-LogEnhanced -Message "Starting batch operation sequence" `
    -Level "Info" `
    -Component "BatchProcessor" `
    -OperationId $OperationId `
    -EventName "BatchStart" `
    -CustomProperties @{
        BatchSize = 100
        BatchType = "DataExport"
    } `
    -EnableAzureMonitor

for ($i = 1; $i -le 3; $i++) {
    Start-Sleep -Milliseconds 100
    
    Write-LogEnhanced -Message "Processing batch item $i" `
        -Level "Info" `
        -Component "BatchProcessor" `
        -OperationId $OperationId `
        -EventName "BatchItemProcessed" `
        -CustomProperties @{
            ItemNumber = $i
            ItemType = "DataRecord"
            ProcessingResult = "Success"
        } `
        -Metrics @{
            ItemsProcessed = $i
        } `
        -Duration (100 + ($i * 10)) `
        -EnableAzureMonitor
}

Write-LogEnhanced -Message "Batch operation completed successfully" `
    -Level "Success" `
    -Component "BatchProcessor" `
    -OperationId $OperationId `
    -EventName "BatchComplete" `
    -CustomProperties @{
        TotalItemsProcessed = 3
        SuccessRate = 100
        TotalDuration = 330
    } `
    -Metrics @{
        BatchSuccessRate = 100
        TotalProcessingTimeMs = 330
        ItemsPerSecond = 9.09
    } `
    -Duration 330 `
    -EnableAzureMonitor

# Flush any remaining batched logs
Write-Host "Flushing remaining logs to Azure Monitor..." -ForegroundColor Yellow
Flush-LogBatch

Write-Host "`n=== Demo completed! ===" -ForegroundColor Cyan
Write-Host "Check your Azure Monitor Log Analytics workspace for the demo logs." -ForegroundColor Green
Write-Host "Query: GitHubRunnerLogs_CL | where Component_s in ('Demo', 'Database', 'FileProcessor', 'HealthMonitor', 'WebAPI', 'SystemMonitor', 'BatchProcessor')" -ForegroundColor Gray
