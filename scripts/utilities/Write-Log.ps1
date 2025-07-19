# Write-Log.ps1
# Utility function for consistent logging across all scripts

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = "C:\Logs\GitHubRunner_$(Get-Date -Format 'yyyyMMdd').log",
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "GitHubRunner",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CustomProperties = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$OperationId = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableAzureMonitor,
        
        [Parameter(Mandatory = $false)]
        [string]$WorkspaceId = $env:AZURE_LOG_ANALYTICS_WORKSPACE_ID,
        
        [Parameter(Mandatory = $false)]
        [string]$SharedKey = $env:AZURE_LOG_ANALYTICS_SHARED_KEY
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Create structured log entry for Azure Monitor
    $StructuredLogEntry = @{
        TimeGenerated = $Timestamp
        Level = $Level
        Message = $Message
        Component = $Component
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        OperationId = if ($OperationId) { $OperationId } else { [System.Guid]::NewGuid().ToString() }
        CorrelationId = $CorrelationId
        SessionId = if ($env:SESSIONNAME) { $env:SESSIONNAME } else { "Console" }
        # Add custom properties
    }
    
    # Merge custom properties
    foreach ($key in $CustomProperties.Keys) {
        $StructuredLogEntry[$key] = $CustomProperties[$key]
    }
    
    # Convert to JSON for structured logging
    $JsonLogEntry = $StructuredLogEntry | ConvertTo-Json -Compress
    
    # Ensure log directory exists
    $LogDir = Split-Path $LogFile -Parent
    if (!(Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Console output with colors
    switch ($Level) {
        "Info" { Write-Host $LogMessage -ForegroundColor White }
        "Warning" { Write-Host $LogMessage -ForegroundColor Yellow }
        "Error" { Write-Host $LogMessage -ForegroundColor Red }
        "Success" { Write-Host $LogMessage -ForegroundColor Green }
        "Debug" { Write-Host $LogMessage -ForegroundColor Gray }
    }
    
    # File output - both human readable and JSON structured
    try {
        # Human-readable log entry
        $LogMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
        
        # JSON structured log for Azure Monitor ingestion
        $JsonLogFile = $LogFile -replace '\.log$', '_structured.json'
        $JsonLogEntry | Out-File -FilePath $JsonLogFile -Append -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
    
    # Windows Event Log
    try {
        if (![System.Diagnostics.EventLog]::SourceExists("GitHubRunner")) {
            New-EventLog -LogName "Application" -Source "GitHubRunner"
        }
        
        $EventType = switch ($Level) {
            "Error" { "Error" }
            "Warning" { "Warning" }
            default { "Information" }
        }
        
        Write-EventLog -LogName "Application" -Source "GitHubRunner" -EventId 1001 -EntryType $EventType -Message $Message
    }
    catch {
        # Silently ignore event log errors to prevent infinite loops
    }
    
    # Azure Monitor integration
    if ($EnableAzureMonitor -and $WorkspaceId -and $SharedKey) {
        try {
            Send-ToAzureMonitor -LogEntry $StructuredLogEntry -WorkspaceId $WorkspaceId -SharedKey $SharedKey
        }
        catch {
            Write-Warning "Failed to send log to Azure Monitor: $($_.Exception.Message)"
        }
    }
}

# Helper function to send logs to Azure Monitor using Logs Ingestion API
function Send-ToAzureMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LogEntry,
        
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory = $true)]
        [string]$SharedKey,
        
        [Parameter(Mandatory = $false)]
        [string]$LogType = "GitHubRunnerLogs"
    )
    
    $Method = "POST"
    $ContentType = "application/json"
    $Resource = "/api/logs"
    $Date = [DateTime]::UtcNow.ToString("r")
    $Body = @($LogEntry) | ConvertTo-Json -Depth 10
    $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $ContentLength = $BodyBytes.Length
    
    # Create authorization signature
    $StringToHash = $Method + "`n" + $ContentLength + "`n" + $ContentType + "`n" + "x-ms-date:" + $Date + "`n" + $Resource
    $BytesToHash = [Text.Encoding]::UTF8.GetBytes($StringToHash)
    $KeyBytes = [Convert]::FromBase64String($SharedKey)
    $HMAC = New-Object System.Security.Cryptography.HMACSHA256
    $HMAC.Key = $KeyBytes
    $CalculatedHash = $HMAC.ComputeHash($BytesToHash)
    $EncodedHash = [Convert]::ToBase64String($CalculatedHash)
    $Authorization = 'SharedKey {0}:{1}' -f $WorkspaceId, $EncodedHash
    
    # Create headers
    $Headers = @{
        "Authorization" = $Authorization
        "Log-Type" = $LogType
        "x-ms-date" = $Date
        "time-generated-field" = "TimeGenerated"
    }
    
    # Send to Azure Monitor
    $Uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $Resource + "?api-version=2016-04-01"
    
    try {
        Invoke-RestMethod -Uri $Uri -Method $Method -ContentType $ContentType -Headers $Headers -Body $Body
    }
    catch {
        throw "Failed to send data to Azure Monitor: $($_.Exception.Message)"
    }
}
